using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record ThemeSettingsResponse(string ThemeName, bool IsSaved, DateTime? LastChangeAt);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveThemeRequest
{
    [Required, StringLength(50)]
    public string ThemeName { get; init; } = string.Empty;
}
