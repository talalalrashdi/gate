# API foundation and agreed integration plan

Agreed and recorded: 18 October 2026. This is the next milestone after the MVC frontend. The user asked to proceed on the assumption that browser/IIS acceptance is complete; this assumption is not new evidence of execution of those deployment checks.

## Decisions

| Area | Decision |
| --- | --- |
| Structure | Separate `Backend/CompanyPortal.Backend.slnx`, one `CompanyPortal.Api` project; frontend solution stays separate under the same portable CompanyPortal folder |
| API | ASP.NET Core 10 controllers, small request/response contracts, built-in dependency injection/validation/logging and Problem Details |
| SQL | New SQL Server database named `CompanyPortal`; Dapper + Microsoft.Data.SqlClient for parameterized SQL; no Entity Framework Core |
| Database deployment | Reviewed, numbered SQL scripts kept with the backend; no automatic schema changes on API startup |
| API testing | Swagger UI and document generation through Swashbuckle; no Microsoft.AspNetCore.OpenApi generator or Scalar UI |
| Authentication | Employees use AD accounts through IIS Windows Authentication; no separate portal password store |
| Exchange data | Inbox, tasks and calendars use the same Exchange records employees see in Outlook |
| Shared calendars | Include manager/secretary scenarios; Exchange permissions remain authoritative |
| Notifications | Start with refresh/read operations; evaluate EWS subscriptions and SignalR for live browser updates later |

Swagger UI necessarily consumes an OpenAPI document; Swashbuckle's transitive Microsoft.OpenApi dependency is part of that tooling. This is distinct from selecting Microsoft's alternative ASP.NET Core OpenAPI generator, which the user declined.

## Exchange findings

The user reported build **15.2.2562.17**. Microsoft's build table identifies this as **Exchange Server Subscription Edition (SE) RTM**, released July 1, 2025. The feature table confirms EWS application support for Exchange Server SE.

The reported version identifies the product/base release; it is not a completed audit of installed security/hotfix updates. In particular, an AdminDisplayVersion result alone should not be used to certify the exact installed servicing level. The administrator can verify the installed ExSetup.exe file version against Microsoft's table.

EWS is the planned on-premises integration protocol. Do not assume Microsoft Graph cloud mailbox APIs are available on this air-gapped deployment. The EWS URL, enabled authentication, certificates, access policies and a .NET 10-compatible client approach are still unverified. No EWS client package has been selected or installed. No Exchange Online retirement schedule is being used to describe this local server.

Exchange remains authoritative for messages, Exchange tasks, appointments, recurring events, meeting invitations/cancellations, delegate rights and private-item visibility. SQL stores portal-specific preferences, pinned systems, groups and other future portal business data. Do not silently import browser tasks into Outlook, replace existing localStorage data, or create a second authoritative copy of Exchange tasks/calendar in SQL. Any future cache/synchronization needs explicit freshness, retention and conflict rules.

## Delegation and identity

A secretary must be able to select a manager's calendar and perform only the operations their actual Exchange permissions permit. Rights can differ for reading, creating, editing/deleting owned items versus all items, private items, and meeting handling on behalf of the owner. Do not infer rights from the job title, UI buttons, SQL role, calendar owner address, or successful Windows portal sign-in.

The API must authorize the requested calendar and operation on the server. Prefer an access arrangement where Exchange itself evaluates the employee/delegate's rights. If administrators choose an application/service identity or impersonation arrangement, it must be scoped and must not bypass the employee's effective rights; an unrestricted service account is not a shortcut to delegation. Authentication and authorization design must be validated before implementing those endpoints.

Windows authentication to IIS does not automatically delegate credentials to a separate API or Exchange. The frontend-to-API and API-to-Exchange identity paths, SPNs/Kerberos delegation if applicable, service identities and permitted mailbox scope remain explicit infrastructure decisions. No user passwords or identity headers will be accepted as a workaround. AD identity is not itself an SMTP address; mailbox mapping needs verification.

## Implemented foundation scope

- .NET 10 SDK selection and an independently buildable backend solution.
- Windows Negotiate authentication with authentication required by default, plus an explicitly protected `GET /api/me` diagnostic endpoint.
- Liveness-only `GET /health`, with no dependency checks yet.
- Swagger UI/document in Development, with bundled UI assets and external validation disabled; Windows authentication still applies.
- Built-in exception/status Problem Details, logging, IIS Express Windows-auth launch profile, local request examples, locked dependency graph and an offline package export helper.
- No database connection, tables, SQL execution, Dapper package, Exchange access, SignalR hub, frontend integration or invented feature scaffolding yet.

## Incremental next steps

