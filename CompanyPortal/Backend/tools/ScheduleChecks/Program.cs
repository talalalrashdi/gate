using System.Net;
using System.Text;
using System.Xml.Linq;
using CompanyPortal.Api.Mail;
using CompanyPortal.Api.Contracts;
using Microsoft.Extensions.Configuration;

static void Check(bool condition,string message){if(!condition)throw new Exception(message);}
var options=new MailOptions{Enabled=true,AccessMode="ScopedServiceAccountImpersonation",EwsUrl="https://exchange.test/EWS/Exchange.asmx",OutlookWebUrl="https://exchange.test/owa/",ScheduleEnabled=true};
var zone=options.ScheduleZone();
var assistantHandler=new FakeExchange("assistant@test.example");
await using(var employee=new EwsMailSession(new HttpClient(assistantHandler),options,"assistant@test.example"))
{
 var access=await employee.CalendarAccessAsync("boss@test.example",default);Check(access.Read&&!access.Modify&&!access.ViewPrivateItems,"Effective read-only rights incorrect.");
 var calendar=await employee.CalendarAsync("boss@test.example",new(2026,10,1),new(2026,11,1),zone,default);
 Check(calendar.Items.Count==5,"Calendar occurrences missing.");
 var hidden=calendar.Items.Single(i=>i.ItemId=="private");Check(hidden.IsPrivate&&hidden.Subject=="موعد خاص"&&hidden.Location==""&&hidden.Organizer==""&&hidden.ResponseStatus=="","Private delegate details leaked.");
 Check(calendar.Items.Single(i=>i.ItemId=="visible-private").Subject=="Permitted private","Explicit private-item rights ignored.");
 Check(calendar.Items.Single(i=>i.ItemId=="no-read").Subject=="وقت مشغول"&&calendar.Items.Single(i=>i.ItemId=="no-read").Location=="","Explicit item read denial leaked details.");
 Check(calendar.Items.Single(i=>i.ItemId=="cancelled").IsCancelled,"Cancellation omitted.");
 Check(calendar.Items.Any(i=>i.IsAllDay&&i.Start.ToOffset(TimeSpan.FromHours(4)).Day==20),"All-day local date incorrect.");
 Check(assistantHandler.CalendarViews==1&&assistantHandler.LastRangeStart=="2026-09-30T20:00:00Z","CalendarView timezone range/recurrence expansion missing.");
 var tasks=await employee.TasksAsync(zone,default);Check(tasks.Items.Count==2&&!tasks.Truncated&&assistantHandler.TaskPages==2,"Task pagination failed.");
 Check(tasks.Items[0].DueDate=="2026-10-20"&&tasks.Items[1].DueDate is null,"Task due date/timezone/missing date incorrect.");
 assistantHandler.ReadAllowed=false;
 try{await employee.CalendarAsync("boss@test.example",new(2026,10,1),new(2026,11,1),zone,default);throw new Exception("Denied delegate was accepted.");}catch(EwsResponseException error){Check(error.Code=="ErrorAccessDenied","Incorrect denied response.");}
 assistantHandler.ReadAllowed=true;
 using var cancel=new CancellationTokenSource();await using var watcher=employee.ObserveFoldersAsync(["calendar","tasks"],cancel.Token).GetAsyncEnumerator();
 Check(await watcher.MoveNextAsync()&&!watcher.Current,"Subscribe-before-read marker missing.");var reads=assistantHandler.CalendarViews;
 Check(await watcher.MoveNextAsync()&&watcher.Current,"Created event missing.");Check(assistantHandler.CalendarViews==reads,"Status/change observation polled calendar items.");cancel.Cancel();
}
Check(assistantHandler.Unsubscribed==1,"Subscription was not released.");
var ownHandler=new FakeExchange("boss@test.example");
await using(var own=new EwsMailSession(new HttpClient(ownHandler),options,"boss@test.example"))
{
 var result=await own.CalendarAsync("boss@test.example",new(2026,10,1),new(2026,11,1),zone,default);Check(result.Items.Single(i=>i.ItemId=="private").Subject=="Secret appointment","Mailbox owner's private item was masked.");
 ownHandler.Truncate=true;Check((await own.CalendarAsync("boss@test.example",new(2026,10,1),new(2026,11,1),zone,default)).Truncated,"Calendar truncation was hidden.");
}
var readerHandler=new FakeExchange("assistant@test.example");var ownerHandler=new FakeExchange("boss@test.example"){NotificationsOnly=true};
await using(var shared=new ScheduleSession(new EwsMailSession(new HttpClient(readerHandler),options,"assistant@test.example"),new EwsMailSession(new HttpClient(ownerHandler),options,"boss@test.example"),
 new(){Key="boss",Name="Shared manager",Mailbox="boss@test.example",EnableNotifications=true},new(2026,10,1),new(2026,11,1),zone))
{
 using var cancel=new CancellationTokenSource();await using var stream=shared.ObserveAsync(cancel.Token).GetAsyncEnumerator();
 Check(await stream.MoveNextAsync(),"Initial shared snapshot missing.");Check(stream.Current.CalendarLive&&readerHandler.CalendarViews>0&&ownerHandler.CalendarViews==0,"Owner notification scope read private data.");
 Check(stream.Current.Calendar.Items.Single(i=>i.ItemId=="private").Subject=="موعد خاص","Shared stream leaked owner details.");
 Check(readerHandler.SubscribedFolders.SequenceEqual(["calendar","tasks"])&&ownerHandler.SubscribedFolders.SequenceEqual(["calendar"]),"Wrong mailbox subscription folders.");
 Check(await stream.MoveNextAsync(),"Shared live invalidation failed.");readerHandler.ReadAllowed=false;
 try{await shared.AuthorizeAsync(default);throw new Exception("Revoked shared permission remained accepted.");}catch(EwsResponseException){}
 cancel.Cancel();
}
Check(ownerHandler.Unsubscribed==1&&readerHandler.Unsubscribed==1,"Shared stream failed to unsubscribe.");
var manualHandler=new FakeExchange("assistant@test.example");
await using(var manual=new ScheduleSession(new EwsMailSession(new HttpClient(manualHandler),options,"assistant@test.example"),null,new(){Key="boss",Name="Manager",Mailbox="boss@test.example"},new(2026,10,1),new(2026,11,1),zone))
 Check(!(await manual.SnapshotAsync(default)).CalendarLive,"Unapproved shared live subscription was advertised.");
