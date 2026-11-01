using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;
public sealed class AdminPermissionsStore(IConfiguration configuration)
{
    public sealed record Grant(int AdminSectionRoleId,string RoleName,string SectionKey,bool Active,DateTime LastChangeAt);
    private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal"));
    private static CommandDefinition Cmd(string sp,object? args,CancellationToken token)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
    public async Task<object> GetAsync(CancellationToken token)
    {
        await using var c=Connection();
        var roles=(await c.QueryAsync<string>(Cmd("Security.Roles_getForAdministration",null,token))).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
        var grants=(await c.QueryAsync<Grant>(Cmd("Portal.AdminSectionRoles_Get",null,token))).ToArray();
        return new{roles=roles.Select(name=>new{roleName=name,isSuperAdmin=name=="CompanyPortal.Admin",sections=grants.Where(g=>g.Active&&g.RoleName==name).Select(g=>g.SectionKey).ToArray()}),sections=AdminSections.All.Where(s=>s!="permissions").ToArray()};
    }
    public async Task SaveAsync(string role,string[] sections,CancellationToken token)
    {await using var c=Connection();await c.ExecuteAsync(Cmd("Portal.AdminSectionRoles_Save",new{RoleName=role,SectionsJson=JsonSerializer.Serialize(sections)},token));}
}
