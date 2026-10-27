using System.Globalization;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;
[ApiController,Authorize,Route("api/magazines")]
public sealed class MagazinesController(MagazinesStore store,MagazineFiles files,ILogger<MagazinesController> logger,IConfiguration configuration):ControllerBase
{
 public sealed record Item(int MagazineId,string MagazineName,string IssueNumber,string IssueDate,int DisplayOrder,bool HasRead);
 [HttpGet,ProducesResponseType<Item[]>(200)]
 public async Task<IActionResult> Get(CancellationToken token)
 {
  Response.Headers.CacheControl="private, no-store";var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
  try{var rows=await store.GetCatalogAsync(name,token);return rows is null?Problem(statusCode:403,title:"User is not registered or is inactive."):Ok(rows.Select(r=>new Item(r.Magazine.MagazineID,r.Magazine.MagazineName,r.Magazine.IssueNumber,r.Magazine.IssueDate.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture),r.Magazine.DisplayOrder,r.HasRead)));}
  catch(Exception e) when(e is SqlException or InvalidOperationException or System.Data.DataException){logger.LogError(e,"Magazine read status failed.");return Problem(statusCode:503,title:"Magazines are temporarily unavailable.");}
 }
 [HttpPost("{id:int:min(1)}/read"),ProducesResponseType(204)]
 public Task<IActionResult> MarkRead(int id,CancellationToken token)
 {
  Response.Headers.CacheControl="private, no-store";
  if(Request.Headers["X-CompanyPortal-Request"]!="magazine-read")return Task.FromResult<IActionResult>(Problem(statusCode:400,title:"Missing magazine request header."));
  var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
  if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Task.FromResult<IActionResult>(Problem(statusCode:403,title:"Origin is not permitted."));
  return Execute(id,async rows=>
  {
   var row=rows.SingleOrDefault();if(row is null)return NotFound();
   var pdf=await files.PdfAsync(row.FileName,token);if(pdf is null)return NotFound();await pdf.Value.Stream.DisposeAsync();
   return await store.MarkReadAsync(User.Identity!.Name!,id,token)?NoContent():Problem(statusCode:403,title:"User is not registered or is inactive.");
  },token);
 }
 [HttpGet("{id:int:min(1)}/pdf")]
 public Task<IActionResult> Pdf(int id,CancellationToken token)=>Execute(id,async rows=>
 {
  var row=rows.SingleOrDefault();if(row is null)return NotFound();
  var opened=await files.PdfAsync(row.FileName,token);if(opened is null)return NotFound();
  Response.Headers.XContentTypeOptions="nosniff";Response.Headers.ContentDisposition=$"inline; filename=\"magazine-{id}.pdf\"";
  return File(opened.Value.Stream,opened.Value.ContentType,enableRangeProcessing:true);
 },token);
 private async Task<IActionResult> Execute(int? id,Func<IReadOnlyList<MagazinesStore.Row>,Task<IActionResult>> action,CancellationToken token)
 {
  Response.Headers.CacheControl="private, no-store";var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
  try{var rows=await store.GetAsync(name,id,token);return rows is null?Problem(statusCode:403,title:"User is not registered or is inactive."):await action(rows);}
  catch(Exception e) when(e is SqlException or InvalidOperationException or System.Data.DataException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
  {logger.LogError(e,"Magazine read failed; trace {TraceId}.",HttpContext.TraceIdentifier);return Problem(statusCode:503,title:"Magazines are temporarily unavailable.");}
 }
}
