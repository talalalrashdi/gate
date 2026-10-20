using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/themes")]
public sealed class ThemesController(UserSettingsStore settings, ILogger<ThemesController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<ThemeDefinition>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ThemeDefinition>>> Get(CancellationToken cancellationToken)
    {
        Response.Headers.CacheControl = "no-store";
        try {
            if(string.IsNullOrWhiteSpace(User.Identity?.Name))return Unauthorized();
            var themes=await settings.GetThemesAsync(User.Identity.Name,cancellationToken);
            return themes.Count==0?Forbid():Ok(themes);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception, "Theme catalog could not be loaded.");
            return Problem(statusCode: 503, title: "Themes are temporarily unavailable.");
        }
    }
}
