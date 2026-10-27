using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Infrastructure;

/// <summary>
/// Shared administration gate. Resolves the Windows account through Portal.AdminAccess_get (one round trip,
/// no cache, so revocation applies on the next request) and requires any one of <paramref name="sections"/>.
/// Writes (anything but GET/HEAD) also need X-CompanyPortal-Request = <paramref name="requestHeader"/> and an
/// allowed Origin. Runs before model binding. Section-specific SQL errors stay in each controller.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class AdminSectionAttribute(string requestHeader, params string[] sections) : Attribute, IAsyncAuthorizationFilter
{
    /// <summary>Applies this attribute only under this path (one controller serving two sections).</summary>
    public string? Path { get; init; }

    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var http = context.HttpContext;
        if (Path is not null && !http.Request.Path.StartsWithSegments(Path)) return;
        http.Response.Headers.CacheControl = "private, no-store";
        var account = http.User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account) || account.Length > 512) { context.Result = new UnauthorizedResult(); return; }
        AdminAccess access;
        try { access = await http.GetAdminAccessAsync(); }
        catch (Exception error) when (error is SqlException or InvalidOperationException)
        {
            http.RequestServices.GetRequiredService<ILogger<AdminSectionAttribute>>().LogError(error, "Administration access lookup failed.");
            context.Result = Problem(http, 503, "Portal administration is temporarily unavailable."); return;
        }
        if (!sections.Any(access.CanManage)) { context.Result = new ForbidResult(); return; }
        if (HttpMethods.IsGet(http.Request.Method) || HttpMethods.IsHead(http.Request.Method)) return;
        if (http.Request.Headers["X-CompanyPortal-Request"] != requestHeader) { context.Result = Problem(http, 400, $"Missing {requestHeader} request header."); return; }
        if (!AllowedOrigin(http)) context.Result = Problem(http, 403, "Origin is not permitted.");
    }

    public static bool AllowedOrigin(HttpContext http)
    {
        var origin = http.Request.Headers.Origin.ToString();
        var allowed = http.RequestServices.GetRequiredService<IConfiguration>().GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        return origin.Length == 0 || origin == $"{http.Request.Scheme}://{http.Request.Host}" || allowed.Contains(origin, StringComparer.Ordinal);
    }

    private static ObjectResult Problem(HttpContext http, int status, string title) =>
        new(http.RequestServices.GetRequiredService<ProblemDetailsFactory>().CreateProblemDetails(http, status, title)) { StatusCode = status };
}

public static class AdminAccessHttpExtensions
{
    /// <summary>The current account's admin access, looked up once per request.</summary>
    public static async Task<AdminAccess> GetAdminAccessAsync(this HttpContext http)
    {
        if (http.Items[typeof(AdminAccess)] is AdminAccess cached) return cached;
        var access = await http.RequestServices.GetRequiredService<AdministrationStore>()
            .GetAccessAsync(http.User.Identity!.Name!, http.RequestAborted);
        http.Items[typeof(AdminAccess)] = access;
        return access;
    }
}
