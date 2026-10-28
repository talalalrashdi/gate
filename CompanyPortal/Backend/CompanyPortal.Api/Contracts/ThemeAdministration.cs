using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using System.Text.Json;

namespace CompanyPortal.Api.Contracts;

public sealed record AdminTheme(int ThemeId,string ThemeName,string LayoutKey,int DisplayOrder,bool IsDefault,bool Active,DateTime LastChangeAt,
    string? PrimaryColor,string? AccentColor,string? BackgroundColor,int? OverlayOpacity,string? ForegroundPreset,string ImagePresentation,int? ImageGroupId,string Visibility,[property:JsonIgnore] string PreviewRolesJson)
{
    public ThemeImagePosition[] ImagePositions {get;init;}=[];
    public string[] PreviewRoles => (JsonSerializer.Deserialize<PreviewRole[]>(PreviewRolesJson??"[]")??[]).Select(r=>r.RoleName).ToArray();
    public sealed record PreviewRole(string RoleName);
}
public sealed record ThemeTemplate(string LayoutKey,string TemplateName,string Thumbnail,string PrimaryColor,string AccentColor,string BackgroundColor,int OverlayOpacity,string ForegroundPreset);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveAdminTheme
{
    [Required,StringLength(200,MinimumLength=1)] public string ThemeName {get;init;}="";
    [Required,RegularExpression("^(official|work|national-day)$")] public string LayoutKey {get;init;}="";
    [Range(0,1000000)] public int DisplayOrder {get;init;}
    [Required] public bool? Active {get;init;}
    [Required] public bool? IsDefault {get;init;}
    [StringLength(7,MinimumLength=7),RegularExpression("^#[0-9a-fA-F]{6}$")] public string? PrimaryColor {get;init;}
    [StringLength(7,MinimumLength=7),RegularExpression("^#[0-9a-fA-F]{6}$")] public string? AccentColor {get;init;}
    [StringLength(7,MinimumLength=7),RegularExpression("^#[0-9a-fA-F]{6}$")] public string? BackgroundColor {get;init;}
    [Range(0,85)] public int? OverlayOpacity {get;init;}
    [StringLength(5,MinimumLength=4),RegularExpression("^(light|dark)$")] public string? ForegroundPreset {get;init;}
    [Required,RegularExpression("^(background|artwork)$")] public string ImagePresentation {get;init;}="background";
    [Range(1,int.MaxValue)] public int? ImageGroupId {get;init;}
    [RegularExpression("^(hidden|preview|public)$")] public string? Visibility {get;init;}
    [MaxLength(50)] public string[] PreviewRoles {get;init;}=[];
    [MaxLength(100)] public ThemeImagePosition[]? ImagePositions {get;init;}
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ThemeImagePosition
{
    [JsonRequired,Range(1,int.MaxValue)] public int ImageId {get;init;}
    [JsonRequired,Range(typeof(decimal),"0","100")] public decimal FocalX {get;init;}
    [JsonRequired,Range(typeof(decimal),"0","100")] public decimal FocalY {get;init;}
}