var limitConfig=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{{"Exchange:MaximumStreamsPerAccount","4"},{"Exchange:MaximumStreams","5"}}).Build();
var limits=new MailStreamLimits(limitConfig);var leases=Enumerable.Range(0,4).Select(_=>limits.TryEnter("account1")).ToArray();
Check(leases.All(l=>l is not null)&&limits.TryEnter("account1") is null,"Combined mail/schedule account budget incorrect.");
using(var other=limits.TryEnter("account2")){Check(other is not null&&limits.TryEnter("account3") is null,"Global stream budget incorrect.");}
foreach(var lease in leases)lease!.Dispose();using(var released=limits.TryEnter("account1"))Check(released is not null,"Stream budget was not released.");
Console.WriteLine("PASS: employee-context shared reads, effective/private rights, CalendarView/timezone/all-day/cancellation, task paging, denied/revoked access, owner-only invalidations, event-driven snapshots and cancellation/unsubscribe.");

sealed class FakeExchange(string actor):HttpMessageHandler
{
 static readonly XNamespace T="http://schemas.microsoft.com/exchange/services/2006/types",M="http://schemas.microsoft.com/exchange/services/2006/messages",S="http://schemas.xmlsoap.org/soap/envelope/";
 public bool ReadAllowed=true,Truncate,NotificationsOnly;
 public int CalendarViews,TaskPages,Unsubscribed;
 public string LastRangeStart="";
 public string[] SubscribedFolders=[];
 protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token)
 {
  var xml=XElement.Parse(await request.Content!.ReadAsStringAsync(token));
  if(xml.Descendants(T+"ConnectingSID").Single().Element(T+"SmtpAddress")?.Value!=actor)throw new Exception("Wrong impersonation identity.");
  var operation=xml.Element(S+"Body")!.Elements().Single();var kind=operation.Name.LocalName;
  if(NotificationsOnly&&kind is not ("Subscribe" or "GetStreamingEvents" or "Unsubscribe"))throw new Exception("Owner session attempted a read.");
  XElement payload;
  if(kind=="GetFolder")payload=new XElement(M+"Folders",new XElement(T+"CalendarFolder",new XElement(T+"EffectiveRights",new XElement(T+"Read",ReadAllowed),new XElement(T+"Modify",false),new XElement(T+"ViewPrivateItems",false))));
  else if(kind=="FindItem"&&operation.Element(M+"CalendarView") is {} view)
  {
   CalendarViews++;LastRangeStart=view.Attribute("StartDate")!.Value;
   if(operation.Descendants(T+"DistinguishedFolderId").Single().Element(T+"Mailbox")?.Element(T+"EmailAddress")?.Value!="boss@test.example")throw new Exception("Shared folder owner missing.");
   XElement Item(string id,string subject,string sensitivity,bool privateRights=false)=>new(T+"CalendarItem",new XElement(T+"ItemId",new XAttribute("Id",id)),new XElement(T+"Subject",subject),new XElement(T+"Sensitivity",sensitivity),
     new XElement(T+"Start","2026-10-19T20:00:00Z"),new XElement(T+"End","2026-10-20T20:00:00Z"),new XElement(T+"IsAllDayEvent",true),new XElement(T+"IsCancelled",id=="cancelled"),new XElement(T+"Location","Private room"),new XElement(T+"Organizer",new XElement(T+"Mailbox",new XElement(T+"Name","Organizer"))),new XElement(T+"MyResponseType","Accept"),new XElement(T+"EffectiveRights",new XElement(T+"Read",id!="no-read"),new XElement(T+"ViewPrivateItems",privateRights)));
   payload=new XElement(M+"RootFolder",new XAttribute("IncludesLastItemInRange",!Truncate),new XElement(T+"Items",Item("occurrence","Occurrence","Normal"),Item("private","Secret appointment","Private"),Item("visible-private","Permitted private","Private",true),Item("cancelled","Cancelled","Normal"),Item("no-read","Restricted details","Normal")));
  }
  else if(kind=="FindItem")
  {
   TaskPages++;if(!operation.Descendants(T+"FieldURI").Any(n=>n.Attribute("FieldURI")?.Value=="task:IsComplete"))throw new Exception("Outstanding-task restriction missing.");
   var first=operation.Element(M+"IndexedPageItemView")!.Attribute("Offset")!.Value=="0";
   payload=new XElement(M+"RootFolder",new XAttribute("IncludesLastItemInRange",!first),new XAttribute("IndexedPagingOffset",first?1:2),new XElement(T+"Items",new XElement(T+"Task",new XElement(T+"ItemId",new XAttribute("Id",first?"task1":"task2")),new XElement(T+"Subject","Task <script>literal</script>"),first?new XElement(T+"DueDate","2026-10-19T20:00:00Z"):null,new XElement(T+"Status","InProgress"),new XElement(T+"Importance","High"),new XElement(T+"PercentComplete",50))));
  }
  else if(kind=="Subscribe"){SubscribedFolders=operation.Descendants(T+"DistinguishedFolderId").Select(n=>n.Attribute("Id")!.Value).ToArray();payload=new XElement(M+"SubscriptionId","subscription");}
  else if(kind=="Unsubscribe"){Unsubscribed++;payload=new XElement(M+"Done");}
  else if(kind=="GetStreamingEvents")
  {
   var status=Envelope(new XElement(T+"Notification",new XElement(T+"StatusEvent")));var change=Envelope(new XElement(T+"Notification",new XElement(T+"CreatedEvent",new XElement(T+"ItemId",new XAttribute("Id","owner-secret-id")))));
   return new(HttpStatusCode.OK){Content=new StreamContent(new FragmentedStream(Encoding.UTF8.GetBytes(status+change)))};
  }
  else throw new Exception("Unexpected operation: "+kind);
  return new(HttpStatusCode.OK){Content=new StringContent(Envelope(payload),Encoding.UTF8,"text/xml")};
 }
 static string Envelope(XElement payload)=>new XElement(S+"Envelope",new XElement(S+"Body",new XElement(M+"Response",new XElement(M+"ResponseCode","NoError"),payload))).ToString(SaveOptions.DisableFormatting);
}
sealed class FragmentedStream(byte[] bytes):MemoryStream(bytes)
{
 public override ValueTask<int> ReadAsync(Memory<byte> buffer,CancellationToken token=default)=>base.ReadAsync(buffer[..Math.Min(buffer.Length,19)],token);
}
