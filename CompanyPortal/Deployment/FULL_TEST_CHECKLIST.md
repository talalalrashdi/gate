# Full transfer and internal Exchange acceptance

Target supplied by user: a separate **Windows 10 / SQL Server Express** machine; .NET 10 Hosting Bundle will be installed there. No application authentication/Exchange code was changed for this test run.

## Before taking the package inside

- Take the entire published Airgap folder, including both apps, Deployment SQL/data files, NewsFiles/outside.pdf and documentation.
- Take the complete .NET 10 x64 Hosting Bundle installer (not only the desktop runtime), internal certificate chains, and any Windows feature installation media needed to enable IIS offline. Install IIS first, then the Hosting Bundle.
- On the destination, run `winver`: confirm the exact edition/build against Microsoft's .NET 10 supported OS list. Windows 10 alone is not enough to establish supported hosting; check the actual edition/LTSC lifecycle. Windows Authentication must be available in that Windows edition. [Supported operating systems](https://github.com/dotnet/core/blob/main/release-notes/10.0/supported-os.md).
- Check SQL Express version using `SELECT SERVERPROPERTY('ProductVersion'),SERVERPROPERTY('Edition');`. This exported script targets SQL Server **2017 or later**. The instance may be `localhost\SQLEXPRESS`, not `localhost`; use its real name in the connection string. No SQL Agent jobs are required.
- Arrange domain access, internal DNS/HTTPS names, an approved API service identity, scoped EWS impersonation for the test mailbox, and internal certificate trust **before** enabling Exchange. These are destination prerequisites, not fixes that require a different application build.
- Use CURRENT_DATA_README.md for the exact snapshot. Map the exported sample NTName to the internal test account while retaining its UserId; configure mailbox mappings, API SQL grants and news paths.

## Automated checks inside

After IIS/configuration/database setup, run the supplied script as the registered test employee in Windows PowerShell:

```powershell
.\Deployment\Test-Destination.ps1 -PortalUrl https://portal.company.local/
```

Before Exchange is enabled, a 503 is explicitly **PENDING**, not proof that Exchange works. After Exchange is configured:

```powershell
.\Deployment\Test-Destination.ps1 -PortalUrl https://portal.company.local/ -RequireExchange
```

This performs authenticated read-only HTTP checks, verifies anonymous mail denial, and records basic Windows/IIS details plus status codes in Destination-Test-Result.json. It neither changes database rows nor writes Exchange items. It does not prove streaming arrival, delegate behaviour or the actual IIS pool's infrastructure permissions merely by inspecting the machine.

## Manual end-to-end checks

Perform changes in **Outlook/OWA**; CompanyPortal calendar/tasks remain read-only.

| Check | Pass condition |
|---|---|
| Frontend/API/database | Themes load and save/reload; cards reorder and personal cards save; source sample news/PDF/image open; admin pages recognize the test admin |
| Offline assets | Fonts/icons/artwork/admin previews work without public internet; browser requests no public asset service |
| Own Inbox | Latest subjects/senders/dates and authoritative unread count match Outlook; portal listing does not mark mail read |
| Inbox live | With portal open, receive test mail; badge/list/notification update without refresh; read/delete/move in Outlook also updates |
| Outlook links | فتح البريد opens the internal inbox; clicking a message opens the intended message in OWA |
| Own calendar | Today/month appointments, location/time/all-day and recurring occurrences match Outlook |
| Calendar live | Create/edit/delete an appointment in Outlook and see portal update without refreshing |
| Own tasks | Outstanding tasks and filters match Outlook; create/edit/complete/delete a task in Outlook and see portal update |
| Independence | Two test users see only their own mailbox data; signing out/revoking registration prevents continued access |
| Multiple tabs | A normal tab uses two streams; test a second tab and check no cross-user/calendar context mixing or notification flood |
| Long-running | Leave portal open beyond ten minutes, then change Outlook data; updates continue after stream renewal |
| Reconnect | Interrupt network/API pool, restore it, and confirm private content clears while unavailable and returns with a fresh snapshot |
| IIS | Test from another domain PC using the HTTPS DNS name, not only localhost; verify API pool service identity and IIS authentication settings |
| Shared calendar (when available) | Reviewer can read; denied users cannot; private titles/details are masked unless explicitly permitted |
| Shared live (separate setup) | Only expect automatic updates after owner-subscription permission and EnableNotifications configuration; otherwise test manual refresh |

Do not mark shared/private acceptance complete until a manager/delegate test pair exists. Shared tasks, calendar/task writes, delegate-management screens and reminders are outside the current CompanyPortal implementation. Do not assume the other test harness's write features are in this build.

## Local verification — 21 October 2026

- Six frontend suites: offline assets, email, schedule, theme catalog, theme selection and workspace synchronization passed. Two stale test fixtures/expectations were updated to match already authorized application behaviour; application code was unchanged.
- MailChecks and ScheduleChecks passed using controlled EWS SOAP responses: own/delegate/private access, read boundaries, authoritative unread counts, task paging, all-day/timezone cases, event framing, cancellation/unsubscribe and stream limits. These tests did **not** connect to real Exchange.
- Published frontend parity passed: 328 original baseline files unchanged, six routes, 313 static resources, 22 styles and 26 scripts.
- Packaged snapshot restored to disposable databases; all 20 tables' counts/data SHA256 hashes, identity state and schema object counts matched.
- Eleven API suites against the published API and disposable databases passed: foundation, mail, schedule, employee theme settings, card order, personal cards/app revocation, administration/role revocation, news fixtures/files, image library, theme administration and theme publication.
- IIS is not installed on the development machine. Real IIS, SQL Express, internal Windows/Exchange authentication, live streaming and shared/private acceptance must be completed on the destination. Package restore/build emitted a NuGet vulnerability-metadata availability warning; it did not prevent the checks and is not a runtime internet dependency.

A single transfer can include everything needed for these checks, but no local mock test can guarantee the destination Exchange/AD/IIS configuration. Keep Destination-Test-Result.json and note manual outcomes so any remaining failure can be traced to configuration or a specific behaviour.
