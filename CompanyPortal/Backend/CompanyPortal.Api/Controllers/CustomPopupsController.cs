using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;
[ApiController,Authorize,RequestSizeLimit(16384)]
public sealed class CustomPopupsController(CustomPopupsStore store,ILogger<CustomPopupsController> log):ControllerBase
{
 [HttpGet("api/custom-popups")] public Task<IActionResult> Visible(CancellationToken t)=>Run(async()=>{var user=await store.User(User.Identity!.Name!,t);return user is null?Forbid():Ok((await store.Get(user,t)).Select(CustomPopupsStore.View));});
 [HttpPost("api/custom-popups/{id:int:min(1)}/dismiss")] public Task<IActionResult> Dismiss(int id,CancellationToken t)=>Run(async()=>{
  if(Request.Headers["X-CompanyPortal-Request"]!="popup-dismiss")return BadRequest();if(!AdminSectionAttribute.AllowedOrigin(HttpContext))return Forbid();
  var user=await store.User(User.Identity!.Name!,t);if(user is null)return Forbid();await store.Dismiss(id,user.Value,t);return NoContent();});
 [HttpGet("api/admin/custom-popups"),AdminSection("custom-popups","notices")] public Task<IActionResult> All(CancellationToken t)=>Run(async()=>Ok((await store.Get(null,t)).Select(CustomPopupsStore.View)));
 [HttpPost("api/admin/custom-popups"),AdminSection("custom-popups","notices")] public Task<IActionResult> Create(SaveCustomPopup r,CancellationToken t)=>Run(async()=>{await store.Save(null,r,User.Identity!.Name!,t);return StatusCode(201);});
 [HttpPut("api/admin/custom-popups/{id:int:min(1)}"),AdminSection("custom-popups","notices")] public Task<IActionResult> Update(int id,SaveCustomPopup r,CancellationToken t)=>Run(async()=>{await store.Save(id,r,User.Identity!.Name!,t);return NoContent();});
 [HttpDelete("api/admin/custom-popups/{id:int:min(1)}"),AdminSection("custom-popups","notices")] public Task<IActionResult> Delete(int id,CancellationToken t)=>Run(async()=>{await store.Delete(id,User.Identity!.Name!,t);return NoContent();});
 private async Task<IActionResult> Run(Func<Task<IActionResult>> action){Response.Headers.CacheControl="private, no-store";try{return await action();}catch(SqlException e)when(e.Number==50052){return NotFound();}catch(SqlException e)when(e.Number==50006){return Problem(statusCode:400,title:"أدخل النوع والتفاصيل وفترة عرض صحيحة.");}catch(Exception e)when(e is SqlException or InvalidOperationException){log.LogError(e,"Custom popup operation failed.");return Problem(statusCode:503,title:"تعذر الوصول إلى التنويهات المخصصة. تحقق من قاعدة البيانات.");}}
}
