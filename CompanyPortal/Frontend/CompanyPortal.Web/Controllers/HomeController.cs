using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

public class HomeController : Controller
{
    [HttpGet("/")]
    [HttpGet("/index.html")]
    [HttpGet("/design-b.html")]
    public IActionResult Index() => View();

    [Route("/error")]
    public IActionResult Error()
    {
        Response.StatusCode = StatusCodes.Status500InternalServerError;
        return View();
    }
}
