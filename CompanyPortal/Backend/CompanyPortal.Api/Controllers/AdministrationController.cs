using CompanyPortal.Api.Contracts;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/admin/cards"), RequestSizeLimit(32768), AdminSection("admin-cards", "cards")]
public sealed class AdministrationController(AdministrationStore store, ILogger<AdministrationController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<MasterCard[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Get(CancellationToken token) => Execute(async () => Ok(await store.GetCardsAsync(token)));

    [HttpGet("applications")]
    [ProducesResponseType<AuthorizedApplication[]>(StatusCodes.Status200OK)]
    public Task<IActionResult> Applications(CancellationToken token) => Execute(async () => Ok(await store.GetApplicationsAsync(token)));

    [HttpPost, Consumes("application/json")]
    [ProducesResponseType<MasterCardIdentity>(StatusCodes.Status201Created)]
    public Task<IActionResult> Create(SaveMasterCardRequest request, CancellationToken token) => Execute(async () =>
    {
        var id = await store.SaveCardAsync(null,request,User.Identity!.Name!,token);
        return StatusCode(StatusCodes.Status201Created,new MasterCardIdentity(id));
    });

    [HttpPut("{id:int:min(1)}"), Consumes("application/json")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public Task<IActionResult> Save(int id, SaveMasterCardRequest request, CancellationToken token) => Execute(async () =>
    {
        await store.SaveCardAsync(id, request, User.Identity!.Name!, token);
        return NoContent();
    });

    private async Task<IActionResult> Execute(Func<Task<IActionResult>> action)
    {
        try
        {
            return await action();
        }
        catch (SqlException exception) when (exception.Number == 50006)
        {
            return Problem(statusCode: 400, title: "Check the active card, name and position. Another fixed card may occupy that position.");
        }
        catch (Exception exception) when (exception is SqlException or InvalidOperationException)
        {
            logger.LogError(exception, "Portal administration operation failed.");
            return Problem(statusCode: 503, title: "Portal administration is temporarily unavailable.");
        }
    }
}
