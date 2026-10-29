using CompanyPortal.Api.Data;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;
[ApiController,Authorize]
public sealed class HeaderEventsController(HeaderEventsStore store,HeaderEventFiles files,ILogger<HeaderEventsController> logger):ControllerBase
{
 [HttpGet("api/header-events")]
 public Task<IActionResult> Visible(CancellationToken token)=>Run(async()=>{
  var rows=await store.Visible(User.Identity!.Name!,token);return rows is null?Forbid():Ok(rows.Where(r=>r.EventType!=1||HeaderEventsStore.SafeUrl(r.EventTarget)).Select(r=>new{r.EventId,r.Title,r.EventType,EventTarget=r.EventType==1?r.EventTarget:null,FileUrl=r.EventType==1?null:Url.ActionLink(nameof(Read),values:new{id=r.EventId}),StartAt=DateTime.SpecifyKind(r.StartAt,DateTimeKind.Utc),EndAt=DateTime.SpecifyKind(r.EndAt,DateTimeKind.Utc)}));});
 [HttpGet("api/header-events/{id:int:min(1)}/file")]
 public Task<IActionResult> Read(int id,CancellationToken token)=>Run(async()=>{
  var rows=await store.Visible(User.Identity!.Name!,token);if(rows is null)return Forbid();
  var row=rows.FirstOrDefault(r=>r.EventId==id);if(row is null||row.EventType==1)return NotFound();
  var opened=await files.Open(row.EventTarget,row.EventType,token);if(opened is null)return NotFound();
  Response.Headers.XContentTypeOptions="nosniff";
  var disposition=new Microsoft.Net.Http.Headers.ContentDispositionHeaderValue("inline");disposition.SetHttpFileName(opened.FileName);Response.Headers.ContentDisposition=disposition.ToString();
  return File(opened.Stream,opened.ContentType,enableRangeProcessing:true);
 });
 [HttpGet("api/admin/events/files"),AdminSection("events","events")]
 public Task<IActionResult> Files(CancellationToken token)=>Run(async()=>Ok(await files.List(token)));
 [HttpGet("api/admin/events/file-options"),AdminSection("events","events")]
 public Task<IActionResult> FileOptions(CancellationToken token)=>Run(async()=>Ok(await files.Options(token)));
 [HttpPost("api/admin/events/upload"),AdminSection("events","events"),Consumes("multipart/form-data"),RequestSizeLimit(105000000),RequestFormLimits(MultipartBodyLengthLimit=105000000)]
 public Task<IActionResult> Upload(IFormFile file,[FromForm] string payload,[FromForm] int? eventId,CancellationToken token)=>Run(async()=>{
  SaveHeaderEvent? parsed;try{parsed=System.Text.Json.JsonSerializer.Deserialize<SaveHeaderEvent>(payload,new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));}catch(System.Text.Json.JsonException){return BadRequest(new{message="تعذر قراءة بيانات الفعالية. راجع الحقول وحاول مجددًا."});}
  if(parsed is null||parsed.EventType is not (0 or 2)||eventId is <=0)return BadRequest(new{message="اختر نوع PDF أو فيديو، وأدخل بيانات فعالية صحيحة."});
  SaveHeaderEvent WithTarget(string target)=>new(){Title=parsed.Title,EventType=parsed.EventType,EventTarget=target,StartAt=parsed.StartAt,EndAt=parsed.EndAt,IsDisplayed=parsed.IsDisplayed};
  if(!TryValidateModel(WithTarget(Path.GetFullPath(parsed.EventType==0?"event.pdf":"event.mp4"))))return ValidationProblem(ModelState);
  var path=await files.Upload(file,parsed.EventType,token);
  try{var id=await store.Save(eventId,WithTarget(path),User.Identity!.Name!,token);return StatusCode(eventId is null?201:200,new{EventId=id});}
  catch(SqlException e)when(e.Number is 50051 or 50052){files.TryDeleteUpload(path);throw;}
  catch(Exception e){logger.LogWarning(e,"Event upload retained at {Path}: database save outcome is uncertain; verify references before cleanup.",path);throw;}
 });
 [HttpGet("api/admin/events"),AdminSection("events","events")]
 public Task<IActionResult> All(CancellationToken token)=>Run(async()=>Ok((await store.All(token)).Select(HeaderEventsStore.View)));
 [HttpPost("api/admin/events"),AdminSection("events","events"),RequestSizeLimit(16384)]
 public Task<IActionResult> Create(SaveHeaderEvent request,CancellationToken token)=>Run(async()=>{await files.Validate(request.Target,request.EventType,token);return StatusCode(201,new{EventId=await store.Save(null,request,User.Identity!.Name!,token)});});
 [HttpPut("api/admin/events/{id:int:min(1)}"),AdminSection("events","events"),RequestSizeLimit(16384)]
 public Task<IActionResult> Update(int id,SaveHeaderEvent request,CancellationToken token)=>Run(async()=>{if(request.IsDisplayed)await files.Validate(request.Target,request.EventType,token);await store.Save(id,request,User.Identity!.Name!,token);return NoContent();});
 [HttpDelete("api/admin/events/{id:int:min(1)}"),AdminSection("events","events")]
 public Task<IActionResult> Delete(int id,CancellationToken token)=>Run(async()=>{await store.Delete(id,User.Identity!.Name!,token);return NoContent();});
 private async Task<IActionResult> Run(Func<Task<IActionResult>> action)
 {
  Response.Headers.CacheControl="private, no-store";if(string.IsNullOrWhiteSpace(User.Identity?.Name))return Unauthorized();
  try{return await action();}
  catch(HeaderEventFiles.FileError e){if(e.Status>=500)logger.LogError(e,"Event file operation failed: {Code}",e.Code);return Problem(statusCode:e.Status,title:e.Message,extensions:new Dictionary<string,object?>{{"code",e.Code},{"field","eventTarget"}});}
  catch(SqlException e)when(e.Number==50052){return NotFound();}
  catch(SqlException e)when(e.Number==50051){return BadRequest(new{message="راجع عنوان الفعالية والرابط وفترة العرض."});}
  catch(IOException e){logger.LogError(e,"Event file read/write failed.");return Problem(statusCode:503,title:"تعذر قراءة الملف أو حفظه على الخادم. تحقق من توفر المجلد والمساحة وصلاحيات حساب API.");}
  catch(UnauthorizedAccessException e){logger.LogError(e,"Event file access denied.");return Problem(statusCode:503,title:"لا يملك حساب تشغيل API صلاحية الوصول إلى الملف أو المجلد.");}
  catch(Exception e)when(e is SqlException or InvalidOperationException or MediaFileException or ArgumentException){logger.LogError(e,"Header event operation failed.");return Problem(statusCode:503,title:"تعذر الاتصال ببيانات الفعاليات. تحقق من اتصال قاعدة البيانات وصلاحيات حساب API.");}
 }
}
