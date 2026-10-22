# CompanyPortal — offline test deployment to IIS

This guide deploys the current MVC frontend and API as two applications with separate app pools. No public internet is required at runtime. Internal AD/DNS, SQL Server, Exchange EWS and Outlook Web must remain reachable. Exchange delivery, delegate behaviour and IIS streaming still require testing on your actual internal servers.

## 1. Prepare before copying

On this connected development machine, from the CompanyPortal folder:

```powershell
powershell -NoProfile -File tools/Publish-Airgap.ps1
```

It publishes Release files to `artifacts/Airgap/Frontend` and `artifacts/Airgap/Backend`, and copies the SQL/configuration/guide. It uses already restored dependencies (`--no-restore`). If dependencies are missing, restore on the connected machine first; the API has a committed NuGet lock file. Do not publish directly over a running IIS folder. Use a fresh output folder for a new release to avoid retaining obsolete files.

Copy the entire `artifacts/Airgap` folder, a supported **.NET 10 x64 Hosting Bundle** installer, and any required internal root/intermediate certificates. Installers must be obtained before entering the offline network; use your organization's offline installation process. The Hosting Bundle includes the IIS ASP.NET Core Module. Install IIS first, then the bundle (repair the bundle if IIS was installed afterwards), and restart IIS/server as required. The published application needs no SDK, Visual Studio, npm, Node, Vite or NuGet feed on the IIS server. [Microsoft IIS hosting requirements](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-10.0).

Copy the source solutions too if you want to edit them there. **Published files are the simplest way to run offline**; rebuilding source offline additionally requires a compatible .NET 10 SDK and all locked NuGet packages in an approved offline feed/cache. Copying source alone does not supply them. Fonts, scripts, styles and original artwork are served locally in the published frontend; Swagger assets are bundled in the API dependency.

## 2. Create the databases — one SQL file

**Current sample data handoff:** use `Deployment/CompanyPortal-CurrentData.sql` and `Deployment/CURRENT_DATA_README.md` to recreate the actual current three databases, including SQL images, themes/settings and sample grants. Import it on a fresh test instance, copy the supplied external NewsFiles, and do not also run CompanyPortal-Setup.sql. The remainder of this section describes the alternative minimal fresh setup.

Open `Deployment/CompanyPortal-Setup.sql` in SSMS. It is UTF-8, works in ordinary SSMS mode, and contains migrations 001–018 in order, including tables, schemas, types, procedures and original three themes/five master cards. Edit the four values near the top, then execute the whole file using a deployment account authorized to create databases:

| Value | Set it to |
|---|---|
| `TestSources` | `1` for a NEW isolated test installation; `0` to use real external sources |
| `TestNTName` | Exact browser employee account, e.g. `MYDOMAIN\mazin` (single backslash in SQL) |
| `ApiIdentity` | API domain service account, e.g. `MYDOMAIN\svcCompanyPortal`; blank means DBA grants permissions separately |
| `PortalUrl` | Final frontend address, e.g. `https://portal.company.local/` |

Alternatively, use `sqlcmd -S YOURSQL -E -b -f 65001 -i .\Deployment\CompanyPortal-Setup.sql`.

**Fresh installation only:** the file refuses an existing CompanyPortal database. With `TestSources=1`, it also refuses existing SecurityDB or Pubs_Info_V4. Nothing existing is deleted, reset or upgraded. After an error, stop and reconnect SSMS; inspect the partially created test installation before retrying. Do not run historical migrations over an existing current database.

Test mode creates sample SecurityDB users/apps/direct role grants and a minimal Pubs_Info_V4 news source plus CompanyPortal.dbo.VNews. Only the explicitly named test employee gets a sample admin role and three sample apps. Sample app links point back to the configured portal. The sample news has no PDF/image attachment, so no file share is needed for this initial test. Additional test employees need explicit active Users rows and their own grants/mappings; never reuse another employee's UserId. These are disposable test sources, not replacements for your organization's security/news databases.

With `TestSources=0`, the script creates CompanyPortal only. It creates an empty dbo.VNews placeholder and no sample users/permissions. Before testing, have the DBA install the real dbo.VNews and map these three procedure contracts to the actual existing security database on the same SQL Server:

- `Security.User_getByUsername @Username nvarchar(512)` → active `UserId` for the authenticated `DOMAIN\username`.
- `Security.Apps_getForUser @UserId int` → authorized `AppId, AppName, LaunchUrl`.
- `Security.UserRoles_get @UserId int` → distinct active `RoleName`, including direct/group grants as appropriate. Portal administration requires `CompanyPortal.Admin`.

