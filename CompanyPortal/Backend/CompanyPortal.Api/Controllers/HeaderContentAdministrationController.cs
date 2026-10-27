using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/header-content"),RequestSizeLimit(16384),AdminSection("header-content","header-content")]
public sealed class HeaderContentAdministrationController(HeaderContentStore store,ILogger<HeaderContentAdministrationController> logger):ControllerBase
{
    [HttpGet,ProducesResponseType<HeaderContentAdministration>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await store.GetForAdministrationAsync(token)));

    [HttpPost("important-numbers"),Consumes("application/json")]
    public Task<IActionResult> CreateNumber(SaveImportantNumberRequest request,CancellationToken token)=>Execute(async()=>
        StatusCode(201,new {Id=await store.SaveNumberAsync(null,request,User.Identity!.Name!,token)}));

    [HttpPut("important-numbers/{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> UpdateNumber(int id,SaveImportantNumberRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveNumberAsync(id,request,User.Identity!.Name!,token);return NoContent();});

    [HttpDelete("important-numbers/{id:int:min(1)}")]
    public Task<IActionResult> DeleteNumber(int id,CancellationToken token)=>Execute(async()=>
    {await store.DeleteNumberAsync(id,User.Identity!.Name!,token);return NoContent();});

    [HttpPut("status-levels/{colorValue:int:range(1,4)}"),Consumes("application/json")]
    public Task<IActionResult> UpdateLevel(int colorValue,SaveStatusLevelRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveLevelAsync(colorValue,request,User.Identity!.Name!,token);return NoContent();});

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch(SqlException e) when(e.Number==50011){return NotFound();}
        catch(SqlException e) when(e.Number==50039){return Problem(statusCode:400,title:"Fill in the required fields.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Header content administration failed.");return Problem(statusCode:503,title:"Header content administration is temporarily unavailable.");}
    }
}
