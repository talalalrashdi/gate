using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/document-library"),Route("api/admin/safety-library"),RequestSizeLimit(65536)]
public sealed class DocumentLibraryAdministrationController(DocumentTabsStore tabs,DocumentsStore documents,AdministrationStore administration,
    IConfiguration configuration,ILogger<DocumentLibraryAdministrationController> logger):ControllerBase
{
    private bool IsSafety=>Request.Path.StartsWithSegments("/api/admin/safety-library");
    private string SectionKey=>IsSafety?"safety":"documents";
    [HttpGet]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async rows=>
    {
        var catalog=await tabs.GetAsync(true,token,SectionKey);
        return Ok(new {Tabs=catalog.Tabs.Select(t=>new {DocumentTabId=t.DocumentTabID,t.TabName,FolderId=t.FolderID,t.DisplayOrder,t.LastChangeAt,t.Active}),
            Items=catalog.Items.Select(i=>new {DocumentTabId=i.DocumentTabID,DocumentId=i.DocumentID}),Documents=rows.Select(r=>new {DocumentId=r.DocumentID,r.DocumentName,
            FileName=r.DocumentPath,FolderId=r.FolderID,r.FolderName}).ToArray()});
    },false,token);

    [HttpPost,Consumes("application/json")]
    public Task<IActionResult> Create(DocumentTabsStore.SaveRequest request,CancellationToken token)=>Save(null,request,token);
    [HttpPut("{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> Update(int id,DocumentTabsStore.SaveRequest request,CancellationToken token)=>Save(id,request,token);

    private Task<IActionResult> Save(int? id,DocumentTabsStore.SaveRequest request,CancellationToken token)=>Execute(async rows=>
    {
        if((IsSafety&&request.DocumentIds.Length!=1)||string.IsNullOrWhiteSpace(request.TabName)||request.DocumentIds.Distinct().Count()!=request.DocumentIds.Length
            ||request.DocumentIds.Any(g=>!rows.Any(r=>r.DocumentID==g&&r.FolderID==request.FolderId)))
            return Problem(statusCode:400,title:"Select authorized PDFs from the selected folder.");
        return Ok(new {DocumentTabId=await tabs.SaveAsync(id,request,token,SectionKey)});
    },true,token);

    private async Task<IActionResult> Execute(Func<IReadOnlyList<DocumentsStore.Row>,Task<IActionResult>> action,bool write,CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            if(!await administration.IsAdminAsync(name,token))return Forbid();
            if(write)
            {
                if(Request.Headers["X-CompanyPortal-Request"]!=(IsSafety?"safety-library":"document-library"))return Problem(statusCode:400,title:"Missing document-library request header.");
                var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
                if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();
            }
            var rows=await documents.GetAsync(name,token);
            return rows is null?Forbid():await action(rows.Where(DocumentTabsStore.IsPdf).ToArray());
        }
        catch(SqlException e) when(e.Number==50011){return NotFound();}
        catch(SqlException e) when(e.Number==50012){return Problem(statusCode:400,title:"Check tab name, folder, order and PDF selection.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Document library administration failed.");return Problem(statusCode:503,title:"Document library administration is temporarily unavailable.");}
    }
}
