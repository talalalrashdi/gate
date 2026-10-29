using System.ComponentModel.DataAnnotations;
namespace CompanyPortal.Api.Contracts;

public sealed class SaveCalendarAppointment : IValidatableObject
{
 [Required,StringLength(4096)] public string CalendarKey {get;init;}="own";
 [StringLength(8000)] public string? ItemId {get;init;}
 [StringLength(2000)] public string? ChangeKey {get;init;}
 [Required,StringLength(255)] public string Subject {get;init;}="";
 [StringLength(255)] public string Location {get;init;}="";
 [StringLength(5000)] public string Body {get;init;}="";
 [Required] public DateTimeOffset? Start {get;init;}
 [Required] public DateTimeOffset? End {get;init;}
 public bool IsAllDay {get;init;}
 public bool IsPrivate {get;init;}
 public bool ConfirmMeetingNotifications {get;init;}
 public IEnumerable<ValidationResult> Validate(ValidationContext context){if(Start is {} s&&End is {} e&&(s.Year<1900||e.Year>2100||e<=s||e-s>TimeSpan.FromDays(366)))yield return new("راجع بداية ونهاية الموعد (النهاية بعد البداية، والمدة لا تتجاوز سنة).",[nameof(End)]);}
}
public sealed class DeleteCalendarAppointment
{
 [Required,StringLength(4096)] public string CalendarKey {get;init;}="own";
 [Required,StringLength(8000)] public string ItemId {get;init;}="";
 [Required,StringLength(2000)] public string ChangeKey {get;init;}="";
 public bool ConfirmMeetingNotifications {get;init;}
}
public sealed class OpenSharedCalendar
{
 [Required,EmailAddress,StringLength(320)] public string Mailbox {get;init;}="";
}
public sealed record CalendarAppointmentDetails(string ItemId,string ChangeKey,string Subject,string Location,string Body,DateTimeOffset Start,DateTimeOffset End,bool IsAllDay,bool IsPrivate,bool IsMeeting,string CalendarItemType,bool CanEdit,bool CanDelete);
