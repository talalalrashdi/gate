using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/header-content")]
public sealed class HeaderContentController(HeaderContentStore store,ILogger<HeaderContentController> logger):ControllerBase
{
    [HttpGet("important-numbers"),ProducesResponseType<ImportantNumber[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Numbers(CancellationToken token)=>Read(async()=>await store.GetNumbersAsync(token));

    [HttpGet("status-levels"),ProducesResponseType<StatusLevel[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Levels(CancellationToken token)=>Read(async()=>await store.GetLevelsAsync(token));

    private async Task<IActionResult> Read<T>(Func<Task<T>> read)
    {
        Response.Headers.CacheControl="no-store";
        try{return Ok(await read());}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Header content read failed.");return Problem(statusCode:503,title:"Header content is temporarily unavailable.");}
    }
}
