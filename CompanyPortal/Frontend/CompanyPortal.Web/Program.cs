var builder = WebApplication.CreateBuilder(args);

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

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();
app.MapControllers();

app.Run();
