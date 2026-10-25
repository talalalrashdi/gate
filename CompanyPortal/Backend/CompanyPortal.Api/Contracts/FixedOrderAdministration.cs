using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace CompanyPortal.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveFixedOrderRequest : IValidatableObject
{
    public DateOnly? Timestamp { get; init; }
    public DateOnly? Timestamp2 { get; init; }
    [StringLength(500)] public string? ContentBefor { get; init; }
    [Required,StringLength(1000)] public string ContentAfter { get; init; } = "";
    [Required,StringLength(1000)] public string ContentText { get; init; } = "";
    [Required] public int? TimestampType { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if(ContentText?.Contains("ds{0}de",StringComparison.Ordinal)==true&&string.IsNullOrWhiteSpace(ContentBefor))
            yield return new("Enter previous text when its marker is used.",[nameof(ContentBefor)]);
        var remaining=(ContentText??"").Replace("ds{0}de","").Replace("ss{1}se","");
        if(Regex.IsMatch(remaining,@"(?:ds|ss)\{[^{}]*\}(?:de|se)",RegexOptions.CultureInvariant))
            yield return new("Use the supplied previous/replacement marker buttons.",[nameof(ContentText)]);
    }
}
