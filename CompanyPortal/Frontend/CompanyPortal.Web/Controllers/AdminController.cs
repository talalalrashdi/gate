using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

public sealed class AdminController : Controller
{
    // Public shell only. The browser calls the API with the visitor's Windows identity;
    // the API authorizes every read/write. Never use the MVC process identity here.
    [HttpGet("/admin/cards")]
    [HttpGet("/admin")]
    [HttpGet("/admin/images")]
    public IActionResult Cards()
    {
        ViewData["AdminSection"] = Request.Path.Value?.TrimEnd('/').EndsWith("/cards", StringComparison.OrdinalIgnoreCase) == true ? "cards" : "overview";
        if (Request.Path.Value?.TrimEnd('/').EndsWith("/images", StringComparison.OrdinalIgnoreCase) == true) ViewData["AdminSection"] = "images";
        return View();
    }
}
