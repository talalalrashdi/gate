using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class FormsInboxStore(IConfiguration configuration)
{
    public sealed class Row
    {
        public long FormId { get; init; }
        public string Title { get; init; } = "";
        public string SenderName { get; init; } = "";
        public DateTime SentAt { get; init; }
        public bool IsOpened { get; init; }
        public bool IsSample { get; init; }
        // Older source adapters may omit Purpose until they are mapped internally.
        public string Purpose { get; init; } = "للعلم";
    }
    public sealed record Inbox(Row[] Items,int UnreadCount);
    public async Task<Inbox?> GetAsync(string name,long? id,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        CommandDefinition Command(string sp,object args)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
        var user=await c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=name}));
        if(user is null)return null;
        var items=(await c.QueryAsync<Row>(Command("Portal.Forms_Inbox_Get",new{UserId=user.Value,FormId=id}))).ToArray();
        var count=await c.QuerySingleAsync<int>(Command("Portal.Forms_UnreadCount_Get",new{UserId=user.Value}));
        return new(items,Math.Max(0,count));
    }
}
