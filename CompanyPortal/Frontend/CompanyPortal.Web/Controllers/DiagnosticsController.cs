using System.Text.Json;
using CompanyPortal.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace CompanyPortal.Web.Controllers;

public sealed class DiagnosticsController(
    IHttpClientFactory clients,
    IWebHostEnvironment environment,
    ILogger<DiagnosticsController> logger) : Controller
{
    [HttpGet("/diagnostics/connection")]
    public async Task<IActionResult> Connection(CancellationToken cancellationToken)
    {
        if (!environment.IsDevelopment()) return NotFound();
        Response.Headers.CacheControl = "no-store";

        try
        {
            var client = clients.CreateClient("CompanyPortalApi");
            using var response = await client.GetAsync("api/diagnostics/database", cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result(new(response.StatusCode == System.Net.HttpStatusCode.ServiceUnavailable,
                    false, null, null,
                    $"تعذر إتمام فحص الاتصال. أعادت واجهة API الحالة {(int)response.StatusCode}."));
            }

            var data = await response.Content.ReadFromJsonAsync<DatabaseConnectionResponse>(cancellationToken);
            if (data is null || data.Status != "Connected" || string.IsNullOrWhiteSpace(data.DatabaseName))
                throw new JsonException("Unexpected database check response.");

            return Result(new(true, true, data.DatabaseName, data.CheckedAtUtc, null));
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Result(new(false, false, null, null, "انتهت مهلة الاتصال بواجهة API."));
        }
        catch (Exception exception) when (exception is HttpRequestException or JsonException or InvalidOperationException)
        {
            logger.LogError(exception, "Frontend-to-API connection check failed.");
            return Result(new(false, false, null, null, "تعذر الاتصال بواجهة API. تحقق من تشغيلها وإعدادات الاتصال."));
        }
    }

    private IActionResult Result(ConnectionCheckViewModel model)
    {
        Response.StatusCode = model.DatabaseConnected ? StatusCodes.Status200OK : StatusCodes.Status503ServiceUnavailable;
        return View("Connection", model);
    }
}
