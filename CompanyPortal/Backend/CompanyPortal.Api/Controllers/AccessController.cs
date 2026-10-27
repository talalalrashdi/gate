using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize]
public sealed class AccessController(ILogger<AccessController> logger) : ControllerBase
{
    // Any authenticated employee: drives the portal's admin icon and which admin sections the browser shows.
    // The API still authorizes every admin request through [AdminSection].
    [HttpGet("/api/access")]
    [ProducesResponseType<PortalAccess>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Get()
    {
        Response.Headers.CacheControl = "private, no-store";
        var account = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length > 512) return Unauthorized();
        try
        {
            var access = await HttpContext.GetAdminAccessAsync();
            var sections = access.GetManagedSections();
            return Ok(new PortalAccess(sections.Length > 0, access.IsSuperAdmin, sections));
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception, "Portal access lookup failed.");
            return Problem(statusCode: 503, title: "Portal administration is temporarily unavailable.");
        }
    }
}
