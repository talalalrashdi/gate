namespace CompanyPortal.Api.Contracts;

public sealed record NewsItem(long NewsId, DateTime? PublishedAt, string Subject, bool IsImportant,
    bool HasPicture, bool HasPdf, bool AttachmentConflict);
public sealed record NewsPage(IReadOnlyList<NewsItem> Items, int Page, int PageSize, int TotalCount)
{
    [System.Text.Json.Serialization.JsonIgnore(Condition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull)]
    public IReadOnlyList<NewsItem>? Headlines { get; init; }
}
