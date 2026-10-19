using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record AuthorizedApplication(int AppId, string AppName);
public sealed record UserCardResponse(int UserCardId, string CardName, AuthorizedApplication[] Applications, DateTime LastChangeAt);
public sealed record UserCardIdentity(int UserCardId);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveUserCardRequest : IValidatableObject
{
    [Required, StringLength(200, MinimumLength = 1)]
    public string CardName { get; init; } = "";
    [Required, MinLength(1), MaxLength(100)]
    public int[] AppIds { get; init; } = [];
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (string.IsNullOrWhiteSpace(CardName))
            yield return new("Supply a card name.", [nameof(CardName)]);
        if (AppIds is not null && (AppIds.Any(id => id <= 0) || AppIds.Distinct().Count() != AppIds.Length))
            yield return new("Supply unique positive application IDs.", [nameof(AppIds)]);
    }
}
