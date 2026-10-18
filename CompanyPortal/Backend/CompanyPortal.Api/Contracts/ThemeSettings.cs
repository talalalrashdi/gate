using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record ThemeSettingsResponse(string Theme, bool IsSaved);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveThemeRequest
{
    [Required, StringLength(50)]
    public string Theme { get; init; } = string.Empty;
}
