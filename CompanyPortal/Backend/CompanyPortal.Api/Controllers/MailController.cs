using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Xml;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Mail;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/mail")]
public sealed class MailController(MailIdentityStore identities, MailSessionFactory sessions, MailStreamLimits limits,
    IConfiguration configuration, ILogger<MailController> logger) : ControllerBase
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [HttpGet("inbox")]
    [ProducesResponseType<InboxSnapshot>(StatusCodes.Status200OK)]
    public Task<IActionResult> Inbox(CancellationToken token) => Execute(async session => Ok(await session.SnapshotAsync(token)), token);

    [HttpGet("open")]
    public Task<IActionResult> Open([Required, StringLength(8000, MinimumLength = 1)] string itemId, CancellationToken token) => Execute(async session =>
    {
        var link = await session.MessageLinkAsync(itemId, token);
        return link is null ? NotFound() : Redirect(link);
    }, token);

    [HttpGet("inbox/open")]
    public Task<IActionResult> OpenInbox(CancellationToken token) => Execute(session => Task.FromResult<IActionResult>(Redirect(session.InboxLink)), token);

    [HttpGet("stream")]
    public async Task<IActionResult> Stream(CancellationToken token)
    {
        Prepare();
        var account = Account(); if (account is null) return Unauthorized();
        if (!PermittedOrigin()) return Forbid();
        if (!configuration.GetValue<bool>("Exchange:Enabled")) return Unavailable();
        using var lease = limits.TryEnter(account);
        if (lease is null) { Response.Headers.RetryAfter = "30"; return StatusCode(429); }
        using var lifetime = CancellationTokenSource.CreateLinkedTokenSource(token);
        lifetime.CancelAfter(TimeSpan.FromMinutes(10));
        try
        {
            var mailbox = await identities.ResolveAsync(account, lifetime.Token); if (mailbox is null) return Forbid();
            await using var session = sessions.Create(mailbox);
            await using var events = session.ObserveAsync(lifetime.Token).GetAsyncEnumerator(lifetime.Token);
            Task<bool>? pending = null;
            try
            {
                // Attempt subscription and initial read before starting a successful
                // response. Disabled/misconfigured Exchange returns a normal 503.
                if (!await events.MoveNextAsync()) return NoContent();
                Response.ContentType = "text/event-stream; charset=utf-8";
                Response.Headers["X-Accel-Buffering"] = "no";
                HttpContext.Features.Get<IHttpResponseBodyFeature>()?.DisableBuffering();
                await Response.WriteAsync("retry: 5000\n\n", lifetime.Token);
                await Send("inbox", events.Current, lifetime.Token);
                while (!lifetime.IsCancellationRequested)
                {
                    pending ??= events.MoveNextAsync().AsTask();
                    using var heartbeat = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
                    var delay = Task.Delay(TimeSpan.FromSeconds(15), heartbeat.Token);
                    var completed = await Task.WhenAny(pending, delay);
                    heartbeat.Cancel();
                    // Registration/config checks are not inbox polling. Revoking
                    // access or changing the mailbox closes this employee's stream.
                    if (!string.Equals(mailbox, await identities.ResolveAsync(account, lifetime.Token), StringComparison.OrdinalIgnoreCase))
                        throw new InvalidOperationException("Mailbox access changed.");
                    if (completed == pending)
                    {
                        if (!await pending) break;
                        pending = null; await Send("inbox", events.Current, lifetime.Token);
                    }
                    else
                    {
                        await Response.WriteAsync(": keep-alive\n\n", lifetime.Token);
                        await Response.Body.FlushAsync(lifetime.Token);
                    }
                }
            }
            finally
            {
                lifetime.Cancel();
                if (pending is not null)
                    try { await pending; } catch (Exception error) when (MailFailure(error) || error is OperationCanceledException) { }
            }
        }
        catch (OperationCanceledException) when (lifetime.IsCancellationRequested) { }
        catch (EwsResponseException error) when (error.Code is "ErrorItemNotFound" or "ErrorInvalidIdMalformed")
        {
            if (!Response.HasStarted) return NotFound();
        }
        catch (Exception error) when (MailFailure(error) || error is OperationCanceledException)
        {
            logger.LogWarning(error, "Mail event stream is unavailable.");
            if (!Response.HasStarted) return Unavailable();
            if (!token.IsCancellationRequested) await Send("unavailable", new { message = "Mail connection interrupted." }, token);
        }
        return new EmptyResult();
    }

    private async Task<IActionResult> Execute(Func<EwsMailSession, Task<IActionResult>> action, CancellationToken token)
    {
        Prepare(); var account = Account(); if (account is null) return Unauthorized();
        if (!configuration.GetValue<bool>("Exchange:Enabled")) return Unavailable();
        try
        {
            var mailbox = await identities.ResolveAsync(account, token); if (mailbox is null) return Forbid();
            await using var session = sessions.Create(mailbox); return await action(session);
        }
        catch (EwsResponseException error) when (error.Code is "ErrorItemNotFound" or "ErrorInvalidIdMalformed") { return NotFound(); }
        catch (Exception error) when (MailFailure(error) || error is OperationCanceledException && !token.IsCancellationRequested)
        {
            logger.LogWarning(error, "Mail read is unavailable."); return Unavailable();
        }
    }
    private Task Send(string name, object data, CancellationToken token) => WriteEvent(name, data, token);
    private async Task WriteEvent(string name, object data, CancellationToken token)
    {
        await Response.WriteAsync($"event: {name}\ndata: {JsonSerializer.Serialize(data, JsonOptions)}\n\n", token);
        await Response.Body.FlushAsync(token);
    }
    private void Prepare() => Response.Headers.CacheControl = "private, no-store";
    private string? Account() => User.Identity?.Name is { Length: > 0 and <= 512 } name ? name : null;
    private ObjectResult Unavailable() => Problem(statusCode: 503, title: "Mail is not configured or is temporarily unavailable.");
    private static bool MailFailure(Exception error) => error is SqlException or InvalidOperationException or HttpRequestException or IOException or XmlException or FormatException or OverflowException;
    private bool PermittedOrigin()
    {
        var origin = Request.Headers.Origin.ToString();
        return origin.Length == 0 || origin == $"{Request.Scheme}://{Request.Host}"
            || (configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? []).Contains(origin, StringComparer.Ordinal);
    }
}
