# Exchange calendar and tasks

Updated 29 October 2026. Exchange access now uses the employee's Windows credentials. Calendar editing and shared-calendar discovery are implemented; real Exchange/IIS acceptance remains pending. No new NuGet package or database migration is required.

## What employees can do

- View today's agenda, a month grid and outstanding personal tasks, with existing task filters and notifications.
- Select their own calendar, configured shared calendars, or calendars found in Outlook navigation shortcuts. Discovery is best effort, not an organization-wide permission inventory. **فتح تقويم مشترك** accepts the owner's mailbox when discovery cannot find it. Manual selections last for the open page only.
- Create an appointment when Exchange grants CreateContents. Open appointment details, edit or delete when that item's EffectiveRights allow it. A reviewer gets a read-only editor. Private shared items remain masked unless Exchange allows access; masked rows have no details button.
- Edit/delete one recurring occurrence; whole-series editing belongs in Outlook. Meeting attendees cannot edit the organizer's meeting. Organizer/delegate meeting changes require explicit confirmation that Exchange will notify participants. Creating a portal appointment does not invite attendees. Deletion uses Deleted Items rather than a hard delete.
- Save explicit drafts using the editor; closing with changes asks before discarding. A stale ChangeKey returns a conflict and requires reopening the appointment. A timed-out write is not automatically retried: check Outlook before retrying.

Tasks remain read-only, personal Tasks-folder items. Shared-task discovery/editing, new attendee invitations, recurrence editing, and delegation management are future work.

## Windows authentication

`Exchange:AccessMode` must be `WindowsDelegation`. Every EWS HTTP send runs inside `WindowsIdentity.RunImpersonatedAsync` using the authenticated employee token. This includes inbox/calendar/tasks reads, discovery, writes, Subscribe, GetStreamingEvents and Unsubscribe. Sessions copy and dispose the Windows identity and isolate HTTP connection pools/cookies. There is no process-account fallback and no EWS ExchangeImpersonation header. SQL access continues under the API's normal process identity.

NTName still resolves an active UserId with Security.User_getByUsername. Supply trusted SMTP mappings in Exchange:MailboxAddresses. That mapping identifies the default employee mailbox; Exchange authenticates the actual Windows caller and enforces permissions. It does not turn a mapping or portal-admin role into mailbox access.

Keep Enabled and ScheduleEnabled false until internal settings are ready. Configure EwsUrl, OutlookWebUrl, OutlookWebInboxUrl, MailboxAddresses and ScheduleTimeZone. Existing SharedCalendars remains supported with Key, Name, Mailbox and EnableNotifications; configured keys remain 1–40 ASCII letters/digits/underscore/hyphen, up to ten per employee. Automatic discovery adds at most30 Outlook shortcuts, with actual calendar rights checked. Browser references for discovered/manual calendars are protected, bound to the Windows account, expire after12hours, and are reauthorized on use. A server recycle/key change may require reopening a manually selected calendar. Persist Data Protection keys under the normal protected IIS application identity when required.

### IIS prerequisites

No extra notification application or Windows service is needed. Existing frontend and API applications handle this feature.

1. Configure Windows authentication on the API and the correct exact credentialed CORS portal origin. Anonymous API requests must be rejected.
2. Use the approved portal/API DNS names, internal TLS trust and unique HTTP SPNs aligned with IIS kernel-mode/app-pool credential settings. The Exchange team must identify the correct identity owning the Exchange HTTP namespace, especially behind a load balancer.
3. Configure **Kerberos constrained delegation** on the agreed API server/app-pool identity to the approved Exchange HTTP service. Do not grant ApplicationImpersonation to employees or enable unrestricted delegation. NTLM sign-in alone cannot forward the employee to Exchange.
4. Test from a separate domain workstation, not only localhost or the IIS server. The employee must be eligible for delegation and have an Exchange mailbox; shared-calendar rights must already exist in Exchange.
5. Re-publish both apps, change any old AccessMode value to WindowsDelegation, restart the API, and use /admin/health to check the caller/process identities and live folder access. Never disable TLS validation.
6. Allow SSE response flushing through IIS/proxies. If long opaque item/calendar references exceed default IIS query limits, set a reviewed request-filtering maxQueryString (for example16384) and maxUrl (for example32768) on the API application; keep application field limits in place.

