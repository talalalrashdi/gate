using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Mail;

public sealed class MailIdentityStore(IConfiguration configuration)
{
    public async Task<string?> ResolveAsync(string account, CancellationToken token)
    {
        await using var connection = new SqlConnection(configuration.GetConnectionString("CompanyPortal"));
        await connection.OpenAsync(token);
        var userId = await connection.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername",
            new { Username = account }, commandType: CommandType.StoredProcedure, commandTimeout: 10, cancellationToken: token));
        if (userId is null) return null;
        var options = configuration.GetSection("Exchange").Get<MailOptions>() ?? new();
        options.Validate();
        return options.MailboxFor(account) ?? throw new InvalidOperationException("Configure the employee's mailbox mapping.");
    }
}
