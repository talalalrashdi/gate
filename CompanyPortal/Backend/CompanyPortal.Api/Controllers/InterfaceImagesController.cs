using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

// Admin actions carry [AdminSection]; the theme editor also reads the library. The two employee
// endpoints (theme images, image content) authorize portal users in Execute.
[ApiController, Authorize, Route("api/admin/images"), RequestSizeLimit(12*1024*1024)]
public sealed class InterfaceImagesController(InterfaceImagesStore images, NewsStore users,
    IConfiguration configuration, ILogger<InterfaceImagesController> logger) : ControllerBase
{
    [HttpGet, AdminSection("admin-images", "images", "themes")]
    public Task<IActionResult> Get(CancellationToken token) => Execute(async _ => Ok(await images.GetAsync(token)), true, token);

    [HttpPost, Consumes("multipart/form-data"), RequestFormLimits(MultipartBodyLengthLimit = 11*1024*1024), AdminSection("admin-images", "images")]
    // IFormFile infers form-file binding; explicit FromForm breaks Swagger generation.
    // thumbnail: optional small preview copy made by the admin browser (see ImageValidation.ReadThumbnail).
    public Task<IActionResult> Upload(IFormFile file, IFormFile? thumbnail, CancellationToken token) => Execute(async _ =>
    {
        var limit = Math.Clamp(configuration.GetValue("InterfaceImages:MaximumUploadMb",10),1,10)*1024*1024;
        if (file.Length < 12 || file.Length > limit) return Problem(statusCode:400,title:$"Upload an image up to {limit/1024/1024} MB.");
        var name = Path.GetFileName(file.FileName.Replace('\\','/'));
        if (string.IsNullOrWhiteSpace(name) || name.Length > 200) return Problem(statusCode:400,title:"Image filename must contain 1–200 characters.");
        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory,token);
        var validated = ImageValidation.Read(memory.ToArray(),Path.GetExtension(name));
        var preview = thumbnail is null ? null : await ReadThumbnail(thumbnail,token);
        return Ok(new { imageId = await images.AddAsync(name,validated,preview,User.Identity!.Name!,token) });
    },true,token);

    [HttpPut("{id:int:min(1)}/thumbnail"), Consumes("multipart/form-data"), RequestSizeLimit(600*1024), AdminSection("admin-images", "images")]
    public Task<IActionResult> SetThumbnail(int id, IFormFile thumbnail, CancellationToken token) => Execute(async _ =>
        await images.SetThumbnailAsync(id,await ReadThumbnail(thumbnail,token),token) ? NoContent() : Problem(statusCode:409,title:"The image is missing or already has a preview copy."),true,token);

    private static async Task<ValidatedImage> ReadThumbnail(IFormFile file, CancellationToken token)
    {
        if (file.Length > ImageValidation.MaximumThumbnailBytes) throw new ArgumentException("The preview copy must be up to 512 KB.");
        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory,token);
        return ImageValidation.ReadThumbnail(memory.ToArray(),Path.GetExtension(Path.GetFileName(file.FileName.Replace('\\','/'))));
    }

    [HttpDelete("{id:int:min(1)}"), AdminSection("admin-images", "images")]
    public Task<IActionResult> Delete(int id, CancellationToken token) => Execute(async _ =>
        await images.DeleteAsync(id,User.Identity!.Name!,token) ? NoContent() : NotFound(),true,token);

    [HttpPost("groups"), Consumes("application/json"), RequestSizeLimit(32768), AdminSection("admin-images", "images")]
    public Task<IActionResult> CreateGroup(SaveImageGroup request, CancellationToken token) => Save(null,request,token);
    [HttpPut("groups/{id:int:min(1)}"), Consumes("application/json"), RequestSizeLimit(32768), AdminSection("admin-images", "images")]
    public Task<IActionResult> UpdateGroup(int id, SaveImageGroup request, CancellationToken token) => Save(id,request,token);
    private Task<IActionResult> Save(int? id, SaveImageGroup request, CancellationToken token) => Execute(async _ =>
    {
        if (string.IsNullOrWhiteSpace(request.GroupName) || request.Items.Any(i=>i is null) || request.Items.Select(i=>i.ImageId).Distinct().Count()!=request.Items.Length
            || request.Items.Select(i=>i.DisplayOrder).Distinct().Count()!=request.Items.Length)
            return Problem(statusCode:400,title:"Enter a group name and unique image positions.");
        return Ok(new { imageGroupId = await images.SaveGroupAsync(id,request,User.Identity!.Name!,token) });
    },true,token);

    [HttpGet("/api/themes/{id:int:min(1)}/images")]
    public Task<IActionResult> Theme(int id, CancellationToken token) => Execute(async _ => Ok(await images.ThemeAsync(id,User.Identity!.Name!,token)),false,token);

    [HttpGet("/api/images/{id:int:min(1)}/content")]
    public Task<IActionResult> Content(int id, CancellationToken token) => Image(id,false,token);
    // Preview copy; same access rule. Set once only, so it is cached like the full image.
    [HttpGet("/api/images/{id:int:min(1)}/thumbnail")]
    public Task<IActionResult> Thumbnail(int id, CancellationToken token) => Image(id,true,token);
    private Task<IActionResult> Image(int id, bool thumbnail, CancellationToken token) => Execute(async admin =>
    {
        var content = await images.ContentAsync(id,admin,User.Identity!.Name!,token,thumbnail);
        if (content is null) return NotFound();
        // Image bytes never change for an ImageId (no update path), so the browser may keep them.
        // Without this, the portal re-downloads each image on every rotation.
        Response.Headers.CacheControl="private, max-age=31536000, immutable";
        Response.Headers.XContentTypeOptions="nosniff";
        Response.Headers.ContentSecurityPolicy=content.ContentType=="image/svg+xml" && BundledArtwork.IsNationalDay(content.ImageData)
            ? "default-src 'none'; img-src data:; style-src 'unsafe-inline'; sandbox"
            : "default-src 'none'; style-src 'none'; sandbox";
        Response.Headers.ContentDisposition=$"inline; filename=\"portal-image-{id}\"";
        return File(content.ImageData,content.ContentType);
    },false,token);

    // adminAction: [AdminSection] already authorized. Otherwise portal users; image/theme admins may also read inactive images.
    private async Task<IActionResult> Execute(Func<bool,Task<IActionResult>> action, bool adminAction, CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var account=User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length>512) return Unauthorized();
        try
        {
            var admin = adminAction;
            if (!adminAction)
            {
                if (Request.Path.StartsWithSegments("/api/images"))
                {
                    var access = await HttpContext.GetAdminAccessAsync();
                    admin = access.CanManage("images") || access.CanManage("themes");
                }
                if (!admin && !await users.IsPortalUserAsync(account,token)) return Forbid();
            }
            return await action(admin);
        }
        catch (SqlException exception) when (exception.Number==50009) { return Problem(statusCode:409,title:"Remove the image from saved groups before deleting it."); }
        catch (SqlException exception) when (exception.Number==50013) { return Problem(statusCode:409,title:"Choose other images for the themes that use this group before deactivating it."); }
        catch (ArgumentException exception) { return Problem(statusCode:400,title:exception.Message); }
        catch (SqlException exception) when (exception.Number==50007) { return Problem(statusCode:400,title:"Check the group, images, default image and theme selection."); }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception,"Interface image operation failed.");
            return Problem(statusCode:503,title:"Interface images are temporarily unavailable.");
        }
    }
}
