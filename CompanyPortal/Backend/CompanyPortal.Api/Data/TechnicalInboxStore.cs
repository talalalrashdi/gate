using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class TechnicalInboxStore(IConfiguration configuration)
{
    public sealed record Row(long TechnicalInboxId,string RequestType,string? DocumentNumber,string? OfficeNumber,string Details,bool HasAttachment,DateTime ReceivedAt,bool IsOpened);
    public sealed record Inbox(Row[] Items,int UnreadCount);
    public async Task<Inbox?> GetAsync(string name,bool countOnly,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        CommandDefinition Command(string sp,object args)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
        var user=await c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=name}));
        if(user is null)return null;
        var args=new{UserId=user.Value};
        var items=countOnly?Array.Empty<Row>():(await c.QueryAsync<Row>(Command("Portal.Isnad_Inbox_Get",args))).ToArray();
        var count=await c.QuerySingleAsync<int>(Command("Portal.Isnad_UnreadCount_Get",args));
        return new(items,Math.Max(0,count));
    }
}
