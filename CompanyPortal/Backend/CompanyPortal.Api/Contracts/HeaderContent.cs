using System.ComponentModel.DataAnnotations;

namespace CompanyPortal.Api.Contracts;

// «أرقام تهمك» and حالة المؤسسة texts (Mng.ImportantNumbers / Mng.StatusLevels). Lengths match the SQL columns.
public sealed record ImportantNumber(int Id,string Title,string Number);
public sealed record ImportantNumberAdministration(int Id,string Title,string Number,int SortOrder,bool Active,DateTime LastChangeAt);
public sealed record StatusLevel(int ColorValue,string Color,string Title,string ColorName,string Summary,string? GuideText,string[] Actions);
public sealed record StatusLevelAdministration(int ColorValue,string Color,string Title,string ColorName,string Summary,string? GuideText,string? Actions,DateTime LastChangeAt);
public sealed record HeaderContentAdministration(ImportantNumberAdministration[] Numbers,StatusLevelAdministration[] Levels);

public sealed class SaveImportantNumberRequest
{
    [Required,StringLength(150,MinimumLength=1)] public string? Title { get; init; }
    [Required,StringLength(50,MinimumLength=1)] public string? Number { get; init; }
    [Range(0,100000)] public int SortOrder { get; init; }
    public bool Active { get; init; }
}

public sealed class SaveStatusLevelRequest
{
    [Required,StringLength(100,MinimumLength=1)] public string? Title { get; init; }
    [Required,StringLength(30,MinimumLength=1)] public string? ColorName { get; init; }
    [Required,StringLength(600,MinimumLength=1)] public string? Summary { get; init; }
    [StringLength(300)] public string? GuideText { get; init; }
    [StringLength(1500)] public string? Actions { get; init; }
}
