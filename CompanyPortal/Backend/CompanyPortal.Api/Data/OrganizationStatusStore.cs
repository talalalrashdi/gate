using System.Data;
using System.Globalization;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class OrganizationStatusStore(IConfiguration configuration)
{
    private sealed record Row(int Id,byte ColorValue,DateTime LastUpdated,int? No);
    private static readonly string[] Colors=["green","yellow","orange","red"];

    public async Task<OrganizationStatus?> GetAsync(CancellationToken token)
    {
        await using var connection=new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ??throw new InvalidOperationException("CompanyPortal connection string is missing."));
        var row=await connection.QuerySingleOrDefaultAsync<Row>(new CommandDefinition("Mng.CurrentStatus_get",
            commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(row is null)return null;
        if(row.ColorValue is <1 or >4)throw new InvalidOperationException($"Unknown organization status ColorValue {row.ColorValue}.");
        return new OrganizationStatus(row.ColorValue,Colors[row.ColorValue-1],
            row.LastUpdated.ToString("yyyy-MM-dd'T'HH:mm:ss",CultureInfo.InvariantCulture),row.No);
    }
}
