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
    public IActionResult Cards()
    {
        ViewData["AdminSection"] = Request.Path.Value?.TrimEnd('/').EndsWith("/cards", StringComparison.OrdinalIgnoreCase) == true ? "cards" : "overview";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/images", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "images";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/themes", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "themes";
        return View();
    }
    [HttpGet("/admin/theme-preview")]
    public IActionResult ThemePreview() => View();
}
