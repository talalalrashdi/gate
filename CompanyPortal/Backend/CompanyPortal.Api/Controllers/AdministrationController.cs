using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/admin/cards"), RequestSizeLimit(32768)]
public sealed class AdministrationController(AdministrationStore store, IConfiguration configuration,
    ILogger<AdministrationController> logger) : ControllerBase
{
    [HttpGet("/api/access")]
    [ProducesResponseType<PortalAccess>(StatusCodes.Status200OK)]
    public Task<IActionResult> Access(CancellationToken token) => Execute(admin => Task.FromResult<IActionResult>(Ok(new PortalAccess(admin))), false, false, token);

    [HttpGet]
    [ProducesResponseType<MasterCard[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token) => Execute(async _ => Ok(await store.GetCardsAsync(token)), true, false, token);

    [HttpGet("applications")]
    [ProducesResponseType<AuthorizedApplication[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Applications(CancellationToken token) => Execute(async _ => Ok(await store.GetApplicationsAsync(token)), true, false, token);

    [HttpPost, Consumes("application/json")]
    [ProducesResponseType<MasterCardIdentity>(StatusCodes.Status201Created)]
    public Task<IActionResult> Create(SaveMasterCardRequest request, CancellationToken token) => Execute(async _ =>
    {
        var id = await store.SaveCardAsync(null,request,token);
        return StatusCode(StatusCodes.Status201Created,new MasterCardIdentity(id));
    },true,true,token);

    [HttpPut("{id:int:min(1)}"), Consumes("application/json")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public Task<IActionResult> Save(int id, SaveMasterCardRequest request, CancellationToken token) => Execute(async _ =>
    {
        await store.SaveCardAsync(id, request, token);
        return NoContent();
    }, true, true, token);

    private async Task<IActionResult> Execute(Func<bool, Task<IActionResult>> action, bool requireAdmin, bool write, CancellationToken token)
    {
        Response.Headers.CacheControl = "no-store";
        var account = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length > 512) return Unauthorized();
        try
        {
            // No role cache: every operation consults the current external permission source.
            var admin = await store.IsAdminAsync(account, token);
            if (requireAdmin && !admin) return Forbid();
            if (write)
            {
                if (Request.Headers["X-CompanyPortal-Request"] != "admin-cards")
                    return Problem(statusCode: 400, title: "Missing admin-cards request header.");
                var origin = Request.Headers.Origin.ToString();
                var allowed = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
                if (origin.Length > 0 && origin != $"{Request.Scheme}://{Request.Host}" && !allowed.Contains(origin, StringComparer.Ordinal))
                    return Problem(statusCode: 403, title: "Origin is not permitted.");
            }
            return await action(admin);
        }
        catch (SqlException exception) when (exception.Number == 50006)
        {
            return Problem(statusCode: 400, title: "Check the active card, name and position. Another fixed card may occupy that position.");
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception, "Portal administration operation failed.");
            return Problem(statusCode: 503, title: "Portal administration is temporarily unavailable.");
        }
    }
}
