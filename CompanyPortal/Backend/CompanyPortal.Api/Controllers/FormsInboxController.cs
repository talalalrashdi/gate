using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Globalization;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/forms")]
public sealed class FormsInboxController(FormsInboxStore store,IConfiguration config,ILogger<FormsInboxController> logger):ControllerBase
{
    [HttpGet]
    public Task<IActionResult> Inbox(CancellationToken token)=>Read(null,data=>
        Ok(new{items=data.Items.Select(r=>new{formId=r.FormId.ToString(CultureInfo.InvariantCulture),r.Title,r.SenderName,
            sentAt=DecisionNoticesStore.Oman(r.SentAt).ToString("O",CultureInfo.InvariantCulture),r.IsOpened,
            isSamplePreview=r.IsSample&&config.GetValue<bool>("Forms:AllowSamplePreview"),
            canOpen=OpenAddress(r.FormId) is not null}).ToArray(),data.UnreadCount,appUrl=AppAddress()}),token);

    [HttpGet("{id:long:min(1)}/open")]
    public Task<IActionResult> Open(long id,CancellationToken token)=>Read(id,data=>
    {
        if(!data.Items.Any(r=>r.FormId==id))return NotFound();
        var address=OpenAddress(id);
        return address is null?Problem(statusCode:503,title:"لم يتم إعداد رابط تطبيق الاستمارات بعد."):Redirect(address);
    },token);

    private string? AppAddress()
    {
        var value=config["Forms:AppUrl"];
        return Uri.TryCreate(value,UriKind.Absolute,out var address)&&address.Scheme is "https" or "http"&&address.UserInfo.Length==0?address.AbsoluteUri:null;
    }
    private string? OpenAddress(long id)
    {
        var template=config["Forms:ItemUrlTemplate"];
        if(string.IsNullOrWhiteSpace(template)||!template.Contains("{id}",StringComparison.Ordinal))return null;
        var url=template.Replace("{id}",id.ToString(CultureInfo.InvariantCulture),StringComparison.Ordinal);
        return Uri.TryCreate(url,UriKind.Absolute,out var address)&&address.Scheme is "https" or "http"&&address.UserInfo.Length==0?address.AbsoluteUri:null;
    }
    private async Task<IActionResult> Read(long? id,Func<FormsInboxStore.Inbox,IActionResult> action,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try{var data=await store.GetAsync(name,id,token);return data is null?Forbid():action(data);}
        catch(Exception ex) when(ex is SqlException or InvalidOperationException or System.Data.DataException)
        {logger.LogError(ex,"Forms inbox failed; trace {Trace}",HttpContext.TraceIdentifier);return Problem(statusCode:503,title:"تعذر تحميل وارد الاستمارات. تحقق من اتصال قاعدة البيانات وإجراءات المصدر.");}
    }
}
