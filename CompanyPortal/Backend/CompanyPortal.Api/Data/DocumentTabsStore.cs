using System.Data;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.ComponentModel.DataAnnotations;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class DocumentTabsStore(IConfiguration configuration)
{
    public sealed record Tab(int DocumentTabID,string TabName,int FolderID,int DisplayOrder,DateTime LastChangeAt,bool Active);
    public sealed record Item(int DocumentTabID,Guid DocumentID);
    public sealed record Catalog(IReadOnlyList<Tab> Tabs,IReadOnlyList<Item> Items);
    [JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
    public sealed record SaveRequest([Required,StringLength(200,MinimumLength=1)] string TabName,
        int FolderId,[Range(0,int.MaxValue)] int DisplayOrder,bool Active,
        [Required,MinLength(1),MaxLength(500)] Guid[] DocumentIds);
    private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")
        ??throw new InvalidOperationException("CompanyPortal connection string is missing."));
    public async Task<Catalog> GetAsync(bool includeHidden,CancellationToken token,string sectionKey="documents")
    {
        await using var connection=Connection();
        using var results=await connection.QueryMultipleAsync(new CommandDefinition("Portal.DocumentTabs_Get",
            new {IncludeHidden=includeHidden,SectionKey=sectionKey},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        return new((await results.ReadAsync<Tab>()).ToArray(),(await results.ReadAsync<Item>()).ToArray());
    }
    public async Task<int> SaveAsync(int? id,SaveRequest request,string changedBy,CancellationToken token,string sectionKey="documents")
    {
        await using var connection=Connection();
        return await connection.QuerySingleAsync<int>(new CommandDefinition("Portal.DocumentTabs_Save",
            new {SectionKey=sectionKey,DocumentTabID=id,TabName=request.TabName.Trim(),request.FolderId,request.DisplayOrder,request.Active,
                DocumentIds=JsonSerializer.Serialize(request.DocumentIds),ChangedBy=changedBy},commandType:CommandType.StoredProcedure,
            commandTimeout:15,cancellationToken:token));
    }
    public static bool IsPdf(DocumentsStore.Row row)=>string.Equals(Path.GetExtension(row.DocumentPath),".pdf",StringComparison.OrdinalIgnoreCase);
}
