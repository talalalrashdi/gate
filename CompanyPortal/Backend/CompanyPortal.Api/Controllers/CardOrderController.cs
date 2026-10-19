using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize]
[Route("api/user-settings/card-order")]
public sealed class CardOrderController(UserSettingsStore settings, IConfiguration configuration,
    ILogger<CardOrderController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<CardOrderResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CardOrderResponse>> Get(CancellationToken token)
    {
        Response.Headers.CacheControl = "no-store";
        var name = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(name) || name.Length > 512) return Unauthorized();
        try
        {
            var result = await settings.GetCardOrderAsync(name, token);
            return result is null ? Unregistered() : Ok(result);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        { return DatabaseFailure(exception); }
    }

    [HttpPut, Consumes("application/json"), RequestSizeLimit(32768)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Put(SaveCardOrderRequest request,
        [FromHeader(Name = "X-CompanyPortal-Request")] string? requestType, CancellationToken token)
    {
        Response.Headers.CacheControl = "no-store";
        if (requestType != "card-order")
            return Problem(statusCode: 400, title: "Missing card-order request header.");
        var origin = Request.Headers.Origin.ToString();
        var allowed = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        if (origin.Length > 0 && origin != $"{Request.Scheme}://{Request.Host}"
            && !allowed.Contains(origin, StringComparer.Ordinal))
            return Problem(statusCode: 403, title: "Origin is not permitted.");
        var name = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(name) || name.Length > 512) return Unauthorized();
        try
        {
            return await settings.SaveCardOrderAsync(name, request.CardKeys, token) ? NoContent() : Unregistered();
        }
        catch (SqlException exception) when (exception.Number == 50004)
        {
            ModelState.AddModelError(nameof(request.CardKeys), "Supply all available card keys once. Reload if the catalog changed.");
            return ValidationProblem(ModelState);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        { return DatabaseFailure(exception); }
    }

    private ObjectResult Unregistered() => Problem(statusCode: 403,
        title: "User is not registered or is inactive.");

    private ObjectResult DatabaseFailure(Exception exception)
    {
        logger.LogError(exception, "Card order database operation failed.");
        return Problem(statusCode: 503, title: "Card order is temporarily unavailable.");
    }
}
