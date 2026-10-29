using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;
public sealed class HeaderEventsStore(IConfiguration configuration)
{
 public sealed class Row
 {
  public int EventId {get;init;} public string Title {get;init;}=""; public string AppUrl {get;init;}="";
  public DateTime StartAt {get;init;} public DateTime EndAt {get;init;}
  public bool Active {get;init;} public DateTime LastChangeAt {get;init;}
 }
 private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal"));
 private static CommandDefinition Cmd(string name,object? args,CancellationToken token)=>new(name,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
 public async Task<Row[]?> Visible(string name,CancellationToken token)
 {
  await using var c=Connection();
  var user=await c.QuerySingleOrDefaultAsync<int?>(Cmd("Security.User_getByUsername",new{Username=name},token));
  return user is null?null:(await c.QueryAsync<Row>(Cmd("Mng.HeaderEvents_GetActive",null,token))).ToArray();
 }
 public async Task<Row[]> All(CancellationToken token){await using var c=Connection();return (await c.QueryAsync<Row>(Cmd("Mng.HeaderEvents_GetAll",null,token))).ToArray();}
 public async Task<int> Save(int? id,CompanyPortal.Api.Contracts.SaveHeaderEvent request,string account,CancellationToken token)
 {
  await using var c=Connection();return await c.QuerySingleAsync<int>(Cmd("Mng.HeaderEvents_Save",new{EventId=id,Title=request.Title.Trim(),AppUrl=request.AppUrl.Trim(),StartAt=request.StartAt!.Value.UtcDateTime,EndAt=request.EndAt!.Value.UtcDateTime,request.Active,ChangedBy=account},token));
 }
 public async Task Delete(int id,string account,CancellationToken token){await using var c=Connection();await c.ExecuteAsync(Cmd("Mng.HeaderEvents_Delete",new{EventId=id,ChangedBy=account},token));}
 public static bool SafeUrl(string url)=>Uri.TryCreate(url,UriKind.Absolute,out var uri)&&uri.Scheme is "http" or "https"&&uri.UserInfo.Length==0;
 public static object View(Row r)=>new{r.EventId,r.Title,r.AppUrl,StartAt=DateTime.SpecifyKind(r.StartAt,DateTimeKind.Utc),EndAt=DateTime.SpecifyKind(r.EndAt,DateTimeKind.Utc),r.Active,LastChangeAt=DecisionNoticesStore.Oman(r.LastChangeAt)};
}
