# Exchange authentication decision and resume notes

## Current decision — 29 October 2026

The user authorized switching CompanyPortal to employee Windows delegation and adding shared-calendar discovery/editing. This is now implemented with WindowsIdentity.RunImpersonatedAsync for all EWS sends, isolated HTTP sessions and retained/disposed caller tokens. The ExchangeImpersonation SOAP header is removed. Set AccessMode=WindowsDelegation; no ApplicationImpersonation role is required. Existing SQL connections continue using the API process identity. No AD/Exchange permissions were changed here.

Calendar create/edit/delete checks current Exchange folder/item permissions, parent folder, private-item access and ChangeKey. Discovery checks Outlook shortcuts, with manual owner-mailbox entry when needed. Shared delegate subscriptions can be refused by Exchange; in that case the UI explicitly requires manual calendar refresh while personal task notifications continue. It never impersonates the owner to bypass this limit.

See [current calendar/API/IIS instructions](EXCHANGE_CALENDAR_TASKS.md). Local mocks and simulation are not live IIS/Exchange acceptance. The earlier comparison and troubleshooting below are preserved as historical context; statements that the choice was deferred or CompanyPortal still used service-account impersonation describe the earlier version only.

## Historical discussion

Recorded: 22 October 2026.

## Status and purpose

Exchange authentication work is deferred at the user's request so other CompanyPortal features can continue. No final authentication choice was made. No switch to employee Kerberos delegation was authorized or implemented in CompanyPortal during this discussion. No AD or Exchange permission changes were performed here.

This document preserves the alternatives, security implications, separate test-project deployment results, and the next investigation step. Reported internal names are recorded as supplied; verify the actual values before any administrative changes. There are no passwords in this document.

## Two different projects

### CompanyPortal: current implementation

- .NET 10 MVC frontend and separate .NET 10 API.
- Browser signs into the API with Windows authentication. The employee's authenticated NTName resolves to the external database UserId and trusted server-side mailbox mapping.
- API HTTP calls use its Windows process credentials (`UseDefaultCredentials`), not forwarded employee credentials.
- EWS SOAP includes `ExchangeImpersonation` for the resolved employee mailbox.
- Local execution uses the account running the API. IIS execution uses the API's process identity. A dedicated domain service account is the proposed production arrangement, not an account already created by this discussion.
- Exchange must grant that account ApplicationImpersonation within an approved recipient scope. Windows sign-in to the portal alone does not grant it.
- Existing functionality reads Inbox/unread count, calendar and tasks, with streaming notifications. It does not send mail or expose Exchange item write endpoints.
- Shared-calendar candidates are configured per employee. Reads impersonate the employee and address the owner's folder, preserving Exchange delegate checks. Automatic discovery of all Outlook shared calendars is not implemented. Shared tasks are not implemented.
- Shared-calendar live notifications have separate owner-subscription requirements; employee Kerberos delegation alone would not solve those requirements.

Relevant code: `Backend/CompanyPortal.Api/Mail/MailSessionFactory.cs`, `Mail/EwsMailSession.cs` and `Mail/EwsMailSession.Schedule.cs`.

See [email](EMAIL.md) and [calendar/tasks](EXCHANGE_CALENDAR_TASKS.md) for implemented configuration, stream limits and behavior.

### Separate Exchange test harness: reported implementation

The source is on another machine and was not available in this workspace. Its description and remote results were supplied by the user; do not assume its implementation has been audited here.

- Portal: `ExchangeIntegrationTest.csproj`, ASP.NET Core 8 MVC.
- Notification app: `ExchangeNotificationService`, ASP.NET Core 8 API.
- Raw EWS SOAP using HttpClient, Windows authentication, local Bootstrap/jQuery; no Microsoft Graph or cloud requirement.
- No EWS `ExchangeImpersonation` header. Calls use the employee's Windows credentials, using Windows impersonation when needed.
- Long-lived notification sessions retain a Windows token for the employee. Browser receives SSE updates directly from the notification app.
- Shared-mailbox choices reportedly use `App_Data/shared-access.json`; item references use ASP.NET Data Protection.
- Includes calendar/task editing and delegate features, but those features were not proven by the user's tests.
- Known review concerns to revisit before reuse include shared subscription behavior, token cleanup/reconnects, private-item handling, recurrence/time zones, notification storage and per-user isolation. It is an experimental harness, not an established production baseline.

