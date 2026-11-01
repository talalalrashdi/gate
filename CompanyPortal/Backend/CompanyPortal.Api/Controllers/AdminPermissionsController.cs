using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;
[ApiController,Authorize,Route("api/admin/permissions"),RequestSizeLimit(16384),AdminSection("admin-permissions","permissions")]
public sealed class AdminPermissionsController(AdminPermissionsStore store,ILogger<AdminPermissionsController> logger):ControllerBase
{
    [HttpGet] public Task<IActionResult> Get(CancellationToken token)=>Run(async()=>Ok(await store.GetAsync(token)));
    [HttpPut,Consumes("application/json")] public Task<IActionResult> Save(SaveAdminPermissionsRequest request,CancellationToken token)=>Run(async()=>
    {
        if(request.RoleName=="CompanyPortal.Admin"||request.Sections.Any(s=>!AdminSections.All.Contains(s)||s=="permissions"))return BadRequest();
        await store.SaveAsync(request.RoleName,request.Sections,token);return NoContent();
    });
    private async Task<IActionResult> Run(Func<Task<IActionResult>> work)
    {
        if(!(await HttpContext.GetAdminAccessAsync()).IsSuperAdmin)return Forbid();
        try{return await work();}
        catch(SqlException e)when(e.Number==50006){return Problem(statusCode:400,title:"اختر دورًا نشطًا من نظام الأمن وأقسامًا صحيحة.");}
        catch(Exception e)when(e is SqlException or InvalidOperationException){logger.LogError(e,"Administration permission operation failed.");return Problem(statusCode:503,title:"تعذر تحميل أو حفظ الصلاحيات. تحقق من اتصال قاعدة البيانات وإجراء دليل الأدوار Security.Roles_getForAdministration.");}
    }
}
