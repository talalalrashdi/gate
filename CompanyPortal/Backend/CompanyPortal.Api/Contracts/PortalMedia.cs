using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
namespace CompanyPortal.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveMediaRequest:IValidatableObject
{
 [Required,StringLength(300)] public string MediaName {get;init;}="";
 [Required,StringLength(2000)] public string MediaPath {get;init;}="";
 [Required,RegularExpression("^(image|video)$")] public string MediaType {get;init;}="image";
 [Range(1,int.MaxValue)] public int? MediaGroupId {get;init;}
 [Range(0,int.MaxValue)] public int DisplayOrder {get;init;}
 public bool Active {get;init;}=true;
 public IEnumerable<ValidationResult> Validate(ValidationContext context)
 {if(MediaType=="video"&&MediaGroupId is not null)yield return new("Videos cannot belong to a photo album.",[nameof(MediaGroupId)]);}
}
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveMediaGroupRequest
{
 [Required,StringLength(200)] public string GroupName {get;init;}="";
 [Range(1,int.MaxValue)] public int? CoverMediaId {get;init;}
 [Range(0,int.MaxValue)] public int DisplayOrder {get;init;}
 public bool Active {get;init;}=true;
}
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class PreviewMediaRequest
{
 [Required,StringLength(2000)] public string MediaPath {get;init;}="";
 [Required,RegularExpression("^(image|video)$")] public string MediaType {get;init;}="image";
}
