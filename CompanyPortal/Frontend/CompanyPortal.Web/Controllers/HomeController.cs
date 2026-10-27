using Microsoft.AspNetCore.Mvc;
using CompanyPortal.Web.Models;
using Microsoft.AspNetCore.Diagnostics;

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
    [Route("/errors/{code:int}")]
    [ResponseCache(NoStore=true,Location=ResponseCacheLocation.None)]
    public IActionResult Error(int? code=null)
    {
        var exception=HttpContext.Features.Get<IExceptionHandlerPathFeature>();
        var model=PortalError.Create(exception is not null?500:code??500,System.Diagnostics.Activity.Current?.Id??HttpContext.TraceIdentifier);
        Response.StatusCode=model.StatusCode;
        Response.Headers.XContentTypeOptions="nosniff";
        return View(model);
    }
}
