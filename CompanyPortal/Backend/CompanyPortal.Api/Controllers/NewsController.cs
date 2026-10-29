using System.ComponentModel.DataAnnotations;
using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/news")]
public sealed class NewsController(NewsStore news, NewsFiles files, ILogger<NewsController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<NewsPage>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get([Range(1,1000000)] int page = 1, [Range(1,50)] int pageSize = 8, bool includeHeadlines = false, CancellationToken token = default) => Execute(async () =>
    {
        var today = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(4)).Date;
        var result = await news.GetAsync(page, pageSize, null, token, today);
        IReadOnlyList<NewsItem>? headlines = null;
        if (includeHeadlines)
        {
            headlines = (await news.GetAsync(1, 5, null, token, today)).Items.Select(ToItem).ToArray();
        }
        return Ok(new NewsPage(result.Items.Select(ToItem).ToArray(), page, pageSize, result.Total) { Headlines = headlines });
    }, token);

    private static NewsItem ToItem(NewsStore.Row row) => new(row.NewsId, row.PublishedAt,
        row.Subject ?? "", row.IsImportant, row.PicturePath is not null, row.PdfPath is not null, row.AttachmentConflict);

    [HttpGet("{id:long:min(1)}/pdf")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public Task<IActionResult> Pdf(long id, CancellationToken token) => ReadFile(id, true, token);

    [HttpGet("{id:long:min(1)}/picture")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public Task<IActionResult> Picture(long id, CancellationToken token) => ReadFile(id, false, token);

    private Task<IActionResult> ReadFile(long id, bool pdf, CancellationToken token) => Execute(async () =>
    {
        // Always recheck current publication/attachment flags, even for a previously listed ID.
        var row = (await news.GetAsync(1, 1, id, token)).Items.SingleOrDefault();
        if (row is null) return NotFound();
        if (pdf && row.AttachmentConflict)
        {
            logger.LogWarning("News {NewsId} has multiple active PDF paths.", id);
            return Problem(statusCode: 409, title: "News attachment data is inconsistent.");
        }
        var path = pdf ? row.PdfPath : row.PicturePath;
        if (path is null) return NotFound();
        var opened = await files.OpenAsync(path, pdf, token);
        if (opened is null) return NotFound();
        Response.Headers.XContentTypeOptions = "nosniff";
        if (pdf) Response.Headers.ContentDisposition = $"inline; filename=\"news-{id}.pdf\"";
        return File(opened.Value.Stream, opened.Value.ContentType, enableRangeProcessing: true);
    }, token);

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action, CancellationToken token)
    {
        Response.Headers.CacheControl = "private, no-store";
        var account = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length > 512) return Unauthorized();
        try
        {
            if (!await news.IsPortalUserAsync(account, token)) return Forbid();
            return await action();
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        {
            logger.LogError(exception, "News read failed.");
            return Problem(statusCode: 503, title: "News is temporarily unavailable.");
        }
    }
}
