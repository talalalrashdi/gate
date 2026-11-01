using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class HeaderContentStore(IConfiguration configuration)
{
    private sealed record LevelRow(byte ColorValue,string Title,string ColorName,string Summary,string? GuideText,string? Actions,DateTime LastChangeAt);
    private static readonly string[] Colors=["green","yellow","orange","red"];

    public async Task<ImportantNumber[]> GetNumbersAsync(CancellationToken token)
    {
        await using var c=Connection();
        return (await c.QueryAsync<ImportantNumber>(Command("Mng.ImportantNumbers_GetActive",null,token))).ToArray();
    }

    public async Task<StatusLevel[]> GetLevelsAsync(CancellationToken token)=>
        (await Levels(token)).Select(r=>new StatusLevel(r.ColorValue,Colors[r.ColorValue-1],r.Title,r.ColorName,r.Summary,r.GuideText,Steps(r.Actions))).ToArray();

    public async Task<HeaderContentAdministration> GetForAdministrationAsync(CancellationToken token,bool includeNumbers=true,bool includeLevels=true)
    {
        await using var c=Connection();
        var numbers=includeNumbers?(await c.QueryAsync<ImportantNumberAdministration>(Command("Mng.ImportantNumbers_GetAll",null,token))).ToArray():[];
        var levels=includeLevels?(await Levels(token)).Select(r=>new StatusLevelAdministration(r.ColorValue,Colors[r.ColorValue-1],r.Title,r.ColorName,r.Summary,r.GuideText,r.Actions,r.LastChangeAt)).ToArray():[];
        return new(numbers,levels);
    }

    public async Task<int> SaveNumberAsync(int? id,SaveImportantNumberRequest request,string changedBy,CancellationToken token)
    {
        await using var c=Connection();
        return await c.QuerySingleAsync<int>(Command("Mng.ImportantNumbers_Save",
            new {Id=id,request.Title,request.Number,request.SortOrder,request.Active,ChangedBy=changedBy},token));
    }

    public async Task DeleteNumberAsync(int id,string changedBy,CancellationToken token)
    {
        await using var c=Connection();
        await c.ExecuteAsync(Command("Mng.ImportantNumbers_Delete",new {Id=id,ChangedBy=changedBy},token));
    }

    public async Task SaveLevelAsync(int colorValue,SaveStatusLevelRequest request,string changedBy,CancellationToken token)
    {
        await using var c=Connection();
        await c.ExecuteAsync(Command("Mng.StatusLevels_Save",
            new {ColorValue=(byte)colorValue,request.Title,request.ColorName,request.Summary,request.GuideText,Actions=string.Join('\n',Steps(request.Actions)),ChangedBy=changedBy},token));
    }

    public sealed record CurrentRow(int Id,byte ColorValue,DateTime LastUpdated,string? ChangedBy,int? UserId);
    public sealed record ChangeRow(long AdminChangeId,DateTime ChangedAt,string ChangedBy,int? StatusId,int? FromColorValue,string? FromTitle,int? ToColorValue,string? ToTitle);
    private sealed record Author(string ChangedBy,string DisplayName);
    public async Task<object> CurrentAsync(CancellationToken token)
    {
        await using var c=Connection();
        using var data=await c.QueryMultipleAsync(Command("Mng.CurrentStatus_AdminGet",null,token));
        var current=await data.ReadSingleOrDefaultAsync<CurrentRow>();var history=(await data.ReadAsync<ChangeRow>()).ToArray();
        var names=history.Select(r=>r.ChangedBy).Concat(current?.ChangedBy is string name?[name]:Array.Empty<string>()).Distinct().ToArray();
        var authors=(await c.QueryAsync<Author>(Command("Portal.AdminAuthors_Get",new{NamesJson=System.Text.Json.JsonSerializer.Serialize(names)},token))).ToDictionary(r=>r.ChangedBy,r=>r.DisplayName);
        string? Who(string? account)=>account is null?null:authors.GetValueOrDefault(account,account);
        return new{current=current is null?null:new{current.Id,current.ColorValue,lastUpdated=DecisionNoticesStore.Oman(current.LastUpdated),current.ChangedBy,current.UserId,displayName=Who(current.ChangedBy)},
            history=history.Select(r=>new{changeId=r.AdminChangeId.ToString(System.Globalization.CultureInfo.InvariantCulture),changedAt=DecisionNoticesStore.Oman(r.ChangedAt),r.ChangedBy,displayName=Who(r.ChangedBy),r.FromColorValue,r.FromTitle,r.ToColorValue,r.ToTitle})};
    }
    public async Task SetCurrentAsync(int colorValue,string changedBy,CancellationToken token)
    {await using var c=Connection();await c.ExecuteAsync(Command("Mng.CurrentStatus_Set",new{ColorValue=colorValue,ChangedBy=changedBy},token));}

    private async Task<LevelRow[]> Levels(CancellationToken token)
    {
        await using var c=Connection();
        var rows=(await c.QueryAsync<LevelRow>(Command("Mng.StatusLevels_GetAll",null,token))).ToArray();
        if(rows.Any(r=>r.ColorValue is <1 or >4))throw new InvalidOperationException("Unknown status level ColorValue.");
        return rows;
    }

    private static string[] Steps(string? actions)=>(actions??"").Replace("\r","").Split('\n',StringSplitOptions.RemoveEmptyEntries|StringSplitOptions.TrimEntries);
    private SqlConnection Connection()=>new(configuration.GetConnectionString("CompanyPortal")??throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string name,object? parameters,CancellationToken token)=>
        new(name,parameters,commandType:CommandType.StoredProcedure,commandTimeout:15,cancellationToken:token);
}
