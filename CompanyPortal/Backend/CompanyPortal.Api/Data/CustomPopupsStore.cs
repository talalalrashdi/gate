using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;
public sealed class CustomPopupsStore(IConfiguration config)
{
 public sealed class Row
 {
  public int PopupId {get;init;} public string PopupType {get;init;}="";public string Details {get;init;}="";
  public DateTime StartAt {get;init;} public DateTime EndAt {get;init;} public bool IsDisplayed {get;init;}
 }
 private SqlConnection Connection()=>new(config.GetConnectionString("CompanyPortal"));
 private static CommandDefinition Cmd(string sp,object? args,CancellationToken t)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:t);
 public async Task<int?> User(string name,CancellationToken t){await using var c=Connection();return await c.QuerySingleOrDefaultAsync<int?>(Cmd("Security.User_getByUsername",new{Username=name},t));}
 public async Task<Row[]> Get(int? user,CancellationToken t){await using var c=Connection();return (await c.QueryAsync<Row>(Cmd(user is null?"Mng.CustomPopups_GetAll":"Mng.CustomPopups_GetVisible",user is null?null:new{UserId=user.Value},t))).ToArray();}
 public async Task Save(int? id,SaveCustomPopup r,string name,CancellationToken t){await using var c=Connection();await c.ExecuteAsync(Cmd("Mng.CustomPopups_Save",new{PopupId=id,PopupType=r.PopupType.Trim(),Details=r.Details.Trim(),StartAt=r.StartAt!.Value.UtcDateTime,EndAt=r.EndAt!.Value.UtcDateTime,r.IsDisplayed,ChangedBy=name},t));}
 public async Task Delete(int id,string name,CancellationToken t){await using var c=Connection();await c.ExecuteAsync(Cmd("Mng.CustomPopups_Delete",new{PopupId=id,ChangedBy=name},t));}
 public async Task Dismiss(int id,int user,CancellationToken t){await using var c=Connection();await c.ExecuteAsync(Cmd("Portal.UserPopupDismissals_Save",new{PopupId=id,UserId=user},t));}
 public static object View(Row r)=>new{r.PopupId,r.PopupType,r.Details,StartAt=DateTime.SpecifyKind(r.StartAt,DateTimeKind.Utc),EndAt=DateTime.SpecifyKind(r.EndAt,DateTimeKind.Utc),r.IsDisplayed};
}
