using CompanyPortal.Logging;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddCentralErrorLogging();

builder.Services.AddControllersWithViews();
builder.Services.AddHttpClient("CompanyPortalApi", (services, client) =>
{
    var address = services.GetRequiredService<IConfiguration>()["Api:BaseUrl"];
    if (string.IsNullOrWhiteSpace(address))
        throw new InvalidOperationException("Api:BaseUrl is not configured.");

    client.BaseAddress = new Uri(address.TrimEnd('/') + "/");
    client.Timeout = TimeSpan.FromSeconds(15);
})
.ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
{
    // Uses the MVC process/service identity; this does not delegate the visitor's identity.
    UseDefaultCredentials = true,
    AllowAutoRedirect = false,
    UseCookies = false
});

var app = builder.Build();
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() => { context.Response.Headers["X-Reference-ID"] = context.TraceIdentifier; return Task.CompletedTask; });
    await next(context);
});

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}

// PDF.js (wwwroot/vendor/pdfjs) needs its ES module, packed character maps and Type1 standard fonts served.
var contentTypes = new Microsoft.AspNetCore.StaticFiles.FileExtensionContentTypeProvider();
contentTypes.Mappings[".mjs"] = "text/javascript";
contentTypes.Mappings[".bcmap"] = "application/octet-stream";
contentTypes.Mappings[".pfb"] = "application/octet-stream";
app.UseStaticFiles(new StaticFileOptions { ContentTypeProvider = contentTypes });
// Browser error pages preserve status codes; JSON/fetch responses keep their own contract.
app.UseWhen(context=>context.Request.Headers.Accept.Any(value=>value?.Contains("text/html",StringComparison.OrdinalIgnoreCase)==true)
    ||context.Request.Headers.Accept.Count==0,branch=>branch.UseStatusCodePagesWithReExecute("/errors/{0}"));
app.UseRouting();
app.MapControllers();

app.Run();
