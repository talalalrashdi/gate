using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class UserSettingsStore(IConfiguration configuration)
{
    public async Task<IReadOnlyList<ThemeDefinition>> GetThemesAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var themes = (await connection.QueryAsync<ThemeDefinition>(Command("Master.Themes_getAll", new { }, cancellationToken))).AsList();
        if (themes.Count == 0 || themes.Count(theme => theme.IsDefault) != 1)
            throw new InvalidOperationException("Configure one active default theme.");
        return themes;
    }

    public async Task<ThemeSettingsResponse?> GetThemeAsync(string ntName, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var userId = await GetUserIdAsync(connection, ntName, cancellationToken);
        if (userId is null) return null;

        var setting = await connection.QuerySingleOrDefaultAsync<ThemeSettingsResponse>(Command(
            "Portal.UserSettings_getTheme", new { UserId = userId.Value }, cancellationToken));
        return setting ?? throw new InvalidOperationException("No active theme or default is available.");
    }

    public async Task<bool> SaveThemeAsync(string ntName, int themeId, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var userId = await GetUserIdAsync(connection, ntName, cancellationToken);
        if (userId is null) return false;

        await connection.ExecuteAsync(Command("Portal.UserSettings_setTheme",
            new { UserId = userId.Value, ThemeId = themeId }, cancellationToken));
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
