using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/user-cards"), RequestSizeLimit(32768)]
public sealed class UserCardsController(UserCardsStore cards, IConfiguration configuration,
    ILogger<UserCardsController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<UserCardResponse[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token) => Read(null, token);

    [HttpGet("{id:int:min(1)}")]
    [ProducesResponseType<UserCardResponse>(StatusCodes.Status200OK)]
    public Task<IActionResult> GetById(int id, CancellationToken token) => Read(id, token);

    [HttpPost, Consumes("application/json")]
    [ProducesResponseType<UserCardIdentity>(StatusCodes.Status201Created)]
    public Task<IActionResult> Create(SaveUserCardRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:int:min(1)}"), Consumes("application/json")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public Task<IActionResult> Update(int id, SaveUserCardRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:int:min(1)}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken token)
    {
        if (Prepare(write: true) is { } error) return error;
        try { return await cards.DeleteAsync(User.Identity!.Name!, id, token) ? NoContent() : Unregistered(); }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return Failure(exception); }
    }

    [HttpGet("/api/applications")]
    [ProducesResponseType<AuthorizedApplication[]>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Applications(CancellationToken token)
    {
        if (Prepare(write: false) is { } error) return error;
        try
        {
            var result = await cards.GetApplicationsAsync(User.Identity!.Name!, token);
            return result is null ? Unregistered() : Ok(result.Select(app => new AuthorizedApplication(app.AppId, app.AppName)));
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return Failure(exception); }
    }

    [HttpGet("/api/applications/{id:int:min(1)}/launch")]
    [ProducesResponseType(StatusCodes.Status302Found)]
    public async Task<IActionResult> Launch(int id, CancellationToken token)
    {
        if (Prepare(write: false) is { } error) return error;
        try
        {
            var allowed = await cards.GetApplicationsAsync(User.Identity!.Name!, token);
            if (allowed is null) return Unregistered();
            var app = allowed.SingleOrDefault(item => item.AppId == id);
            if (app is null) return NotFound();
            if (!Uri.TryCreate(app.LaunchUrl, UriKind.Absolute, out var address)
                || (address.Scheme != Uri.UriSchemeHttp && address.Scheme != Uri.UriSchemeHttps)
                || !string.IsNullOrEmpty(address.UserInfo))
                throw new InvalidOperationException("Configure a valid application launch address.");
            return Redirect(address.AbsoluteUri);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return Failure(exception); }
    }

    private async Task<IActionResult> Read(int? id, CancellationToken token)
    {
        if (Prepare(write: false) is { } error) return error;
        try
        {
            var result = await cards.GetAsync(User.Identity!.Name!, token);
            if (result is null) return Unregistered();
            if (id is null) return Ok(result);
            var card = result.SingleOrDefault(item => item.UserCardId == id);
            return card is null ? NotFound() : Ok(card);
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return Failure(exception); }
    }

    private async Task<IActionResult> Save(int? id, SaveUserCardRequest request, CancellationToken token)
    {
        if (Prepare(write: true) is { } error) return error;
        try
        {
            var savedId = await cards.SaveAsync(User.Identity!.Name!, id, request, token);
            if (savedId is null) return Unregistered();
            return id is null ? CreatedAtAction(nameof(GetById), new { id = savedId.Value }, new UserCardIdentity(savedId.Value)) : NoContent();
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException) { return Failure(exception); }
    }

    private IActionResult? Prepare(bool write)
    {
        Response.Headers.CacheControl = "no-store";
        var account = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length > 512) return Unauthorized();
        if (!write) return null;
        if (Request.Headers["X-CompanyPortal-Request"] != "custom-cards")
            return Problem(statusCode: 400, title: "Missing custom-cards request header.");
        var origin = Request.Headers.Origin.ToString();
        var allowed = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        return origin.Length > 0 && origin != $"{Request.Scheme}://{Request.Host}"
            && !allowed.Contains(origin, StringComparer.Ordinal)
            ? Problem(statusCode: 403, title: "Origin is not permitted.") : null;
    }

    private ObjectResult Unregistered() => Problem(statusCode: 403, title: "User is not registered or is inactive.");
    private IActionResult Failure(Exception exception)
    {
        if (exception is SqlException { Number: 50008 }) return NotFound();
        if (exception is SqlException { Number: 50007 or 50009 })
            return Problem(statusCode: 400, title: "Select authorized applications and check the card limits.");
        logger.LogError(exception, "Custom card operation failed.");
        return Problem(statusCode: 503, title: "Custom cards are temporarily unavailable.");
    }
}
