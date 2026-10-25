using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

public sealed class AdminController(IConfiguration configuration) : Controller
{
    [HttpGet("/admin/diagnostics")]
    public IActionResult Diagnostics() => configuration.GetValue<bool>("Diagnostics:Enabled") ? View() : NotFound();
    // Public shell only. The browser calls the API with the visitor's Windows identity;
    // the API authorizes every read/write. Never use the MVC process identity here.
    [HttpGet("/admin/cards")]
    [HttpGet("/admin")]
    [HttpGet("/admin/images")]
    [HttpGet("/admin/themes")]
    [HttpGet("/admin/applications")]
    [HttpGet("/admin/documents")]
    [HttpGet("/admin/safety")]
    [HttpGet("/admin/fixed-orders")]
    [HttpGet("/admin/media")]
    public IActionResult Cards()
    {
        ViewData["AdminSection"] = Request.Path.Value?.TrimEnd('/').EndsWith("/cards", StringComparison.OrdinalIgnoreCase) == true ? "cards" : "overview";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/images", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "images";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/themes", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "themes";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/applications", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "applications";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/documents", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "documents";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/safety", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "safety";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/fixed-orders", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "fixed-orders";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/media", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "media";
        return View();
    }
    [HttpGet("/admin/theme-preview")]
    public IActionResult ThemePreview() => View();
}
