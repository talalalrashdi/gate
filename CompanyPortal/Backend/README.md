# CompanyPortal API

Independent ASP.NET Core 10 controller-based API solution. Open `CompanyPortal.Backend.slnx` in Visual Studio 2026. Run .NET commands from this directory so `global.json` selects the same SDK feature band as the frontend.

## Run

```powershell
dotnet restore CompanyPortal.Backend.slnx --locked-mode
dotnet build CompanyPortal.Backend.slnx --no-restore
dotnet run --project CompanyPortal.Api
```

The default Project profile uses `http://localhost:5081` on loopback so the initial foundation runs without a development certificate. Open `http://localhost:5081/swagger`. The optional `CompanyPortal.Api (HTTPS)` profile uses `https://localhost:7081` and `http://localhost:5081`; first create/trust the local ASP.NET development certificate with `dotnet dev-certs https --trust`. Use HTTPS for normal development once configured and for production. The IIS Express profile enables Windows authentication and disables anonymous authentication.

| Address | Behavior |
| --- | --- |
| `/health` | Process liveness (`Healthy`), visible in Swagger; does not check SQL Server, Exchange, or AD availability |
| `/api/me` | Requires Windows authentication; returns account name, SID when supplied by Windows, and authentication type; response is not cached |
| `/api/diagnostics/database` | Development only; requires Windows authentication and queries the configured SQL database with Dapper |
| `/api/user-settings/theme` | Windows-authenticated GET/PUT for the employee's theme, resolved through the external security database |
| `/swagger` | Development only, Swagger UI; same-origin Windows authentication |
| `/swagger/v1/swagger.json` | Development only, generated Swagger document |

Authentication is required by default. The health endpoint explicitly allows anonymous access in the application; IIS can still require authentication before the request reaches it. Swagger middleware also sits behind the application authorization middleware. The browser must permit integrated authentication to the site's address. A prompt or HTTP 401 can occur if browser/domain policies do not allow automatic sign-in. `CompanyPortal.Api.http` documents requests but does not configure Windows credentials for an HTTP editor.

To check the signed-in account with PowerShell:

```powershell
Invoke-RestMethod http://localhost:5081/api/me -UseDefaultCredentials
```

The development machine can return a local Windows account; this does not prove production AD/domain sign-in. No password login, JWT issuer, fake user, client-supplied identity header, or directory lookup is implemented. SID/account name are identity diagnostics, not an employee profile or mailbox address.

## Small structure

With the API running locally, verify the foundation using Windows PowerShell:

```powershell
powershell -File tools/Test-Foundation.ps1
```

The script checks anonymous rejection, actual Windows identity, local Swagger assets, route errors and Problem Details. For a configured production IIS address use `-BaseUrl https://your-api-address -Production`. It sends current Windows credentials only to the supplied API address; use an address you administer. The local run does not prove AD delegation or Exchange access.

- `Controllers/`: HTTP endpoints.
- `Contracts/`: request/response records.
- `Program.cs`: dependency registration, errors, authentication and routes.

Add feature-specific data/services/integration classes when implementing real features. No empty repository/service layers, template WeatherForecast endpoints or sample business data are included. Built-in logging and Problem Details handle diagnostics/errors. Configure a retained log destination during IIS deployment; the application does not create its own file logging subsystem.

Windows authentication, Swagger, Dapper and Microsoft.Data.SqlClient are installed. The database access is currently a read-only connection check, not a business feature. EF Core and the Microsoft.AspNetCore.OpenApi generator are excluded. Swashbuckle uses the OpenAPI specification and its own Microsoft.OpenApi dependency internally. See the [connection check](../docs/CONNECTION_CHECK.md) for the MVC → API → SQL test and configuration.

## IIS

Publish independently of the MVC frontend:

```powershell
dotnet publish CompanyPortal.Api --configuration Release --no-restore --output artifacts/publish
```

Install the matching .NET 10 Hosting Bundle and IIS Windows Authentication feature. Create a separate application/app pool (No Managed Code); enable Windows Authentication, disable Anonymous Authentication, configure HTTPS and the approved host binding, and keep the environment `Production`. `launchSettings.json` configures local launch profiles only; it does not configure production IIS authentication. `/swagger` and its document are unavailable in Production. A Windows-authenticated request can verify their absence; an anonymous request can receive 401 from the authorization policy or IIS first.

No CORS policy is configured. A Development-only MVC connection check now calls the API using the MVC process/service identity; the two solutions remain independently buildable. Before employee-specific features are connected, choose the identity flow: a server-to-server request does not automatically forward the employee's Windows identity. Kerberos delegation and Exchange access require explicit infrastructure configuration; do not substitute the app-pool account for the employee or trust an account name supplied by the client. Mutating browser endpoints will also need an explicit CSRF protection strategy before introduction.

## Offline delivery

The frontend has no application NuGet packages; this API does. Copying source alone is insufficient for offline restore. `packages.lock.json` pins the full dependency graph. Complete a connected restore/audit first, then export all resolved packages:

```powershell
powershell -File tools/Export-OfflinePackages.ps1
```

Copy `Backend/artifacts/offline-feed` with the source handoff, or deliver it as a separate approved dependency bundle. On the disconnected machine with the selected SDK/reference packs installed:

```powershell
dotnet restore CompanyPortal.Backend.slnx --locked-mode --source artifacts/offline-feed --packages artifacts/offline-packages -p:NuGetAudit=false
dotnet build CompanyPortal.Backend.slnx --no-restore
```

`NuGetAudit=false` is only for that disconnected restore because vulnerability metadata requires a reachable audit service; it does not replace the connected audit. Repeat export/audit when dependencies change. Framework-dependent publish includes application libraries, but the destination still needs the ASP.NET Core runtime/Hosting Bundle. Publish for the intended architecture if using RID-specific or self-contained deployment later. Keep secrets out of source, exported packages and appsettings; configure future connection secrets through deployment configuration.

## Next steps

The first employee feature is [theme settings](../docs/THEME_SETTINGS.md), using external NTName → UserId lookup and `Portal.UserSettings`. Its local-only sample SecurityDB and internal mapping/permission requirements are documented there. After setup, run `powershell -File tools/Test-ThemeSettings.ps1` with Windows PowerShell and a registered test account. It saves/restores that account's theme; if no setting existed, it leaves a row containing the original default. Other preferences and Exchange integration remain separate steps.
