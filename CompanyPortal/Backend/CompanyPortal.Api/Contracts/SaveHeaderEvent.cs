using System.ComponentModel.DataAnnotations;
namespace CompanyPortal.Api.Contracts;
public sealed class SaveHeaderEvent : IValidatableObject
{
 [Required(ErrorMessage="أدخل عنوان الفعالية."),StringLength(150,ErrorMessage="العنوان يجب ألا يتجاوز 150 حرفًا.")] public string Title {get;init;}="";
 [Range(0,2)] public int EventType {get;init;}=1;
 [StringLength(2048)] public string? EventTarget {get;init;}
 // Accept older link clients during rollout; persisted/public field is EventTarget.
 [StringLength(2048)] public string? AppUrl {get;init;}
 [System.Text.Json.Serialization.JsonIgnore] public string Target => (EventTarget??AppUrl??"").Trim();
 [Required(ErrorMessage="حدد بداية العرض.")] public DateTimeOffset? StartAt {get;init;}
 [Required(ErrorMessage="حدد نهاية العرض.")] public DateTimeOffset? EndAt {get;init;}
 public bool IsDisplayed {get;init;}=true;
 // End dates are always 23:59 in the portal's +04:00 business timezone.
 [System.Text.Json.Serialization.JsonIgnore] public DateTimeOffset? EndOfDay => EndAt is {} end && end.ToOffset(TimeSpan.FromHours(4)).Year<9999
  ? new DateTimeOffset(end.ToOffset(TimeSpan.FromHours(4)).Date.AddHours(23).AddMinutes(59),TimeSpan.FromHours(4)) : null;
 public IEnumerable<ValidationResult> Validate(ValidationContext context)
 {
  if(string.IsNullOrWhiteSpace(Target))yield return new("اختر ملفًا من جهازك أو أدخل مساره الكامل.",[nameof(EventTarget)]);
  if(EventType is 0 or 2 && (!Path.IsPathFullyQualified(Target)||Target.Any(char.IsControl)))yield return new("أدخل مسارًا مطلقًا على خادم البوابة مثل D:\\PortalFiles\\Events\\event.pdf.",[nameof(EventTarget)]);
  if(EventType==1&&!CompanyPortal.Api.Data.HeaderEventsStore.SafeUrl(Target))yield return new("أدخل رابطًا صحيحًا يبدأ بـ https:// أو http:// دون اسم مستخدم أو كلمة مرور.",[nameof(EventTarget)]);
  if(StartAt is {} start && EndAt is {} end && (start.UtcDateTime.Year<1753||end.UtcDateTime.Year>=9999||end<=start||EndOfDay is null||EndOfDay<=start))yield return new("نهاية العرض الساعة 11:59 مساءً يجب أن تكون بعد بداية العرض، والتواريخ ضمن المجال المسموح.",[nameof(EndAt)]);
 }
}
