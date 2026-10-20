using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record ThemeDefinition(int ThemeId, string ThemeName, string LayoutKey, int DisplayOrder, bool IsDefault,
    string? PrimaryColor, string? AccentColor, string? BackgroundColor, int? OverlayOpacity, string? ForegroundPreset, string ImagePresentation, int? ImageGroupId);
public sealed record ThemeSettingsResponse(int ThemeId, string ThemeName, string LayoutKey, bool IsSaved, DateTime? LastChangeAt);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveThemeRequest
{
    [Range(1, int.MaxValue)]
    public int ThemeId { get; init; }
}
