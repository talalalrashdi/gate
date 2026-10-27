using CompanyPortal.Api.Contracts;
using System.Globalization;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/technical-services"),RequestSizeLimit(32768)]
public sealed class TechnicalServicesController(TechnicalServicesStore store,IConfiguration configuration,ILogger<TechnicalServicesController> logger):ControllerBase
{
    [HttpGet]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async user=>
    {
        var catalog=await store.CatalogAsync(user,token);
        string? Link(string name){var raw=configuration["TechnicalServices:"+name];return Uri.TryCreate(raw,UriKind.Absolute,out var u)&&u.Scheme is "http" or "https"&&u.UserInfo.Length==0?u.AbsoluteUri:null;}
        return Ok(new{catalog.AssignmentRecipients,catalog.ReportCategories,catalog.ReportRecipients,catalog.ReportTypes,catalog.InitiativeTypes,
            links=new{assignment=Link("IsnadUrl"),report=Link("ReportsUrl"),initiative=Link("ReportsUrl")}});
    },false,token);

    [HttpPost("{kind}"),Consumes("application/json")]
    public Task<IActionResult> Create(string kind,TechnicalServiceRequest request,CancellationToken token)=>Execute(async user=>
    {
        if(kind is not ("assignment" or "report" or "initiative"))return NotFound();
        if(request.RequestKey==Guid.Empty||string.IsNullOrWhiteSpace(request.Details)
            ||kind!="assignment"&&string.IsNullOrWhiteSpace(request.Title)
            ||kind=="assignment"&&(request.RecipientId is null or <=0||request.TypeId is not null||request.CategoryId is not null)
            ||kind!="assignment"&&(request.TypeId is null or <=0)
            ||kind=="report"&&(request.CategoryId is null or <=0)
            ||kind=="initiative"&&(request.CategoryId is not null||request.RecipientId is not null))
            return Problem(statusCode:400,title:"تحقق من الحقول المطلوبة ونوع الخدمة.");
        var id=await store.CreateAsync(kind,user,request,token);
        return StatusCode(201,new{requestId=id.ToString(CultureInfo.InvariantCulture)});
    },true,token);

    private async Task<IActionResult> Execute(Func<int,Task<IActionResult>> action,bool write,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        if(write){
            if(Request.Headers["X-CompanyPortal-Request"]!="technical-services")return BadRequest();
            var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
            if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();
        }
        try{var user=await store.UserAsync(name,token);return user is null?Forbid():await action(user.Value);}
        catch(SqlException ex) when(ex.Number==50012){return Problem(statusCode:400,title:"القائمة المختارة غير متاحة أو لا تتوافق مع تصنيف البلاغ. حدّث القوائم وحاول مجددًا.");}
        catch(Exception ex) when(ex is SqlException or InvalidOperationException or System.Data.DataException)
        {logger.LogError(ex,"Technical service request failed; trace {Trace}",HttpContext.TraceIdentifier);return Problem(statusCode:503,title:"تعذر الاتصال بنظام الخدمة. احتفظ بالتفاصيل وحاول مجددًا.");}
    }
}
