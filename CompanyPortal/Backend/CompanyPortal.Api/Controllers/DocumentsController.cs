using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Net.Http.Headers;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/documents")]
public sealed class DocumentsController(DocumentsStore documents,DocumentFiles files,ILogger<DocumentsController> logger):ControllerBase
{
    public sealed record DocumentItem(Guid DocumentId,string DocumentName,string FileName,int FolderId,int? ParentId,string FolderName,string FolderPath,bool IsPdf);

    [HttpGet,ProducesResponseType<DocumentItem[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(rows=>Task.FromResult<IActionResult>(Ok(rows.Select(row=>
        new DocumentItem(row.DocumentID,row.DocumentName,row.DocumentPath,row.FolderID,row.ParentID,row.FolderName,row.FolderPath,IsPdf(row))).ToArray())),token);

    [HttpGet("{id:guid}/file")]
    public Task<IActionResult> FileById(Guid id,CancellationToken token)=>Execute(async rows=>
    {
        // Re-run current permissions before streaming; filenames and paths never come from the browser.
        var row=rows.SingleOrDefault(row=>row.DocumentID==id);
        if(row is null)return NotFound();
        var pdf=IsPdf(row);var stream=await files.OpenAsync(row,pdf,token);
        if(stream is null)return NotFound();
        var disposition=new ContentDispositionHeaderValue(pdf?"inline":"attachment");
        disposition.SetHttpFileName(row.DocumentPath);
        Response.Headers.ContentDisposition=disposition.ToString();
        Response.Headers.XContentTypeOptions="nosniff";
        return File(stream,pdf?"application/pdf":"application/octet-stream",enableRangeProcessing:pdf);
    },token);

    private static bool IsPdf(DocumentsStore.Row row)=>string.Equals(Path.GetExtension(row.DocumentPath),".pdf",StringComparison.OrdinalIgnoreCase);

    private async Task<IActionResult> Execute(Func<IReadOnlyList<DocumentsStore.Row>,Task<IActionResult>> action,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            var rows=await documents.GetAsync(name,token);
            return rows is null?Forbid():await action(rows);
        }
        catch(Exception exception) when(exception is SqlException or InvalidOperationException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        {
            logger.LogError(exception,"Documents read failed.");
            return Problem(statusCode:503,title:"Documents are temporarily unavailable.");
        }
    }
}
