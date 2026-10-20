using System.Globalization;
using System.Runtime.CompilerServices;
using System.Xml;
using System.Xml.Linq;
using CompanyPortal.Api.Contracts;

namespace CompanyPortal.Api.Mail;

public sealed partial class EwsMailSession
{
    private static bool Flag(XElement? node,string name)=>node?.Element(T+name)?.Value is "true" or "1";
    private static DateTimeOffset Instant(string value)=>DateTimeOffset.Parse(value,CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal);
    private static XElement Folder(string kind,string owner)=>new(T+"DistinguishedFolderId",new XAttribute("Id",kind),new XElement(T+"Mailbox",new XElement(T+"EmailAddress",owner)));
    public async Task<CalendarAccess> CalendarAccessAsync(string owner,CancellationToken token)
    {
        // The SOAP impersonation header remains the viewing employee, even when owner is a manager.
        var doc=await CallAsync(new XElement(M+"GetFolder",new XElement(M+"FolderShape",new XElement(T+"BaseShape","IdOnly"),
            new XElement(T+"AdditionalProperties",Field("folder:EffectiveRights"))),new XElement(M+"FolderIds",Folder("calendar",owner))),token);
        var rights=doc.Descendants(T+"CalendarFolder").SingleOrDefault()?.Element(T+"EffectiveRights");
        return new(Flag(rights,"Read"),Flag(rights,"CreateContents"),Flag(rights,"Modify"),Flag(rights,"Delete"),Flag(rights,"ViewPrivateItems"));
    }
    public async Task<CalendarResult> CalendarAsync(string owner,DateOnly from,DateOnly to,TimeZoneInfo zone,CancellationToken token)
    {
        var access=await CalendarAccessAsync(owner,token);
        if(!access.Read)throw new EwsResponseException("ErrorAccessDenied");
        var start=TimeZoneInfo.ConvertTimeToUtc(from.ToDateTime(TimeOnly.MinValue),zone);
        var end=TimeZoneInfo.ConvertTimeToUtc(to.ToDateTime(TimeOnly.MinValue),zone);
        var doc=await CallAsync(new XElement(M+"FindItem",new XAttribute("Traversal","Shallow"),
            new XElement(M+"ItemShape",new XElement(T+"BaseShape","IdOnly"),new XElement(T+"AdditionalProperties",
                new[]{"item:Subject","item:Sensitivity","item:EffectiveRights","calendar:Start","calendar:End","calendar:IsAllDayEvent","calendar:Location","calendar:Organizer","calendar:IsCancelled","calendar:MyResponseType"}.Select(Field))),
            new XElement(M+"CalendarView",new XAttribute("StartDate",XmlConvert.ToString(start,XmlDateTimeSerializationMode.Utc)),new XAttribute("EndDate",XmlConvert.ToString(end,XmlDateTimeSerializationMode.Utc)),new XAttribute("MaxEntriesReturned",1000)),
            new XElement(M+"ParentFolderIds",Folder("calendar",owner))),token);
        var own=string.Equals(owner,mailbox,StringComparison.OrdinalIgnoreCase);
        var items=doc.Descendants(T+"CalendarItem").Select(item=>{
            var sensitivity=item.Element(T+"Sensitivity")?.Value;
            var privateItem=sensitivity=="Private" || (!own&&sensitivity is null);
            var itemPrivate=item.Element(T+"EffectiveRights")?.Element(T+"ViewPrivateItems");
            var permitted=own || (itemPrivate is null?access.ViewPrivateItems:Flag(item.Element(T+"EffectiveRights"),"ViewPrivateItems"));
            var itemRead=item.Element(T+"EffectiveRights")?.Element(T+"Read");
            var mask=privateItem&&!permitted || !own&&itemRead is not null&&!Flag(item.Element(T+"EffectiveRights"),"Read");
            return new CalendarAppointment(item.Element(T+"ItemId")?.Attribute("Id")?.Value??throw new XmlException("Missing appointment ID."),
                mask?(privateItem?"موعد خاص":"وقت مشغول"):item.Element(T+"Subject")?.Value??"",Instant(item.Element(T+"Start")?.Value??throw new XmlException("Missing appointment start.")),
                Instant(item.Element(T+"End")?.Value??throw new XmlException("Missing appointment end.")),Flag(item,"IsAllDayEvent"),
                mask?"":item.Element(T+"Location")?.Value??"",mask?"":item.Element(T+"Organizer")?.Descendants(T+"Name").FirstOrDefault()?.Value??"",
                Flag(item,"IsCancelled"),privateItem,mask?"":item.Element(T+"MyResponseType")?.Value??"");
        }).OrderBy(i=>i.Start).ToArray();
        if(items.Length>1000 || items.Any(i=>i.End<i.Start))throw new XmlException("Invalid calendar results.");
        return new(items,doc.Descendants(M+"RootFolder").Any(f=>f.Attribute("IncludesLastItemInRange")?.Value is "false" or "0"));
    }
    public async Task<TaskResult> TasksAsync(TimeZoneInfo zone,CancellationToken token)
    {
        var items=new List<ExchangeTask>();var offset=0;var complete=false;
        while(items.Count<500&&!complete)
        {
            var doc=await CallAsync(new XElement(M+"FindItem",new XAttribute("Traversal","Shallow"),new XElement(M+"ItemShape",new XElement(T+"BaseShape","IdOnly"),
                new XElement(T+"AdditionalProperties",new[]{"item:Subject","item:Importance","task:DueDate","task:StartDate","task:Status","task:PercentComplete"}.Select(Field))),
                new XElement(M+"IndexedPageItemView",new XAttribute("MaxEntriesReturned",100),new XAttribute("Offset",offset),new XAttribute("BasePoint","Beginning")),
                new XElement(M+"Restriction",new XElement(T+"IsEqualTo",Field("task:IsComplete"),new XElement(T+"FieldURIOrConstant",new XElement(T+"Constant",new XAttribute("Value","false"))))),
                new XElement(M+"SortOrder",new XElement(T+"FieldOrder",new XAttribute("Order","Ascending"),Field("task:DueDate"))),new XElement(M+"ParentFolderIds",Folder("tasks",mailbox))),token);
            string? Day(XElement item,string field)=>item.Element(T+field) is {} date?DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(Instant(date.Value),zone).DateTime).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture):null;
            var page=doc.Descendants(T+"Task").Select(item=>new ExchangeTask(item.Element(T+"ItemId")?.Attribute("Id")?.Value??throw new XmlException("Missing task ID."),
                item.Element(T+"Subject")?.Value??"",Day(item,"DueDate"),Day(item,"StartDate"),item.Element(T+"Status")?.Value??"NotStarted",item.Element(T+"Importance")?.Value??"Normal",
                double.TryParse(item.Element(T+"PercentComplete")?.Value,NumberStyles.Float,CultureInfo.InvariantCulture,out var percent)&&double.IsFinite(percent)?Math.Clamp(percent,0,100):0)).ToArray();
            if(page.Length>100)throw new XmlException("Oversized tasks page.");
            items.AddRange(page);var root=doc.Descendants(M+"RootFolder").Single();
            complete=root.Attribute("IncludesLastItemInRange")?.Value is "true" or "1";
            if(!complete){var next=int.Parse(root.Attribute("IndexedPagingOffset")?.Value??throw new XmlException("Missing task page offset."),CultureInfo.InvariantCulture);if(next<=offset||page.Length==0)throw new XmlException("Invalid task paging.");offset=next;}
        }
        return new(items,!complete);
    }
    // Only invalidation signals leave this method: owner item IDs/details never reach a delegate.
    public async IAsyncEnumerable<bool> ObserveFoldersAsync(string[] folders,[EnumeratorCancellation] CancellationToken token)
    {
        var doc=await CallAsync(new XElement(M+"Subscribe",new XElement(M+"StreamingSubscriptionRequest",new XAttribute("SubscribeToAllFolders","false"),
            new XElement(T+"FolderIds",folders.Select(kind=>Folder(kind,mailbox))),new XElement(T+"EventTypes",new[]{"CreatedEvent","ModifiedEvent","DeletedEvent","MovedEvent","CopiedEvent","FreeBusyChangedEvent"}.Select(name=>new XElement(T+"EventType",name))))),token);
        var id=doc.Descendants(M+"SubscriptionId").Single().Value;
        try
        {
            yield return false; // Subscription is ready before the caller reads its initial snapshot.
            while(!token.IsCancellationRequested)
            {
                using var timeout=CancellationTokenSource.CreateLinkedTokenSource(token);timeout.CancelAfter(TimeSpan.FromSeconds(90));
                using var request=Request(new XElement(M+"GetStreamingEvents",new XElement(M+"SubscriptionIds",new XElement(T+"SubscriptionId",id)),new XElement(M+"ConnectionTimeout",1)));
                using var response=await client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,timeout.Token);response.EnsureSuccessStatusCode();
                await using var stream=await response.Content.ReadAsStreamAsync(timeout.Token);var started=DateTime.UtcNow;
                await foreach(var envelope in ReadEnvelopesAsync(stream,timeout.Token))
                    if(envelope.Descendants().Any(n=>n.Name.Namespace==T&&n.Name.LocalName is "CreatedEvent" or "ModifiedEvent" or "DeletedEvent" or "MovedEvent" or "CopiedEvent" or "FreeBusyChangedEvent"))yield return true;
                if(DateTime.UtcNow-started<TimeSpan.FromSeconds(1))throw new InvalidOperationException("Exchange ended the subscription prematurely.");
            }
        }
        finally
        {
            using var cleanup=new CancellationTokenSource(TimeSpan.FromSeconds(2));
            try{await CallAsync(new XElement(M+"Unsubscribe",new XElement(M+"SubscriptionId",id)),cleanup.Token);}catch(Exception error)when(error is HttpRequestException or OperationCanceledException or InvalidOperationException or XmlException){}
        }
    }
}
