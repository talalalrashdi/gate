using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/header-content"),RequestSizeLimit(16384)]
public sealed class HeaderContentAdministrationController(HeaderContentStore store,AdministrationStore administration,
    IConfiguration configuration,ILogger<HeaderContentAdministrationController> logger):ControllerBase
{
    [HttpGet,ProducesResponseType<HeaderContentAdministration>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await store.GetForAdministrationAsync(token)),false,token);

    [HttpPost("important-numbers"),Consumes("application/json")]
    public Task<IActionResult> CreateNumber(SaveImportantNumberRequest request,CancellationToken token)=>Execute(async()=>
        StatusCode(201,new {Id=await store.SaveNumberAsync(null,request,token)}),true,token);

    [HttpPut("important-numbers/{id:int:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> UpdateNumber(int id,SaveImportantNumberRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveNumberAsync(id,request,token);return NoContent();},true,token);

    [HttpDelete("important-numbers/{id:int:min(1)}")]
    public Task<IActionResult> DeleteNumber(int id,CancellationToken token)=>Execute(async()=>
    {await store.DeleteNumberAsync(id,token);return NoContent();},true,token);

    [HttpPut("status-levels/{colorValue:int:range(1,4)}"),Consumes("application/json")]
    public Task<IActionResult> UpdateLevel(int colorValue,SaveStatusLevelRequest request,CancellationToken token)=>Execute(async()=>
    {await store.SaveLevelAsync(colorValue,request,token);return NoContent();},true,token);

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,bool write,CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            if(!await administration.IsAdminAsync(name,token))return Forbid();
            if(write)
            {
                if(Request.Headers["X-CompanyPortal-Request"]!="header-content")return Problem(statusCode:400,title:"Missing header-content request header.");
                var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
                if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();
            }
            return await action();
        }
        catch(SqlException e) when(e.Number==50011){return NotFound();}
        catch(SqlException e) when(e.Number==50039){return Problem(statusCode:400,title:"Fill in the required fields.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Header content administration failed.");return Problem(statusCode:503,title:"Header content administration is temporarily unavailable.");}
    }
}
