using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Data;

public sealed class FolderPathsStore(IConfiguration configuration)
{
    private sealed record FolderPath(string Key, string Path);

    public async Task<IReadOnlyList<string>> GetAsync(string key, CancellationToken token)
    {
        await using var connection = new SqlConnection(configuration.GetConnectionString("CompanyPortal")
            ?? throw new InvalidOperationException("CompanyPortal connection string is missing."));
        await connection.OpenAsync(token);
        var rows = await connection.QueryAsync<FolderPath>(new CommandDefinition("Mstr.Utls_GetFolderPaths",
            commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token));
        var roots = rows.Where(row => string.Equals(row.Key, key, StringComparison.OrdinalIgnoreCase))
            .Select(row => row.Path?.Trim() ?? "").ToArray();
        if (roots.Length == 0 || roots.Any(root => string.IsNullOrWhiteSpace(root) || !Path.IsPathFullyQualified(root)))
            throw new InvalidOperationException("Configure active absolute folder paths for " + key + " in Mstr.Utls.");
        return roots;
    }
}
