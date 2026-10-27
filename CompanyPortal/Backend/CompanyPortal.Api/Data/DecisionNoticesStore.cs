using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class DecisionNoticesStore(IConfiguration configuration)
{
 public sealed record Setting(int ChannelID,int DurationDays,string DecisionTypes,DateTime LastChangeAt,bool Active);
 public sealed record Window(int ChannelID,long DecisionId,DateTime? FromAt,DateTime? ToAt,bool IsHidden);
 public sealed record Appearance(int ChannelId,DateTimeOffset FromAt,DateTimeOffset ToAt);
 public sealed record Catalog(Setting[] Settings,Window[] Windows)
 {
  public Appearance[] For(LegalDecisionsStore.Row decision)=>Settings.Where(s=>s.Active&&
   (JsonSerializer.Deserialize<string[]>(s.DecisionTypes)??[]).Contains(decision.DecisionType,StringComparer.Ordinal))
   .Select(s=>{var w=Windows.SingleOrDefault(w=>w.ChannelID==s.ChannelID&&w.DecisionId==decision.DecisionId);
    var start=w?.FromAt??decision.PublishedAt;var end=w?.ToAt??decision.PublishedAt.AddDays(s.DurationDays);
    return w?.IsHidden==true?null:new Appearance(s.ChannelID,Oman(start),Oman(end));})
   .OfType<Appearance>().ToArray();
 }
 // Existing publication dates and admin fields are Oman wall-clock values.
 public static DateTimeOffset Oman(DateTime value)=>new(DateTime.SpecifyKind(value,DateTimeKind.Unspecified),TimeSpan.FromHours(4));
 private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")??throw new InvalidOperationException("Missing database connection."));
 private static CommandDefinition Command(string sp,object? args,CancellationToken token)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
 public async Task<Catalog> GetAsync(CancellationToken token)
 {
  await using var c=Connection();using var sets=await c.QueryMultipleAsync(Command("Portal.DecisionNotices_Get",null,token));
  return new((await sets.ReadAsync<Setting>()).ToArray(),(await sets.ReadAsync<Window>()).ToArray());
 }
 public async Task SaveAsync(int channel,int days,string[] types,bool active,string changedBy,CancellationToken token)
 {await using var c=Connection();await c.ExecuteAsync(Command("Portal.DecisionNotices_Save",new{ChannelID=channel,DurationDays=days,DecisionTypes=JsonSerializer.Serialize(types),Active=active,ChangedBy=changedBy},token));}
 public async Task SaveWindowAsync(int channel,long id,DateTime? from,DateTime? to,bool hidden,string changedBy,CancellationToken token)
 {await using var c=Connection();await c.ExecuteAsync(Command("Portal.DecisionNoticeWindows_Save",new{ChannelID=channel,DecisionId=id,FromAt=from,ToAt=to,IsHidden=hidden,ChangedBy=changedBy},token));}
}
