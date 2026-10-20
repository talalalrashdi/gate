using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/themes"),RequestSizeLimit(8192)]
public sealed class ThemeAdministrationController(ThemeAdministrationStore themes,AdministrationStore administration,IConfiguration configuration,ILogger<ThemeAdministrationController> logger):ControllerBase
{
    [HttpGet] public Task<IActionResult> Get(CancellationToken token)=>Execute(async()=>Ok(await themes.GetAsync(token)),false,token);
    [HttpGet("templates")] public Task<IActionResult> Templates(CancellationToken token)=>Execute(()=>Task.FromResult<IActionResult>(Ok(new ThemeTemplate[]{
        new("official","الرسمي","assets/hero-oman-fort.png","#0A2947","#8B5E3C","#F5F1EA",45,"light"),
        new("work","العملي","assets/hero-oman-mosque.png","#800000","#F28500","#F5F1EA",35,"light"),
        new("national-day","اليوم الوطني","assets/national-day-complete.jpg","#143F33","#A3333B","#F5F9F3",80,"dark")
    })),false,token);
    [HttpPost,Consumes("application/json")] public Task<IActionResult> Create(SaveAdminTheme request,CancellationToken token)=>Save(null,request,token);
    [HttpPut("{id:int:min(1)}"),Consumes("application/json")] public Task<IActionResult> Update(int id,SaveAdminTheme request,CancellationToken token)=>Save(id,request,token);
    [HttpDelete("{id:int:min(1)}")] public Task<IActionResult> Delete(int id,CancellationToken token)=>Execute(async()=>await themes.DeleteAsync(id,token)?NoContent():NotFound(),true,token);
    [HttpPost("{id:int:min(1)}/apply-to-all")] public Task<IActionResult> ApplyToAll(int id,CancellationToken token)=>Execute(async()=>{await themes.ApplyToAllAsync(id,token);return NoContent();},true,token);
    private Task<IActionResult> Save(int? id,SaveAdminTheme request,CancellationToken token)=>Execute(async()=>{
        if(string.IsNullOrWhiteSpace(request.ThemeName)||request.IsDefault==true&&request.Active!=true)return Problem(statusCode:400,title:"Check the theme name and active default.");
        if(request.PreviewRoles is null || request.PreviewRoles.Any(r=>string.IsNullOrWhiteSpace(r)||r.Trim().Length>200)
            || request.PreviewRoles.Select(r=>r.Trim()).Distinct(StringComparer.Ordinal).Count()!=request.PreviewRoles.Length
            || request.Visibility=="preview"&&request.PreviewRoles.Length==0
            || request.IsDefault==true&&request.Visibility is "preview" or "hidden") return Problem(statusCode:400,title:"Check preview roles and public default status.");
        return Ok(new{themeId=await themes.SaveAsync(id,request,token)});
    },true,token);
    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action,bool write,CancellationToken token)
    {
        Response.Headers.CacheControl="no-store";
        var account=User.Identity?.Name;
        if(string.IsNullOrWhiteSpace(account)||account.Length>512)return Unauthorized();
        try{
            if(!await administration.IsAdminAsync(account,token))return Forbid();
            if(write){
                if(Request.Headers["X-CompanyPortal-Request"]!="admin-themes")return Problem(statusCode:400,title:"Missing admin-themes request header.");
                var origin=Request.Headers.Origin.ToString();var allowed=configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()??[];
                if(origin.Length>0&&origin!=$"{Request.Scheme}://{Request.Host}"&&!allowed.Contains(origin,StringComparer.Ordinal))return Forbid();
            }
            return await action();
        }catch(SqlException exception)when(exception.Number==50008){return Problem(statusCode:400,title:"Check publication status, preview roles and the active image group. Choose another live default before hiding or deleting the current default.");}
        catch(Exception exception)when(exception is SqlException or InvalidOperationException){logger.LogError(exception,"Theme administration failed.");return Problem(statusCode:503,title:"Themes are temporarily unavailable.");}
    }
}
