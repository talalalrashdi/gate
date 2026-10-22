using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class UserCardsStore(IConfiguration configuration)
{
    public sealed record ApplicationAccess(int AppId, string AppName, string LaunchUrl);
    private sealed record CardRow(int UserCardId, string CardName, DateTime LastChangeAt);
    private sealed record CardAppRow(int UserCardId, int AppId, string AppName);

    public async Task<IReadOnlyList<DirectoryApplication>?> GetDirectoryAsync(string ntName,CancellationToken token)
    {
        await using var connection=await OpenAsync(token);
        var userId=await ResolveAsync(connection,ntName,token);
        if(userId is null) return null;
        return (await connection.QueryAsync<DirectoryApplication>(Command("Master.Applications_getForUser",new {UserId=userId.Value},token))).AsList();
    }

    public async Task<IReadOnlyList<ApplicationAccess>?> GetApplicationsAsync(string ntName, CancellationToken token)
    {
        await using var connection = await OpenAsync(token);
        var userId = await ResolveAsync(connection, ntName, token);
        if (userId is null) return null;
        return (await connection.QueryAsync<ApplicationAccess>(Command("Security.Apps_getForUser", new { UserId = userId.Value }, token))).AsList();
    }

    public async Task<IReadOnlyList<UserCardResponse>?> GetAsync(string ntName, CancellationToken token)
    {
        await using var connection = await OpenAsync(token);
        var userId = await ResolveAsync(connection, ntName, token);
        if (userId is null) return null;
        using var results = await connection.QueryMultipleAsync(Command("Portal.UserCards_get", new { UserId = userId.Value }, token));
        var cards = (await results.ReadAsync<CardRow>()).AsList();
        var apps = (await results.ReadAsync<CardAppRow>()).ToLookup(app => app.UserCardId);
        return cards.Select(card => new UserCardResponse(card.UserCardId, card.CardName,
            apps[card.UserCardId].Select(app => new AuthorizedApplication(app.AppId, app.AppName)).ToArray(), card.LastChangeAt)).ToArray();
    }

    public async Task<int?> SaveAsync(string ntName, int? id, SaveUserCardRequest request, CancellationToken token)
    {
        await using var connection = await OpenAsync(token);
        var userId = await ResolveAsync(connection, ntName, token);
        if (userId is null) return null;
        var apps = new DataTable();
        apps.Columns.Add("AppId", typeof(int));
        foreach (var appId in request.AppIds) apps.Rows.Add(appId);
        return await connection.QuerySingleAsync<int>(Command("Portal.UserCards_save", new
        {
            UserId = userId.Value, UserCardId = id, request.CardName,
            Apps = apps.AsTableValuedParameter("Portal.AppIdInput")
        }, token));
    }

    public async Task<bool> DeleteAsync(string ntName, int id, CancellationToken token)
    {
        await using var connection = await OpenAsync(token);
        var userId = await ResolveAsync(connection, ntName, token);
        if (userId is null) return false;
        await connection.ExecuteAsync(Command("Portal.UserCards_delete", new { UserId = userId.Value, UserCardId = id }, token));
        return true;
    }

    private async Task<SqlConnection> OpenAsync(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
        try { await connection.OpenAsync(token); return connection; }
        catch { await connection.DisposeAsync(); throw; }
    }
    private static Task<int?> ResolveAsync(SqlConnection connection, string ntName, CancellationToken token) =>
        connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername", new { Username = ntName }, token));
    private static CommandDefinition Command(string name, object parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token);
}
