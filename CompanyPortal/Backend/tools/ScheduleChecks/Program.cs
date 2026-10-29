using System.Net;
using System.Text;
using System.Xml.Linq;
using CompanyPortal.Api.Mail;
using CompanyPortal.Api.Contracts;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.DataProtection;

static void Check(bool condition,string message){if(!condition)throw new Exception(message);}
var options=new MailOptions{Enabled=true,AccessMode="WindowsDelegation",EwsUrl="https://exchange.test/EWS/Exchange.asmx",OutlookWebUrl="https://exchange.test/owa/",ScheduleEnabled=true};
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
var readerHandler=new FakeExchange("assistant@test.example");var ownerHandler=new FakeExchange("assistant@test.example"){NotificationsOnly=true};
await using(var shared=new ScheduleSession(new EwsMailSession(new HttpClient(readerHandler),options,"assistant@test.example"),new EwsMailSession(new HttpClient(ownerHandler),options,"assistant@test.example"),
 new(){Key="boss",Name="Shared manager",Mailbox="boss@test.example",EnableNotifications=true},new(2026,10,1),new(2026,11,1),zone))
{
 using var cancel=new CancellationTokenSource();await using var stream=shared.ObserveAsync(cancel.Token).GetAsyncEnumerator();
 Check(await stream.MoveNextAsync(),"Initial shared snapshot missing.");Check(stream.Current.CalendarLive&&readerHandler.CalendarViews>0&&ownerHandler.CalendarViews==0,"Owner notification scope read private data.");
 Check(stream.Current.Calendar.Items.Single(i=>i.ItemId=="private").Subject=="موعد خاص","Shared stream leaked owner details.");
 Check(readerHandler.SubscribedFolders.SequenceEqual(["tasks"])&&ownerHandler.SubscribedFolders.SequenceEqual(["calendar"]),"Wrong mailbox subscription folders.");
 Check(await stream.MoveNextAsync(),"Shared live invalidation failed.");readerHandler.ReadAllowed=false;
 try{await shared.AuthorizeAsync(default);throw new Exception("Revoked shared permission remained accepted.");}catch(EwsResponseException){}
 cancel.Cancel();
}
Check(ownerHandler.Unsubscribed==1&&readerHandler.Unsubscribed==1,"Shared stream failed to unsubscribe.");
var manualHandler=new FakeExchange("assistant@test.example");
await using(var manual=new ScheduleSession(new EwsMailSession(new HttpClient(manualHandler),options,"assistant@test.example"),null,new(){Key="boss",Name="Manager",Mailbox="boss@test.example"},new(2026,10,1),new(2026,11,1),zone))
 Check(!(await manual.SnapshotAsync(default)).CalendarLive,"Unapproved shared live subscription was advertised.");
