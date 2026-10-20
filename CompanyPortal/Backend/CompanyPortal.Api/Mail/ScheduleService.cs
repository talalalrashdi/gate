using System.Runtime.CompilerServices;
using System.Xml;
using CompanyPortal.Api.Contracts;

namespace CompanyPortal.Api.Mail;

public sealed class ScheduleService(MailSessionFactory sessions,IConfiguration configuration)
{
    public MailOptions Options()=>configuration.GetSection("Exchange").Get<MailOptions>()??new();
    public async Task<ScheduleCatalog> CalendarsAsync(string account,string mailbox,CancellationToken token)
    {
        var options=Options();var result=new List<ScheduleCalendar>();_ = options.ScheduleZone();
        await using var employee=sessions.Create(mailbox);
        var candidates=new[]{new SharedCalendarOptions{Key="own",Name="تقويمي",Mailbox=mailbox,EnableNotifications=true}}.Concat(options.CalendarsFor(account));
        foreach(var calendar in candidates)
        {
            try{var rights=await employee.CalendarAccessAsync(calendar.Mailbox,token);if(rights.Read)result.Add(new(calendar.Key,calendar.Name,calendar.Key=="own",calendar.EnableNotifications,rights));}
            catch(EwsResponseException error)when(error.Code is "ErrorAccessDenied" or "ErrorFolderNotFound" or "ErrorItemNotFound"){} // A candidate is never a grant.
        }
        return new(options.ScheduleZoneId(),result);
    }
    public ScheduleSession Create(string account,string mailbox,string key,DateOnly from,DateOnly to)
    {
        var options=Options();
        var calendar=key=="own"?new SharedCalendarOptions{Key="own",Name="تقويمي",Mailbox=mailbox,EnableNotifications=true}
            :options.CalendarsFor(account).SingleOrDefault(c=>c.Key==key)??throw new EwsResponseException("ErrorAccessDenied");
        return new(sessions,mailbox,calendar,from,to,options.ScheduleZone());
    }
}

public sealed class ScheduleSession : IAsyncDisposable
{
    private readonly EwsMailSession employee;
    private readonly EwsMailSession? ownerNotifications;
    private readonly SharedCalendarOptions calendar;
    private readonly DateOnly from,to;
    private readonly TimeZoneInfo zone;
    private readonly bool own;
    private CalendarAccess? initialRights;
    public ScheduleSession(MailSessionFactory sessions,string mailbox,SharedCalendarOptions calendar,DateOnly from,DateOnly to,TimeZoneInfo zone)
        :this(sessions.Create(mailbox),calendar.Key!="own"&&calendar.EnableNotifications?sessions.Create(calendar.Mailbox):null,calendar,from,to,zone){}
    public ScheduleSession(EwsMailSession employee,EwsMailSession? ownerNotifications,SharedCalendarOptions calendar,DateOnly from,DateOnly to,TimeZoneInfo zone)
    {
        this.employee=employee;this.ownerNotifications=ownerNotifications;this.calendar=calendar;this.from=from;this.to=to;this.zone=zone;own=calendar.Key=="own";
    }
    public async Task AuthorizeAsync(CancellationToken token)
    {
        var rights=await employee.CalendarAccessAsync(calendar.Mailbox,token);
        if(!rights.Read)throw new EwsResponseException("ErrorAccessDenied");
        if(initialRights is not null&&initialRights!=rights)throw new EwsResponseException("ErrorAccessDenied");
        initialRights=rights;
    }
    public async Task<ScheduleSnapshot> SnapshotAsync(CancellationToken token)
    {
        await AuthorizeAsync(token);
        var appointments=await employee.CalendarAsync(calendar.Mailbox,from,to,zone,token);
        var tasks=await employee.TasksAsync(zone,token);
        return new(calendar.Key,calendar.Name,TimeZoneInfo.TryConvertWindowsIdToIanaId(zone.Id,out var iana)?iana:zone.Id,own||calendar.EnableNotifications,from,to,appointments,tasks,DateTimeOffset.UtcNow);
    }
    public async IAsyncEnumerable<ScheduleSnapshot> ObserveAsync([EnumeratorCancellation] CancellationToken token)
    {
        await AuthorizeAsync(token); // Never open an owner subscription before checking the employee's rights.
        using var lifetime=CancellationTokenSource.CreateLinkedTokenSource(token);
        var watchers=new List<IAsyncEnumerator<bool>>{employee.ObserveFoldersAsync(["calendar","tasks"],lifetime.Token).GetAsyncEnumerator(lifetime.Token)};
        if(ownerNotifications is not null)watchers.Add(ownerNotifications.ObserveFoldersAsync(["calendar"],lifetime.Token).GetAsyncEnumerator(lifetime.Token));
        var pending=new Task<bool>?[watchers.Count];
        try
        {
            foreach(var watcher in watchers)if(!await watcher.MoveNextAsync())yield break;
            yield return await SnapshotAsync(lifetime.Token);
            while(!lifetime.IsCancellationRequested)
            {
                for(var i=0;i<watchers.Count;i++)pending[i]??=watchers[i].MoveNextAsync().AsTask();
                var changed=await Task.WhenAny(pending.Select(p=>p!));
                if(!await changed)yield break;
                for(var i=0;i<pending.Length;i++)if(pending[i]==changed)pending[i]=null;
                // Owner events are only invalidations. Every snapshot is read as the employee.
                yield return await SnapshotAsync(lifetime.Token);
            }
        }
        finally
        {
            lifetime.Cancel();
            foreach(var task in pending.Where(p=>p is not null))try{await task!;}catch(Exception error)when(error is OperationCanceledException or HttpRequestException or IOException or InvalidOperationException or XmlException){}
            foreach(var watcher in watchers)await watcher.DisposeAsync();
        }
    }
    public async ValueTask DisposeAsync(){await employee.DisposeAsync();if(ownerNotifications is not null)await ownerNotifications.DisposeAsync();}
}
