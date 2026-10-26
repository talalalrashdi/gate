using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class ProfileSummaryStore(IConfiguration configuration)
{
    public sealed record Person(string? DisplayName,string? JobTitle,string? Department);
    public sealed record Attendance(string? DisplayName,string? JobTitle,string? Department,DateTime? AttendanceDate,DateTime? ArrivalAt,DateTime? ExpectedLeaveAt);
    public sealed record LeaveBalance(decimal? HolidayDays,decimal? DaysToBeDeleted,DateTime? AsOfDate,DateTime? DeletionDate);
    private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal") ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string sp,object args,CancellationToken token)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
    public async Task<int?> GetUserIdAsync(string name,CancellationToken token)
    {await using var c=Connection();return await c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=name},token));}
    public async Task<Person?> GetPersonAsync(int userId,CancellationToken token)
    {await using var c=Connection();return await c.QuerySingleOrDefaultAsync<Person>(Command("Portal.UserProfile_Get",new{UserId=userId},token));}
    public async Task<Attendance?> GetAttendanceAsync(int userId,CancellationToken token)
    {await using var c=Connection();return await c.QuerySingleOrDefaultAsync<Attendance>(Command("Portal.UserAttendance_Get",new{UserId=userId},token));}
    public async Task<LeaveBalance?> GetLeaveBalanceAsync(int userId,CancellationToken token)
    {
        await using var c=Connection();var row=await c.QuerySingleOrDefaultAsync<LeaveBalance>(Command("Portal.UserLeaveBalance_Get",new{UserId=userId},token));
        if(row?.HolidayDays<0 || row?.DaysToBeDeleted<0)throw new InvalidOperationException("Invalid leave balance source contract.");
        return row;
    }
}
