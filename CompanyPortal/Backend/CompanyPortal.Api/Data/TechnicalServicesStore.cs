using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
namespace CompanyPortal.Api.Data;

public sealed class TechnicalServicesStore(IConfiguration configuration)
{
    public sealed record Option(int Id,string Name);
    public sealed record Category(int Id,string Name,bool RequiresRecipient);
    public sealed record ClassifiedOption(int Id,string Name,int CategoryId);
    public sealed record Catalog(Option[] AssignmentRecipients,Category[] ReportCategories,ClassifiedOption[] ReportRecipients,ClassifiedOption[] ReportTypes,Option[] InitiativeTypes);
    private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal"));
    private static CommandDefinition Command(string sp,object args,CancellationToken token)=>new(sp,args,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
    public async Task<int?> UserAsync(string name,CancellationToken token)
    {await using var c=Connection();return await c.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername",new{Username=name},token));}
    public async Task<Catalog> CatalogAsync(int user,CancellationToken token)
    {
        await using var c=Connection();var args=new{UserId=user};
        var assignment=(await c.QueryAsync<Option>(Command("Portal.Isnad_Recipients_Get",args,token))).ToArray();
        var categories=(await c.QueryAsync<Category>(Command("Portal.Reports_Categories_Get",args,token))).ToArray();
        var recipients=(await c.QueryAsync<ClassifiedOption>(Command("Portal.Reports_Recipients_Get",args,token))).ToArray();
        var types=(await c.QueryAsync<ClassifiedOption>(Command("Portal.Reports_Types_Get",args,token))).ToArray();
        var initiatives=(await c.QueryAsync<Option>(Command("Portal.Initiatives_Types_Get",args,token))).ToArray();
        return new(assignment,categories,recipients,types,initiatives);
    }
    public async Task<long> CreateAsync(string kind,int user,CompanyPortal.Api.Contracts.TechnicalServiceRequest r,CancellationToken token)
    {
        var args=new DynamicParameters();args.Add("UserId",user);args.Add("Details",r.Details.Trim());args.Add("RequestKey",r.RequestKey);
        if(kind=="assignment"){args.Add("RecipientId",r.RecipientId);args.Add("OfficeNumber",r.OfficeNumber?.Trim());args.Add("DocumentNumber",r.DocumentNumber?.Trim());}
        else{args.Add("TypeId",r.TypeId);args.Add("Title",r.Title?.Trim());if(kind=="report"){args.Add("CategoryId",r.CategoryId);args.Add("RecipientId",r.RecipientId);}}
        var sp=kind switch{"assignment"=>"Portal.Isnad_Create","report"=>"Portal.Reports_Create",_=>"Portal.Initiatives_Create"};
        await using var c=Connection();return await c.QuerySingleAsync<long>(Command(sp,args,token));
    }
}
