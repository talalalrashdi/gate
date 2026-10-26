using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/profile")]
public sealed class ProfileSummaryController(ProfileSummaryStore store,ILogger<ProfileSummaryController> logger):ControllerBase
{
    public sealed record DataResponse<T>(T? Data);
    [HttpGet("person"),ProducesResponseType<DataResponse<ProfileSummaryStore.Person>>(200)]
    public Task<IActionResult> Person(CancellationToken token)=>Read(id=>store.GetPersonAsync(id,token),"person",token);
    [HttpGet("attendance"),ProducesResponseType<DataResponse<ProfileSummaryStore.Attendance>>(200)]
    public Task<IActionResult> Attendance(CancellationToken token)=>Read(id=>store.GetAttendanceAsync(id,token),"attendance",token);
    [HttpGet("leave-balance"),ProducesResponseType<DataResponse<ProfileSummaryStore.LeaveBalance>>(200)]
    public Task<IActionResult> LeaveBalance(CancellationToken token)=>Read(id=>store.GetLeaveBalanceAsync(id,token),"leave-balance",token);
    private async Task<IActionResult> Read<T>(Func<int,Task<T?>> read,string source,CancellationToken token) where T:class
    {
        Response.Headers.CacheControl="no-store";
        var name=User.Identity?.Name;
        if(string.IsNullOrWhiteSpace(name)||name.Length>512)return Unauthorized();
        try
        {
            var userId=await store.GetUserIdAsync(name,token);
            if(userId is null)return Problem(statusCode:403,title:"User is not registered or is inactive.");
            return Ok(new DataResponse<T>(await read(userId.Value)));
        }
        catch(Exception e) when(e is SqlException or InvalidOperationException or System.Data.DataException)
        {
            logger.LogError(e,"Profile summary source {Source} failed; trace {TraceId}.",source,HttpContext.TraceIdentifier);
            return Problem(statusCode:503,title:"Profile information is temporarily unavailable.");
        }
    }
}
