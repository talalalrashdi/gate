using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class AdminChangesStore(IConfiguration configuration)
{
    public class Change
    {
        public string Section { get; set; } = "";
        public string ItemType { get; set; } = "";
        public string ItemId { get; set; } = "";
        public string? ItemTitle { get; set; }
        public string Action { get; set; } = "";
        public DateTime ChangedAt { get; set; }
        public string ChangedBy { get; set; } = "";
        public string DisplayName { get; set; } = "";
        public string ChangeId { get; set; } = "";
    }
    private static CommandDefinition Command(string sp, object args, CancellationToken token) =>
        new(sp, args, commandType: CommandType.StoredProcedure, commandTimeout: 15, cancellationToken: token);

    public async Task<Change[]> GetAsync(string[] sections, string? section, CancellationToken token)
    {
        await using var c = new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        var rows = (await c.QueryAsync<Change>(section is null
            ? Command("Portal.AdminChanges_GetRecent", new { Top = 10, SectionsJson = JsonSerializer.Serialize(sections) }, token)
            : Command("Portal.AdminChanges_GetLatestByItem", new { Section = section }, token))).ToArray();
        if (section is not null) foreach (var row in rows) row.Section = section;
        if (rows.Length == 0) return rows;
        var authors = (await c.QueryAsync<Author>(Command("Portal.AdminAuthors_Get",
            new { NamesJson = JsonSerializer.Serialize(rows.Select(r => r.ChangedBy).Distinct()) }, token)))
            .ToDictionary(a => a.ChangedBy, a => a.DisplayName, StringComparer.OrdinalIgnoreCase);
        foreach (var row in rows) row.DisplayName = authors.GetValueOrDefault(row.ChangedBy, row.ChangedBy);
        return rows;
    }
    private sealed record Author(string ChangedBy, string DisplayName);

    public sealed class Detail : Change
    {
        public string? OldJson { get; set; }
        public string? NewJson { get; set; }
    }
    public async Task<object> SearchAsync(string? section,string? person,DateTime? from,DateTime? to,int page,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        using var sets=await c.QueryMultipleAsync(Command("Portal.AdminChanges_GetPage",new{Section=section,ChangedBy=person,FromAt=from,ToAt=to,Page=page,PageSize=25},token));
        var total=await sets.ReadSingleAsync<int>();var rows=(await sets.ReadAsync<Change>()).ToArray();
        // Dispose the multi-reader before issuing the author batch on this connection.
        sets.Dispose();await Authors(c,rows,token);
        return new{Total=total,Page=page,PageSize=25,Items=rows};
    }
    public async Task<Detail?> DetailAsync(long id,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        var row=await c.QuerySingleOrDefaultAsync<Detail>(Command("Portal.AdminChanges_GetById",new{AdminChangeId=id},token));
        if(row is not null)await Authors(c,[row],token);return row;
    }
    private static async Task Authors(SqlConnection c,Change[] rows,CancellationToken token)
    {
        if(rows.Length==0)return;
        var authors=(await c.QueryAsync<Author>(Command("Portal.AdminAuthors_Get",new{NamesJson=JsonSerializer.Serialize(rows.Select(r=>r.ChangedBy).Distinct())},token)))
            .ToDictionary(a=>a.ChangedBy,a=>a.DisplayName,StringComparer.OrdinalIgnoreCase);
        foreach(var row in rows)row.DisplayName=authors.GetValueOrDefault(row.ChangedBy,row.ChangedBy);
    }
}