1. Verify foundation build/startup/Swagger, anonymous rejection and Windows identity. Repeat AD sign-in on the actual domain/IIS address; local account sign-in is not domain acceptance.
2. Confirm SQL Server instance, database naming/access and application service identity. Review a minimal schema and initial numbered scripts before creating the new database. Install Dapper/SqlClient with the first real data feature.
3. Implement a portal-owned feature, such as preferences or pinned systems, from SQL through API to frontend. Tasks/calendar belong to Exchange and are not the initial SQL CRUD example.
4. With the Exchange administrator, verify EWS URL/authentication/certificate and a test employee mailbox. Verify a manager/secretary test calendar: read-only, create/edit/delete, denied actions, private items, recurrence and meeting updates/cancellations.
5. Add Exchange reads, then deliberate writes and frontend integration. Define CSRF protection for browser writes and settle CORS/same-origin hosting before connecting the clients. Keep Exchange permissions authoritative.
6. Add reliable notification delivery only after the basic integration works. EWS subscriptions need renewal/reconnect/reconciliation and throttling management; SignalR delivers updates to a connected browser, not to a closed portal by itself. Decide later whether background Exchange work requires a dedicated worker rather than an IIS process that may recycle or idle.

## Verification — 18 October 2026

- Connected restore succeeded with Negotiate 10.0.13 and Swashbuckle 10.2.3; the committed lock file records eight resolved packages including transitive dependencies.
- Release build and publish completed with zero warnings/errors. A subsequent build using the isolated offline package directory also passed.
- Exported all eight package archives and successfully performed a locked restore from that local-only feed into a fresh package directory with NuGet auditing disabled only for the disconnected check.
- The published app passed `tools/Test-Foundation.ps1` in Development and Production: liveness, anonymous Windows challenge, authenticated Windows identity and no-store header, Swagger UI/document/assets in Development and absence in Production, authenticated 404, and 405 Problem Details.
- Checks used Kestrel on localhost with the machine's current Windows credentials; account details were not exported. Domain/IIS authentication, delegation, SQL connectivity and Exchange access remain untested.
- No usable local development HTTPS certificate was available. HTTPS startup correctly failed without a certificate; HTTP loopback was used for the runtime checks. The default launch profile therefore uses HTTP loopback, with a separate HTTPS profile and certificate setup instructions. The Production smoke check verified environment behavior over local HTTP; it did not verify HTTPS/certificate deployment. Configure and verify HTTPS on the actual IIS address.
- Temporary verification processes were stopped after testing to avoid executable locks during Visual Studio builds.

## Local database and health follow-up — 18 October 2026

The user confirmed that the API runs and selected the local default SQL Server instance (`localhost`) for the new database. The instance reports SQL Server 2019 Developer Edition, 15.0.2000.5. The first numbered script, `Backend/Database/Scripts/001_CreateDatabase.sql`, creates an empty `CompanyPortal` database using server-default file locations and safely leaves an existing database unchanged. Schema/data-access implementation is separate; Exchange remains authoritative for mail, tasks and calendars.

The agreed deployment approach is identical application code and ordered database scripts in both environments, with the destination API connection string changed through configuration. SQL service-account grants, network connectivity and certificate trust must also be provisioned. `Backend/Database/README.md` documents the procedure. No actual internal deployment is claimed by local tests.

The `/health` endpoint originally used the health middleware and was absent from Swagger's controller discovery. It now uses a controller backed by the same built-in HealthCheckService, preserving the existing URL, `Healthy` text, anonymous application access and liveness-only semantics while appearing in Swagger. IIS can still require authentication before it reaches the application. Health is not a database connectivity check.

Verified locally: `CompanyPortal` was created on `localhost`, is ONLINE and contains zero application tables. Running script 001 again reported that the database already exists and made no changes. The Release build/publish passed with zero warnings/errors, and the Windows-authenticated foundation checks passed including discovery of both `/health` and `/api/me` in Swagger. The temporary API test process was stopped. No connection string is consumed by the API yet; Dapper/SqlClient and application schema are the next feature step.

## Sources

- [Exchange build numbers and version verification](https://learn.microsoft.com/en-us/exchange/new-features/build-numbers-and-release-dates)
- [Exchange feature availability](https://learn.microsoft.com/en-us/exchange/new-features/feature-availability)
- [EWS delegate access](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/delegate-access-and-ews-in-exchange)
- [EWS notification subscriptions](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/notification-subscriptions-mailbox-events-and-ews-in-exchange)
- [ASP.NET Core Windows authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/windowsauth?view=aspnetcore-10.0)
- [Swashbuckle tooling](https://github.com/domaindrivendev/Swashbuckle.AspNetCore)
- [Dapper](https://github.com/DapperLib/Dapper)
- [Microsoft.Data.SqlClient](https://learn.microsoft.com/en-us/sql/connect/ado-net/introduction-microsoft-data-sqlclient-namespace)
