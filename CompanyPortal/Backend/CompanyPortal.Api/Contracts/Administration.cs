using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record PortalAccess(bool IsAdmin);
public sealed record MasterCard(int CardId, string CardKey, string CardName, int DisplayOrder, bool IsFixed, DateTime LastChangeAt,
    string CardType, bool Active, string Audience, int[] AppIds, string[] RoleNames);
public sealed record MasterCardIdentity(int CardId);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveMasterCardRequest : IValidatableObject
{
    [Required, StringLength(200, MinimumLength = 1)]
    public string CardName { get; init; } = "";
    [Required]
    public bool? IsFixed { get; init; }
    [Required, Range(1, int.MaxValue)]
    public int? DisplayOrder { get; init; }
    [Required] public bool? Active { get; init; }
    [Required, RegularExpression("^(everyone|roles)$")] public string Audience { get; init; } = "everyone";
    [Required, MaxLength(100)] public int[] AppIds { get; init; } = [];
    [Required, MaxLength(50)] public string[] RoleNames { get; init; } = [];
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (string.IsNullOrWhiteSpace(CardName))
            yield return new("Supply a card name.", [nameof(CardName)]);
        if (AppIds is not null && (AppIds.Any(id => id < 1) || AppIds.Distinct().Count() != AppIds.Length))
            yield return new("Supply unique positive application IDs.", [nameof(AppIds)]);
        if (RoleNames is not null && (RoleNames.Any(role => string.IsNullOrWhiteSpace(role) || role.Length > 200 || role != role.Trim())
            || RoleNames.Distinct(StringComparer.Ordinal).Count() != RoleNames.Length
            || (Audience == "roles" && RoleNames.Length == 0) || (Audience == "everyone" && RoleNames.Length != 0)))
            yield return new("Supply role names only for a restricted audience.", [nameof(RoleNames)]);
    }
}
