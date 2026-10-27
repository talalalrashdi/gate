using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class LegalDecisionsStore(IConfiguration configuration)
{
    public sealed record Row(long DecisionId,string DecisionType,string Title,DateTime PublishedAt,string PdfFileName)
    { public Row():this(0,string.Empty,string.Empty,default,string.Empty){} public string? DecisionNumber {get;set;} public bool HasRead {get;set;} public bool NoticeDismissed {get;set;} }
    public async Task<bool> MarkReadAsync(string name,long id,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        var user=await c.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername",new{Username=name},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(user is null)return false;
        var allowed=await c.QueryAsync<Row>(new CommandDefinition("Legal.Decisions_getForUser",new{UserId=user.Value,DecisionId=(long?)id},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(!allowed.Any(r=>r.DecisionId==id))return false;
        await c.ExecuteAsync(new CommandDefinition("Portal.UserReads_MarkRead",new{UserId=user.Value,ContentTypeID=2,ContentId=id.ToString(System.Globalization.CultureInfo.InvariantCulture)},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));return true;
    }

    public async Task<bool> DismissNoticeAsync(string name,long id,CancellationToken token)
    {
        await using var c=new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        var user=await c.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername",new{Username=name},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(user is null)return false;
        var allowed=await c.QueryAsync<Row>(new CommandDefinition("Legal.Decisions_getForUser",new{UserId=user.Value,DecisionId=(long?)id},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));
        if(!allowed.Any(r=>r.DecisionId==id))return false;
        await c.ExecuteAsync(new CommandDefinition("Portal.UserDecisionDismissals_Dismiss",new{UserId=user.Value,DecisionId=id,ChannelId=1},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token));return true;
    }

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
        var result=rows.ToArray();
        if(id is null){var read=(await connection.QueryAsync<string>(new CommandDefinition("Portal.UserReads_Get",new{UserId=userId.Value,ContentTypeID=2},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).ToHashSet(StringComparer.Ordinal);
        var dismissed=(await connection.QueryAsync<long>(new CommandDefinition("Portal.UserDecisionDismissals_Get",new{UserId=userId.Value,ChannelId=1},commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token))).ToHashSet();
        foreach(var row in result){row.HasRead=read.Contains(row.DecisionId.ToString(System.Globalization.CultureInfo.InvariantCulture));row.NoticeDismissed=dismissed.Contains(row.DecisionId);}}
        return result;
    }
}
