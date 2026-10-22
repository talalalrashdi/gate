using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record DirectoryApplication(int AppId,string AppName,string Description,int? CategoryId,string CategoryName,int CategoryOrder);
public sealed record AdminDirectoryApplication(int AppId,string AppName,string Description,int? CategoryId,DateTime? LastChangeAt);
public sealed record ApplicationCategory(int CategoryId,string CategoryName,int DisplayOrder,bool Active,DateTime LastChangeAt);
public sealed record ApplicationDirectoryAdministration(AdminDirectoryApplication[] Applications,ApplicationCategory[] Categories);
public sealed record CategoryIdentity(int CategoryId);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveApplicationDetailsRequest
{
    [Required(AllowEmptyStrings=true),StringLength(2000)] public string Description { get; init; } = "";
    [Range(1,int.MaxValue)] public int? CategoryId { get; init; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveApplicationCategoryRequest : IValidatableObject
{
    [Required,StringLength(200)] public string CategoryName { get; init; } = "";
    [Required,Range(0,int.MaxValue)] public int? DisplayOrder { get; init; }
    [Required] public bool? Active { get; init; }
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if(string.IsNullOrWhiteSpace(CategoryName)) yield return new("Supply a category name.",[nameof(CategoryName)]);
    }
}
