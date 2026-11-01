using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class LibraryReadsStore(IConfiguration configuration)
{
 public sealed record Entry(int ContentTypeID,string ContentId);
 private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")??throw new InvalidOperationException("CompanyPortal connection string is missing."));
 private static CommandDefinition Command(string sp,object args,CancellationToken token)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
 public async Task<Entry[]> GetAsync(string account,CancellationToken token)
 {
  await using var c=Connection();var user=await User(c,account,token);
  return (await c.QueryAsync<Entry>(Command("Portal.LibraryReads_Get",new{UserId=user},token))).ToArray();
 }
 public async Task MarkAsync(string account,string section,Guid[] ids,bool markRead,CancellationToken token)
 {
  await using var c=Connection();var user=await User(c,account,token);
  await c.ExecuteAsync(Command("Portal.LibraryReads_Mark",new{UserId=user,Section=section,DocumentIdsJson=JsonSerializer.Serialize(ids),MarkRead=markRead},token));
 }
 private static async Task<int> User(SqlConnection c,string account,CancellationToken token)=>await c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=account},token))??throw new InvalidOperationException("Portal user is unavailable.");
}
