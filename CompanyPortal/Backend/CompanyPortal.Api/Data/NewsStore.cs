using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class NewsStore(IConfiguration configuration)
{
    public sealed record Row(long NewsId, DateTime? PublishedAt, string? Subject, bool IsImportant,
        string? PicturePath, string? PdfPath, bool AttachmentConflict);

    public async Task<bool> IsPortalUserAsync(string ntName, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        return await connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername", new { Username = ntName }, token)) is not null;
    }

    public async Task<(IReadOnlyList<Row> Items, int Total)> GetAsync(int page, int pageSize, long? newsId, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        using var results = await connection.QueryMultipleAsync(Command("News.Items_get", new { Page = page, PageSize = pageSize, NewsId = newsId }, token));
        return ((await results.ReadAsync<Row>()).AsList(), await results.ReadSingleAsync<int>());
    }

    private SqlConnection Connection() => new(configuration.GetConnectionString("CompanyPortal")
        ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string name, object parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 15, cancellationToken: token);
}
