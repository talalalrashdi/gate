using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;
public sealed class MagazinesStore(IConfiguration configuration)
{
 public sealed record Row(int MagazineID,string MagazineName,string IssueNumber,DateTime IssueDate,string FileName,int DisplayOrder,DateTime LastChangeAt,bool Active);
 private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")??throw new InvalidOperationException("CompanyPortal connection string is missing."));
 private static CommandDefinition Command(string name,object args,CancellationToken token)=>new(name,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
 private static Task<int?> UserId(SqlConnection c,string name,CancellationToken token)=>c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=name},token));
 public sealed record CatalogRow(Row Magazine,bool HasRead);
 public async Task<IReadOnlyList<CatalogRow>?> GetCatalogAsync(string name,CancellationToken token)
 {
  await using var c=Connection();var user=await UserId(c,name,token);if(user is null)return null;
  var rows=await Rows(c,null,token);var read=(await c.QueryAsync<int>(Command("Portal.UserMagazineReads_Get",new{UserId=user.Value},token))).ToHashSet();
  return rows.Select(row=>new CatalogRow(row,read.Contains(row.MagazineID))).ToArray();
 }
 public async Task<bool> MarkReadAsync(string name,int id,CancellationToken token)
 {
  await using var c=Connection();var user=await UserId(c,name,token);if(user is null)return false;
  await c.ExecuteAsync(Command("Portal.UserMagazineReads_MarkRead",new{UserId=user.Value,MagazineID=id},token));return true;
 }
 public async Task<IReadOnlyList<Row>?> GetAsync(string name,int? id,CancellationToken token)
 {
  await using var c=Connection();if(await UserId(c,name,token) is null)return null;return await Rows(c,id,token);
 }
 private static async Task<IReadOnlyList<Row>> Rows(SqlConnection c,int? id,CancellationToken token)
 {
  var rows=(await c.QueryAsync<Row>(new CommandDefinition("Portal.Magazines_GetAll",new{MagazineID=id},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).ToArray();
  if(rows.Any(r=>r.MagazineID<1||string.IsNullOrWhiteSpace(r.MagazineName)||string.IsNullOrWhiteSpace(r.FileName))||rows.Select(r=>r.MagazineID).Distinct().Count()!=rows.Length)throw new InvalidOperationException("Invalid magazine source contract.");
  return rows.Where(r=>r.Active&&(id is null||r.MagazineID==id)).OrderByDescending(r=>r.IssueDate).ThenBy(r=>r.DisplayOrder).ThenByDescending(r=>r.MagazineID).ToArray();
 }
}
