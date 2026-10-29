using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

[Route("admin")]
public sealed class AdminController : Controller
{
    // Section keys served by the admin shell (/admin/{section}); matches data-admin-panel in the views.
    private static readonly HashSet<string> Sections = new(StringComparer.OrdinalIgnoreCase)
        { "events", "history", "cards", "applications", "documents", "safety", "fixed-orders", "header-content", "notices", "alerts", "media", "images", "themes" };

    [HttpGet("health")]
    public IActionResult Health() => View();

    [HttpGet("content-preview")]
    public IActionResult ContentPreview() { Response.Headers.ContentSecurityPolicy="frame-ancestors 'self'"; Response.Headers.CacheControl="no-store"; return View(); }

    // Public shell only. The browser calls the API with the visitor's Windows identity;
    // the API authorizes every read/write. Never use the MVC process identity here.
    [HttpGet("")]
    [HttpGet("{section}")]
    public IActionResult Cards(string? section)
    {
        if (section is not null && !Sections.Contains(section)) return NotFound();
        ViewData["AdminSection"] = section?.ToLowerInvariant() ?? "overview";
        return View();
    }

    [HttpGet("theme-preview")]
    public IActionResult ThemePreview() => View();
}
