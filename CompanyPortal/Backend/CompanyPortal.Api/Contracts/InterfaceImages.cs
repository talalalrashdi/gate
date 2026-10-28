using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace CompanyPortal.Api.Contracts;

public sealed record PortalImage(int ImageId, string ImageName, string ContentType, int PixelWidth, int PixelHeight, long ByteLength, DateTime LastChangeAt, bool HasThumbnail);
public sealed record ImageGroup(int ImageGroupId, string GroupName, bool RotateImages, int RotationSeconds, int? DefaultImageId, bool Active, DateTime LastChangeAt);
public sealed record ImageGroupItem(int ImageGroupId, int ImageId, int DisplayOrder, bool Active);
public sealed record ImageTheme(int ThemeId, string ThemeName, string LayoutKey, int? ImageGroupId);
public sealed record ImageAdministration(IReadOnlyList<PortalImage> Images, IReadOnlyList<ImageGroup> Groups, IReadOnlyList<ImageGroupItem> Items, IReadOnlyList<ImageTheme> Themes);
public sealed record ThemeImageSettings(int ImageGroupId, bool RotateImages, int RotationSeconds, int? DefaultImageId);
public sealed record ThemeImage(int ImageId, string ImageName, int DisplayOrder)
{
    public decimal? FocalX {get;init;}
    public decimal? FocalY {get;init;}
}
public sealed record ThemeImages(ThemeImageSettings? Settings, IReadOnlyList<ThemeImage> Images);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveImageGroup
{
    [Required, StringLength(200, MinimumLength = 1)] public string GroupName { get; init; } = "";
    [Required] public bool? RotateImages { get; init; }
    [Range(3, 3600)] public int RotationSeconds { get; init; } = 8;
    [Range(1, int.MaxValue)] public int? DefaultImageId { get; init; }
    [Required] public bool? Active { get; init; }
    [Required, MaxLength(100)] public ImageSelection[] Items { get; init; } = [];
}
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class ImageSelection
{
    [Range(1, int.MaxValue)] public int ImageId { get; init; }
    [Range(1, 100)] public int DisplayOrder { get; init; }
    [Required] public bool? Active { get; init; }
}
