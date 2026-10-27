using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using CompanyPortal.Api.Contracts;
namespace CompanyPortal.Api.Data;

public sealed class PortalMediaStore(IConfiguration configuration)
{
 public sealed record Group(int MediaGroupID,string GroupName,int? CoverMediaID,int DisplayOrder,DateTime LastChangeAt,bool Active);
 public sealed record Media(int MediaID,string MediaName,string MediaPath,string MediaType,int? MediaGroupID,int DisplayOrder,DateTime LastChangeAt,bool Active);
 public sealed record Catalog(IReadOnlyList<Group> Groups,IReadOnlyList<Media> Items);
 private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")??throw new InvalidOperationException("CompanyPortal connection string is missing."));
 private static CommandDefinition Command(string sp,object args,CancellationToken token)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
 public async Task<Catalog> GetAsync(bool includeHidden,CancellationToken token)
 {
  await using var c=Connection();using var r=await c.QueryMultipleAsync(Command("Portal.Media_GetAll",new{IncludeHidden=includeHidden},token));
  var groups=(await r.ReadAsync<Group>()).ToArray();var media=(await r.ReadAsync<Media>()).ToArray();
  if(groups.Select(g=>g.MediaGroupID).Distinct().Count()!=groups.Length||media.Select(m=>m.MediaID).Distinct().Count()!=media.Length
   ||groups.Any(g=>g.MediaGroupID<1)||media.Any(m=>m.MediaID<1||m.MediaType is not ("image" or "video")||(m.MediaType=="video"&&m.MediaGroupID is not null)))
   throw new InvalidOperationException("Invalid media source contract.");
  return includeHidden?new(groups,media):new(groups.Where(g=>g.Active).ToArray(),media.Where(m=>m.Active&&(m.MediaGroupID is null||groups.Any(g=>g.MediaGroupID==m.MediaGroupID&&g.Active))).ToArray());
 }
 public async Task<Media?> GetByIdAsync(int id,bool includeHidden,CancellationToken token)
 {await using var c=Connection();return await c.QuerySingleOrDefaultAsync<Media>(Command("Portal.Media_GetById",new{MediaID=id,IncludeHidden=includeHidden},token));}
 public async Task<int> SaveAsync(int? id,SaveMediaRequest r,string changedBy,CancellationToken token)
 {await using var c=Connection();return await c.QuerySingleAsync<int>(Command("Portal.Media_Save",new{MediaID=id,MediaName=r.MediaName.Trim(),MediaPath=r.MediaPath.Trim(),r.MediaType,MediaGroupID=r.MediaGroupId,r.DisplayOrder,r.Active,ChangedBy=changedBy},token));}
 public async Task<int> SaveGroupAsync(int? id,SaveMediaGroupRequest r,string changedBy,CancellationToken token)
 {await using var c=Connection();return await c.QuerySingleAsync<int>(Command("Portal.MediaGroups_Save",new{MediaGroupID=id,GroupName=r.GroupName.Trim(),CoverMediaID=r.CoverMediaId,r.DisplayOrder,r.Active,ChangedBy=changedBy},token));}
}
