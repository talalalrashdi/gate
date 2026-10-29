using System.Globalization;
using System.Xml;
using System.Xml.Linq;
using CompanyPortal.Api.Contracts;
namespace CompanyPortal.Api.Mail;

public sealed class CalendarOperationException(int status,string message):Exception(message){public int Status=>status;}
public sealed partial class EwsMailSession
{
 private static string Utc(DateTimeOffset value)=>value.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ",CultureInfo.InvariantCulture);
 private static string Change(XElement item)=>item.Element(T+"ItemId")?.Attribute("ChangeKey")?.Value??throw new XmlException("Missing appointment change key.");
 private async Task<XElement> AppointmentItem(string owner,string? folderId,string id,CancellationToken token)
 {
  var folder=await CalendarFolderAsync(owner,folderId,token);if(!folder.Rights.Read)throw new EwsResponseException("ErrorAccessDenied");
  var fields=new[]{"item:ParentFolderId","item:Subject","item:Body","item:Sensitivity","item:EffectiveRights","calendar:Start","calendar:End","calendar:IsAllDayEvent","calendar:Location","calendar:IsMeeting","calendar:IsOrganizer","calendar:IsCancelled","calendar:Organizer","calendar:CalendarItemType"};
  var doc=await CallAsync(new XElement(M+"GetItem",new XElement(M+"ItemShape",new XElement(T+"BaseShape","IdOnly"),new XElement(T+"BodyType","Text"),new XElement(T+"AdditionalProperties",fields.Select(Field))),new XElement(M+"ItemIds",new XElement(T+"ItemId",new XAttribute("Id",id)))),token);
  var item=doc.Descendants(T+"CalendarItem").SingleOrDefault()??throw new EwsResponseException("ErrorItemNotFound");
  if(item.Element(T+"ParentFolderId")?.Attribute("Id")?.Value!=folder.Id||!Flag(item.Element(T+"EffectiveRights"),"Read"))throw new EwsResponseException("ErrorAccessDenied");
  var own=string.Equals(owner,mailbox,StringComparison.OrdinalIgnoreCase);
  if(!own&&(item.Element(T+"Sensitivity") is null||item.Element(T+"Sensitivity")?.Value=="Private"&&!Flag(item.Element(T+"EffectiveRights"),"ViewPrivateItems")))throw new EwsResponseException("ErrorAccessDenied");
  return item;
 }
 private static bool EditableMeeting(XElement item,string owner)=>!Flag(item,"IsMeeting")||Flag(item,"IsOrganizer")||string.Equals(item.Element(T+"Organizer")?.Descendants(T+"EmailAddress").FirstOrDefault()?.Value,owner,StringComparison.OrdinalIgnoreCase);
 public async Task<CalendarAppointmentDetails> AppointmentAsync(string owner,string? folderId,string id,CancellationToken token)
 {
  var i=await AppointmentItem(owner,folderId,id,token);var kind=i.Element(T+"CalendarItemType")?.Value??"Single";var valid=kind!="RecurringMaster"&&EditableMeeting(i,owner);
  return new(id,Change(i),i.Element(T+"Subject")?.Value??"",i.Element(T+"Location")?.Value??"",i.Element(T+"Body")?.Value??"",Instant(i.Element(T+"Start")?.Value??throw new XmlException("Missing start.")),Instant(i.Element(T+"End")?.Value??throw new XmlException("Missing end.")),Flag(i,"IsAllDayEvent"),i.Element(T+"Sensitivity")?.Value=="Private",Flag(i,"IsMeeting"),kind,valid&&!Flag(i,"IsCancelled")&&Flag(i.Element(T+"EffectiveRights"),"Modify"),valid&&Flag(i.Element(T+"EffectiveRights"),"Delete"));
 }
 private void ValidateTimes(SaveCalendarAppointment r)
 {
  if(r.Start is null||r.End is null||r.End<=r.Start)throw new CalendarOperationException(400,"راجع بداية ونهاية الموعد.");
  if(r.IsAllDay){var zone=options.ScheduleZone();if(TimeZoneInfo.ConvertTime(r.Start.Value,zone).TimeOfDay!=TimeSpan.Zero||TimeZoneInfo.ConvertTime(r.End.Value,zone).TimeOfDay!=TimeSpan.Zero)throw new CalendarOperationException(400,"الموعد طوال اليوم يجب أن يبدأ وينتهي عند منتصف الليل، والنهاية غير مشمولة.");}
 }
 private static XElement SetField(string field,string name,object value)=>new(T+"SetItemField",Field(field),new XElement(T+"CalendarItem",value is XElement e?e:new XElement(T+name,value)));
 public async Task<object> CreateAppointmentAsync(string owner,string? folderId,SaveCalendarAppointment r,CancellationToken token)
 {
  ValidateTimes(r);var folder=await CalendarFolderAsync(owner,folderId,token);if(!folder.Rights.Read||!folder.Rights.Create)throw new EwsResponseException("ErrorAccessDenied");
  var zone=options.ScheduleTimeZone;TimeZoneInfo.TryConvertIanaIdToWindowsId(zone,out var windows);zone=windows??zone;
  var item=new XElement(T+"CalendarItem",new XElement(T+"Subject",r.Subject.Trim()),new XElement(T+"Sensitivity",r.IsPrivate?"Private":"Normal"),new XElement(T+"Body",new XAttribute("BodyType","Text"),r.Body),
   new XElement(T+"Start",Utc(r.Start!.Value)),new XElement(T+"End",Utc(r.End!.Value)),new XElement(T+"IsAllDayEvent",r.IsAllDay),new XElement(T+"LegacyFreeBusyStatus","Busy"),new XElement(T+"Location",r.Location.Trim()),new XElement(T+"StartTimeZone",new XAttribute("Id",zone)),new XElement(T+"EndTimeZone",new XAttribute("Id",zone)));
  var doc=await CallAsync(new XElement(M+"CreateItem",new XAttribute("SendMeetingInvitations","SendToNone"),new XElement(M+"SavedItemFolderId",new XElement(T+"FolderId",new XAttribute("Id",folder.Id))),new XElement(M+"Items",item)),token);
  var saved=doc.Descendants(T+"ItemId").FirstOrDefault()??throw new XmlException("Missing created appointment ID.");return new{ItemId=saved.Attribute("Id")?.Value,ChangeKey=saved.Attribute("ChangeKey")?.Value};
 }
 public async Task UpdateAppointmentAsync(string owner,string? folderId,SaveCalendarAppointment r,CancellationToken token)
 {
  ValidateTimes(r);var current=await AppointmentAsync(owner,folderId,r.ItemId!,token);if(!current.CanEdit)throw new EwsResponseException("ErrorAccessDenied");
  if(current.ChangeKey!=r.ChangeKey)throw new CalendarOperationException(409,"تم تعديل الموعد في Outlook. أعد فتحه قبل الحفظ.");
  if(current.IsMeeting&&!r.ConfirmMeetingNotifications)throw new CalendarOperationException(400,"تعديل الاجتماع يتطلب تأكيد إرسال التحديث للمشاركين.");
  await CallAsync(new XElement(M+"UpdateItem",new XAttribute("ConflictResolution","NeverOverwrite"),new XAttribute("SendMeetingInvitationsOrCancellations",current.IsMeeting?"SendToAllAndSaveCopy":"SendToNone"),new XElement(M+"ItemChanges",new XElement(T+"ItemChange",new XElement(T+"ItemId",new XAttribute("Id",r.ItemId!),new XAttribute("ChangeKey",current.ChangeKey)),new XElement(T+"Updates",
   SetField("item:Subject","Subject",r.Subject.Trim()),SetField("item:Sensitivity","Sensitivity",r.IsPrivate?"Private":"Normal"),SetField("item:Body","Body",new XElement(T+"Body",new XAttribute("BodyType","Text"),r.Body)),SetField("calendar:Start","Start",Utc(r.Start!.Value)),SetField("calendar:End","End",Utc(r.End!.Value)),SetField("calendar:IsAllDayEvent","IsAllDayEvent",r.IsAllDay),SetField("calendar:Location","Location",r.Location.Trim()))))),token);
 }
 public async Task DeleteAppointmentAsync(string owner,string? folderId,DeleteCalendarAppointment r,CancellationToken token)
 {
  var current=await AppointmentAsync(owner,folderId,r.ItemId,token);if(!current.CanDelete)throw new EwsResponseException("ErrorAccessDenied");
  if(current.ChangeKey!=r.ChangeKey)throw new CalendarOperationException(409,"تم تعديل الموعد في Outlook. أعد فتحه قبل الحذف.");
  if(current.IsMeeting&&!r.ConfirmMeetingNotifications)throw new CalendarOperationException(400,"حذف الاجتماع يتطلب تأكيد إرسال الإلغاء للمشاركين.");
  await CallAsync(new XElement(M+"DeleteItem",new XAttribute("DeleteType","MoveToDeletedItems"),new XAttribute("SendMeetingCancellations",current.IsMeeting?"SendToAllAndSaveCopy":"SendToNone"),new XAttribute("AffectedTaskOccurrences","SpecifiedOccurrenceOnly"),new XElement(M+"ItemIds",new XElement(T+"ItemId",new XAttribute("Id",r.ItemId),new XAttribute("ChangeKey",current.ChangeKey)))),token);
 }
}
