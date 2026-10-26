using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/organization-status")]
public sealed class OrganizationStatusController(OrganizationStatusStore store,ILogger<OrganizationStatusController> logger) : ControllerBase
{
    [HttpGet,ProducesResponseType<OrganizationStatus>(StatusCodes.Status200OK),ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        try
        {
            var status=await store.GetAsync(token);
            // 204 (not 404) for an empty table, so a 404 always means the endpoint itself is missing.
            return status is null?NoContent():Ok(status);
        }
        catch(Exception exception) when(exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception,"Organization status read failed.");
            return Problem(statusCode:503,title:"Organization status is temporarily unavailable.");
        }
    }
}
