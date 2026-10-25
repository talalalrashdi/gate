using System.Globalization;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/fixed-orders"),RequestSizeLimit(16384)]
public sealed class FixedOrdersAdministrationController(FixedOrdersStore orders,AdministrationStore administration,
    IConfiguration configuration,ILogger<FixedOrdersAdministrationController> logger):ControllerBase
{
    [HttpGet,ProducesResponseType<FixedOrder[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await orders.GetForAdministrationAsync(token)),false,token);

    [HttpPost,Consumes("application/json")]
    public Task<IActionResult> Create(SaveFixedOrderRequest request,CancellationToken token)=>Execute(async()=>
        StatusCode(201,new {FixedOrderId=(await orders.SaveAsync(null,request,token)).ToString(CultureInfo.InvariantCulture)}),true,token);

    [HttpPut("{id:long:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> Update(long id,SaveFixedOrderRequest request,CancellationToken token)=>Execute(async()=>
    {await orders.SaveAsync(id,request,token);return NoContent();},true,token);

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,bool write,CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        var name=User.Identity?.Name;if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            if(!await administration.IsAdminAsync(name,token))return Forbid();
            if(write)
            {
                if(Request.Headers["X-CompanyPortal-Request"]!="fixed-orders")return Problem(statusCode:400,title:"Missing fixed-orders request header.");
                var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
                if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();
            }
            return await action();
        }
        catch(SqlException e) when(e.Number==50011){return NotFound();}
        catch(SqlException e) when(e.Number==50012){return Problem(statusCode:400,title:"Check the directive title, wording and previous text.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Fixed order administration failed.");return Problem(statusCode:503,title:"Fixed order administration is temporarily unavailable.");}
    }
}
