using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

[Route("admin")]
public sealed class AdminController(IConfiguration configuration) : Controller
{
    // Section keys served by the admin shell (/admin/{section}); matches data-admin-panel in the views.
    private static readonly HashSet<string> Sections = new(StringComparer.OrdinalIgnoreCase)
        { "cards", "applications", "documents", "safety", "fixed-orders", "header-content", "notices", "alerts", "media", "images", "themes" };

    [HttpGet("diagnostics")]
    public IActionResult Diagnostics() => configuration.GetValue<bool>("Diagnostics:Enabled") ? View() : NotFound();

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