The user confirmed Inbox, Calendar, Tasks and automatic notifications worked on localhost under their own account. Shared calendar/tasks were not tested because no shared resources were available. Local success does not prove remote IIS delegation or capacity for thousands of employees.

## Why CompanyPortal originally could not read the mailbox

The first offline diagnostics showed HTTP 500 for Inbox, Calendar and Tasks. Exchange SOAP faults were hidden by throwing on HTTP status before reading the fault. After a diagnostic code adjustment, all three reported `ErrorImpersonateUserDenied`.

Interpretation: Exchange rejected the requested EWS impersonation. Check the actual API execution account, its ApplicationImpersonation assignment and recipient scope. Even accessing that account's own mailbox with the impersonation header uses this authorization path.

This is different from the test harness's later HTTP 401: a 401 is an authentication rejection, not proof of an ApplicationImpersonation scope problem.

The bounded SOAP-fault handling and deployment compatibility fixes are documented separately in `Deployment/EWS_HTTP500_UPDATE.md` and `Deployment/SqlServer2017-Compatibility.sql`. SQL Server 2017 requires the revised snapshot/compatibility guidance; level 100 is insufficient for the project's OPENJSON usage.

## Option A: dedicated account with ApplicationImpersonation

Flow: employee Windows sign-in → API resolves employee → API service account authenticates to Exchange → EWS impersonates that employee.

Exchange administrators assign the role to one dedicated API account, not to every employee. Scope it to approved mailboxes; an unscoped assignment can cover the organization. Start with a small test scope before expansion.

The account needs application file access, the API's minimum SQL permissions and the scoped Exchange role. It does not need Domain Admin or Exchange Administrator privileges to run. It need not be a separate executable or Windows service: it can be the existing API application-pool identity. Employee delegation to Exchange is not required in this model. Ordinary browser-to-IIS Windows authentication still needs correct configuration.

Security consequences:

- Employees do not receive impersonation permission or the service account's password.
- The service account itself can act as any employee in its scope. This is a substantial privilege.
- ApplicationImpersonation is not read-only. A read-only portal API does not reduce the underlying Exchange permission to read-only.
- A stolen service credential, compromised server or authorization vulnerability can expose other scoped mailboxes. An air-gapped network does not remove this risk.
- Restrict the account to application use, protect credentials and deployments, restrict privileged access, maintain audit/monitoring, and review scope membership with IT. Confirm what the actual Exchange version logs; do not assume every read is audited by default.

The API must derive the employee from authenticated Windows identity and resolve mailbox access on the server. Browser-supplied UserId, mailbox address, calendar key or item reference must never be sufficient authorization. Cache entries, SSE connections and item access must remain employee-scoped. Portal admin status must not implicitly grant access to other inboxes.

For shared resources, do not simply impersonate the owner because the API technically can. Read in the viewing employee's context and let Exchange enforce their folder/delegate/private-item permissions.

## Option B: employee credentials with Kerberos constrained delegation

Flow: employee authenticates to IIS using Kerberos → IIS application uses the employee's Windows identity to call EWS → Exchange enforces that employee's permissions.

This is the test harness's intended central-hosting approach. It needs correct HTTP SPNs, IIS credential settings, constrained delegation to the Exchange HTTP service, and employee eligibility for delegation. Negotiate being enabled or automatic sign-in alone does not prove that both connection steps use Kerberos.

CompanyPortal would require deliberate code changes: remove the EWS impersonation header for this mode, execute EWS calls under the employee identity, correctly retain/dispose tokens for streams and isolate HTTP sessions. Keep SQL work under the API identity rather than unintentionally delegating employee credentials to SQL. Review shared notification design separately.

No additional application is inherently required. A domain service account is an identity, not a new running service. Configuration can use the IIS computer account or a dedicated domain application-pool account, depending on the chosen IIS/SPN arrangement. Employees need no ApplicationImpersonation role; existing Exchange sharing rights still determine delegated access.

Constrained delegation is also security-sensitive. Limit destinations to the required Exchange HTTP service; do not choose unrestricted delegation. Compromise of a trusted IIS server remains a risk.

## Decision factors and maintenance

