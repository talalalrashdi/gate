using System.Security.Cryptography;
using System.Text.Json;
using CompanyPortal.Api.Contracts;
using Microsoft.AspNetCore.DataProtection;
namespace CompanyPortal.Api.Mail;

public sealed class ScheduleService(MailSessionFactory sessions,IConfiguration configuration,IDataProtectionProvider protection)
{
 private readonly ITimeLimitedDataProtector protector=protection.CreateProtector("CompanyPortal.EmployeeCalendar.v1").ToTimeLimitedDataProtector();
 private sealed record Ticket(string Account,string Mailbox,string Name,string? FolderId);
 public MailOptions Options()=>configuration.GetSection("Exchange").Get<MailOptions>()??new();
 private static string Reference(string owner,string? folder)=>Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(owner.ToUpperInvariant()+"|"+folder)));
 private string Key(string account,string owner,string name,string? folder)=>"shared_"+protector.Protect(JsonSerializer.Serialize(new Ticket(account,owner,name,folder)),TimeSpan.FromHours(12));
 public SharedCalendarOptions Resolve(string account,string mailbox,string key)
 {
  if(key=="own")return new(){Key="own",Name="تقويمي",Mailbox=mailbox,EnableNotifications=true};
  var configured=Options().CalendarsFor(account).SingleOrDefault(c=>c.Key==key);if(configured is not null)return configured;
  if(key.StartsWith("shared_",StringComparison.Ordinal)&&key.Length<=4096){try{var data=JsonSerializer.Deserialize<Ticket>(protector.Unprotect(key[7..]));if(data is not null&&string.Equals(data.Account,account,StringComparison.OrdinalIgnoreCase))return new(){Key=key,Name=data.Name,Mailbox=data.Mailbox,FolderId=data.FolderId,EnableNotifications=true};}catch(Exception e)when(e is CryptographicException or JsonException){}}
  throw new EwsResponseException("ErrorAccessDenied");
 }
 public async Task<ScheduleCatalog> CalendarsAsync(string account,string mailbox,CancellationToken token)
 {
  var options=Options();var result=new List<ScheduleCalendar>();_=options.ScheduleZone();await using var employee=sessions.Create(mailbox);
  var discovery=await employee.DiscoverCalendarsAsync(token);
  var candidates=new[]{new SharedCalendarOptions{Key="own",Name="تقويمي",Mailbox=mailbox,EnableNotifications=true}}.Concat(options.CalendarsFor(account)).Concat(discovery.Calendars.Select(c=>new SharedCalendarOptions{Key=Key(account,c.Mailbox,c.Name,c.FolderId),Name=c.Name,Mailbox=c.Mailbox,FolderId=c.FolderId,EnableNotifications=true}));
  var seen=new HashSet<string>(StringComparer.Ordinal);
  foreach(var calendar in candidates){try{var folder=await employee.CalendarFolderAsync(calendar.Mailbox,calendar.FolderId,token);var rights=folder.Rights;if(!seen.Add(calendar.Mailbox.ToUpperInvariant()+"|"+folder.Id))continue;if(rights.Read&&calendar.Key.Length<=4096)result.Add(new(calendar.Key,calendar.Name,calendar.Key=="own",calendar.EnableNotifications,rights){Reference=Reference(calendar.Mailbox,folder.Id)});}catch(EwsResponseException error)when(error.Code is "ErrorAccessDenied" or "ErrorFolderNotFound" or "ErrorItemNotFound"){}}
  return new(options.ScheduleZoneId(),result){DiscoveryWarning=discovery.Warning};
 }
 public async Task<ScheduleCalendar> OpenAsync(string account,string mailbox,string owner,CancellationToken token)
 {
  await using var employee=sessions.Create(mailbox);var folder=await employee.CalendarFolderAsync(owner,null,token);var rights=folder.Rights;if(!rights.Read)throw new EwsResponseException("ErrorAccessDenied");
  return string.Equals(owner,mailbox,StringComparison.OrdinalIgnoreCase)?new("own","تقويمي",true,true,rights){Reference=Reference(mailbox,folder.Id)}:new(Key(account,owner,owner,null),owner,false,true,rights){Reference=Reference(owner,folder.Id)};
 }
 public ScheduleSession Create(string account,string mailbox,string key,DateOnly from,DateOnly to)=>new(sessions,mailbox,Resolve(account,mailbox,key),from,to,Options().ScheduleZone());
}

