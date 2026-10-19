using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record PortalAccess(bool IsAdmin);
public sealed record MasterCard(int CardId, string CardKey, string CardName, int DisplayOrder, bool IsFixed, DateTime LastChangeAt);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveMasterCardRequest : IValidatableObject
{
    [Required, StringLength(200, MinimumLength = 1)]
    public string CardName { get; init; } = "";
    [Required]
    public bool? IsFixed { get; init; }
    [Required, Range(1, int.MaxValue)]
    public int? DisplayOrder { get; init; }
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (string.IsNullOrWhiteSpace(CardName))
            yield return new("Supply a card name.", [nameof(CardName)]);
    }
}