| Topic | ApplicationImpersonation | Employee Kerberos delegation |
|---|---|---|
| Exchange authorizes | Service account acting as scoped employee | Delegated employee identity |
| Main infrastructure work | Dedicated execution identity and scoped Exchange role | SPNs, matching IIS identities/settings and constrained delegation |
| Server move | Reuse approved service identity, configure new pool/files/settings; role normally stays | Recheck SPNs/delegation; computer-account configuration must move to the new computer account |
| Dedicated identity and stable DNS | Simplifies operations | Can preserve account-owned SPNs/delegation across moves, but new IIS configuration still needs verification |
| Password rotation | Update every pool/consumer using that password | Same if password-based dedicated pool identity is used |
| Employee onboarding | Trusted mailbox mapping plus inclusion in approved scope | Trusted identity/mailbox resolution and valid employee delegation/Exchange access |
| Shared calendar discovery | Separate application feature | Separate application feature |
| Thousands of employees | Requires measured Exchange/portal capacity testing | Requires measured Exchange/portal capacity testing |

A stable portal DNS alias is preferable to exposing a replaceable machine name as the long-term address. No recommendation to create or move SPNs blindly was approved. Exchange URL/certificate changes, employee permissions and service-identity changes require review under either option.

Provisional decision guidance: scoped ApplicationImpersonation fits current CompanyPortal code and generally simplifies Exchange access deployment if IT accepts its privilege. Employee Kerberos delegation fits a policy requiring employee-context access, but must first be proven through remote IIS. Neither alternative was selected as final.

## Separate test harness: actual IIS investigation

These are reported results from the other machine, not checks executed by this workspace agent.

### Reported environment

| Item | Value |
|---|---|
| IIS computer | `server1` |
| AD domain | `domain.com` |
| Domain joined | True |
| Portal | `https://server1/PortalTest` |
| Notifications | `https://server1/NotificationsTest` |
| Portal pool | `PortalTestAppPool`, identity `ApplicationPoolIdentity` |
| Notification pool | `NotificationsTestPool`, identity `ApplicationPoolIdentity` |
| EWS | `https://mail.domain.com/EWS/Exchange.asmx` |

### Fixed or checked

1. Initial 500.19/hosting errors involved folder access; user moved deployment to an accessible server location.
2. Notification startup produced 500.30/CoreCLR worker exit. Running its executable exposed an `AllowedPortalOrigins` configuration error.
3. User supplied the actual portal origin. In this table's names it must be `https://server1`, without `/PortalTest`, no trailing slash and no wildcard. Origins must match the address actually used; earlier discussion used the placeholder `https://server`.
4. Invalid-hostname/stream-address issue was corrected. `AllowedHosts` is a separate setting accepting hostnames, not full origins. Verify deployed values rather than assuming exactly which edit solved it.
5. Correct original stream route is plural: `/notifications/stream`. With the IIS application path it is `https://server1/NotificationsTest/notifications/stream`.
6. Both apps use separate pools. User confirmed Anonymous disabled, Windows enabled, Negotiate before NTLM, kernel-mode authentication enabled.
7. A separate domain computer signed in automatically and `klist` showed `HTTP/server1.domain.com`. This supports first-hop Kerberos ticket availability, not proof of successful EWS delegation or that a specific application request used that ticket.

The notification service's anonymous application `/health` may still be challenged when IIS Anonymous Authentication is disabled. Do not treat a health-route authentication challenge alone as a startup failure.

### Still failing / not configured

- Both applications receive HTTP 401 from the Exchange EWS address (not the browser SSE route).
- SPN/delegation changes have not been made. Missing delegation is a likely blocker, but HTTP 401 alone does not establish the entire cause.
- The user does not have Exchange administration access.
- No shared-resource or multi-user capacity test has passed.

### Read-only lookup results

```cmd
setspn -L server1
```

User found `HOST/server1` and `HOST/server1.domain.com`.

```cmd
setspn -F -Q HTTP/server1
setspn -F -Q HTTP/mail.domain.com
setspn -F -Q HOST/mail.domain.com
```

Each query returned no such SPN found. No separate query of `HTTP/server1.domain.com` was reported. Standard HOST mappings can support HTTP authentication on a computer; missing explicit HTTP registration alone is not proof of a fault.

```cmd
nslookup mail.domain.com
```

Returned a DNS timeout message but also the requested name and an IP address. No exact IP, alias chain, Exchange server identity or load-balancer topology was recorded. This result does not identify the correct Exchange SPN owner.

## Exact point to resume