public sealed class ScheduleSession:IAsyncDisposable
{
 private readonly EwsMailSession employee;
 private readonly EwsMailSession? sharedNotifications;
 private readonly SharedCalendarOptions calendar;
 private readonly DateOnly from,to;
 private readonly TimeZoneInfo zone;
 private readonly bool own;
 private bool sharedLive;
 private CalendarAccess? initialRights;
 public ScheduleSession(MailSessionFactory sessions,string mailbox,SharedCalendarOptions calendar,DateOnly from,DateOnly to,TimeZoneInfo zone)
  :this(sessions.Create(mailbox),calendar.Key!="own"&&calendar.EnableNotifications?sessions.Create(mailbox):null,calendar,from,to,zone){}
 public ScheduleSession(EwsMailSession employee,EwsMailSession? sharedNotifications,SharedCalendarOptions calendar,DateOnly from,DateOnly to,TimeZoneInfo zone)
 {this.employee=employee;this.sharedNotifications=sharedNotifications;this.calendar=calendar;this.from=from;this.to=to;this.zone=zone;own=calendar.Key=="own";}
 public async Task AuthorizeAsync(CancellationToken token){var rights=await employee.CalendarAccessAsync(calendar.Mailbox,token,calendar.FolderId);if(!rights.Read||initialRights is not null&&initialRights!=rights)throw new EwsResponseException("ErrorAccessDenied");initialRights=rights;}
 public async Task<ScheduleSnapshot> SnapshotAsync(CancellationToken token)
 {await AuthorizeAsync(token);var appointments=await employee.CalendarAsync(calendar.Mailbox,from,to,zone,token,calendar.FolderId);var tasks=await employee.TasksAsync(zone,token);return new(calendar.Key,calendar.Name,TimeZoneInfo.TryConvertWindowsIdToIanaId(zone.Id,out var iana)?iana:zone.Id,own||sharedLive,from,to,appointments,tasks,DateTimeOffset.UtcNow){Rights=initialRights};}
 public async IAsyncEnumerable<ScheduleSnapshot> ObserveAsync([System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken token)
 {
  await AuthorizeAsync(token);using var lifetime=CancellationTokenSource.CreateLinkedTokenSource(token);var watchers=new List<IAsyncEnumerator<bool>>();var pending=new List<Task<bool>?>();
  try{
   var ownWatcher=employee.ObserveFoldersAsync(own?["calendar","tasks"]:["tasks"],lifetime.Token).GetAsyncEnumerator(lifetime.Token);watchers.Add(ownWatcher);if(!await ownWatcher.MoveNextAsync())yield break;
   if(sharedNotifications is not null){var shared=sharedNotifications.ObserveFoldersAsync(["calendar"],lifetime.Token,calendar.Mailbox,calendar.FolderId).GetAsyncEnumerator(lifetime.Token);var added=false;try{added=await shared.MoveNextAsync();}catch(EwsResponseException e)when(e.Code is "ErrorAccessDenied" or "ErrorSubscriptionAccessDenied" or "ErrorSubscriptionDelegateAccessNotSupported" or "ErrorInvalidSubscriptionRequest" or "ErrorInvalidOperation"){}if(added){watchers.Add(shared);sharedLive=true;}else await shared.DisposeAsync();}
   pending.AddRange(watchers.Select(_=>(Task<bool>?)null));yield return await SnapshotAsync(lifetime.Token);
   while(!lifetime.IsCancellationRequested){for(var i=0;i<watchers.Count;i++)pending[i]??=watchers[i].MoveNextAsync().AsTask();var changed=await Task.WhenAny(pending.Select(p=>p!));if(!await changed)yield break;for(var i=0;i<pending.Count;i++)if(pending[i]==changed)pending[i]=null;yield return await SnapshotAsync(lifetime.Token);}
  }finally{lifetime.Cancel();foreach(var task in pending.Where(p=>p is not null))try{await task!;}catch(Exception e)when(e is OperationCanceledException or HttpRequestException or IOException or InvalidOperationException or System.Xml.XmlException){}foreach(var watcher in watchers)await watcher.DisposeAsync();}
 }
 public async ValueTask DisposeAsync(){await employee.DisposeAsync();if(sharedNotifications is not null)await sharedNotifications.DisposeAsync();}
}
