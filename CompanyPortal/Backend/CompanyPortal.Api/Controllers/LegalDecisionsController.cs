using System.Globalization;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/decisions")]
public sealed class LegalDecisionsController(LegalDecisionsStore decisions,NewsFiles files,FolderPathsStore folders,
    ILogger<LegalDecisionsController> logger):ControllerBase
{
    public sealed record DecisionItem(string DecisionId,string DecisionType,string Title,string PublishedAt);

    [HttpGet,ProducesResponseType<DecisionItem[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(null,rows=>Task.FromResult<IActionResult>(Ok(rows.Select(row=>
        new DecisionItem(row.DecisionId.ToString(CultureInfo.InvariantCulture),row.DecisionType,row.Title,
            row.PublishedAt.ToString("yyyy-MM-ddTHH:mm:ss",CultureInfo.InvariantCulture))).ToArray())),token);

    [HttpGet("{id:long:min(1)}/pdf")]
    public Task<IActionResult> Pdf(long id,CancellationToken token)=>Execute(id,async rows=>
    {
        // Recheck current employee permissions on every file request; do not accept a path from the browser.
        var row=rows.SingleOrDefault();
        if(row is null)return NotFound();
        var roots=await folders.GetAsync("LegalAffairs",token);
        if(string.IsNullOrWhiteSpace(row.PdfFileName))return NotFound();
        var qualified=Path.IsPathFullyQualified(row.PdfFileName);
        if(!qualified&&Path.IsPathRooted(row.PdfFileName))return NotFound();
        foreach(var root in roots)
        {
            var path=qualified?row.PdfFileName:Path.Combine(root,row.PdfFileName);
            var opened=await files.OpenAsync(path,true,token,"LegalAffairs");
            if(opened is null)continue;
            Response.Headers.XContentTypeOptions="nosniff";
            Response.Headers.ContentDisposition=$"inline; filename=\"decision-{id}.pdf\"";
            return File(opened.Value.Stream,opened.Value.ContentType,enableRangeProcessing:true);
        }
        return NotFound();
    },token);

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
        catch(Exception exception) when(exception is SqlException or InvalidOperationException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        {
            logger.LogError(exception,"Legal decisions read failed.");
            return Problem(statusCode:503,title:"Legal decisions are temporarily unavailable.");
        }
    }
}
