using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/application-directory"),RequestSizeLimit(16384)]
public sealed class ApplicationDirectoryAdministrationController(AdministrationStore store,IConfiguration configuration,
    ILogger<ApplicationDirectoryAdministrationController> logger) : ControllerBase
{
    [HttpGet,ProducesResponseType<ApplicationDirectoryAdministration>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await store.GetApplicationDirectoryAsync(token)),false,token);

    [HttpPut("applications/{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> SaveApplication(int id,SaveApplicationDetailsRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveApplicationDetailsAsync(id,request,token);return NoContent();},true,token);

    [HttpPost("categories"),Consumes("application/json"),ProducesResponseType<CategoryIdentity>(StatusCodes.Status201Created)]
    public Task<IActionResult> CreateCategory(SaveApplicationCategoryRequest request,CancellationToken token)=>Execute(async()=>
    {var id=await store.SaveApplicationCategoryAsync(null,request,token);return StatusCode(201,new CategoryIdentity(id));},true,token);

    [HttpPut("categories/{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> UpdateCategory(int id,SaveApplicationCategoryRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveApplicationCategoryAsync(id,request,token);return NoContent();},true,token);

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,bool write,CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        var name=User.Identity?.Name;
        if(string.IsNullOrWhiteSpace(name)||name.Length>512) return Unauthorized();
        try
        {
            if(!await store.IsAdminAsync(name,token)) return Forbid();
            if(write)
            {
                if(Request.Headers["X-CompanyPortal-Request"]!="application-directory") return Problem(statusCode:400,title:"Missing application-directory request header.");
                var origin=Request.Headers.Origin.ToString();
                var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
                if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal)) return Problem(statusCode:403,title:"Origin is not permitted.");
            }
            return await action();
        }
        catch(SqlException e) when(e.Number==50011) {return NotFound();}
        catch(SqlException e) when(e.Number==50012) {return Problem(statusCode:400,title:"Check category name, order and application details.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Application directory operation failed.");return Problem(statusCode:503,title:"Application directory is temporarily unavailable.");}
    }
}
