using System.Globalization;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/decisions")]
public sealed class LegalDecisionsController(LegalDecisionsStore decisions,NewsFiles files,FolderPathsStore folders,
    ILogger<LegalDecisionsController> logger,DecisionNoticesStore notices,IConfiguration configuration):ControllerBase
{
    public sealed record DecisionItem(string DecisionId,string DecisionType,string Title,string PublishedAt,bool HasRead,DecisionNoticesStore.Appearance[] Notices);

    // Read-only rules for the optional frontend simulation tools. Publication matching
    // for real decisions still happens on the server in Get(). No permissions are granted here.
    [HttpGet("notice-rules")]
    public Task<IActionResult> NoticeRules(CancellationToken token)=>Execute(null,async _=>
    {
        var catalog=await notices.GetAsync(token);
        return Ok(catalog.Settings.Select(s=>new{ChannelId=s.ChannelID,s.Active,s.DurationDays,
            DecisionTypes=System.Text.Json.JsonSerializer.Deserialize<string[]>(s.DecisionTypes)??[]}));
    },token);

    [HttpGet,ProducesResponseType<DecisionItem[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(null,async rows=>
    {
        var settings=await notices.GetAsync(token);
        return Ok(rows.Select(row=>new DecisionItem(row.DecisionId.ToString(CultureInfo.InvariantCulture),row.DecisionType,row.Title,
            DecisionNoticesStore.Oman(row.PublishedAt).ToString("O",CultureInfo.InvariantCulture),row.HasRead,settings.For(row).Where(n=>n.ChannelId!=1||!row.NoticeDismissed).ToArray())).ToArray());
    },token);

    [HttpPost("{id:long:min(1)}/dismiss-notice"),ProducesResponseType(204)]
    public Task<IActionResult> DismissNotice(long id,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        if(Request.Headers["X-CompanyPortal-Request"]!="decision-dismiss")return Task.FromResult<IActionResult>(BadRequest());
        var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
        if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Task.FromResult<IActionResult>(Forbid());
        return Execute(id,async rows=>
        {
            var row=rows.SingleOrDefault();if(row is null)return NotFound();
            var settings=await notices.GetAsync(token);var now=DateTimeOffset.UtcNow;
            if(!settings.For(row).Any(n=>n.ChannelId==1&&n.FromAt<=now&&now<n.ToAt))return NotFound();
            return await decisions.DismissNoticeAsync(User.Identity!.Name!,id,token)?NoContent():Forbid();
        },token);
    }

    [HttpPost("{id:long:min(1)}/read"),ProducesResponseType(204)]
    public Task<IActionResult> MarkRead(long id,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        if(Request.Headers["X-CompanyPortal-Request"]!="decision-read")return Task.FromResult<IActionResult>(BadRequest());
        var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
        if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Task.FromResult<IActionResult>(Forbid());
        return Execute(id,async rows=>
        {
            var row=rows.SingleOrDefault();if(row is null)return NotFound();
            var opened=await OpenPdf(row,token);if(opened is null)return NotFound();await opened.Value.Stream.DisposeAsync();
            return await decisions.MarkReadAsync(User.Identity!.Name!,id,token)?NoContent():Forbid();
        },token);
    }

    [HttpGet("{id:long:min(1)}/pdf")]
    public Task<IActionResult> Pdf(long id,CancellationToken token)=>Execute(id,async rows=>
    {
        // Recheck current employee permissions on every file request; do not accept a path from the browser.
        var row=rows.SingleOrDefault();
        if(row is null)return NotFound();
        var opened=await OpenPdf(row,token);if(opened is null)return NotFound();
        Response.Headers.XContentTypeOptions="nosniff";
        Response.Headers.ContentDisposition=$"inline; filename=\"decision-{id}.pdf\"";
        return File(opened.Value.Stream,opened.Value.ContentType,enableRangeProcessing:true);
    },token);

    private async Task<(FileStream Stream,string ContentType)?> OpenPdf(LegalDecisionsStore.Row row,CancellationToken token)
    {
        if(string.IsNullOrWhiteSpace(row.PdfFileName))return null;
        var qualified=Path.IsPathFullyQualified(row.PdfFileName);if(!qualified&&Path.IsPathRooted(row.PdfFileName))return null;
        foreach(var root in await folders.GetAsync("LegalAffairs",token))
        {var opened=await files.OpenAsync(qualified?row.PdfFileName:Path.Combine(root,row.PdfFileName),true,token,"LegalAffairs");if(opened is not null)return opened;}
        return null;
    }

    private async Task<IActionResult> Execute(long? id,Func<IReadOnlyList<LegalDecisionsStore.Row>,Task<IActionResult>> action,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var name=User.Identity?.Name;
        if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            var rows=await decisions.GetAsync(name,id,token);
            return rows is null?Forbid():await action(rows);
        }
        catch(Exception exception) when(exception is SqlException or InvalidOperationException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException or System.Text.Json.JsonException)
        {
            logger.LogError(exception,"Legal decisions read failed.");
            return Problem(statusCode:503,title:"Legal decisions are temporarily unavailable.");
        }
    }
}
