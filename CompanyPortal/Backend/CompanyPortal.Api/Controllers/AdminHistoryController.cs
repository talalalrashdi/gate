using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/changes")]
public sealed class AdminHistoryController(AdminChangesStore changes,ILogger<AdminHistoryController> logger):ControllerBase
{
    [HttpGet]
    public Task<IActionResult> Search(string? section,string? person,DateOnly? from,DateOnly? to,int page=1,CancellationToken token=default)=>Execute(async()=>
    {
        if(section is not null&&!AdminSections.All.Contains(section,StringComparer.Ordinal)||person?.Length>512||page is <1 or >1000000
            ||from?.Year<1753||to?.Year<1753||to?.Year>=9999||from>to)return BadRequest();
        return Ok(await changes.SearchAsync(section,string.IsNullOrWhiteSpace(person)?null:person.Trim(),from?.ToDateTime(TimeOnly.MinValue),to?.AddDays(1).ToDateTime(TimeOnly.MinValue),page,token));
    });
    [HttpGet("{id:long:min(1)}")]
    public Task<IActionResult> Detail(long id,CancellationToken token)=>Execute(async()=>
    {var row=await changes.DetailAsync(id,token);return row is null?NotFound():Ok(row);});
    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        Response.Headers.CacheControl="private, no-store";
        if(string.IsNullOrWhiteSpace(User.Identity?.Name))return Unauthorized();
        try{if(!(await HttpContext.GetAdminAccessAsync()).IsSuperAdmin)return Forbid();return await action();}
        catch(Exception e)when(e is SqlException or InvalidOperationException){logger.LogError(e,"Admin history failed. Reference {Reference}",HttpContext.TraceIdentifier);return Problem(statusCode:503,title:"History is temporarily unavailable.",extensions:new Dictionary<string,object?>{{"reference",HttpContext.TraceIdentifier}});}
    }
}
