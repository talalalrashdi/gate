using System.Data;
using System.Text.Json;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class AdministrationStore(IConfiguration configuration)
{
    public async Task<bool> IsAdminAsync(string ntName, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        var userId = await connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername", new { Username = ntName }, token));
        if (userId is null) return false;
        var roles = await connection.QueryAsync<string>(Command("Security.UserRoles_get", new { UserId = userId.Value }, token));
        return roles.Contains("CompanyPortal.Admin", StringComparer.Ordinal);
    }

    public async Task<IReadOnlyList<MasterCard>> GetCardsAsync(CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        using var results = await connection.QueryMultipleAsync(Command("Master.Cards_get", null, token));
        var rows = (await results.ReadAsync<CardRow>()).AsList();
        var apps = (await results.ReadAsync<CardApp>()).ToLookup(row => row.CardId);
        var roles = (await results.ReadAsync<CardRole>()).ToLookup(row => row.CardId);
        return rows.Select(row => new MasterCard(row.CardId,row.CardKey,row.CardName,row.DisplayOrder,row.IsFixed,row.LastChangeAt,
            row.CardType,row.Active,row.Audience,apps[row.CardId].Select(app => app.AppId).ToArray(),roles[row.CardId].Select(role => role.RoleName).ToArray())).ToArray();
    }

    public async Task<int> SaveCardAsync(int? id, SaveMasterCardRequest request, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        return await connection.QuerySingleAsync<int>(Command("Master.Cards_save", new { CardId = id, CardName = request.CardName.Trim(),
            request.IsFixed, request.DisplayOrder, request.Active, request.Audience,
            AppsJson = JsonSerializer.Serialize(request.AppIds), RolesJson = JsonSerializer.Serialize(request.RoleNames) }, token));
    }

    public async Task<IReadOnlyList<AuthorizedApplication>> GetApplicationsAsync(CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        return (await connection.QueryAsync<AuthorizedApplication>(Command("Security.Apps_getForAdministration",null,token))).AsList();
    }

    private sealed record CardRow(int CardId,string CardKey,string CardName,int DisplayOrder,bool IsFixed,DateTime LastChangeAt,string CardType,bool Active,string Audience);
    private sealed record CardApp(int CardId,int AppId);
    private sealed record CardRole(int CardId,string RoleName);

    private SqlConnection Connection() => new(configuration.GetConnectionString("CompanyPortal")
        ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string name, object? parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token);
}
