using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Globalization;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/correspondence")]
public sealed class CorrespondenceInboxController(CorrespondenceInboxStore store,IConfiguration config,ILogger<CorrespondenceInboxController> logger):ControllerBase
{
    [HttpGet]
    public Task<IActionResult> Inbox(CancellationToken token)=>Read(null,data=>
        Ok(new{items=data.Items.Select(r=>new{correspondenceId=r.CorrespondenceId.ToString(CultureInfo.InvariantCulture),r.DocNo,r.Title,r.Purpose,r.SenderName,
            receivedAt=DecisionNoticesStore.Oman(r.ReceivedAt).ToString("O",CultureInfo.InvariantCulture),r.IsOpened,
            isSamplePreview=r.IsSample&&config.GetValue<bool>("Correspondence:AllowSamplePreview"),canOpen=OpenAddress(r) is not null}).ToArray(),data.UnreadCount}),token);

    [HttpGet("{id:long:min(1)}/open")]
    public Task<IActionResult> Open(long id,CancellationToken token)=>Read(id,data=>
    {
        var row=data.Items.SingleOrDefault(r=>r.CorrespondenceId==id);if(row is null)return NotFound();
        var address=OpenAddress(row);
        return address is null?Problem(statusCode:503,title:"لم يتم إعداد رابط تطبيق المراسلات بعد."):Redirect(address);
    },token);
    private string? OpenAddress(CorrespondenceInboxStore.Row row)
    {
        var template=config["Correspondence:ItemUrlTemplate"];
        if(string.IsNullOrWhiteSpace(template)||!template.Contains("{id}",StringComparison.Ordinal)&&!template.Contains("{docNo}",StringComparison.Ordinal))return null;
        var url=template.Replace("{id}",row.CorrespondenceId.ToString(CultureInfo.InvariantCulture),StringComparison.Ordinal)
            .Replace("{docNo}",Uri.EscapeDataString(row.DocNo),StringComparison.Ordinal);
        return Uri.TryCreate(url,UriKind.Absolute,out var address)&&address.Scheme is "https" or "http"&&address.UserInfo.Length==0?address.AbsoluteUri:null;
    }
    private async Task<IActionResult> Read(long? id,Func<CorrespondenceInboxStore.Inbox,IActionResult> action,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";var name=User.Identity?.Name;
        if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try{var data=await store.GetAsync(name,id,token);return data is null?Forbid():action(data);}
        catch(SqlException ex) when(ex.Number==0&&token.IsCancellationRequested&&HttpContext.RequestAborted.IsCancellationRequested)
        {throw new OperationCanceledException("Correspondence request canceled by client.",ex,token);}
        catch(Exception ex) when(ex is SqlException or InvalidOperationException or System.Data.DataException)
        {logger.LogError(ex,"Correspondence inbox failed; trace {Trace}",HttpContext.TraceIdentifier);return Problem(statusCode:503,title:"تعذر تحميل وارد المراسلات. تحقق من اتصال قاعدة البيانات وإجراءات المصدر.");}
    }
}
