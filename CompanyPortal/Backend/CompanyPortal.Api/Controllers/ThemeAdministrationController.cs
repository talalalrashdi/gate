using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/themes"),RequestSizeLimit(32768),AdminSection("admin-themes","themes")]
public sealed class ThemeAdministrationController(ThemeAdministrationStore themes,ILogger<ThemeAdministrationController> logger):ControllerBase
{
    [HttpGet] public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await themes.GetAsync(token)));
    [HttpGet("templates")] public Task<IActionResult> Templates(CancellationToken token)=>Execute(()=>Task.FromResult<IActionResult>(Ok(new ThemeTemplate[]{
        new("official","الرسمي","assets/hero-oman-fort.png","#0A2947","#8B5E3C","#F5F1EA",45,"light"),
        new("work","العملي","assets/hero-oman-mosque.png","#800000","#F28500","#F5F1EA",35,"light"),
        new("national-day","اليوم الوطني","assets/national-day-complete.jpg","#143F33","#A3333B","#F5F9F3",80,"dark")
    })));
    // Role names the portal already knows, for suggestions only (there is no full role catalog).
    [HttpGet("roles")] public Task<IActionResult> Roles(CancellationToken token)=>Execute(async()=>Ok(await themes.GetKnownRolesAsync(User.Identity!.Name!,token)));
    [HttpPost,Consumes("application/json")] public Task<IActionResult> Create(SaveAdminTheme request,CancellationToken token)=>Save(null,request,token);
    [HttpPut("{id:int:min(1)}"),Consumes("application/json")] public Task<IActionResult> Update(int id,SaveAdminTheme request,CancellationToken token)=>Save(id,request,token);
    [HttpDelete("{id:int:min(1)}")] public Task<IActionResult> Delete(int id,CancellationToken token)=>Execute(async()=>await themes.DeleteAsync(id,User.Identity!.Name!,token)?NoContent():NotFound());
    [HttpPost("{id:int:min(1)}/apply-to-all")] public Task<IActionResult> ApplyToAll(int id,CancellationToken token)=>Execute(async()=>{await themes.ApplyToAllAsync(id,User.Identity!.Name!,token);return NoContent();});
    private Task<IActionResult> Save(int? id,SaveAdminTheme request,CancellationToken token)=>Execute(async()=>{
        if(string.IsNullOrWhiteSpace(request.ThemeName))return Coded(400,"details","Check the theme name.");
        if(request.IsDefault==true&&(request.Active!=true||request.Visibility is "preview" or "hidden"))return Coded(400,"default-not-public","The default theme must be live for everyone.");
        if(request.ImagePositions is not null && (request.ImagePositions.Any(p=>p is null)||request.ImagePositions.Select(p=>p.ImageId).Distinct().Count()!=request.ImagePositions.Length))
            return Coded(400,"positions","Use one focal position per image.");
        if(request.PreviewRoles is null || request.PreviewRoles.Any(r=>string.IsNullOrWhiteSpace(r)||r.Trim().Length>200)
            || request.PreviewRoles.Select(r=>r.Trim()).Distinct(StringComparer.Ordinal).Count()!=request.PreviewRoles.Length
            || request.Visibility=="preview"&&request.PreviewRoles.Length==0) return Coded(400,"roles","Check preview roles.");
        return Ok(new{themeId=await themes.SaveAsync(id,request,User.Identity!.Name!,token)});
    });
    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try{
            return await action();
        }catch(SqlException exception)when(exception.Number==50008){var (status,code)=Classify(exception.Message);return Coded(status,code,exception.Message);}
        catch(Exception exception)when(exception is SqlException or InvalidOperationException){logger.LogError(exception,"Theme administration failed.");return Problem(statusCode:503,title:"Themes are temporarily unavailable.");}
    }
    // Themes_save/_delete/_applyToAll raise 50008 with these fixed messages; the code lets the editor show a specific Arabic message.
    private static (int Status,string Code) Classify(string message)=>message switch{
        "Theme catalog is busy."=>(409,"busy"),
        "Theme not found."=>(404,"not-found"),
        "Default must be live for everyone." or "Only live public themes can be applied to everyone."=>(400,"default-not-public"),
        "Choose another default before disabling this default." or "Choose another default first." or "Exactly one active default is required."=>(400,"default-required"),
        "Invalid roles." or "Enter up to 50 role names." or "Choose preview roles."=>(400,"roles"),
        "Choose an active image group."=>(400,"inactive-group"),
        "Invalid image positions." or "Use up to 100 valid image positions." or "Duplicate image position." or "Positioned images must belong to the selected group."=>(400,"positions"),
        _=>(400,"details")};
    private ObjectResult Coded(int status,string code,string title)
    {
        var problem=ProblemDetailsFactory.CreateProblemDetails(HttpContext,status,title);problem.Extensions["code"]=code;
        return new ObjectResult(problem){StatusCode=status};
    }
}
