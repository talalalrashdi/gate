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
        try { return Ok(await settings.GetThemesAsync(cancellationToken)); }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception, "Theme catalog could not be loaded.");
            return Problem(statusCode: 503, title: "Themes are temporarily unavailable.");
        }
    }
}