var fallbackReader=new FakeExchange("assistant@test.example");var fallbackSubscription=new FakeExchange("assistant@test.example"){RejectSubscription=true};
await using(var fallback=new ScheduleSession(new EwsMailSession(new HttpClient(fallbackReader),options,"assistant@test.example"),new EwsMailSession(new HttpClient(fallbackSubscription),options,"assistant@test.example"),new(){Key="boss",Name="Manager",Mailbox="boss@test.example",EnableNotifications=true},new(2026,10,1),new(2026,11,1),zone))
{
 using var cancel=new CancellationTokenSource();await using var stream=fallback.ObserveAsync(cancel.Token).GetAsyncEnumerator();Check(await stream.MoveNextAsync()&&!stream.Current.CalendarLive&&stream.Current.Tasks.Items.Count==2,"Unsupported delegate subscription did not preserve manual calendar/personal tasks.");cancel.Cancel();
}
Check(fallbackReader.Unsubscribed==1&&fallbackSubscription.Unsubscribed==0,"Unsupported subscription cleanup incorrect.");
var limitConfig=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{{"Exchange:MaximumStreamsPerAccount","4"},{"Exchange:MaximumStreams","5"}}).Build();
var limits=new MailStreamLimits(limitConfig);var leases=Enumerable.Range(0,4).Select(_=>limits.TryEnter("account1")).ToArray();
Check(leases.All(l=>l is not null)&&limits.TryEnter("account1") is null,"Combined mail/schedule account budget incorrect.");
using(var other=limits.TryEnter("account2")){Check(other is not null&&limits.TryEnter("account3") is null,"Global stream budget incorrect.");}
foreach(var lease in leases)lease!.Dispose();using(var released=limits.TryEnter("account1"))Check(released is not null,"Stream budget was not released.");
// Calendar writes are tested against an in-memory SOAP server, never a real mailbox.
var editing=new EditingExchange();
await using(var session=new EwsMailSession(new HttpClient(editing),options,"assistant@test.example"))
{
 var draft=new SaveCalendarAppointment{Subject="موعد <script>نص</script>",Location="المكتب",Body="تفاصيل",Start=DateTimeOffset.Parse("2026-10-20T09:00+04:00"),End=DateTimeOffset.Parse("2026-10-20T10:00+04:00"),ItemId="appointment",ChangeKey="v1"};
 var discovered=await session.DiscoverCalendarsAsync(default);Check(discovered.Calendars.Count==1&&discovered.Calendars[0].Mailbox=="boss@test.example"&&discovered.Calendars[0].FolderId=="boss-folder","Outlook shortcut discovery failed.");
 await session.CreateAppointmentAsync("boss@test.example",null,draft,default);Check(editing.Writes==1&&editing.LastWrite!.Descendants(EditingExchange.T+"Subject").Single().Value==draft.Subject,"Create did not preserve literal text.");
 var details=await session.AppointmentAsync("boss@test.example",null,"appointment",default);Check(details.CanEdit&&details.CanDelete&&details.ChangeKey=="v1","Item rights/details missing.");
 await session.UpdateAppointmentAsync("boss@test.example",null,draft,default);Check(editing.LastWrite!.Attribute("SendMeetingInvitationsOrCancellations")?.Value=="SendToNone","Ordinary appointment unexpectedly sent meeting updates.");
 await session.DeleteAppointmentAsync("boss@test.example",null,new(){ItemId="appointment",ChangeKey="v1"},default);Check(editing.LastWrite!.Attribute("DeleteType")?.Value=="MoveToDeletedItems","Delete was not recoverable.");
 async Task Denied(Func<Task> action){var writes=editing.Writes;try{await action();throw new Exception("Denied operation accepted.");}catch(EwsResponseException e)when(e.Code=="ErrorAccessDenied"){}Check(editing.Writes==writes,"Denied operation reached Exchange write.");}
 editing.Parent="other-folder";await Denied(()=>session.UpdateAppointmentAsync("boss@test.example",null,draft,default));editing.Parent="boss-folder";
 editing.Private=true;await Denied(()=>session.AppointmentAsync("boss@test.example",null,"appointment",default));editing.Private=false;
 editing.Modify=false;await Denied(()=>session.UpdateAppointmentAsync("boss@test.example",null,draft,default));editing.Modify=true;
 editing.Delete=false;await Denied(()=>session.DeleteAppointmentAsync("boss@test.example",null,new(){ItemId="appointment",ChangeKey="v1"},default));editing.Delete=true;
 editing.Create=false;await Denied(()=>session.CreateAppointmentAsync("boss@test.example",null,draft,default));editing.Create=true;
 editing.Kind="RecurringMaster";await Denied(()=>session.UpdateAppointmentAsync("boss@test.example",null,draft,default));editing.Kind="Occurrence";
 Check((await session.AppointmentAsync("boss@test.example",null,"appointment",default)).CanEdit,"Occurrence editing was rejected.");
 editing.ChangeKey="v2";try{await session.UpdateAppointmentAsync("boss@test.example",null,draft,default);throw new Exception("Stale change key accepted.");}catch(CalendarOperationException e){Check(e.Status==409,"Conflict status incorrect.");}editing.ChangeKey="v1";
 editing.Meeting=true;editing.Organizer=false;await Denied(()=>session.UpdateAppointmentAsync("boss@test.example",null,draft,default));editing.Organizer=true;
 try{await session.UpdateAppointmentAsync("boss@test.example",null,draft,default);throw new Exception("Meeting update sent without consent.");}catch(CalendarOperationException e){Check(e.Status==400,"Meeting consent status incorrect.");}
 var confirmed=new SaveCalendarAppointment{Subject="اجتماع",Start=draft.Start,End=draft.End,ItemId="appointment",ChangeKey="v1",ConfirmMeetingNotifications=true};
 await session.UpdateAppointmentAsync("boss@test.example",null,confirmed,default);Check(editing.LastWrite!.Attribute("SendMeetingInvitationsOrCancellations")?.Value=="SendToAllAndSaveCopy","Meeting participants would not be notified.");
 await session.DeleteAppointmentAsync("boss@test.example",null,new(){ItemId="appointment",ChangeKey="v1",ConfirmMeetingNotifications=true},default);Check(editing.LastWrite!.Attribute("SendMeetingCancellations")?.Value=="SendToAllAndSaveCopy","Meeting cancellation would not notify participants.");
}
if(OperatingSystem.IsWindows())
{
 using var caller=System.Security.Principal.WindowsIdentity.GetCurrent();var name=caller.Name;
 using var transport=new TokenProbe(name);using var client=new HttpClient(new CallerWindowsHandler(caller,transport));caller.Dispose();
 await client.GetAsync("https://test.invalid/");await client.GetAsync("https://test.invalid/");Check(transport.Calls==2,"Caller token did not survive source disposal/async sends.");
 using var after=System.Security.Principal.WindowsIdentity.GetCurrent();Check(after.Name==name,"Impersonation leaked outside the request.");
}
var securityConfig=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{{"Exchange:Enabled","true"},{"Exchange:AccessMode","WindowsDelegation"},{"Exchange:EwsUrl",options.EwsUrl},{"Exchange:OutlookWebUrl",options.OutlookWebUrl}}).Build();
var factory=new MailSessionFactory(securityConfig,new Microsoft.AspNetCore.Http.HttpContextAccessor());
var missingRejected=false;try{factory.Create("boss@test.example");}catch(InvalidOperationException e){missingRejected=e.Message.Contains("Windows identity");}Check(missingRejected,"Missing Windows caller fell back to process identity.");
var provider=new Microsoft.AspNetCore.DataProtection.EphemeralDataProtectionProvider();
var resolver=new ScheduleService(factory,securityConfig,provider);Check(resolver.Resolve("DOMAIN\\alice","alice@test.example","own").Mailbox=="alice@test.example","Own calendar mapping changed.");
var ticketProtector=provider.CreateProtector("CompanyPortal.EmployeeCalendar.v1").ToTimeLimitedDataProtector();
var ticketJson=System.Text.Json.JsonSerializer.Serialize(new{Account="DOMAIN\\alice",Mailbox="boss@test.example",Name="المدير",FolderId="boss-folder"});
var validTicket="shared_"+ticketProtector.Protect(ticketJson,TimeSpan.FromMinutes(5));Check(resolver.Resolve("DOMAIN\\alice","alice@test.example",validTicket).Mailbox=="boss@test.example","Valid account-bound reference rejected.");
try{resolver.Resolve("DOMAIN\\bob","bob@test.example",validTicket);throw new Exception("Another employee reused a shared-calendar ticket.");}catch(EwsResponseException){}
var expiredTicket="shared_"+ticketProtector.Protect(ticketJson,DateTimeOffset.UtcNow.AddMinutes(-1));
try{resolver.Resolve("DOMAIN\\alice","alice@test.example",expiredTicket);throw new Exception("Expired calendar ticket accepted.");}catch(EwsResponseException){}
try{resolver.Resolve("DOMAIN\\alice","alice@test.example","shared_forged");throw new Exception("Forged shared calendar reference accepted.");}catch(EwsResponseException){}
Console.WriteLine("PASS: employee-context shared reads, effective/private rights, CalendarView/timezone/all-day/cancellation, task paging, denied/revoked access, employee-context shared invalidations, event-driven snapshots/cancellation, discovery, calendar writes, folder membership/private/item rights, conflicts, meeting consent, async Windows token lifetime and forged-reference denial.");

