using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
namespace CompanyPortal.Api.Contracts;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveAdminPermissionsRequest
{
    [Required,StringLength(200,MinimumLength=1)] public string RoleName {get;init;}="";
    [Required,MaxLength(13)] public string[] Sections {get;init;}=[];
}
