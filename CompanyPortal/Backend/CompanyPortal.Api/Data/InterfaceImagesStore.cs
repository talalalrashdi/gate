using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class InterfaceImagesStore(IConfiguration configuration)
{
    private SqlConnection Connection() => new(configuration.GetConnectionString("CompanyPortal")
        ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string name, object? parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 20, cancellationToken: token);

    public async Task<ImageAdministration> GetAsync(CancellationToken token)
    {
        await using var connection = Connection();
        var images = (await connection.QueryAsync<PortalImage>(Command("Master.Images_getAll", null, token))).AsList();
        using var rows = await connection.QueryMultipleAsync(Command("Master.ImageGroups_getAll", null, token));
        return new(images, (await rows.ReadAsync<ImageGroup>()).AsList(), (await rows.ReadAsync<ImageGroupItem>()).AsList(), (await rows.ReadAsync<ImageTheme>()).AsList());
    }
    public async Task<int> AddAsync(string name, ValidatedImage image, ValidatedImage? thumbnail, string changedBy, CancellationToken token)
    {
        await using var connection = Connection();
        return await connection.QuerySingleAsync<int>(Command("Master.Images_add", new { ImageName = name, image.ContentType, ImageData = image.Data, PixelWidth = image.Width, PixelHeight = image.Height, ChangedBy = changedBy,
            ThumbnailData = thumbnail?.Data, ThumbnailType = thumbnail?.ContentType }, token));
    }
    // False when the image is missing/deleted or already has a preview copy (set once only).
    public async Task<bool> SetThumbnailAsync(int id, ValidatedImage thumbnail, CancellationToken token)
    {
        await using var connection = Connection();
        return await connection.QuerySingleAsync<bool>(Command("Master.Images_setThumbnail", new { ImageId = id, ThumbnailData = thumbnail.Data, ThumbnailType = thumbnail.ContentType }, token));
    }
    public async Task<bool> DeleteAsync(int id, string changedBy, CancellationToken token)
    {
        await using var connection = Connection();
        return await connection.QuerySingleAsync<bool>(Command("Master.Images_delete", new { ImageId = id, ChangedBy = changedBy }, token));
    }
    public async Task<int> SaveGroupAsync(int? id, SaveImageGroup request, string changedBy, CancellationToken token)
    {
        var items = new DataTable();
        items.Columns.Add("ImageId", typeof(int)); items.Columns.Add("DisplayOrder", typeof(int)); items.Columns.Add("Active", typeof(bool));
        foreach (var item in request.Items) items.Rows.Add(item.ImageId, item.DisplayOrder, item.Active!.Value);
        await using var connection = Connection();
        return await connection.QuerySingleAsync<int>(Command("Master.ImageGroups_save", new { ImageGroupId = id, GroupName = request.GroupName.Trim(), request.RotateImages, request.RotationSeconds, request.DefaultImageId, request.Active, Items = items.AsTableValuedParameter("Master.ImageSelection"), ChangedBy = changedBy }, token));
    }
    public async Task<ThemeImages> ThemeAsync(int id, string account, CancellationToken token)
    {
        await using var connection = Connection();
        var userId=await connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new {Username=account},token));
        using var rows = await connection.QueryMultipleAsync(Command("Master.Themes_getImages", new { ThemeId = id,UserId=userId }, token));
        var settings=await rows.ReadSingleOrDefaultAsync<ThemeImageSettings>();
        var items=(await rows.ReadAsync<ThemeImage>()).ToArray();
        rows.Dispose();
        var positions=(await connection.QueryAsync<PositionRow>(Command("Master.ThemeImagePositions_Get",new {ThemeId=id},token))).ToDictionary(p=>p.ImageId);
        return new(settings,items.Select(i=>positions.TryGetValue(i.ImageId,out var p)?i with {FocalX=p.FocalX,FocalY=p.FocalY}:i).ToArray());
    }
    private sealed record PositionRow(int ThemeId,int ImageId,decimal FocalX,decimal FocalY);
    public sealed record Content(byte[] ImageData, string ContentType);
    public async Task<Content?> ContentAsync(int id, bool admin, string account, CancellationToken token, bool thumbnail = false)
    {
        await using var connection = Connection();
        var userId=await connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new {Username=account},token));
        return await connection.QuerySingleOrDefaultAsync<Content>(Command(thumbnail ? "Master.Images_getThumbnail" : "Master.Images_getContent", new { ImageId = id, IsAdmin = admin,UserId=userId }, token));
    }
}
