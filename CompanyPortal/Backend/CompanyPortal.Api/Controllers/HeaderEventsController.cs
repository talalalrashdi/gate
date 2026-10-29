using CompanyPortal.Api.Data;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;
[ApiController,Authorize]
public sealed class HeaderEventsController(HeaderEventsStore store,ILogger<HeaderEventsController> logger):ControllerBase
{
 [HttpGet("api/header-events")]
 public Task<IActionResult> Visible(CancellationToken token)=>Run(async()=>{
  var rows=await store.Visible(User.Identity!.Name!,token);return rows is null?Forbid():Ok(rows.Where(r=>HeaderEventsStore.SafeUrl(r.AppUrl)).Select(r=>new{r.EventId,r.Title,r.AppUrl,StartAt=DateTime.SpecifyKind(r.StartAt,DateTimeKind.Utc),EndAt=DateTime.SpecifyKind(r.EndAt,DateTimeKind.Utc)}));});
 [HttpGet("api/admin/events"),AdminSection("events","events")]
 public Task<IActionResult> All(CancellationToken token)=>Run(async()=>Ok((await store.All(token)).Select(HeaderEventsStore.View)));
 [HttpPost("api/admin/events"),AdminSection("events","events"),RequestSizeLimit(16384)]
 public Task<IActionResult> Create(SaveHeaderEvent request,CancellationToken token)=>Run(async()=>StatusCode(201,new{EventId=await store.Save(null,request,User.Identity!.Name!,token)}));
 [HttpPut("api/admin/events/{id:int:min(1)}"),AdminSection("events","events"),RequestSizeLimit(16384)]
 public Task<IActionResult> Update(int id,SaveHeaderEvent request,CancellationToken token)=>Run(async()=>{await store.Save(id,request,User.Identity!.Name!,token);return NoContent();});
 [HttpDelete("api/admin/events/{id:int:min(1)}"),AdminSection("events","events")]
 public Task<IActionResult> Delete(int id,CancellationToken token)=>Run(async()=>{await store.Delete(id,User.Identity!.Name!,token);return NoContent();});
 private async Task<IActionResult> Run(Func<Task<IActionResult>> action)
 {
  Response.Headers.CacheControl="private, no-store";if(string.IsNullOrWhiteSpace(User.Identity?.Name))return Unauthorized();
  try{return await action();}
  catch(SqlException e)when(e.Number==50052){return NotFound();}
  catch(SqlException e)when(e.Number==50051){return BadRequest(new{message="Check event fields."});}
  catch(Exception e)when(e is SqlException or InvalidOperationException){logger.LogError(e,"Header event operation failed.");return Problem(statusCode:503,title:"Event links are temporarily unavailable.");}
 }
}
