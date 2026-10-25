using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class DocumentsStore(IConfiguration configuration)
{
    public sealed record Row(Guid DocumentID,string DocumentName,string DocumentPath,int FolderID,int? ParentID,string FolderName,string FolderPath);

    public async Task<IReadOnlyList<Row>?> GetAsync(string ntName,CancellationToken token)
    {
        await using var connection=new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
        await connection.OpenAsync(token);
        var userId=await connection.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername",
            new {Username=ntName},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(userId is null)return null;
        var rows=await connection.QueryAsync<Row>(new CommandDefinition("Portal.Document_GetAll",new {UserId=userId.Value},
            commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        return rows.ToArray();
    }
}
