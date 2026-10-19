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
    public async Task<int> AddAsync(string name, ValidatedImage image, CancellationToken token)
    {
        await using var connection = Connection();
        return await connection.QuerySingleAsync<int>(Command("Master.Images_add", new { ImageName = name, image.ContentType, ImageData = image.Data, PixelWidth = image.Width, PixelHeight = image.Height }, token));
    }
    public async Task<int> SaveGroupAsync(int? id, SaveImageGroup request, CancellationToken token)
    {
        var items = new DataTable();
        items.Columns.Add("ImageId", typeof(int)); items.Columns.Add("DisplayOrder", typeof(int)); items.Columns.Add("Active", typeof(bool));
        foreach (var item in request.Items) items.Rows.Add(item.ImageId, item.DisplayOrder, item.Active!.Value);
        await using var connection = Connection();
        return await connection.QuerySingleAsync<int>(Command("Master.ImageGroups_save", new { ImageGroupId = id, GroupName = request.GroupName.Trim(), request.RotateImages, request.RotationSeconds, request.DefaultImageId, request.Active, Items = items.AsTableValuedParameter("Master.ImageSelection") }, token));
    }
    public async Task AssignAsync(int id, int? groupId, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.ExecuteAsync(Command("Master.Themes_setImageGroup", new { ThemeId = id, ImageGroupId = groupId }, token));
    }
    public async Task<ThemeImages> ThemeAsync(int id, CancellationToken token)
    {
        await using var connection = Connection();
        using var rows = await connection.QueryMultipleAsync(Command("Master.Themes_getImages", new { ThemeId = id }, token));
        return new(await rows.ReadSingleOrDefaultAsync<ThemeImageSettings>(), (await rows.ReadAsync<ThemeImage>()).AsList());
    }
    public sealed record Content(byte[] ImageData, string ContentType);
    public async Task<Content?> ContentAsync(int id, bool admin, CancellationToken token)
    {
        await using var connection = Connection();
        return await connection.QuerySingleOrDefaultAsync<Content>(Command("Master.Images_getContent", new { ImageId = id, IsAdmin = admin }, token));
    }
}
