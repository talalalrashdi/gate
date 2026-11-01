using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Net.Http.Headers;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/document-library"),Route("api/safety-library")]
public sealed class DocumentLibraryController(DocumentTabsStore tabs,DocumentsStore documents,DocumentFiles files,
    LibraryReadsStore reads,ILogger<DocumentLibraryController> logger):ControllerBase
{
    private string SectionKey=>Request.Path.StartsWithSegments("/api/safety-library")?"safety":"documents";
    public sealed record LibraryDocument(Guid DocumentId,string DocumentName,bool HasRead,bool HasSeen);
    public sealed record LibraryTab(int DocumentTabId,string TabName,IReadOnlyList<LibraryDocument> Documents);

    [HttpGet,ProducesResponseType<LibraryTab[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async rows=>
    {
        var catalog=await tabs.GetAsync(false,token,SectionKey);
        var states=await reads.GetAsync(User.Identity!.Name!,token);
        var opened=states.Where(r=>r.ContentTypeID==4).Select(r=>r.ContentId).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var seen=states.Where(r=>r.ContentTypeID==5).Select(r=>r.ContentId).ToHashSet(StringComparer.OrdinalIgnoreCase);
        return Ok(catalog.Tabs.Select(tab=>new LibraryTab(tab.DocumentTabID,tab.TabName,rows
            .Where(row=>row.FolderID==tab.FolderID&&catalog.Items.Any(i=>i.DocumentTabID==tab.DocumentTabID&&i.DocumentID==row.DocumentID))
            .Select(row=>new LibraryDocument(row.DocumentID,row.DocumentName,opened.Contains(row.DocumentID.ToString("D")),seen.Contains(SectionKey+":"+row.DocumentID.ToString("D")))).ToArray()))
            .Where(tab=>tab.Documents.Count>0).ToArray());
    },token);

    public sealed class SeenRequest
    {
        [System.ComponentModel.DataAnnotations.Required,System.ComponentModel.DataAnnotations.MaxLength(500)]
        public Guid[] DocumentIds {get;init;}=[];
    }
    [HttpPost("seen"),RequestSizeLimit(32768)]
    public Task<IActionResult> Seen(SeenRequest request,CancellationToken token)=>Acknowledge(request.DocumentIds,false,token);
    [HttpPost("{id:guid}/read")]
    public Task<IActionResult> Read(Guid id,CancellationToken token)=>Acknowledge([id],true,token);
    private Task<IActionResult> Acknowledge(Guid[] ids,bool markRead,CancellationToken token)=>Execute(async rows=>
    {
        if(Request.Headers["X-CompanyPortal-Request"]!="library-read")return BadRequest();
        if(!CompanyPortal.Api.Infrastructure.AdminSectionAttribute.AllowedOrigin(HttpContext))return Forbid();
        var catalog=await tabs.GetAsync(false,token,SectionKey);
        var visible=rows.Where(row=>catalog.Items.Any(i=>i.DocumentID==row.DocumentID&&catalog.Tabs.Any(t=>t.DocumentTabID==i.DocumentTabID&&t.FolderID==row.FolderID))).Select(r=>r.DocumentID).ToHashSet();
        if(ids.Any(id=>!visible.Contains(id)))return NotFound();
        if(markRead)foreach(var id in ids){await using var opened=await files.OpenAsync(rows.Single(r=>r.DocumentID==id),true,token);if(opened is null)return NotFound();}
        if(ids.Length>0)await reads.MarkAsync(User.Identity!.Name!,SectionKey,ids.Distinct().ToArray(),markRead,token);
        return NoContent();
    },token);

    [HttpGet("{id:guid}/file")]
    public Task<IActionResult> Pdf(Guid id,CancellationToken token)=>Execute(async rows=>
    {
        var row=rows.SingleOrDefault(row=>row.DocumentID==id);if(row is null)return NotFound();
        var catalog=await tabs.GetAsync(false,token,SectionKey);
        if(!catalog.Items.Any(i=>i.DocumentID==id&&catalog.Tabs.Any(t=>t.DocumentTabID==i.DocumentTabID&&t.FolderID==row.FolderID)))return NotFound();
        var stream=await files.OpenAsync(row,true,token);if(stream is null)return NotFound();
        var disposition=new ContentDispositionHeaderValue("inline");disposition.SetHttpFileName(row.DocumentPath);
        Response.Headers.ContentDisposition=disposition.ToString();Response.Headers.XContentTypeOptions="nosniff";
        return File(stream,"application/pdf",enableRangeProcessing:true);
    },token);

    private async Task<IActionResult> Execute(Func<IReadOnlyList<DocumentsStore.Row>,Task<IActionResult>> action,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            var rows=await documents.GetAsync(name,token);
            return rows is null?Forbid():await action(rows.Where(DocumentTabsStore.IsPdf).ToArray());
        }
        catch(SqlException e) when(e.Number==0 && token.IsCancellationRequested && HttpContext.RequestAborted.IsCancellationRequested)
        {throw new OperationCanceledException("Document request canceled by client.",e,token);}
        catch(Exception e) when(e is SqlException or InvalidOperationException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        {logger.LogError(e,"Document library read failed.");return Problem(statusCode:503,title:"Document library is temporarily unavailable.");}
    }
}
