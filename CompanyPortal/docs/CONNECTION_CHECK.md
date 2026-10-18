# Frontend → API → SQL connection check

This step verifies infrastructure only. No preferences, business tables, writes, browser data imports, Exchange calls or employee identity delegation are included.

## What happens

1. Open the MVC route `/diagnostics/connection`.
2. The MVC server calls `api/diagnostics/database` using its process's Windows credentials.
3. The API requires Windows authentication and opens SQL Server using its own configured database connection identity.
4. Dapper executes the read-only query `SELECT DB_NAME();` against that connection.
5. The MVC page displays connection status, the actual returned database name and the check time.

Both diagnostic routes are **Development only** and return 404 outside that environment (an unauthenticated API request can receive 401 first). The main portal design, sample business features and localStorage are unchanged. This check is reached through its explicit address, not a new portal menu item. The frontend receives API data over HTTP; it has no SQL package, connection string or reference to the backend project. `/health` remains a separate liveness-only check.

## Run locally

Start the API solution in one Visual Studio instance and the frontend solution in another, or use two terminals:

```powershell
# Terminal 1, from CompanyPortal/Backend
dotnet run --project CompanyPortal.Api
```

```powershell
# Terminal 2, from CompanyPortal/Frontend
dotnet run --project CompanyPortal.Web
```

Open `http://localhost:5080/diagnostics/connection`. The page should show API/database connected and `CompanyPortal` as the database name. The frontend launch profile can also use `127.0.0.1:5080`; the configured outgoing API address stays `localhost:5081` for Windows authentication.

In API Swagger, execute `GET /api/diagnostics/database` directly to isolate the API → SQL portion. Missing configuration, SQL login failures or unavailable SQL Server return HTTP 503 with a generic Problem Details response; internal SQL exception details remain in server logs. If the API is stopped, the MVC page shows a failure rather than an old success. Connection checks are not cached, and connect/query/HTTP timeouts are bounded.

From `Backend/`, with both applications running, use:

```powershell
powershell -File tools/Test-Connection.ps1
```

It checks anonymous API rejection, the real database query, Swagger discovery and the MVC result. Current Windows credentials are sent to the supplied API address; only use addresses you administer. The optional failure modes `-ExpectApiUnavailable` and `-ExpectDatabaseUnavailable` verify the corresponding deliberately arranged failure rather than causing one themselves.

## Configuration

| Application | Setting | Local value |
| --- | --- | --- |
| MVC frontend | `Api:BaseUrl` | `http://localhost:5081/` |
| API | `ConnectionStrings:CompanyPortal` | Default local SQL instance, CompanyPortal database, Windows integrated security |

Local defaults are in each application's `appsettings.Development.json`. No credentials/passwords are stored in source. The SQL development value encrypts the connection but allows the local self-signed server certificate. Use approved certificate validation for internal deployment. Environment overrides use `Api__BaseUrl` and `ConnectionStrings__CompanyPortal`. API URLs must include the application path if hosted beneath an IIS sub-application; a trailing slash is normalized by the MVC registration. Configure normal production URLs with HTTPS.

No database/schema creation occurs during this check. [Script 001](../Backend/Database/Scripts/001_CreateDatabase.sql) already created the empty local database. [Database deployment](../Backend/Database/README.md) explains using the same scripts on the internal SQL Server.

## Identity boundaries

This verifies two server/service connections, not forwarding the employee's identity. For local runs both applications normally run as the developer, so API authentication and SQL access use that account. Under IIS the MVC and API may run as different service identities; configure the API's Windows access and SQL grants accordingly. The current check neither impersonates visitors nor reads their account from a supplied header. It must not become the authorization basis for future employee-specific data.

Employee-specific requests and manager/secretary Exchange delegation still need an explicit identity design before those features are connected. No general-purpose API proxy or CORS policy is introduced here. To repeat the diagnostics on an internal server, use a controlled Development test deployment; production keeps these diagnostic routes disabled. That test deployment also enables Swagger, so keep its bindings/access limited appropriately.

## Dependencies and offline handoff

API data access uses Dapper 2.1.89 and Microsoft.Data.SqlClient 7.1.1. NuGet initially resolved an affected transitive System.Security.Cryptography.Pkcs 9.0.18; an explicit patched 10.0.13 reference resolves the restore warnings. The locked dependency graph and exported offline feed must be refreshed after these additions. The frontend still uses only the shared ASP.NET Core framework.

Run `Backend/tools/Export-OfflinePackages.ps1` after a successful connected restore/audit. Deliver its package bundle with the source for offline builds. Package versions and configuration are documented here so the internal test can use the same code rather than environment-specific source edits.

## Verification — 18 October 2026

- Both independent solutions built/published in Release with zero warnings/errors.
- The final published MVC page passed the complete Windows-authenticated API → Dapper → local SQL Server test and displayed `CompanyPortal` from the API response. Anonymous calls to the API diagnostic were rejected with 401; its Swagger operation was present.
- Stopping the API produced a frontend 503 failure instead of a cached success. A temporary configuration pointing at a nonexistent database produced generic API Problem Details and a frontend 503, without creating that database or exposing SQL exception details to the client.
- The main portal and diagnostic stylesheet returned HTTP 200. These were HTTP/rendered-markup checks, not a new full browser acceptance run.
- Both diagnostic routes returned 404 in Production. This was a localhost HTTP smoke check, not validation of actual IIS/HTTPS/domain deployment.
- All 25 resolved package archives were exported and a locked offline restore succeeded into a separate package directory using only that feed. The API then published from those restored packages.
- SQL still reports zero application tables. No preferences/business features, Exchange data or local browser storage were modified. Verification servers were stopped after checks.