sealed class FakeExchange(string actor):HttpMessageHandler
{
 static readonly XNamespace T="http://schemas.microsoft.com/exchange/services/2006/types",M="http://schemas.microsoft.com/exchange/services/2006/messages",S="http://schemas.xmlsoap.org/soap/envelope/";
 public bool ReadAllowed=true,Truncate,NotificationsOnly,RejectSubscription;
 public int CalendarViews,TaskPages,Unsubscribed;
 public string LastRangeStart="";
 public string[] SubscribedFolders=[];
 protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token)
 {
  var xml=XElement.Parse(await request.Content!.ReadAsStringAsync(token));
  if(xml.Descendants(T+"ExchangeImpersonation").Any())throw new Exception("Service-account impersonation header must never be sent.");
  var operation=xml.Element(S+"Body")!.Elements().Single();var kind=operation.Name.LocalName;
  if(NotificationsOnly&&kind is not ("Subscribe" or "GetStreamingEvents" or "Unsubscribe"))throw new Exception("Owner session attempted a read.");
  XElement payload;
  if(kind=="GetFolder")payload=new XElement(M+"Folders",new XElement(T+"CalendarFolder",new XElement(T+"FolderId",new XAttribute("Id","boss-folder")),new XElement(T+"EffectiveRights",new XElement(T+"Read",ReadAllowed),new XElement(T+"Modify",false),new XElement(T+"ViewPrivateItems",false))));
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
   TaskPages++;if(operation.Descendants(T+"DistinguishedFolderId").Single().Element(T+"Mailbox")?.Element(T+"EmailAddress")?.Value!=actor)throw new Exception("Tasks requested for another mailbox.");if(!operation.Descendants(T+"FieldURI").Any(n=>n.Attribute("FieldURI")?.Value=="task:IsComplete"))throw new Exception("Outstanding-task restriction missing.");
   var first=operation.Element(M+"IndexedPageItemView")!.Attribute("Offset")!.Value=="0";
   payload=new XElement(M+"RootFolder",new XAttribute("IncludesLastItemInRange",!first),new XAttribute("IndexedPagingOffset",first?1:2),new XElement(T+"Items",new XElement(T+"Task",new XElement(T+"ItemId",new XAttribute("Id",first?"task1":"task2")),new XElement(T+"Subject","Task <script>literal</script>"),first?new XElement(T+"DueDate","2026-10-19T20:00:00Z"):null,new XElement(T+"Status","InProgress"),new XElement(T+"Importance","High"),new XElement(T+"PercentComplete",50))));
  }
  else if(kind=="Subscribe"){if(RejectSubscription)return new(HttpStatusCode.OK){Content=new StringContent(new XElement(S+"Envelope",new XElement(S+"Body",new XElement(M+"ResponseCode","ErrorSubscriptionDelegateAccessNotSupported"))).ToString(),Encoding.UTF8,"text/xml")};SubscribedFolders=operation.Descendants(T+"DistinguishedFolderId").Select(n=>n.Attribute("Id")!.Value).ToArray();payload=new XElement(M+"SubscriptionId","subscription");}
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