Samples are in `Deployment/Integration` in the handoff folder, or `Backend/Database/Integration` in the source copy. Real-source mode intentionally grants no guessed access. Configure real news roots in `Mstr.Utls` (`[Key]='PubsInfo'`, `strVal`=absolute allowed folder, Active=1) and grant the API identity read access to those folders/shares. See FOLDER_PATHS.md and NEWS.md in the included docs folder.

If ApiIdentity is supplied, the script creates its Windows SQL login/database users, grants EXECUTE on application procedures and EXECUTE/REFERENCES on table types, and—in test mode—SELECT on the specific external sample tables. In real-source mode the DBA must grant the underlying external reads needed by the adapter procedures/view. No runtime db_owner/sysadmin, TRUSTWORTHY or cross-database ownership-chaining change is needed. Employees do not need direct SQL access.

**To keep today's exact uploaded images, image groups, themes and employee settings:** use a CompanyPortal database backup/restore to a compatible SQL Server instead of this fresh-install file. The setup script seeds the base project; it is not a data export. A restored database still needs the destination SQL login/user mapping (`ALTER USER ... WITH LOGIN=...`), external security/news adapters, real folder paths and service-account permissions. Do not transfer development sample security grants as real production access.

## 3. Simple IIS structure

Use one HTTPS site so the browser and API share an origin:

```text
https://portal.company.local/                  → Frontend publish folder
https://portal.company.local/backend/          → Backend publish folder (IIS Application)
https://portal.company.local/backend/api/...   → API controllers
https://portal.company.local/backend/health    → process liveness
```

1. Enable IIS **Windows Authentication** and the usual Static Content features. No WebSocket feature is needed for SSE.
2. Create two app pools: `CompanyPortal.Frontend` and `CompanyPortal.Api`. Both: **No Managed Code**, Integrated pipeline, **Enable 32-Bit Applications=False**, one worker process. Use in-process hosting from the generated web.config; keep that file.
3. Create the frontend site with the Frontend publish directory as its physical path. Bind HTTPS to the internal DNS name with a trusted internal certificate. Give its pool identity read/execute permission on its folder.
4. Add an **Application** alias `backend` beneath that site, physical path pointing to the separate Backend publish directory, and select the API pool. A virtual directory alone is insufficient. Do not put both applications in the same in-process app pool.
5. Frontend Authentication: Anonymous **Enabled**, Windows **Disabled**. The frontend is the UI shell; protected API operations authenticate the employee.
6. API `/backend` Authentication: Windows **Enabled**, Anonymous **Disabled**. Disable Basic authentication. Browsers must treat this internal address as a Local Intranet/trusted Windows integrated-authentication destination under company policy. Use the DNS name rather than an IP address. [Microsoft Windows authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/windowsauth?view=aspnetcore-10.0).
7. Set the **API pool identity** to the approved domain service account (or an IT-managed service identity) with SQL access and scoped Exchange impersonation rights. Set its password using IIS/IT procedures, never appsettings. This is different from the employee signing in. Give this identity read/execute permission on Backend and read access to approved news paths.
8. For the active streaming test, set the API pool Idle Time-out to `0`; keep worker count `1`. Disable Static/Dynamic Compression on `/backend` for the initial SSE test. If any reverse proxy is used, disable response buffering for `/api/mail/stream` and `/api/schedule/stream`, and allow long-lived responses. Recycling interrupts streams; the browser reconnects. Do not add a proxy for the first test.

