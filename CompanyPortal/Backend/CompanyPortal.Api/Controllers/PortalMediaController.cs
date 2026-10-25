using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Net.Http.Headers;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/media")]
public sealed class PortalMediaController(PortalMediaStore store,PortalMediaFiles files,NewsStore identity,ILogger<PortalMediaController> logger):ControllerBase
{
 [HttpGet]
 public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>
 {
  var c=await store.GetAsync(false,token);
  return Ok(new{Groups=c.Groups.Where(g=>c.Items.Any(m=>m.MediaGroupID==g.MediaGroupID&&m.MediaType=="image")).Select(g=>new{MediaGroupId=g.MediaGroupID,g.GroupName,g.DisplayOrder,
   CoverMediaId=c.Items.Where(m=>m.MediaGroupID==g.MediaGroupID&&m.MediaType=="image").OrderBy(m=>m.MediaID==g.CoverMediaID?0:1).ThenBy(m=>m.DisplayOrder).ThenBy(m=>m.MediaID).First().MediaID}),
   Items=c.Items.Select(m=>new{MediaId=m.MediaID,m.MediaName,m.MediaType,MediaGroupId=m.MediaGroupID,m.DisplayOrder})});
 },token);
 [HttpGet("{id:int:min(1)}/file")]
 public Task<IActionResult> Read(int id,CancellationToken token)=>Execute(async()=>
 {
  var m=await store.GetByIdAsync(id,false,token);if(m is null||!m.Active)return NotFound();
  try
  {
   var opened=await files.OpenAsync(m.MediaPath,m.MediaType,token);
   var disposition=new ContentDispositionHeaderValue("inline");disposition.SetHttpFileName(opened.FileName);Response.Headers.ContentDisposition=disposition.ToString();Response.Headers.XContentTypeOptions="nosniff";
   return File(opened.Stream,opened.ContentType,enableRangeProcessing:true);
  }catch(MediaFileException e) when(e.Status<500){return NotFound();}
 },token);
 private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,CancellationToken token)
 {
  Response.Headers.CacheControl="private, no-store";var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
  try{if(!await identity.IsPortalUserAsync(name,token))return Forbid();return await action();}
  catch(Exception e) when(e is SqlException or InvalidOperationException or System.Data.DataException or IOException or MediaFileException)
  {logger.LogError(e,"Portal media read failed.");return Problem(statusCode:503,title:"Media is temporarily unavailable.");}
 }
}
