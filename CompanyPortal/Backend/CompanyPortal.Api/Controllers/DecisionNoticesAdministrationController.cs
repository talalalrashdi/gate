using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text.Json;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;

// Channel 1 = التنويهات (section "notices"), channel 2 = التنبيهات (section "alerts").
[ApiController,Authorize,Route("api/admin/decision-notices"),RequestSizeLimit(16384),AdminSection("decision-notices","notices","alerts")]
public sealed class DecisionNoticesAdministrationController(DecisionNoticesStore notices,LegalDecisionsStore decisions,
 ILogger<DecisionNoticesAdministrationController> logger):ControllerBase
{
 public sealed record SaveDecisionNoticeRequest([Range(1,365)]int DurationDays,[Required,MaxLength(16)]string[] DecisionTypes,bool Active);
 public sealed record SaveDecisionNoticeWindowRequest([Required]string DecisionId,DateTime? FromAt,DateTime? ToAt,bool IsHidden);
 private static string Section(int channel)=>channel==1?"notices":"alerts";
 [HttpGet]
 public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>
 {
  var access=await HttpContext.GetAdminAccessAsync();
  var data=await notices.GetAsync(token);var rows=await decisions.GetAsync(User.Identity!.Name!,null,token);
  if(rows is null)return Forbid();
  var settings=data.Settings.Where(s=>access.CanManage(Section(s.ChannelID))).ToArray();
  return Ok(new{Settings=settings.Select(s=>new{s.ChannelID,s.DurationDays,DecisionTypes=JsonSerializer.Deserialize<string[]>(s.DecisionTypes),s.LastChangeAt,s.Active}),
   Windows=data.Windows.Where(w=>access.CanManage(Section(w.ChannelID))&&rows.Any(r=>r.DecisionId==w.DecisionId)).Select(w=>new{w.ChannelID,DecisionId=w.DecisionId.ToString(CultureInfo.InvariantCulture),w.FromAt,w.ToAt,w.IsHidden}),
   Decisions=rows.Select(r=>new{DecisionId=r.DecisionId.ToString(CultureInfo.InvariantCulture),r.Title,r.DecisionType,r.PublishedAt}),
   Types=rows.Select(r=>r.DecisionType).Concat(settings.SelectMany(s=>JsonSerializer.Deserialize<string[]>(s.DecisionTypes)??[])).Distinct().Order().ToArray()});
 });
 [HttpPut("{channel:int:range(1,2)}"),Consumes("application/json")]
 public Task<IActionResult> Save(int channel,SaveDecisionNoticeRequest request,CancellationToken token)=>Execute(async()=>
 {
  if(!(await HttpContext.GetAdminAccessAsync()).CanManage(Section(channel)))return Forbid();
  if(request.DecisionTypes.Any(t=>string.IsNullOrWhiteSpace(t)||t.Length>200))return BadRequest();
  var types=request.DecisionTypes.Select(t=>t.Trim()).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
  if(JsonSerializer.Serialize(types).Length>4000)return BadRequest();
  await notices.SaveAsync(channel,request.DurationDays,types,request.Active,User.Identity!.Name!,token);return NoContent();
 });
 [HttpPut("{channel:int:range(1,2)}/window"),Consumes("application/json")]
 public Task<IActionResult> Window(int channel,SaveDecisionNoticeWindowRequest request,CancellationToken token)=>Execute(async()=>
 {
  if(!(await HttpContext.GetAdminAccessAsync()).CanManage(Section(channel)))return Forbid();
  if(!long.TryParse(request.DecisionId,NumberStyles.None,CultureInfo.InvariantCulture,out var id)||id<1||
   request.FromAt.HasValue!=request.ToAt.HasValue||request.FromAt is { } from&&(from.Year<1753||request.ToAt<=from)||
   request.FromAt is {Kind: not DateTimeKind.Unspecified}||request.ToAt is {Kind: not DateTimeKind.Unspecified})return BadRequest();
  var rows=await decisions.GetAsync(User.Identity!.Name!,id,token);if(rows is null)return Forbid();if(rows.Count!=1)return NotFound();
  await notices.SaveWindowAsync(channel,id,request.FromAt,request.ToAt,request.IsHidden,User.Identity!.Name!,token);return NoContent();
 });
 private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
 {
  try
  {
   return await action();
  }
  catch(SqlException e) when(e.Number==50012){return BadRequest();}
  catch(Exception e) when(e is SqlException or InvalidOperationException or JsonException or ArgumentException)
  {logger.LogError(e,"Decision notice administration failed.");return Problem(statusCode:503,title:"Decision notice administration is temporarily unavailable.");}
 }
}
