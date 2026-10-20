using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/admin/images"), RequestSizeLimit(12*1024*1024)]
public sealed class InterfaceImagesController(InterfaceImagesStore images, AdministrationStore administration, NewsStore users,
    IConfiguration configuration, ILogger<InterfaceImagesController> logger) : ControllerBase
{
    [HttpGet]
    public Task<IActionResult> Get(CancellationToken token) => Execute(async _ => Ok(await images.GetAsync(token)), true, false, token);

    [HttpPost, Consumes("multipart/form-data"), RequestFormLimits(MultipartBodyLengthLimit = 11*1024*1024)]
    // IFormFile infers form-file binding; explicit FromForm breaks Swagger generation.
    public Task<IActionResult> Upload(IFormFile file, CancellationToken token) => Execute(async _ =>
    {
        var limit = Math.Clamp(configuration.GetValue("InterfaceImages:MaximumUploadMb",10),1,10)*1024*1024;
        if (file.Length < 12 || file.Length > limit) return Problem(statusCode:400,title:$"Upload an image up to {limit/1024/1024} MB.");
        var name = Path.GetFileName(file.FileName.Replace('\\','/'));
        if (string.IsNullOrWhiteSpace(name) || name.Length > 200) return Problem(statusCode:400,title:"Image filename must contain 1–200 characters.");
        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory,token);
        var validated = ImageValidation.Read(memory.ToArray(),Path.GetExtension(name));
        return Ok(new { imageId = await images.AddAsync(name,validated,token) });
    },true,true,token);

    [HttpPost("groups"), Consumes("application/json"), RequestSizeLimit(32768)]
    public Task<IActionResult> CreateGroup(SaveImageGroup request, CancellationToken token) => Save(null,request,token);
    [HttpPut("groups/{id:int:min(1)}"), Consumes("application/json"), RequestSizeLimit(32768)]
    public Task<IActionResult> UpdateGroup(int id, SaveImageGroup request, CancellationToken token) => Save(id,request,token);
    private Task<IActionResult> Save(int? id, SaveImageGroup request, CancellationToken token) => Execute(async _ =>
    {
        if (string.IsNullOrWhiteSpace(request.GroupName) || request.Items.Any(i=>i is null) || request.Items.Select(i=>i.ImageId).Distinct().Count()!=request.Items.Length
            || request.Items.Select(i=>i.DisplayOrder).Distinct().Count()!=request.Items.Length)
            return Problem(statusCode:400,title:"Enter a group name and unique image positions.");
        return Ok(new { imageGroupId = await images.SaveGroupAsync(id,request,token) });
    },true,true,token);

    [HttpPut("themes/{id:int:min(1)}/group"), Consumes("application/json"), RequestSizeLimit(4096)]
    public Task<IActionResult> Assign(int id, AssignImageGroup request, CancellationToken token) => Execute(async _ =>
    {
        await images.AssignAsync(id,request.ImageGroupId,token); return NoContent();
    },true,true,token);

    [HttpGet("/api/themes/{id:int:min(1)}/images")]
    public Task<IActionResult> Theme(int id, CancellationToken token) => Execute(async _ => Ok(await images.ThemeAsync(id,token)),false,false,token);

    [HttpGet("/api/images/{id:int:min(1)}/content")]
    public Task<IActionResult> Content(int id, CancellationToken token) => Execute(async admin =>
    {
        var content = await images.ContentAsync(id,admin,token);
        if (content is null) return NotFound();
        Response.Headers.XContentTypeOptions="nosniff";
        Response.Headers.ContentSecurityPolicy=content.ContentType=="image/svg+xml" && BundledArtwork.IsNationalDay(content.ImageData)
            ? "default-src 'none'; img-src data:; style-src 'unsafe-inline'; sandbox"
            : "default-src 'none'; style-src 'none'; sandbox";
        Response.Headers.ContentDisposition=$"inline; filename=\"portal-image-{id}\"";
        return File(content.ImageData,content.ContentType);
    },false,false,token);

    private async Task<IActionResult> Execute(Func<bool,Task<IActionResult>> action, bool requireAdmin, bool write, CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var account=User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length>512) return Unauthorized();
        try
        {
            var admin = requireAdmin || Request.Path.StartsWithSegments("/api/images")
                ? await administration.IsAdminAsync(account,token) : false;
            if (requireAdmin ? !admin : !admin && !await users.IsPortalUserAsync(account,token)) return Forbid();
            if (write)
            {
                if (Request.Headers["X-CompanyPortal-Request"]!="admin-images") return Problem(statusCode:400,title:"Missing admin-images request header.");
                var origin=Request.Headers.Origin.ToString();
                var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
                if (origin.Length>0 && origin!=$"{Request.Scheme}://{Request.Host}" && !allowed.Contains(origin,StringComparer.Ordinal)) return Forbid();
            }
            return await action(admin);
        }
        catch (ArgumentException exception) { return Problem(statusCode:400,title:exception.Message); }
        catch (SqlException exception) when (exception.Number==50007) { return Problem(statusCode:400,title:"Check the group, images, default image and theme selection."); }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception,"Interface image operation failed.");
            return Problem(statusCode:503,title:"Interface images are temporarily unavailable.");
        }
    }
}
