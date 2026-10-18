using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

public class HomeController : Controller
{
    [HttpGet("/")]
    [HttpGet("/index.html")]
    public IActionResult Index() => View();

    // Retain old bookmarks while the portal's canonical address is the site root.
    [HttpGet("/design-b.html")]
    public IActionResult LegacyPortal() => LocalRedirect(Url.Content("~/") + Request.QueryString);

    [Route("/error")]
    public IActionResult Error()
    {
        Response.StatusCode = StatusCodes.Status500InternalServerError;
        return View();
    }
}
