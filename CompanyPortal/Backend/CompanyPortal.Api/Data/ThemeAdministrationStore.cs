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
        var themes=(await connection.QueryAsync<AdminTheme>(new CommandDefinition("Master.Themes_getForAdministration",commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).AsList();
        var positions=(await connection.QueryAsync<PositionRow>(new CommandDefinition("Master.ThemeImagePositions_Get",commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).ToLookup(p=>p.ThemeId);
        return themes.Select(t=>t with {ImagePositions=positions[t.ThemeId].Select(p=>new ThemeImagePosition{ImageId=p.ImageId,FocalX=p.FocalX,FocalY=p.FocalY}).ToArray()}).ToArray();
    }
    public async Task<int> SaveAsync(int? id,SaveAdminTheme request,string changedBy,CancellationToken token)
    {
        await using var connection=Connection();
        return await connection.QuerySingleAsync<int>(new CommandDefinition("Master.Themes_save",new {
            ThemeId=id,ThemeName=request.ThemeName.Trim(),request.LayoutKey,request.DisplayOrder,request.Active,request.IsDefault,
            PrimaryColor=request.PrimaryColor?.ToUpperInvariant(),AccentColor=request.AccentColor?.ToUpperInvariant(),BackgroundColor=request.BackgroundColor?.ToUpperInvariant(),
            request.OverlayOpacity,request.ForegroundPreset,request.ImagePresentation,request.ImageGroupId,request.Visibility,PreviewRolesJson=JsonSerializer.Serialize(request.PreviewRoles.Select(r=>r.Trim())),ChangedBy=changedBy,
            ImagePositionsJson=request.ImagePositions is null?null:JsonSerializer.Serialize(request.ImagePositions)
        },commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
    }
    private sealed record PositionRow(int ThemeId,int ImageId,decimal FocalX,decimal FocalY);
    public async Task<IReadOnlyList<string>> GetKnownRolesAsync(string username,CancellationToken token)
    {
        await using var connection=Connection();
        return (await connection.QueryAsync<string>(new CommandDefinition("Portal.KnownRoles_get",new {Username=username},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).AsList();
    }
    public async Task<bool> DeleteAsync(int id,string changedBy,CancellationToken token)
    {
        await using var connection=Connection();
        return await connection.QuerySingleAsync<bool>(new CommandDefinition("Master.Themes_delete",new {ThemeId=id,ChangedBy=changedBy},commandType:CommandType.StoredProcedure,cancellationToken:token));
    }
    public async Task ApplyToAllAsync(int id,string changedBy,CancellationToken token)
    {
        await using var connection=Connection();
        await connection.ExecuteAsync(new CommandDefinition("Master.Themes_applyToAll",new {ThemeId=id,ChangedBy=changedBy},commandType:CommandType.StoredProcedure,cancellationToken:token));
    }
}
