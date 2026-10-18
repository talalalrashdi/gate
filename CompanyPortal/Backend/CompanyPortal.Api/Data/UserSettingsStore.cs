using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class UserSettingsStore(IConfiguration configuration)
{
    public async Task<ThemeSettingsResponse?> GetThemeAsync(string ntName, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var userId = await GetUserIdAsync(connection, ntName, cancellationToken);
        if (userId is null) return null;

        var theme = await connection.QuerySingleOrDefaultAsync<string>(Command(
            "Portal.UserSettings_getTheme", new { UserId = userId.Value }, cancellationToken));
        return new ThemeSettingsResponse(theme ?? "majestic", theme is not null);
    }

    public async Task<bool> SaveThemeAsync(string ntName, string theme, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var userId = await GetUserIdAsync(connection, ntName, cancellationToken);
        if (userId is null) return false;

        await connection.ExecuteAsync(Command("Portal.UserSettings_setTheme",
            new { UserId = userId.Value, Theme = theme }, cancellationToken));
        return true;
    }

    private async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
        try
        {
            await connection.OpenAsync(cancellationToken);
            return connection;
        }
        catch { await connection.DisposeAsync(); throw; }
    }

    private static Task<int?> GetUserIdAsync(SqlConnection connection, string ntName, CancellationToken token) =>
        connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername", new { Username = ntName }, token));

    private static CommandDefinition Command(string name, object parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token);
}