First revisit the authentication choice with IT. Do not resume by randomly adding SPNs, granting all employees impersonation, changing to Basic authentication or using a personal account for the pools.

If continuing the test harness Kerberos investigation, ask the Exchange administrator:

> Both IIS applications receive EWS HTTP 401 while using employee Windows credentials. The client has an HTTP/server1.domain.com ticket. No HTTP/mail.domain.com or HOST/mail.domain.com registration was found in the queried forest. Is mail.domain.com a single Exchange host or a shared/load-balanced namespace? Is Kerberos enabled for this namespace, and which AD identity is intended to own its HTTP SPN?

Ask them to run this read-only command in Exchange Management Shell and supply its output:

```powershell
Get-WebServicesVirtualDirectory |
    Format-List Identity,InternalUrl,ExternalUrl,WindowsAuthentication
```

This identifies EWS virtual-directory settings and participating server identities; it does not by itself establish SPN ownership or complete Kerberos configuration. If a shared namespace is used, the Exchange team must check its alternate service account arrangement. Do not register the Exchange hostname on the portal account or arbitrarily on one Exchange computer.

After the correct Exchange identity is established, an authorized AD administrator can plan constrained delegation on `server1`'s computer account for the current ApplicationPoolIdentity arrangement, or agree a dedicated account design first. Check IIS `useAppPoolCredentials` against that design; it was not recorded during the latest guided checks. Custom account-owned SPNs and computer-account/kernel-mode configurations must not be mixed.

For ApplicationImpersonation instead, ask for one dedicated API account and a small approved test recipient scope, configure API execution identity, then rerun CompanyPortal diagnostics. Do not change the test harness and assume it implements this model already.

Administrative roles: the user can check IIS if locally authorized, run normal domain SPN/DNS queries, and run client `klist`. AD permission changes require delegated AD rights; Exchange configuration/role changes require Exchange rights. Local IIS administrator access alone grants neither. Another department is needed only when those rights or organizational responsibility are held there.

## Acceptance before rollout

- Prove remote employee → IIS → Exchange access from another domain computer using the agreed DNS name.
- Prove two employees see only their own mail/calendar/tasks. Test modified identifiers, cross-user item access, cache and SSE isolation. Portal administrators should have no implicit mailbox access.
- Test private shared appointments and read/write permission boundaries. Shared tasks and discovery must be separately scoped/implemented.
- Confirm live arrival/unread changes, reconnects, multiple tabs, sign-out, disabled users, revoked sharing, stream/token cleanup and app-pool recycle recovery.
- Load-test realistic concurrent users, tabs, SSE and EWS subscriptions. Review existing CompanyPortal per-process limits before promising thousands of concurrent users. Use bounded concurrency, backoff and Exchange throttling handling; do not simply disable throttling.
- Check HTTPS trust, Data Protection persistence, restricted folder/credential access, logs and identity/scope changes after migration or password rotation. Do not log mailbox content, passwords or raw SOAP faults.
- Neither localhost success nor a single first-hop Kerberos ticket establishes production readiness.

## Sources and related documentation

Microsoft references consulted during the discussion; verify current guidance against the actual on-premises Exchange version before making changes. Exchange Online retirement guidance must not be confused with this on-premises decision.

- [Impersonation and EWS security considerations](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/impersonation-and-ews-in-exchange)
- [Configure scoped ApplicationImpersonation](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/how-to-configure-impersonation)
- [Delegate access and EWS](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/delegate-access-and-ews-in-exchange)
- [ASP.NET Core Windows authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/windowsauth)
- [Kerberos constrained delegation](https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-constrained-delegation-overview)
- [IIS Kerberos troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/developer/webapps/iis/www-authentication-authorization/troubleshoot-kerberos-failures-ie)
- [Exchange shared-namespace Kerberos setup](https://learn.microsoft.com/en-us/exchange/architecture/client-access/kerberos-auth-for-load-balanced-client-access)
- [setspn reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setspn)
- [EWS virtual-directory inspection](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-webservicesvirtualdirectory)
- [EWS throttling](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/ews-throttling-in-exchange)
- [Current CompanyPortal email implementation](EMAIL.md)
- [Current CompanyPortal calendar/tasks implementation](EXCHANGE_CALENDAR_TASKS.md)
- [CompanyPortal offline/IIS guide](AIRGAP_IIS_GUIDE.md)
