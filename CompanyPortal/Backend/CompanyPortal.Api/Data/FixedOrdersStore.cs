using System.Data;
using System.Globalization;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class FixedOrdersStore(IConfiguration configuration)
{
    private sealed record Row(long FixedOrderID,DateTime? Timestamp,DateTime? Timestamp2,
        string? ContentBefor,string? ContentAfter,string? ContentText,int TimestampType);

    public async Task<IReadOnlyList<FixedOrder>?> GetAsync(string ntName,CancellationToken token)
    {
        await using var connection=new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
        await connection.OpenAsync(token);
        var userId=await connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new {Username=ntName},token));
        if(userId is null)return null;
        var rows=await connection.QueryAsync<Row>(Command("Portal.FixedOrders_getAll",null,token));
        return Map(rows);
    }

    public async Task<IReadOnlyList<FixedOrder>> GetForAdministrationAsync(CancellationToken token)
    {
        await using var connection=new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ??throw new InvalidOperationException("CompanyPortal connection string is missing."));
        return Map(await connection.QueryAsync<Row>(Command("Portal.FixedOrders_getAll",null,token)));
    }

    public async Task<long> SaveAsync(long? id,SaveFixedOrderRequest request,CancellationToken token)
    {
        await using var connection=new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ??throw new InvalidOperationException("CompanyPortal connection string is missing."));
        var parameters=new DynamicParameters(new {
            FixedOrderID=id,
            ContentBefor=string.IsNullOrWhiteSpace(request.ContentBefor)?null:request.ContentBefor,
            request.ContentAfter,request.ContentText,TimestampType=request.TimestampType!.Value});
        parameters.Add("Timestamp",request.Timestamp?.ToDateTime(TimeOnly.MinValue),DbType.Date);
        parameters.Add("Timestamp2",request.Timestamp2?.ToDateTime(TimeOnly.MinValue),DbType.Date);
        return await connection.QuerySingleAsync<long>(Command("Portal.FixedOrders_Save",parameters,token));
    }

    private static FixedOrder[] Map(IEnumerable<Row> rows)=>rows.Select(row=>new FixedOrder(row.FixedOrderID.ToString(CultureInfo.InvariantCulture),
        row.Timestamp?.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture),row.Timestamp2?.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture),
        row.ContentBefor,row.ContentAfter,row.ContentText,row.TimestampType,row.Timestamp?.Year)).ToArray();

    private static CommandDefinition Command(string name,object? parameters,CancellationToken token)=>
        new(name,parameters,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
}
