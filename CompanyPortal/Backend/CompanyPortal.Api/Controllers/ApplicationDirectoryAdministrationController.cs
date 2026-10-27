using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/application-directory"),RequestSizeLimit(16384),AdminSection("application-directory","applications")]
public sealed class ApplicationDirectoryAdministrationController(AdministrationStore store,
    ILogger<ApplicationDirectoryAdministrationController> logger) : ControllerBase
{
    [HttpGet,ProducesResponseType<ApplicationDirectoryAdministration>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await store.GetApplicationDirectoryAsync(token)));

    [HttpPut("applications/{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> SaveApplication(int id,SaveApplicationDetailsRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveApplicationDetailsAsync(id,request,User.Identity!.Name!,token);return NoContent();});

    [HttpPost("categories"),Consumes("application/json"),ProducesResponseType<CategoryIdentity>(StatusCodes.Status201Created)]
    public Task<IActionResult> CreateCategory(SaveApplicationCategoryRequest request,CancellationToken token)=>Execute(async()=>
    {var id=await store.SaveApplicationCategoryAsync(null,request,User.Identity!.Name!,token);return StatusCode(201,new CategoryIdentity(id));});

    [HttpPut("categories/{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> UpdateCategory(int id,SaveApplicationCategoryRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveApplicationCategoryAsync(id,request,User.Identity!.Name!,token);return NoContent();});

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch(SqlException e) when(e.Number==50011) {return NotFound();}
        catch(SqlException e) when(e.Number==50012) {return Problem(statusCode:400,title:"Check category name, order and application details.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Application directory operation failed.");return Problem(statusCode:503,title:"Application directory is temporarily unavailable.");}
    }
}