RunImpersonatedAsync implements employee-context calls; it does not configure AD delegation or make an NTLM token remotely delegatable. See [authentication decision and IIS notes](EXCHANGE_AUTHENTICATION_DECISION.md).

## Shared-calendar notifications

Own calendar and tasks use EWS streaming. While a shared calendar is selected, personal tasks continue streaming; the API attempts that shared calendar's subscription only as the employee when EnableNotifications is true. Ordinary EWS delegate subscriptions can fail with ErrorSubscriptionDelegateAccessNotSupported. That expected failure falls back to a readable shared calendar with an explicit manual-refresh message. No owner impersonation or silent polling is used. Portal changes reconnect/read after a successful save so the employee sees their change immediately. External shared-calendar changes cannot be promised to arrive instantly when Exchange refuses subscriptions.

The browser uses SSE; EWS events invalidate snapshots. Status frames do not fetch items. The15-second heartbeat rechecks registration/configuration and calendar rights, not calendar-item polling. Connection lifetime10minutes, reconnect backoff5–30seconds. Disconnects clear stale private data. Active employee changes produce notices; initial/reconnect snapshots do not announce all old items.

Existing limits remain4 browser streams/account and100/API process by default. One tab uses email plus schedule; a shared live subscription may add an upstream EWS connection. Capacity/Exchange throttling must be measured before thousands of concurrent users are enabled.

## API

All require a registered, mapped Windows employee and private/no-store responses.

| Route | Purpose |
|---|---|
| GET /api/schedule/calendars | Own/configured/discovered readable calendars, rights and discovery warning |
| POST /api/schedule/calendars/open | Check owner's mailbox and return a protected calendar reference |
| GET /api/schedule?from=...&to=...&calendar=... | Month/day snapshot and personal tasks |
| GET /api/schedule/stream?from=...&to=...&calendar=... | SSE snapshots |
| GET /api/schedule/appointments?calendar=...&itemId=... | Details after item membership/private/read checks |
| POST /api/schedule/appointments | Create in selected authorized calendar |
| PUT /api/schedule/appointments | Edit with fresh item rights and ChangeKey |
| DELETE /api/schedule/appointments | Move to Deleted Items with fresh rights/ChangeKey |

Writes require X-CompanyPortal-Request: schedule, JSON and an allowed origin. No client-selected UserId is trusted. Shared mailbox entry is a candidate only; Exchange checks access. IDs cannot escape the selected calendar: ParentFolderId is rechecked before detail/edit/delete. Invalid inputs400, anonymous401, denied403, stale409, stream budget429, disabled/unavailable503. Save field limits: subject255, location255, plain body5000; End>Start, duration<=366days. All-day end is exclusive midnight in ScheduleTimeZone; UI shows an inclusive last day. List range1–42days; max1000 calendar items and500 tasks, with truncation warnings.

## Verification

ScheduleChecks uses mocked SOAP to test privacy, revocation, recurrence reads, timezone/all-day, task paging, streaming cleanup, discovery, create/update/delete, membership, per-item rights, stale changes, meeting confirmation and async Windows token lifetime. MailChecks covers inbox counts/links/events and ensures the old impersonation header is absent. Test-Schedule.ps1 checks real local Swagger/auth/disabled routes/validation/write headers/origins. verify-schedule.mjs covers renderer/events/simulation and absence of polling/storage. Browser simulation exercises appointment create/edit/delete/all-day/shared editor and discard confirmation without mailbox or SQL writes.

Internal acceptance must still test remote IIS/Kerberos, TLS and actual Exchange build; two employees; reviewer/editor/author delegates and owned-item rules; private-item rights/revocation; recurring occurrence updates; meeting participant notifications; all-day/timezone/DST; arrival/read/task events; subscription fallback/reconnect/recycle and realistic capacity. Mocks are not proof of live Exchange behavior.

References: [Windows authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/windowsauth?view=aspnetcore-10.0), [RunImpersonatedAsync](https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsidentity.runimpersonatedasync?view=net-10.0), [delegate access](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/delegate-access-and-ews-in-exchange), [delegate subscription limitation](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/handling-delegation-related-errors-in-ews-in-exchange), [meeting updates](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/how-to-update-appointments-and-meetings-by-using-ews-in-exchange).
