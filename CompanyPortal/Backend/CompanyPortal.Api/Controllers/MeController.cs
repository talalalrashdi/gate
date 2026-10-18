using System.Security.Claims;
using CompanyPortal.Api.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/me")]
public sealed class MeController : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<CurrentUserResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public ActionResult<CurrentUserResponse> Get()
    {
        Response.Headers.CacheControl = "no-store";

        return Ok(new CurrentUserResponse(
            User.Identity!.Name ?? string.Empty,
            User.FindFirstValue(ClaimTypes.PrimarySid) ?? User.FindFirstValue(ClaimTypes.Sid),
            User.Identity.AuthenticationType));
    }
}
