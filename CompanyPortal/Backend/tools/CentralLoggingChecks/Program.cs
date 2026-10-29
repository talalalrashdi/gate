using CompanyPortal.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Security.Principal;
using System.Text.Json;

var connectionString = "Server=localhost;Database=CentralLog;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;";
var reference = "CentralLoggingCheck-" + Guid.NewGuid().ToString("N");
var folder = Path.Combine(Path.GetTempPath(), reference);
if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Run the Windows SQL authentication checks on Windows.");
var identity = WindowsIdentity.GetCurrent().Name;
IHost Create(string centralConnection, bool enabled = true)
{
    var builder = Host.CreateApplicationBuilder();
    builder.Configuration.AddInMemoryCollection(new Dictionary<string,string?> {
        ["ConnectionStrings:CentralLog"] = centralConnection,
        ["CentralLogging:Enabled"] = enabled.ToString(), ["CentralLogging:SystemId"] = "9999",
        ["CentralLogging:FallbackDirectory"] = folder });
    builder.Logging.ClearProviders();
    builder.Services.AddCentralErrorLogging();
    var host = builder.Build();
    host.Services.GetRequiredService<IHttpContextAccessor>().HttpContext = new DefaultHttpContext {
        TraceIdentifier = reference, User = new GenericPrincipal(new GenericIdentity(identity, "test"), []) };
    return host;
}
await using var sql = new SqlConnection(connectionString);
await sql.OpenAsync();
try
{
    using (var host = Create(connectionString))
    {
        await host.StartAsync();
        var options = host.Services.GetRequiredService<Microsoft.Extensions.Options.IOptions<Microsoft.AspNetCore.Mvc.MvcOptions>>().Value;
        var action = new Microsoft.AspNetCore.Mvc.ActionContext(host.Services.GetRequiredService<IHttpContextAccessor>().HttpContext!,
            new Microsoft.AspNetCore.Routing.RouteData(), new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor());
        var problem = new Microsoft.AspNetCore.Mvc.ProblemDetails { Status = 503 };
        var result = new Microsoft.AspNetCore.Mvc.Filters.ResultExecutingContext(action, [], new Microsoft.AspNetCore.Mvc.ObjectResult(problem), new object());
        foreach (var filter in options.Filters.OfType<Microsoft.AspNetCore.Mvc.Filters.IAlwaysRunResultFilter>()) filter.OnResultExecuting(result);
        if (!Equals(problem.Extensions["reference"], reference)) throw new Exception("ProblemDetails reference mismatch.");
        Console.WriteLine("PASS: MVC ProblemDetails Reference ID matches request.");
        var logger = host.Services.GetRequiredService<ILoggerFactory>().CreateLogger("CompanyPortal.Logging.Checks");
        logger.LogError(new InvalidOperationException("A safe test failure; Password=\"secret value\";"), "Central logging test operation failed.");
        try { await using var fail = new SqlCommand("SELECT * FROM dbo.CentralLoggingCheck_MissingTable_9999", sql); await fail.ExecuteNonQueryAsync(); }
        catch (SqlException error) { logger.LogError(error, "Central logging SQL test failed."); }
        logger.LogWarning(new HttpRequestException("Exchange test unavailable"), "Exchange test read failed.");
        logger.LogInformation("Do not save ordinary information.");
        logger.LogError(new OperationCanceledException(), "Cancellation without client disconnect is a failure.");
        var context = host.Services.GetRequiredService<IHttpContextAccessor>().HttpContext!;
        using var cancel = new CancellationTokenSource(); cancel.Cancel(); context.RequestAborted = cancel.Token;
        logger.LogError(new OperationCanceledException(), "Do not save cancelled browser request.");
        for (var attempt=0;attempt<40;attempt++)
        {
            await using var count = new SqlCommand("SELECT COUNT(*) FROM dbo.ApplicationError WHERE JSON_VALUE(ExtraDetails,'$.Reference')=@ref", sql);
            count.Parameters.AddWithValue("@ref", reference);
            if (Convert.ToInt32(await count.ExecuteScalarAsync()) == 4) break;
            await Task.Delay(250);
        }
        await host.StopAsync();
    }
    await using (var verify = new SqlCommand("SELECT SystemID,WorkStation,NtUserName,StackTrace,ExtraDetails FROM dbo.ApplicationError WHERE JSON_VALUE(ExtraDetails,'$.Reference')=@ref", sql))
    {
        verify.Parameters.AddWithValue("@ref", reference);
        await using var reader = await verify.ExecuteReaderAsync(); int rows=0, linked=0;
        while(await reader.ReadAsync())
        {
            rows++;
            if(reader.GetInt32(0)!=9999 || reader.GetString(1)!=Environment.MachineName || reader.GetString(2)!=identity) throw new Exception("Identity/SystemId/machine mismatch.");
            if(reader.GetString(3).Contains("secret value")) throw new Exception("Secret was not redacted.");
            using var json=JsonDocument.Parse(reader.GetString(4));
            if(json.RootElement.GetProperty("DatabaseErrorId").ValueKind==JsonValueKind.Number) linked++;
        }
        if(rows!=4 || linked!=1)throw new Exception($"Expected four errors/one SQL link; got {rows}/{linked}.");
        Console.WriteLine("PASS: central writes, actual Environment.MachineName, NTName, configurable SystemId, SQL linkage, redaction, warning exceptions, cancellation and information exclusion.");
    }
    using(var host=Create("Server=127.0.0.1,1;Database=CentralLog;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=1;"))
    {
        await host.StartAsync();
        host.Services.GetRequiredService<ILoggerFactory>().CreateLogger("CompanyPortal.Check").LogError(new Exception("Fallback check"), "CentralLog unavailable test");
        for(var i=0;i<40 && !File.Exists(Path.Combine(folder,"errors.jsonl"));i++)await Task.Delay(250);
        await host.StopAsync();
        var text=await File.ReadAllTextAsync(Path.Combine(folder,"errors.jsonl"));
        if(!text.Contains(Environment.MachineName)||!text.Contains(reference))throw new Exception("Fallback missing reference/machine.");
        Console.WriteLine("PASS: unavailable SQL produces local fallback with reference and machine name.");
    }
    var before=new FileInfo(Path.Combine(folder,"errors.jsonl")).Length;
    using(var host=Create("",false))
    {
        await host.StartAsync();
        host.Services.GetRequiredService<ILoggerFactory>().CreateLogger("CompanyPortal.Check").LogError(new Exception("Disabled check"),"Disabled check");
        await host.StopAsync();
    }
    if(new FileInfo(Path.Combine(folder,"errors.jsonl")).Length!=before)throw new Exception("Disabled logger wrote a file.");
    Console.WriteLine("PASS: Enabled=false suppresses writes.");
}
finally
{
    await using var cleanup=new SqlCommand("DELETE FROM dbo.DatabaseError WHERE DatabaseErrorID IN (SELECT TRY_CONVERT(bigint,JSON_VALUE(ExtraDetails,'$.DatabaseErrorId')) FROM dbo.ApplicationError WHERE JSON_VALUE(ExtraDetails,'$.Reference')=@ref); DELETE FROM dbo.ApplicationError WHERE JSON_VALUE(ExtraDetails,'$.Reference')=@ref;",sql);
    cleanup.Parameters.AddWithValue("@ref",reference);await cleanup.ExecuteNonQueryAsync();
    // Only the unique directory created by this test, containing its one fallback file.
    var file=Path.Combine(folder,"errors.jsonl");if(File.Exists(file))File.Delete(file);if(Directory.Exists(folder))Directory.Delete(folder);
}
