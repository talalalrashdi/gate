using System.Security.Cryptography;
using System.Text.Json;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Net.Http.Headers;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/media"),RequestSizeLimit(16384)]
public sealed class PortalMediaAdministrationController(PortalMediaStore store,PortalMediaFiles files,AdministrationStore administration,
 IDataProtectionProvider protection,IConfiguration configuration,ILogger<PortalMediaAdministrationController> logger):ControllerBase
{
 [HttpGet]
 public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>
 {
  var c=await store.GetAsync(true,token);return Ok(new{Groups=c.Groups.Select(g=>new{MediaGroupId=g.MediaGroupID,g.GroupName,CoverMediaId=g.CoverMediaID,g.DisplayOrder,g.LastChangeAt,g.Active}),
   Items=c.Items.Select(m=>new{MediaId=m.MediaID,m.MediaName,m.MediaPath,m.MediaType,MediaGroupId=m.MediaGroupID,m.DisplayOrder,m.LastChangeAt,m.Active})});
 },false,token);
 [HttpPost("items"),Consumes("application/json")]
 public Task<IActionResult> Create(SaveMediaRequest r,CancellationToken token)=>Save(null,r,token);
 [HttpPut("items/{id:int:min(1)}"),Consumes("application/json")]
 public Task<IActionResult> Update(int id,SaveMediaRequest r,CancellationToken token)=>Save(id,r,token);
 private Task<IActionResult> Save(int? id,SaveMediaRequest r,CancellationToken token)=>Execute(async()=>
 {
  if(r.Active){var opened=await files.OpenAsync(r.MediaPath,r.MediaType,token);await opened.Stream.DisposeAsync();}
  return Ok(new{MediaId=await store.SaveAsync(id,r,token)});
 },true,token);
 [HttpPost("groups"),Consumes("application/json")]
 public Task<IActionResult> CreateGroup(SaveMediaGroupRequest r,CancellationToken token)=>SaveGroup(null,r,token);
 [HttpPut("groups/{id:int:min(1)}"),Consumes("application/json")]
 public Task<IActionResult> UpdateGroup(int id,SaveMediaGroupRequest r,CancellationToken token)=>SaveGroup(id,r,token);
 private Task<IActionResult> SaveGroup(int? id,SaveMediaGroupRequest r,CancellationToken token)=>Execute(async()=>Ok(new{MediaGroupId=await store.SaveGroupAsync(id,r,token)}),true,token);
 [HttpPost("preview"),Consumes("application/json")]
 public Task<IActionResult> CreatePreview(PreviewMediaRequest r,CancellationToken token)=>Execute(async()=>
 {
  var opened=await files.OpenAsync(r.MediaPath,r.MediaType,token);await opened.Stream.DisposeAsync();
  var protector=protection.CreateProtector("CompanyPortal.AdminMediaPreview.v1").ToTimeLimitedDataProtector();
  var ticket=protector.Protect(JsonSerializer.Serialize(new PreviewTicket(User.Identity!.Name!,r.MediaPath,r.MediaType)),TimeSpan.FromMinutes(30));
  return Ok(new{Token=ticket,r.MediaType});
 },true,token);
 private sealed record PreviewTicket(string Account,string Path,string Type);
 [HttpGet("preview/{ticket}")]
 public Task<IActionResult> Preview(string ticket,CancellationToken token)=>Execute(async()=>
 {
  PreviewTicket? data;
  try{data=JsonSerializer.Deserialize<PreviewTicket>(protection.CreateProtector("CompanyPortal.AdminMediaPreview.v1").ToTimeLimitedDataProtector().Unprotect(ticket));}
  catch(Exception e) when(e is CryptographicException or JsonException){return NotFound();}
  if(data is null||!string.Equals(data.Account,User.Identity!.Name,StringComparison.OrdinalIgnoreCase))return NotFound();
  var opened=await files.OpenAsync(data.Path,data.Type,token);var d=new ContentDispositionHeaderValue("inline");d.SetHttpFileName(opened.FileName);
  Response.Headers.ContentDisposition=d.ToString();Response.Headers.XContentTypeOptions="nosniff";return File(opened.Stream,opened.ContentType,enableRangeProcessing:true);
 },false,token);
 private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,bool write,CancellationToken token)
 {
  Response.Headers.CacheControl="private, no-store";var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
  try
  {
   if(!await administration.IsAdminAsync(name,token))return Forbid();
   if(write)
   {
    if(Request.Headers["X-CompanyPortal-Request"]!="media")return Problem(statusCode:400,title:"Missing media request header.");
    var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
    if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();
   }
   return await action();
  }
  catch(MediaFileException e){return Problem(statusCode:e.Status,title:"Check the media file and configured PortalMedia root.",extensions:new Dictionary<string,object?>{{"code",e.Code}});}
  catch(SqlException e) when(e.Number==50011){return NotFound();}
  catch(SqlException e) when(e.Number==50012){return Problem(statusCode:400,title:"Check the media/group fields and cover selection.");}
  catch(Exception e) when(e is SqlException or InvalidOperationException or System.Data.DataException or IOException)
  {logger.LogError(e,"Media administration failed.");return Problem(statusCode:503,title:"Media administration is temporarily unavailable.",extensions:new Dictionary<string,object?>{{"code","SOURCE_UNAVAILABLE"}});}
 }
}
