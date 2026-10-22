using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace CompanyPortal.Api.Contracts;

public sealed record WorkspaceCardDefinition(string CardKey, string CardName, bool IsFixed, int DisplayOrder, bool IsCustom, int? UserCardId,
    string CardType, AuthorizedApplication[] Applications);
public sealed record CardOrderResponse(string[] CardKeys, WorkspaceCardDefinition[] Cards, bool IsSaved, DateTime? LastChangeAt);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveCardOrderRequest : IValidatableObject
{
    [Required, MaxLength(200)]
    public string[] CardKeys { get; init; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (CardKeys is null) yield break;
        if (CardKeys.Any(key => key is null || !Regex.IsMatch(key, "^[a-z][a-z0-9-]{0,99}$"))
            || CardKeys.Distinct(StringComparer.Ordinal).Count() != CardKeys.Length)
            yield return new ValidationResult("Supply unique, valid card keys.", [nameof(CardKeys)]);
    }
}
