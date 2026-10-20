using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class UserSettingsStore(IConfiguration configuration)
{
    public async Task<CardOrderResponse?> GetCardOrderAsync(string ntName, CancellationToken token)
    {
        await using var connection = await OpenAsync(token);
        var userId = await GetUserIdAsync(connection, ntName, token);
        if (userId is null) return null;
        var rows = (await connection.QueryAsync<CardOrderRow>(Command(
            "Portal.UserCardOrder_get", new { UserId = userId.Value }, token))).AsList();
        if (rows.Count == 0) throw new InvalidOperationException("No active workspace cards are configured.");
        return new(rows.Select(row => row.CardKey).ToArray(),
            rows.Select(row => new WorkspaceCardDefinition(row.CardKey, row.CardName, row.IsFixed, row.DisplayOrder, row.IsCustom, row.UserCardId)).ToArray(), rows.Any(row => row.IsSaved),
            rows.Max(row => row.LastChangeAt));
    }

    public async Task<bool> SaveCardOrderAsync(string ntName, string[] cardKeys, CancellationToken token)
    {
        await using var connection = await OpenAsync(token);
        var userId = await GetUserIdAsync(connection, ntName, token);
        if (userId is null) return false;
        var cards = new DataTable();
        cards.Columns.Add("SortOrder", typeof(int));
        cards.Columns.Add("CardKey", typeof(string));
        for (var index = 0; index < cardKeys.Length; index++) cards.Rows.Add(index, cardKeys[index]);
        await connection.ExecuteAsync(Command("Portal.UserCardOrder_set",
            new { UserId = userId.Value, Cards = cards.AsTableValuedParameter("Portal.CardOrderInput") }, token));
        return true;
    }

    private sealed record CardOrderRow(string CardKey, string CardName, bool IsFixed, int DisplayOrder, bool IsCustom, int? UserCardId, bool IsSaved, DateTime? LastChangeAt);

    public async Task<IReadOnlyList<ThemeDefinition>> GetThemesAsync(string ntName, CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var userId=await GetUserIdAsync(connection,ntName,cancellationToken);
        if(userId is null)return [];
        var themes = (await connection.QueryAsync<ThemeDefinition>(Command("Master.Themes_getAll", new {UserId=userId.Value}, cancellationToken))).AsList();
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
