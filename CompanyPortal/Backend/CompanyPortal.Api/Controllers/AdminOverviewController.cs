using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/admin"),
 AdminSection("admin-overview", "cards", "applications", "documents", "safety", "fixed-orders", "header-content", "notices", "alerts", "media", "images", "themes")]
public sealed class AdminOverviewController(AdminChangesStore changes, OrganizationStatusStore status,
    HeaderContentStore header, MagazinesStore magazines, PortalMediaStore media, DecisionNoticesStore notices,
    LegalDecisionsStore decisions, ILogger<AdminOverviewController> logger) : ControllerBase
{
    [HttpGet("changes/latest")]
    public Task<IActionResult> Latest([FromQuery] string section, CancellationToken token) => Execute(async () =>
    {
        if (!AdminSections.All.Contains(section, StringComparer.Ordinal)) return BadRequest();
        var access = await HttpContext.GetAdminAccessAsync();
        if (!access.CanManage(section)) return Forbid();
        return Ok(await changes.GetAsync(access.GetManagedSections(), section, token));
    });

    [HttpGet("overview")]
    public Task<IActionResult> Overview(CancellationToken token) => Execute(async () =>
    {
        var access = await HttpContext.GetAdminAccessAsync();
        var cards = new List<object>();
        if (access.CanManage("header-content"))
        {
            var current = await status.GetAsync(token);
            var levels = await header.GetLevelsAsync(token);
            cards.Add(new { Section = "header-content", Kind = "status", Value = current,
                Name = levels.FirstOrDefault(l => l.ColorValue == current?.ColorValue)?.Title });
        }
        var magazine = (await magazines.GetAsync(User.Identity!.Name!, null, token))?.FirstOrDefault();
        cards.Add(new { Section = (string?)null, Kind = "magazine", Value = magazine is null ? null :
            new { magazine.MagazineID, magazine.MagazineName, magazine.IssueNumber, magazine.IssueDate } });
        if (access.CanManage("notices") || access.CanManage("alerts"))
        {
            var catalog = await notices.GetAsync(token);
            var rows = await decisions.GetAsync(User.Identity!.Name!, null, token);
            if (rows is null) return Forbid();
            var now = DateTimeOffset.UtcNow;
            foreach (var (section, channel) in new[] { ("notices", 1), ("alerts", 2) })
            {
                if (!access.CanManage(section)) continue;
                var visible = rows.Where(r => catalog.For(r).Any(a => a.ChannelId == channel && a.FromAt <= now && now < a.ToAt))
                    .OrderByDescending(r => r.PublishedAt).ThenByDescending(r => r.DecisionId).ToArray();
                cards.Add(new { Section = section, Kind = "notices", Count = visible.Length, Titles = visible.Take(3).Select(r => r.Title) });
            }
        }
        if (access.CanManage("media"))
        {
            var catalog = await media.GetAsync(false, token);
            cards.Add(new { Section = "media", Kind = "media", Items = catalog.Items.OrderByDescending(r => r.LastChangeAt)
                .ThenByDescending(r => r.MediaID).Take(3).Select(r => new { r.MediaID, r.MediaName, r.MediaType, r.LastChangeAt }) });
        }
        return Ok(new { Cards = cards, Changes = await changes.GetAsync(access.GetManagedSections(), null, token) });
    });

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try { return await action(); }
        catch (Exception e) when (e is SqlException or InvalidOperationException or System.Text.Json.JsonException)
        {
            logger.LogError(e, "Administration overview/history lookup failed.");
            return Problem(statusCode: 503, title: "Administration information is temporarily unavailable.");
        }
    }
}
