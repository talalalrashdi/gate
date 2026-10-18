using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class DatabaseConnectionCheck(IConfiguration configuration)
{
    public async Task<string> GetDatabaseNameAsync(CancellationToken cancellationToken)
    {
        var connectionString = configuration.GetConnectionString("CompanyPortal");
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("ConnectionStrings:CompanyPortal is not configured.");

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        // A real read-only query proves SQL access without creating application tables.
        return await connection.QuerySingleAsync<string>(new CommandDefinition(
            "SELECT DB_NAME();", commandTimeout: 5, cancellationToken: cancellationToken));
    }
}
