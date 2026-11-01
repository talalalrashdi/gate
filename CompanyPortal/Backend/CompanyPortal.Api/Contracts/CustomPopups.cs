using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
namespace CompanyPortal.Api.Contracts;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveCustomPopup : IValidatableObject
{
 [Required,StringLength(100)] public string PopupType {get;init;}="";
 [Required,StringLength(2000)] public string Details {get;init;}="";
 [Required] public DateTimeOffset? StartAt {get;init;}
 [Required] public DateTimeOffset? EndAt {get;init;}
 public bool IsDisplayed {get;init;}
 public IEnumerable<ValidationResult> Validate(ValidationContext context)
 {if(StartAt is {} a&&EndAt is {} b&&(b<=a||a.Year<1753||b.Year>9998))yield return new("أدخل فترة عرض صحيحة، والنهاية بعد البداية.",[nameof(EndAt)]);}
}
