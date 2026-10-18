using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

public class ProfileController : Controller
{
    [HttpGet("/profile")]
    [HttpGet("/user-profile.html")]
    public IActionResult Index() => View();
}
