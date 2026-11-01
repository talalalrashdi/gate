using System.Globalization;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/technical-inbox")]
public sealed class TechnicalInboxController(TechnicalInboxStore store,IConfiguration configuration,ILogger<TechnicalInboxController> logger):ControllerBase
{
    [HttpGet]
    public Task<IActionResult> Inbox(CancellationToken token)=>Read(false,token);
    [HttpGet("count")]
    public Task<IActionResult> Count(CancellationToken token)=>Read(true,token);
    private async Task<IActionResult> Read(bool countOnly,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            var data=await store.GetAsync(name,countOnly,token);if(data is null)return Forbid();
            var raw=configuration["TechnicalServices:IsnadUrl"];
            var appUrl=Uri.TryCreate(raw,UriKind.Absolute,out var url)&&url.Scheme is "http" or "https"&&url.UserInfo.Length==0?url.AbsoluteUri:null;
            if(countOnly)return Ok(new{data.UnreadCount,appUrl});
            return Ok(new{items=data.Items.Select(r=>new{inboxId=r.TechnicalInboxId.ToString(CultureInfo.InvariantCulture),r.RequestType,r.DocumentNumber,r.OfficeNumber,r.Details,r.HasAttachment,r.IsOpened,receivedAt=DecisionNoticesStore.Oman(r.ReceivedAt).ToString("O",CultureInfo.InvariantCulture)}),data.UnreadCount,appUrl});
        }
        catch(Exception ex) when(ex is SqlException or InvalidOperationException or System.Data.DataException)
        {logger.LogError(ex,"Technical inbox failed; trace {Trace}",HttpContext.TraceIdentifier);return Problem(statusCode:503,title:"تعذر تحميل وارد الإسناد الفني. تحقق من اتصال قاعدة البيانات وإجراءات المصدر.");}
    }
}
