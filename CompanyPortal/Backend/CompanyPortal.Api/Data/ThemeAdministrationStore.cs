using System.Data;
using System.Text.Json;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class ThemeAdministrationStore(IConfiguration configuration)
{
    private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")??throw new InvalidOperationException("CompanyPortal connection string is missing."));
    public async Task<IReadOnlyList<AdminTheme>> GetAsync(CancellationToken token)
    {
        await using var connection=Connection();
        return (await connection.QueryAsync<AdminTheme>(new CommandDefinition("Master.Themes_getForAdministration",commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).AsList();
    }
    public async Task<int> SaveAsync(int? id,SaveAdminTheme request,CancellationToken token)
    {
        await using var connection=Connection();
        return await connection.QuerySingleAsync<int>(new CommandDefinition("Master.Themes_save",new {
            ThemeId=id,ThemeName=request.ThemeName.Trim(),request.LayoutKey,request.DisplayOrder,request.Active,request.IsDefault,
            PrimaryColor=request.PrimaryColor?.ToUpperInvariant(),AccentColor=request.AccentColor?.ToUpperInvariant(),BackgroundColor=request.BackgroundColor?.ToUpperInvariant(),
            request.OverlayOpacity,request.ForegroundPreset,request.ImagePresentation,request.ImageGroupId,request.Visibility,PreviewRolesJson=JsonSerializer.Serialize(request.PreviewRoles.Select(r=>r.Trim()))
        },commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
    }
    public async Task<bool> DeleteAsync(int id,CancellationToken token)
    {
        await using var connection=Connection();
        return await connection.QuerySingleAsync<bool>(new CommandDefinition("Master.Themes_delete",new {ThemeId=id},commandType:CommandType.StoredProcedure,cancellationToken:token));
    }
    public async Task ApplyToAllAsync(int id,CancellationToken token)
    {
        await using var connection=Connection();
        await connection.ExecuteAsync(new CommandDefinition("Master.Themes_applyToAll",new {ThemeId=id},commandType:CommandType.StoredProcedure,cancellationToken:token));
    }
}
