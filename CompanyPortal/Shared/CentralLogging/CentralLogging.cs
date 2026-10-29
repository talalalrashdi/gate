using System.Diagnostics;
using System.Data;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Channels;
using Microsoft.Data.SqlClient;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CompanyPortal.Logging;

public static class CentralLoggingExtensions
{
    public static IServiceCollection AddCentralErrorLogging(this IServiceCollection services)
    {
        services.AddHttpContextAccessor();
        services.Configure<Microsoft.AspNetCore.Mvc.MvcOptions>(options => options.Filters.Add(new ReferenceFilter()));
        services.AddSingleton<CentralErrorLogger>();
        services.AddSingleton<ILoggerProvider>(s => s.GetRequiredService<CentralErrorLogger>());
        services.AddSingleton<IHostedService>(s => s.GetRequiredService<CentralErrorLogger>());
        return services;
    }
}

internal sealed class ReferenceFilter : Microsoft.AspNetCore.Mvc.Filters.IAlwaysRunResultFilter
{
    public void OnResultExecuting(Microsoft.AspNetCore.Mvc.Filters.ResultExecutingContext context)
    {
        if (context.Result is Microsoft.AspNetCore.Mvc.ObjectResult { Value: Microsoft.AspNetCore.Mvc.ProblemDetails problem })
            problem.Extensions["reference"] = context.HttpContext.TraceIdentifier;
    }
    public void OnResultExecuted(Microsoft.AspNetCore.Mvc.Filters.ResultExecutedContext context) { }
}

// Shared source linked into both solutions; no separate deployed logging service.
public sealed class CentralErrorLogger : BackgroundService, ILoggerProvider
{
    private readonly IConfiguration configuration;
    private readonly IHttpContextAccessor accessor;
    private readonly IHostEnvironment environment;
    private readonly Channel<Entry> queue = Channel.CreateBounded<Entry>(new BoundedChannelOptions(512)
    { SingleReader = true, FullMode = BoundedChannelFullMode.Wait });
    private readonly object fileLock = new();
    private readonly string folder;
    private DateTime retryAfter;
    private bool Enabled => configuration.GetValue("CentralLogging:Enabled", true);

    public CentralErrorLogger(IConfiguration configuration, IHttpContextAccessor accessor, IHostEnvironment environment)
    {
        this.configuration = configuration; this.accessor = accessor; this.environment = environment;
        folder = Path.GetFullPath(configuration["CentralLogging:FallbackDirectory"] ?? "App_Data/Logs", environment.ContentRootPath);
    }
    public ILogger CreateLogger(string categoryName) => new Sink(this, categoryName);