The site uses one origin to avoid Windows-authentication preflight complications. If you later split frontend/API hosts, configure exact credentialed CORS and handle unauthenticated OPTIONS in IIS; just enabling Windows authentication and disabling Anonymous on a separate-origin API can block preflight before ASP.NET Core sees it. [Microsoft CORS/IIS notes](https://learn.microsoft.com/en-us/aspnet/core/security/cors?view=aspnetcore-10.0).

## 4. Configure the published applications

In the frontend publish folder, copy `Deployment/appsettings.Frontend.Production.example.json` as `appsettings.Production.json`. In the backend folder, copy `Deployment/appsettings.Api.Production.example.json` as `appsettings.Production.json`. Edit all example domain/host/user/mailbox values. Leave the published base appsettings.json in place; Production settings override it. IIS uses Production by default; launchSettings.json has no effect there.

- Frontend `Api:BaseUrl`: `https://portal.company.local/backend/` including the trailing slash. Do **not** add another `/api`; scripts append controller paths themselves.
- API connection string: destination SQL host and CompanyPortal database. Integrated Security connects as the API pool identity. Install/trust the SQL server certificate chain and use a matching SQL hostname; do not bypass TLS validation to solve certificate errors.
- `AllowedHosts`: actual portal DNS hostname. `Cors:AllowedOrigins`: exact `https://portal.company.local` with no trailing slash/path; SSE also checks Origin.
- Keep Exchange flags false until URLs, employee registration, mappings and service permissions are ready. Then set both `Exchange.Enabled=true` and `Exchange.ScheduleEnabled=true`.
- `EwsUrl`: actual internal `https://.../EWS/Exchange.asmx`. `OutlookWebUrl`: actual Outlook Web root. `OutlookWebInboxUrl`: the verified internal inbox link copied from your working Outlook Web; do not leave it empty if testing **فتح البريد**.
- `MailboxAddresses`: exact registered employee `DOMAIN\\username` JSON keys → actual SMTP mailbox addresses. Backslashes are doubled in JSON, single in SQL. Do not map all employees to one mailbox.
- `AccessMode`: `ScopedServiceAccountImpersonation`. This setting grants nothing by itself. Exchange must allow Windows integrated authentication for the API service identity and approve ApplicationImpersonation scoped to the required employee mailboxes. Internal DNS/TLS certificate chains must be trusted by the IIS server. The implementation uses API service credentials plus EWS employee impersonation; it does not forward the browser employee's password/token to SQL/Exchange.
- Shared calendars: configure candidates per employee under `SharedCalendars`, and have the manager grant the delegate access in Exchange/Outlook. Candidate configuration is not permission. Keep `EnableNotifications=false` initially: delegate reads/manual refresh work, while shared live notifications require separately approved owner-mailbox subscriptions. Personal calendar/tasks/email already use EWS streaming. Change the example manager entry or remove it if not needed.

Recycle the API pool after changing settings. No Exchange data is stored in SQL. Do not place secrets in the source/publish templates. Ensure internal CA certificate/revocation services are reachable where your TLS policy requires them; do not disable certificate checks to work around internet isolation. See EXCHANGE_CALENDAR_TASKS.md and EMAIL.md in docs for detailed permission and notification behaviour.

## 5. Test inside the offline network

1. From an employee PC, open the HTTPS portal using its DNS name. Verify images/fonts/icons and switch themes without public internet access.
2. As the named registered test employee, request `https://portal.company.local/backend/api/access`; check the expected admin capability. Check `/backend/api/themes` and save/reload a theme. This verifies browser → API → SQL and employee identity.
3. `/backend/health` reports process health only, **not SQL or Exchange readiness**. With IIS Anonymous disabled it also requires Windows authentication, even though the controller allows anonymous at the application level.
4. Enable/configure Exchange and open `/backend/api/mail/inbox` and `/backend/api/schedule/calendars`. Test today's agenda, month navigation, outstanding task filters and an authorized shared calendar.
5. Keep the portal tab open. Send test mail from Outlook, change read/unread state, create/change an Outlook appointment and an Outlook task. Check unread count, agenda/tasks and notifications update without refreshing. Test two employee accounts independently and verify denied/private shared items remain protected. Try disconnect/reconnect. Shared live updates are only expected after the extra owner-subscription setup.
6. Check **فتح البريد** and an individual title open the correct internal Outlook Web mailbox/message. This version displays calendar/tasks read-only; edit/complete operations stay in Outlook.
7. Browser Network should show local portal/API/internal requests; streaming requests staying Pending is normal. A firewall-blocked public internet connection is the final environmental check; the static scan alone cannot prove the installed server/network configuration.

Swagger is intentionally enabled only in Development in the current API. A Production `/backend/swagger` 404 is expected; do not switch the whole deployed site to Development just to enable it. Use the protected endpoints above for this test.

## Quick troubleshooting

| Symptom | First check |
|---|---|
| IIS 500.30 / 500.31 / missing framework | .NET 10 x64 Hosting Bundle, generated web.config, Windows Application Event Log |
| IIS 500.19 | Installed ASP.NET Core Module, malformed web.config, locked IIS settings |
| 401 / repeated credential prompt | API Windows Authentication, intranet browser policy, actual DNS name, IT-managed SPN/service identity configuration |
| Registered employee denied | Exact NTName and Active flag returned by Security.User_getByUsername, real role/app adapters |
| SQL login/certificate failure | API service account SQL login/user/grants; DNS/server certificate chain; correct Production connection string |
| Mail/calendar unavailable (503) | Both Exchange flags, mappings, EWS Windows authentication, scoped impersonation, TLS trust and EWS reachability |
| No immediate live updates | Browser SSE connection, buffering/compression/proxy settings, Exchange subscription rights/throttling, pool recycle |
| 429 | Too many live streams/tabs; close extra tabs; default four per account, 100 per API process |
| News files unavailable | dbo.VNews mapping, Mstr.Utls PubsInfo roots and API identity folder/share read access |

Local verification: offline asset source scan; Release folder publishing; isolated SQL fresh-install/guard checks. Actual destination IIS, AD, certificates and live Exchange acceptance must be completed using the checklist above.