sealed class TokenProbe(string expected):HttpMessageHandler
{
 public int Calls;
 protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token){await Task.Yield();if(OperatingSystem.IsWindows()){using var identity=System.Security.Principal.WindowsIdentity.GetCurrent();if(identity.Name!=expected)throw new Exception("Windows caller lost across async continuation.");}Calls++;return new(HttpStatusCode.OK);}
}
sealed class EditingExchange:HttpMessageHandler
{
 public static readonly XNamespace T="http://schemas.microsoft.com/exchange/services/2006/types";
 static readonly XNamespace M="http://schemas.microsoft.com/exchange/services/2006/messages",S="http://schemas.xmlsoap.org/soap/envelope/";
 public bool Modify=true,Create=true,Delete=true,Private,Meeting,Organizer;public string Parent="boss-folder",ChangeKey="v1",Kind="Single";public int Writes;public XElement? LastWrite;
 static XElement Flag(string key,bool value)=>new(T+key,value);
 static XElement Binary(string tag,byte[] value)=>new(T+"ExtendedProperty",new XElement(T+"ExtendedFieldURI",new XAttribute("PropertyTag",tag)),new XElement(T+"Value",Convert.ToBase64String(value)));
 protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token)
 {
  var xml=XElement.Parse(await request.Content!.ReadAsStringAsync(token));if(xml.Descendants(T+"ExchangeImpersonation").Any())throw new Exception("Impersonation header sent.");var operation=xml.Element(S+"Body")!.Elements().Single();XElement payload;
  switch(operation.Name.LocalName)
  {
   case "GetFolder":
    payload=operation.Descendants(T+"DistinguishedFolderId").Any(x=>x.Attribute("Id")?.Value=="root")?new XElement(M+"Folders",new XElement(T+"Folder",Binary("0x35E6",[1,2,3]))):new XElement(M+"Folders",new XElement(T+"CalendarFolder",new XElement(T+"FolderId",new XAttribute("Id","boss-folder")),new XElement(T+"EffectiveRights",Flag("Read",true),Flag("CreateContents",Create),Flag("Modify",Modify),Flag("Delete",true))));break;
   case "ConvertId":payload=new XElement(T+"AlternateId",new XAttribute("Id",operation.Descendants(T+"AlternateId").Single().Attribute("Mailbox")!.Value=="assistant@test.example"?"common-folder":"boss-folder"));break;
   case "ResolveNames":payload=new XElement(T+"Resolution",new XElement(T+"Mailbox",new XElement(T+"EmailAddress","boss@test.example"),new XElement(T+"Name","المدير")));break;
   case "FindItem":
    if(operation.Attribute("Traversal")?.Value!="Associated")throw new Exception("Discovery did not read associated shortcuts.");
    payload=new XElement(M+"RootFolder",new XAttribute("IncludesLastItemInRange",true),new XElement(T+"Items",new XElement(T+"Message",Binary("0x6854",new byte[28].Concat(Encoding.ASCII.GetBytes("/o=Company/ou=Exchange/cn=Recipients/cn=boss\0")).ToArray()),Binary("0x684C",[4,5,6]))));break;
   case "GetItem":payload=new XElement(M+"Items",new XElement(T+"CalendarItem",new XElement(T+"ItemId",new XAttribute("Id","appointment"),new XAttribute("ChangeKey",ChangeKey)),new XElement(T+"ParentFolderId",new XAttribute("Id",Parent)),new XElement(T+"Subject","موعد"),new XElement(T+"Body","نص"),new XElement(T+"Sensitivity",Private?"Private":"Normal"),new XElement(T+"Start","2026-10-20T05:00:00Z"),new XElement(T+"End","2026-10-20T06:00:00Z"),Flag("IsAllDayEvent",false),Flag("IsMeeting",Meeting),Flag("IsOrganizer",Organizer),new XElement(T+"CalendarItemType",Kind),new XElement(T+"EffectiveRights",Flag("Read",true),Flag("Modify",Modify),Flag("Delete",Delete),Flag("ViewPrivateItems",false))));break;
   case "CreateItem":case "UpdateItem":case "DeleteItem":Writes++;LastWrite=operation;payload=new XElement(M+"Items",new XElement(T+"CalendarItem",new XElement(T+"ItemId",new XAttribute("Id","saved"),new XAttribute("ChangeKey","v2"))));break;
   default:throw new Exception("Unexpected editing SOAP: "+operation.Name.LocalName);
  }
  return new(HttpStatusCode.OK){Content=new StringContent(new XElement(S+"Envelope",new XElement(S+"Body",new XElement(M+"Response",new XElement(M+"ResponseCode","NoError"),payload))).ToString(),Encoding.UTF8,"text/xml")};
 }
}
