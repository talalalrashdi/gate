using System.Globalization;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/fixed-orders"),RequestSizeLimit(16384),AdminSection("fixed-orders","fixed-orders")]
public sealed class FixedOrdersAdministrationController(FixedOrdersStore orders,ILogger<FixedOrdersAdministrationController> logger):ControllerBase
{
    [HttpGet,ProducesResponseType<FixedOrder[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await orders.GetForAdministrationAsync(token)));

    [HttpPost,Consumes("application/json")]
    public Task<IActionResult> Create(SaveFixedOrderRequest request,CancellationToken token)=>Execute(async()=>
        StatusCode(201,new {FixedOrderId=(await orders.SaveAsync(null,request,User.Identity!.Name!,token)).ToString(CultureInfo.InvariantCulture)}));

    [HttpPut("{id:long:min(1)}"),Consumes("application/json")]
    public Task<IActionResult> Update(long id,SaveFixedOrderRequest request,CancellationToken token)=>Execute(async()=>
    {await orders.SaveAsync(id,request,User.Identity!.Name!,token);return NoContent();});

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch(SqlException e) when(e.Number==50011){return NotFound();}
        catch(SqlException e) when(e.Number==50012){return Problem(statusCode:400,title:"Check the directive title, wording and previous text.");}
        catch(Exception e) when(e is SqlException or InvalidOperationException)
        {logger.LogError(e,"Fixed order administration failed.");return Problem(statusCode:503,title:"Fixed order administration is temporarily unavailable.");}
    }
}
