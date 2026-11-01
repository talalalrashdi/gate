using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/header-content"),RequestSizeLimit(16384)]
public sealed class HeaderContentAdministrationController(HeaderContentStore store,ILogger<HeaderContentAdministrationController> logger):ControllerBase
{
    [HttpGet,AdminSection("header-content","important-numbers","institution-status"),ProducesResponseType<HeaderContentAdministration>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>{var access=await HttpContext.GetAdminAccessAsync();return Ok(await store.GetForAdministrationAsync(token,access.CanManage("important-numbers"),access.CanManage("institution-status")));});

    [HttpPost("important-numbers"),AdminSection("header-content","important-numbers"),Consumes("application/json")]
    public Task<IActionResult> CreateNumber(SaveImportantNumberRequest request,CancellationToken token)=>Execute(async()=>
        StatusCode(201,new {Id=await store.SaveNumberAsync(null,request,User.Identity!.Name!,token)}));

    [HttpPut("important-numbers/{id:int:min(1)}"),AdminSection("header-content","important-numbers"),Consumes("application/json")]
    public Task<IActionResult> UpdateNumber(int id,SaveImportantNumberRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveNumberAsync(id,request,User.Identity!.Name!,token);return NoContent();});

    [HttpDelete("important-numbers/{id:int:min(1)}"),AdminSection("header-content","important-numbers")]
    public Task<IActionResult> DeleteNumber(int id,CancellationToken token)=>Execute(async()=>
    {await store.DeleteNumberAsync(id,User.Identity!.Name!,token);return NoContent();});

    [HttpPut("status-levels/{colorValue:int:range(1,4)}"),AdminSection("header-content","institution-status"),Consumes("application/json")]
    public Task<IActionResult> UpdateLevel(int colorValue,SaveStatusLevelRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveLevelAsync(colorValue,request,User.Identity!.Name!,token);return NoContent();});

    [HttpGet("current-status"),AdminSection("header-content","institution-status")]
    public Task<IActionResult> Current(CancellationToken token)=>Execute(async()=>Ok(await store.CurrentAsync(token)));

    [HttpPut("current-status"),AdminSection("header-content","institution-status"),Consumes("application/json")]
    public Task<IActionResult> SetCurrent(SaveCurrentStatusRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SetCurrentAsync(request.ColorValue!.Value,User.Identity!.Name!,token);return NoContent();});

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
