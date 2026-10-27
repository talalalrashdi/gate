using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class CorrespondenceInboxStore(IConfiguration configuration)
{
    public sealed class Row
    {
        public long CorrespondenceId { get; set; }
        public string DocNo { get; set; } = "";
        public string Title { get; set; } = "";
        public string Purpose { get; set; } = "";
        public string? SenderName { get; set; }
        public DateTime ReceivedAt { get; set; }
        public bool IsOpened { get; set; }
        public bool IsSample { get; set; }
    }
    public sealed record Inbox(Row[] Items,int UnreadCount);
    public async Task<Inbox?> GetAsync(string name,long? id,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        CommandDefinition Command(string sp,object args)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
        var user=await c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=name}));
        if(user is null)return null;
        var items=(await c.QueryAsync<Row>(Command("Portal.Correspondence_Inbox_Get",new{UserId=user.Value,CorrespondenceId=id}))).ToArray();
        var count=await c.QuerySingleAsync<int>(Command("Portal.Correspondence_UnreadCount_Get",new{UserId=user.Value}));
        return new(items,Math.Max(0,count));
    }
}
