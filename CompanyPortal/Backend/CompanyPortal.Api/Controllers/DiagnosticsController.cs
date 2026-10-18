using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/diagnostics")]
public sealed class DiagnosticsController(
    DatabaseConnectionCheck database,
    IWebHostEnvironment environment,
    ILogger<DiagnosticsController> logger) : ControllerBase
{
    [HttpGet("database")]
    [ProducesResponseType<DatabaseConnectionResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<DatabaseConnectionResponse>> Database(CancellationToken cancellationToken)
    {
        if (!environment.IsDevelopment()) return NotFound();
        Response.Headers.CacheControl = "no-store";

        try
        {
            var name = await database.GetDatabaseNameAsync(cancellationToken);
            return Ok(new DatabaseConnectionResponse("Connected", name, DateTimeOffset.UtcNow));
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException or ArgumentException)
        {
            logger.LogError(exception, "Database connection check failed.");
            return Problem(statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Database connection check failed.",
                detail: "Check the API database configuration and SQL Server access. See server logs for details.");
        }
    }
}
