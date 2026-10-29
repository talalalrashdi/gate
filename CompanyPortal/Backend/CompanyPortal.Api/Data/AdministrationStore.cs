using System.Data;
using System.Text.Json;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

/// <summary>Administration section keys. CompanyPortal.Admin manages all of them; Portal.AdminSectionRoles can grant single sections to other roles.</summary>
public static class AdminSections
{
    public static readonly string[] All = ["cards","applications","documents","safety","fixed-orders","header-content","notices","alerts","media","images","themes","events"];
}

public sealed record AdminAccess(bool IsSuperAdmin, IReadOnlySet<string> Sections)
{
    public bool CanManage(string section) => IsSuperAdmin || Sections.Contains(section);
    public string[] GetManagedSections() => AdminSections.All.Where(CanManage).ToArray();
}

public sealed class AdministrationStore(IConfiguration configuration)
{
    // One round trip; no cache, so a revoked role applies on the next request.
    public async Task<AdminAccess> GetAccessAsync(string ntName, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        using var results = await connection.QueryMultipleAsync(Command("Portal.AdminAccess_get", new { Username = ntName }, token));
        var superAdmin = await results.ReadSingleAsync<bool>();
        var sections = (await results.ReadAsync<string>()).Where(AdminSections.All.Contains).ToHashSet(StringComparer.Ordinal);
        return new(superAdmin, sections);
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

    public async Task<int> SaveCardAsync(int? id, SaveMasterCardRequest request, string changedBy, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        return await connection.QuerySingleAsync<int>(Command("Master.Cards_save", new { CardId = id, CardName = request.CardName.Trim(),
            request.IsFixed, request.DisplayOrder, request.Active, request.Audience,
            AppsJson = JsonSerializer.Serialize(request.AppIds), RolesJson = JsonSerializer.Serialize(request.RoleNames), ChangedBy = changedBy }, token));
    }

    public async Task<IReadOnlyList<AuthorizedApplication>> GetApplicationsAsync(CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        return (await connection.QueryAsync<AuthorizedApplication>(Command("Security.Apps_getForAdministration",null,token))).AsList();
    }

    private sealed record CardRow(int CardId,string CardKey,string CardName,int DisplayOrder,bool IsFixed,DateTime LastChangeAt,string CardType,bool Active,string Audience);

    public async Task<ApplicationDirectoryAdministration> GetApplicationDirectoryAsync(CancellationToken token)
    {
        await using var connection=Connection(); await connection.OpenAsync(token);
        using var results=await connection.QueryMultipleAsync(Command("Master.Applications_adminGet",null,token));
        var apps=(await results.ReadAsync<AdminDirectoryApplication>()).ToArray();
        var categories=(await results.ReadAsync<ApplicationCategory>()).ToArray();
        return new(apps,categories);
    }

    public async Task SaveApplicationDetailsAsync(int id,SaveApplicationDetailsRequest request,string changedBy,CancellationToken token)
    {
        await using var connection=Connection(); await connection.OpenAsync(token);
        await connection.ExecuteAsync(Command("Master.Applications_save",new {AppId=id,request.Description,request.CategoryId,ChangedBy=changedBy},token));
    }

    public async Task<int> SaveApplicationCategoryAsync(int? id,SaveApplicationCategoryRequest request,string changedBy,CancellationToken token)
    {
        await using var connection=Connection(); await connection.OpenAsync(token);
        return await connection.QuerySingleAsync<int>(Command("Master.ApplicationCategories_save",new {CategoryId=id,request.CategoryName,request.DisplayOrder,request.Active,ChangedBy=changedBy},token));
    }
    private sealed record CardApp(int CardId,int AppId);
    private sealed record CardRole(int CardId,string RoleName);

    private SqlConnection Connection() => new(configuration.GetConnectionString("CompanyPortal")
        ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string name, object? parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token);
}
