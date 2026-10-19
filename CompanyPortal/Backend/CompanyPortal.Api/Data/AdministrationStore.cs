using System.Data;
using CompanyPortal.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class AdministrationStore(IConfiguration configuration)
{
    public async Task<bool> IsAdminAsync(string ntName, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        var userId = await connection.QuerySingleOrDefaultAsync<int?>(Command("Security.User_getByUsername", new { Username = ntName }, token));
        if (userId is null) return false;
        var roles = await connection.QueryAsync<string>(Command("Security.UserRoles_get", new { UserId = userId.Value }, token));
        return roles.Contains("CompanyPortal.Admin", StringComparer.Ordinal);
    }

    public async Task<IReadOnlyList<MasterCard>> GetCardsAsync(CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        return (await connection.QueryAsync<MasterCard>(Command("Master.Cards_get", null, token))).AsList();
    }

    public async Task SaveCardAsync(int id, SaveMasterCardRequest request, CancellationToken token)
    {
        await using var connection = Connection();
        await connection.OpenAsync(token);
        await connection.ExecuteAsync(Command("Master.Cards_save", new { CardId = id, CardName = request.CardName.Trim(), request.IsFixed, request.DisplayOrder }, token));
    }

    private SqlConnection Connection() => new(configuration.GetConnectionString("CompanyPortal")
        ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
    private static CommandDefinition Command(string name, object? parameters, CancellationToken token) =>
        new(name, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token);
}
