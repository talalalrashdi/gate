using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/fixed-orders")]
public sealed class FixedOrdersController(FixedOrdersStore store,ILogger<FixedOrdersController> logger) : ControllerBase
{
    [HttpGet,ProducesResponseType<FixedOrder[]>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        var name=User.Identity?.Name;
        if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            var orders=await store.GetAsync(name,token);
            return orders is null?Problem(statusCode:403,title:"User is not registered or is inactive."):Ok(orders);
        }
        catch(Exception exception) when(exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception,"Fixed orders read failed.");
            return Problem(statusCode:503,title:"Fixed orders are temporarily unavailable.");
        }
    }
}