    private sealed class Sink(CentralErrorLogger owner, string category) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel level) => owner.Enabled && level >= LogLevel.Warning;
        public void Log<TState>(LogLevel level, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(level) || (exception is null && level < LogLevel.Error)) return;
            var context = owner.accessor.HttpContext;
            // Closing the browser / cancelling a request is not a server fault.
            if (exception is OperationCanceledException && context?.RequestAborted.IsCancellationRequested == true) return;
            try
            {
                var sql = FindSql(exception);
                var method = exception is null ? null : new StackTrace(exception, true).GetFrames()?
                    .FirstOrDefault(f => f.GetMethod()?.DeclaringType?.Namespace?.StartsWith("CompanyPortal", StringComparison.Ordinal) == true);
                var name = context?.User.Identity?.IsAuthenticated == true ? context.User.Identity.Name : null;
                var entry = new Entry(DateTimeOffset.UtcNow, context?.TraceIdentifier ?? Guid.NewGuid().ToString("N"),
                    category, level.ToString(), Limit(Clean(formatter(state, exception)), 8000),
                    exception?.GetType().FullName, Limit(Clean(exception?.ToString()), 64000), method?.GetFileName() is string file ? Path.GetFileName(file) : null,
                    method?.GetMethod()?.ToString() ?? exception?.TargetSite?.ToString(), name,
                    context?.Request.Method, context?.Request.Path.Value, context?.GetEndpoint()?.DisplayName,
                    sql is null ? null : new SqlFailure(sql.Number, sql.Class, sql.State, sql.Procedure, sql.LineNumber, Clean(sql.Message), sql.Server));
                if (!owner.queue.Writer.TryWrite(entry)) owner.Fallback(entry, "Central logging queue is full; recorded locally.");
            }
            catch (Exception e) { Console.Error.WriteLine("Central logging capture failed: " + e.GetType().Name); }
        }
    }
    public sealed record SqlFailure(int Number, byte Severity, byte State, string? Procedure, int Line, string? Message, string? Server);
    public sealed record Entry(DateTimeOffset At, string Reference, string Category, string Level, string? Message,
        string? ExceptionType, string? Exception, string? File, string? Method, string? Account,
        string? HttpMethod, string? Path, string? Endpoint, SqlFailure? Sql);

    private static SqlException? FindSql(Exception? e)
    {
        if (e is SqlException sql) return sql;
        if (e is AggregateException aggregate)
            foreach (var inner in aggregate.InnerExceptions) if (FindSql(inner) is { } found) return found;
        return e?.InnerException is { } next ? FindSql(next) : null;
    }
    // Never collect request bodies, cookies, authorization headers or query strings.
    private static string? Clean(string? value) => value is null ? null : Regex.Replace(value,
        @"(?i)\b(password|pwd|access_token|client_secret|authorization)\s*[:=]\s*(""[^""]*""|'[^']*'|[^;\s]+)", "$1=[REDACTED]");
    private static string? Limit(string? value, int length) => value?.Length > length ? value[..length] : value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await foreach (var entry in queue.Reader.ReadAllAsync(stoppingToken))
            {
                if (DateTime.UtcNow < retryAfter) { Fallback(entry, "CentralLog is temporarily unavailable; recorded locally."); continue; }
                try { await Save(entry, stoppingToken); }
                catch (Exception e)
                {
                    retryAfter = DateTime.UtcNow.AddSeconds(30);
                    Fallback(entry, "CentralLog write failed: " + e.GetType().Name + ". Check connection, database procedures and EXECUTE permission.");
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
        finally { while (queue.Reader.TryRead(out var pending)) Fallback(pending, "Application stopping; recorded locally."); }
    }
    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        queue.Writer.TryComplete();
        if (ExecuteTask is { } task) await Task.WhenAny(task, Task.Delay(TimeSpan.FromSeconds(5), cancellationToken));
        await base.StopAsync(cancellationToken);
    }

    private async Task Save(Entry entry, CancellationToken token)
    {
        var connectionString = configuration.GetConnectionString("CentralLog");
        if (string.IsNullOrWhiteSpace(connectionString)) throw new InvalidOperationException("CentralLog connection string is missing.");
        var builder = new SqlConnectionStringBuilder(connectionString) { ConnectTimeout = 3 };
        await using var connection = new SqlConnection(builder.ConnectionString);
        await connection.OpenAsync(token);
        var userId = await ResolveUser(entry.Account, token);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        long? databaseErrorId = null;
        if (entry.Sql is { } sql)
        {
            await using var command = Procedure(connection, "dbo.DatabaseError_Insert", transaction);
            Add(command, "DBName", SqlDbType.NVarChar, SourceDatabase(), 100);
            Add(command, "ErrorNumber", SqlDbType.Int, sql.Number);
            Add(command, "ErrorSeverity", SqlDbType.Int, (int)sql.Severity);
            Add(command, "ErrorState", SqlDbType.Int, (int)sql.State);
            Add(command, "ErrorProcedure", SqlDbType.NVarChar, sql.Procedure, 128);
            Add(command, "ErrorLine", SqlDbType.Int, sql.Line);
            Add(command, "ErrorMessage", SqlDbType.NVarChar, sql.Message, 4000);
            Add(command, "WorkStation", SqlDbType.NVarChar, Environment.MachineName, 100);
            Add(command, "NTUserName", SqlDbType.NVarChar, entry.Account, 100);
            databaseErrorId = Convert.ToInt64(await command.ExecuteScalarAsync(token));
        }
        await using var app = Procedure(connection, "dbo.ApplicationError_Insert", transaction);
        Add(app, "SystemID", SqlDbType.Int, configuration.GetValue("CentralLogging:SystemId", 9999));
        Add(app, "NameSpace", SqlDbType.NVarChar, entry.Category, 150);
        Add(app, "FileName", SqlDbType.NVarChar, entry.File, 150);
        Add(app, "ExceptionType", SqlDbType.NVarChar, entry.ExceptionType, 150);
        Add(app, "MethodSignature", SqlDbType.NVarChar, entry.Method, 400);
        Add(app, "StackTrace", SqlDbType.NVarChar, entry.Exception, -1);
        Add(app, "ErrorMessage", SqlDbType.NVarChar, entry.Message + (entry.Sql is { } s ? $" SQL {s.Number}, procedure {s.Procedure}: {s.Message}" : ""), 500);
        Add(app, "ExtraDetails", SqlDbType.NVarChar, JsonSerializer.Serialize(new {
            entry.Reference, entry.At, Application = environment.ApplicationName, environment.EnvironmentName,
            Version = System.Reflection.Assembly.GetEntryAssembly()?.GetName().Version?.ToString(),
            entry.Level, entry.HttpMethod, entry.Path, entry.Endpoint, DatabaseErrorId = databaseErrorId,
            SqlServer = entry.Sql?.Server, OriginalMessage = entry.Message, MachineName = Environment.MachineName }), -1);
        Add(app, "UserId", SqlDbType.Int, userId);
        Add(app, "WorkStation", SqlDbType.NVarChar, Environment.MachineName, 100);
        Add(app, "NtUserName", SqlDbType.NVarChar, entry.Account, 100);
        await app.ExecuteNonQueryAsync(token);
        await transaction.CommitAsync(token);
    }
    private string? SourceDatabase()
    {
        try { return new SqlConnectionStringBuilder(configuration.GetConnectionString("CompanyPortal") ?? "").InitialCatalog is { Length: > 0 } name ? name : "CompanyPortal"; }
        catch { return "CompanyPortal"; }
    }
    private async Task<int?> ResolveUser(string? account, CancellationToken token)
    {
        if (string.IsNullOrEmpty(account) || string.IsNullOrEmpty(configuration.GetConnectionString("CompanyPortal"))) return null;
        try
        {
            var builder = new SqlConnectionStringBuilder(configuration.GetConnectionString("CompanyPortal")) { ConnectTimeout = 2 };
            await using var connection = new SqlConnection(builder.ConnectionString);
            await connection.OpenAsync(token);
            await using var command = Procedure(connection, "Security.User_getByUsername");
            Add(command, "Username", SqlDbType.NVarChar, account, 256);
            var value = await command.ExecuteScalarAsync(token);
            return value is null or DBNull ? null : Convert.ToInt32(value);
        }
        catch { return null; } // Identity lookup failure must never prevent recording the original fault.
    }
    private static SqlCommand Procedure(SqlConnection connection, string name, SqlTransaction? transaction = null) => new(name, connection, transaction)
        { CommandType = CommandType.StoredProcedure, CommandTimeout = 3 };
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = command.Parameters.Add("@" + name, type);
        if (size != 0) parameter.Size = size;
        parameter.Value = value is string text && size > 0 ? Limit(text, size)! : value ?? DBNull.Value;
    }
    private void Fallback(Entry entry, string reason)
    {
        try
        {
            lock (fileLock)
            {
                Directory.CreateDirectory(folder);
                var path = Path.Combine(folder, "errors.jsonl");
                if (File.Exists(path) && new FileInfo(path).Length >= 10 * 1024 * 1024)
                {
                    for (var i = 8; i >= 1; i--)
                    {
                        var older = Path.Combine(folder, $"errors.{i}.jsonl");
                        if (File.Exists(older)) File.Move(older, Path.Combine(folder, $"errors.{i + 1}.jsonl"), true);
                    }
                    File.Move(path, Path.Combine(folder, "errors.1.jsonl"), true);
                }
                File.AppendAllText(path, JsonSerializer.Serialize(new { Reason = reason, Application = environment.ApplicationName,
                    SystemID = configuration.GetValue("CentralLogging:SystemId", 9999), WorkStation = Environment.MachineName, Error = entry }) + Environment.NewLine);
            }
        }
        catch (Exception error) { Console.Error.WriteLine($"CentralLog and local fallback unavailable. Reference {entry.Reference}. {error.GetType().Name}"); }
    }
}
