using CompanyPortal.Logging;
using Microsoft.AspNetCore.Authentication.Negotiate;
using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Mail;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddCentralErrorLogging();

builder.Services.AddControllers();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
    context.ProblemDetails.Extensions["reference"] = context.HttpContext.TraceIdentifier);
builder.Services.AddHealthChecks();
builder.Services.AddScoped<DatabaseConnectionCheck>();
builder.Services.AddScoped<UserSettingsStore>();
builder.Services.AddScoped<UserCardsStore>();
builder.Services.AddScoped<AdministrationStore>();
builder.Services.AddScoped<AdminChangesStore>();
builder.Services.AddScoped<ThemeAdministrationStore>();
builder.Services.AddScoped<InterfaceImagesStore>();
builder.Services.AddScoped<NewsStore>();
builder.Services.AddScoped<MagazinesStore>();
builder.Services.AddScoped<MagazineFiles>();
builder.Services.AddScoped<ProfileSummaryStore>();
builder.Services.AddScoped<FormsInboxStore>();
builder.Services.AddScoped<CorrespondenceInboxStore>();
builder.Services.AddScoped<TechnicalServicesStore>();
builder.Services.AddScoped<PortalMediaStore>();
builder.Services.AddScoped<PortalMediaFiles>();
builder.Services.AddDataProtection();
builder.Services.AddScoped<FixedOrdersStore>();
builder.Services.AddScoped<OrganizationStatusStore>();
builder.Services.AddScoped<HeaderContentStore>();
builder.Services.AddScoped<HeaderEventsStore>();
builder.Services.AddScoped<LegalDecisionsStore>();
builder.Services.AddScoped<DecisionNoticesStore>();
builder.Services.AddScoped<DocumentsStore>();
builder.Services.AddScoped<DocumentTabsStore>();
builder.Services.AddScoped<DocumentFiles>();
builder.Services.AddScoped<NewsFiles>();
builder.Services.AddScoped<FolderPathsStore>();
builder.Services.AddScoped<MailIdentityStore>();
builder.Services.AddScoped<MailSessionFactory>();
builder.Services.AddScoped<ScheduleService>();
builder.Services.AddSingleton<MailStreamLimits>();
builder.Services.AddCors(options => options.AddPolicy("Portal", policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    if (origins.Length > 0)
        policy.WithOrigins(origins).WithMethods("GET", "POST", "PUT", "DELETE")
            .WithHeaders("Content-Type", "X-CompanyPortal-Request").WithExposedHeaders("X-Reference-ID").AllowCredentials();
}));
builder.Services.AddAuthentication(NegotiateDefaults.AuthenticationScheme)
    .AddNegotiate();
builder.Services.AddAuthorization(options =>
{
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "CompanyPortal API",
        Version = "v1",
        Description = "Windows authentication uses your current account. No bearer token is required."
    });
});

var app = builder.Build();
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() => { context.Response.Headers["X-Reference-ID"] = context.TraceIdentifier; return Task.CompletedTask; });
    await next(context);
});

app.UseExceptionHandler();
// Inside exception handling so confirmed client cancellations are handled before it logs an error.
app.UseMiddleware<CompanyPortal.Api.Infrastructure.RequestCancellationMiddleware>();
app.UseStatusCodePages();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseRouting();
app.UseCors("Portal");
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        // Relative URL also works when IIS hosts the API beneath a virtual path.
        options.SwaggerEndpoint("v1/swagger.json", "CompanyPortal API v1");
        options.ConfigObject.AdditionalItems["validatorUrl"] = null;
    });
}

app.MapControllers();

app.Run();
