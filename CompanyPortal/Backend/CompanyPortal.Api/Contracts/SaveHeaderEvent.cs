using System.ComponentModel.DataAnnotations;
namespace CompanyPortal.Api.Contracts;
public sealed class SaveHeaderEvent : IValidatableObject
{
 [Required,StringLength(150)] public string Title {get;init;}="";
 [Required,StringLength(2048)] public string AppUrl {get;init;}="";
 [Required] public DateTimeOffset? StartAt {get;init;}
 [Required] public DateTimeOffset? EndAt {get;init;}
 public bool Active {get;init;}=true;
 public IEnumerable<ValidationResult> Validate(ValidationContext context)
 {
  if(!CompanyPortal.Api.Data.HeaderEventsStore.SafeUrl(AppUrl))yield return new("Use an HTTP(S) application URL without credentials.",[nameof(AppUrl)]);
  if(StartAt is {} start && EndAt is {} end && (start.UtcDateTime.Year<1753||end.UtcDateTime.Year>=9999||end<=start))yield return new("End must be after start, within SQL datetime range.",[nameof(EndAt)]);
 }
}
