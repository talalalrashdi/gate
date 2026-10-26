using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text.Json;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/decision-notices"),RequestSizeLimit(16384)]
public sealed class DecisionNoticesAdministrationController(DecisionNoticesStore notices,LegalDecisionsStore decisions,
 AdministrationStore administration,IConfiguration configuration,ILogger<DecisionNoticesAdministrationController> logger):ControllerBase
{
 public sealed record SaveDecisionNoticeRequest([Range(1,365)]int DurationDays,[Required,MaxLength(16)]string[] DecisionTypes,bool Active);
 public sealed record SaveDecisionNoticeWindowRequest([Required]string DecisionId,DateTime? FromAt,DateTime? ToAt,bool IsHidden);
 [HttpGet]
 public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>
 {
  var data=await notices.GetAsync(token);var rows=await decisions.GetAsync(User.Identity!.Name!,null,token);
  if(rows is null)return Forbid();
  return Ok(new{Settings=data.Settings.Select(s=>new{s.ChannelID,s.DurationDays,DecisionTypes=JsonSerializer.Deserialize<string[]>(s.DecisionTypes),s.LastChangeAt,s.Active}),
   Windows=data.Windows.Where(w=>rows.Any(r=>r.DecisionId==w.DecisionId)).Select(w=>new{w.ChannelID,DecisionId=w.DecisionId.ToString(CultureInfo.InvariantCulture),w.FromAt,w.ToAt,w.IsHidden}),
   Decisions=rows.Select(r=>new{DecisionId=r.DecisionId.ToString(CultureInfo.InvariantCulture),r.Title,r.DecisionType,r.PublishedAt}),
   Types=rows.Select(r=>r.DecisionType).Concat(data.Settings.SelectMany(s=>JsonSerializer.Deserialize<string[]>(s.DecisionTypes)??[])).Distinct().Order().ToArray()});
 },false,token);
 [HttpPut("{channel:int:range(1,2)}"),Consumes("application/json")]
 public Task<IActionResult> Save(int channel,SaveDecisionNoticeRequest request,CancellationToken token)=>Execute(async()=>
 {
  if(request.DecisionTypes.Any(t=>string.IsNullOrWhiteSpace(t)||t.Length>200))return BadRequest();
  var types=request.DecisionTypes.Select(t=>t.Trim()).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
  if(JsonSerializer.Serialize(types).Length>4000)return BadRequest();
  await notices.SaveAsync(channel,request.DurationDays,types,request.Active,token);return NoContent();
 },true,token);
 [HttpPut("{channel:int:range(1,2)}/window"),Consumes("application/json")]
 public Task<IActionResult> Window(int channel,SaveDecisionNoticeWindowRequest request,CancellationToken token)=>Execute(async()=>
 {
  if(!long.TryParse(request.DecisionId,NumberStyles.None,CultureInfo.InvariantCulture,out var id)||id<1||
   request.FromAt.HasValue!=request.ToAt.HasValue||request.FromAt is { } from&&(from.Year<1753||request.ToAt<=from)||
   request.FromAt is {Kind: not DateTimeKind.Unspecified}||request.ToAt is {Kind: not DateTimeKind.Unspecified})return BadRequest();
  var rows=await decisions.GetAsync(User.Identity!.Name!,id,token);if(rows is null)return Forbid();if(rows.Count!=1)return NotFound();
  await notices.SaveWindowAsync(channel,id,request.FromAt,request.ToAt,request.IsHidden,token);return NoContent();
 },true,token);
 private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,bool write,CancellationToken token)
 {
  Response.Headers.CacheControl="private, no-store";var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
  try
  {
   if(!await administration.IsAdminAsync(name,token))return Forbid();
   if(write){if(Request.Headers["X-CompanyPortal-Request"]!="decision-notices")return BadRequest();
    var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
    if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();}
   return await action();
  }
  catch(SqlException e) when(e.Number==50012){return BadRequest();}
  catch(Exception e) when(e is SqlException or InvalidOperationException or JsonException or ArgumentException)
  {logger.LogError(e,"Decision notice administration failed.");return Problem(statusCode:503,title:"Decision notice administration is temporarily unavailable.");}
 }
}
