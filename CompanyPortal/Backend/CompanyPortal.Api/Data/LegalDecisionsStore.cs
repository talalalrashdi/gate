using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class LegalDecisionsStore(IConfiguration configuration)
{
    public sealed record Row(long DecisionId,string DecisionType,string Title,DateTime PublishedAt,string PdfFileName);

    public async Task<IReadOnlyList<Row>?> GetAsync(string ntName,long? id,CancellationToken token)
    {
        await using var connection=new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
        await connection.OpenAsync(token);
        var userId=await connection.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername",
            new {Username=ntName},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(userId is null)return null;
        var rows=await connection.QueryAsync<Row>(new CommandDefinition("Legal.Decisions_getForUser",
            new {UserId=userId.Value,DecisionId=id},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        return rows.ToArray();
    }
}
