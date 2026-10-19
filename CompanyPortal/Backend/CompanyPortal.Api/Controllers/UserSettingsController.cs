using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/user-settings/theme")]
public sealed class UserSettingsController(UserSettingsStore settings, IConfiguration configuration,
    ILogger<UserSettingsController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<ThemeSettingsResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<ThemeSettingsResponse>> Get(CancellationToken cancellationToken)
    {
        Response.Headers.CacheControl = "no-store";
        var name = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(name) || name.Length > 512) return Unauthorized();
        try
        {
            var result = await settings.GetThemeAsync(name, cancellationToken);
            return result is null ? Unregistered() : Ok(result);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return DatabaseFailure(exception); }
    }

    [HttpPut]
    [Consumes("application/json")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Put(SaveThemeRequest request,
        [FromHeader(Name = "X-CompanyPortal-Request")] string? requestType,
        CancellationToken cancellationToken)
    {
        Response.Headers.CacheControl = "no-store";
        // Custom-header + JSON requests cannot be submitted by a cross-site HTML form.
        // Cross-origin scripts must first pass the explicit credentialed CORS policy.
        if (requestType != "theme")
            return Problem(statusCode: 400, title: "Missing theme request header.");
        var origin = Request.Headers.Origin.ToString();
        var allowedOrigins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        var sameOrigin = $"{Request.Scheme}://{Request.Host}";
        if (origin.Length > 0 && origin != sameOrigin && !allowedOrigins.Contains(origin, StringComparer.Ordinal))
            return Problem(statusCode: 403, title: "Origin is not permitted.");
        var name = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(name) || name.Length > 512) return Unauthorized();
        try
        {
            return await settings.SaveThemeAsync(name, request.ThemeId, cancellationToken)
                ? NoContent() : Unregistered();
        }
        catch (SqlException exception) when (exception.Number == 50002)
        {
            ModelState.AddModelError(nameof(request.ThemeId), "Select an available theme.");
            return ValidationProblem(ModelState);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return DatabaseFailure(exception); }
    }

    private ObjectResult Unregistered() => Problem(statusCode: 403,
        title: "User is not registered or is inactive.",
        detail: "Contact the administrator to register your Windows account in the security database.");

    private ObjectResult DatabaseFailure(Exception exception)
    {
        logger.LogError(exception, "Theme settings database operation failed.");
        return Problem(statusCode: 503, title: "Theme settings are temporarily unavailable.");
    }
}
