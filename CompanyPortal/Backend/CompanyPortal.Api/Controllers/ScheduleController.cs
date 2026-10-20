using System.Text.Json;
using System.Xml;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Mail;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/schedule")]
public sealed class ScheduleController(MailIdentityStore identities,ScheduleService schedules,MailStreamLimits limits,IConfiguration configuration,ILogger<ScheduleController> logger):ControllerBase
{
    private static readonly JsonSerializerOptions JsonOptions=new(JsonSerializerDefaults.Web);
    [HttpGet("calendars")]
    [ProducesResponseType<ScheduleCatalog>(200)]
    public Task<IActionResult> Calendars(CancellationToken token)=>Execute(async(account,mailbox)=>Ok(await schedules.CalendarsAsync(account,mailbox,token)),token);
    [HttpGet]
    [ProducesResponseType<ScheduleSnapshot>(200)]
    public Task<IActionResult> Get([FromQuery] DateOnly from,[FromQuery] DateOnly to,[FromQuery] string calendar="own",CancellationToken token=default)
    {
        if(!ValidRange(from,to)||!ValidKey(calendar))return Task.FromResult<IActionResult>(BadRequest("Select a calendar range of 1–42 days."));
        return Execute(async(account,mailbox)=>{await using var session=schedules.Create(account,mailbox,calendar,from,to);return Ok(await session.SnapshotAsync(token));},token);
    }
    [HttpGet("stream")]
    public async Task<IActionResult> Stream([FromQuery] DateOnly from,[FromQuery] DateOnly to,[FromQuery] string calendar="own",CancellationToken token=default)
    {
        Prepare();
        if(!ValidRange(from,to)||!ValidKey(calendar))return BadRequest("Select a calendar range of 1–42 days.");
        var account = Account(); if (account is null) return Unauthorized();
        if (!PermittedOrigin()) return Forbid();
        if (!Enabled()) return Unavailable();
        using var lease = limits.TryEnter(account);
        if (lease is null) { Response.Headers.RetryAfter = "30"; return StatusCode(429); }
        using var lifetime = CancellationTokenSource.CreateLinkedTokenSource(token);
        lifetime.CancelAfter(TimeSpan.FromMinutes(10));
        try
        {
            var mailbox = await identities.ResolveAsync(account, lifetime.Token); if (mailbox is null) return Forbid();
            await using var session = schedules.Create(account,mailbox,calendar,from,to);
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
                await Send("schedule", events.Current, lifetime.Token);
                while (!lifetime.IsCancellationRequested)
                {
                    pending ??= events.MoveNextAsync().AsTask();
                    using var heartbeat = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
                    var delay = Task.Delay(TimeSpan.FromSeconds(15), heartbeat.Token);
                    var completed = await Task.WhenAny(pending, delay);
                    heartbeat.Cancel();
                    // Registration/config checks are not calendar-item polling. Revoking
                    // access or changing the mailbox closes this employee's stream.
                    if (!string.Equals(mailbox, await identities.ResolveAsync(account, lifetime.Token), StringComparison.OrdinalIgnoreCase))
                        throw new InvalidOperationException("Mailbox access changed.");
                    await session.AuthorizeAsync(lifetime.Token);
                    if (completed == pending)
                    {
                        if (!await pending) break;
                        pending = null; await Send("schedule", events.Current, lifetime.Token);
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
                    try { await pending; } catch (Exception error) when (ScheduleFailure(error) || error is OperationCanceledException) { }
            }
        }
        catch (OperationCanceledException) when (lifetime.IsCancellationRequested) { }
        catch (EwsResponseException error) when (error.Code is "ErrorAccessDenied" or "ErrorFolderNotFound" or "ErrorItemNotFound" or "ErrorInvalidIdMalformed")
        {
            if (!Response.HasStarted) return Forbid();
            if (!token.IsCancellationRequested) await Send("unavailable",new {message="Calendar access changed."},token);
        }
        catch (Exception error) when (ScheduleFailure(error) || error is OperationCanceledException)
        {
            logger.LogWarning(error, "Schedule event stream is unavailable.");
            if (!Response.HasStarted) return Unavailable();
            if (!token.IsCancellationRequested) await Send("unavailable", new { message = "Schedule connection interrupted." }, token);
        }
        return new EmptyResult();
    }

    private async Task<IActionResult> Execute(Func<string,string,Task<IActionResult>> action,CancellationToken token)
    {
        Prepare();var account=Account();if(account is null)return Unauthorized();if(!Enabled())return Unavailable();
        try{var mailbox=await identities.ResolveAsync(account,token);return mailbox is null?Forbid():await action(account,mailbox);}
        catch(EwsResponseException error)when(error.Code is "ErrorAccessDenied" or "ErrorFolderNotFound" or "ErrorItemNotFound" or "ErrorInvalidIdMalformed"){return Forbid();}
        catch(Exception error)when(ScheduleFailure(error)||error is OperationCanceledException&&!token.IsCancellationRequested){logger.LogWarning(error,"Exchange schedule read is unavailable.");return Unavailable();}
    }
    private static bool ValidRange(DateOnly from,DateOnly to)=>from.Year>=1900&&to.Year<=2100&&to.DayNumber-from.DayNumber is >0 and <=42;
    private static bool ValidKey(string key)=>key is not null&&System.Text.RegularExpressions.Regex.IsMatch(key,"^[a-zA-Z0-9_-]{1,40}$");
    private bool Enabled()=>configuration.GetValue<bool>("Exchange:Enabled")&&configuration.GetValue<bool>("Exchange:ScheduleEnabled");
    private void Prepare()=>Response.Headers.CacheControl="private, no-store";
    private string? Account()=>User.Identity?.Name is {Length:>0 and <=512} account?account:null;
    private ObjectResult Unavailable()=>Problem(statusCode:503,title:"Exchange calendar and tasks are not configured or are temporarily unavailable.");
    private static bool ScheduleFailure(Exception error)=>error is SqlException or InvalidOperationException or HttpRequestException or IOException or XmlException or FormatException or OverflowException or TimeZoneNotFoundException or InvalidTimeZoneException;
    private bool PermittedOrigin(){var origin=Request.Headers.Origin.ToString();return origin.Length==0||origin==$"{Request.Scheme}://{Request.Host}"||(configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[]).Contains(origin,StringComparer.Ordinal);}
    private async Task Send(string name,object data,CancellationToken token){await Response.WriteAsync($"event: {name}\ndata: {JsonSerializer.Serialize(data,JsonOptions)}\n\n",token);await Response.Body.FlushAsync(token);}
}
