# Exchange calendar and tasks

Read-only implementation, 20 October 2026. Exchange remains disabled locally until approved internal configuration is supplied. No real Exchange data, AD rights, database tables or employee browser tasks were changed or imported.

## Employee experience

The existing calendar in all three portal templates now shows Outlook-backed data: a 42-day month grid, a selected-day agenda (initially today), and the employee's outstanding tasks. Tasks can be filtered into all, overdue, today and upcoming; entries show due date, importance, progress and status. Appointments include title, local times, location, organizer, all-day, tentative/response and cancellation information. Recurring occurrences come from EWS CalendarView; all-day/end-exclusive dates use the configured timezone.

The compact floating summary shows upcoming items in the viewed date range and the outstanding-task count. Its plus button expands the month/day/task view. In the work template the planner is displayed inline. Calendar/task notifications also feed the existing header notification list. New items trigger an in-portal notice, and subsequent changes refresh the view without page reload. Initial loading and reconnect snapshots do not announce every old item as new. Changed items outside the displayed month can produce a generic update notice.

There are no create/edit/delete/complete actions in this version. The old local add-task controls are hidden/disabled. Existing localStorage tasks and notes remain untouched; the Exchange planner neither seeds more demo tasks nor uploads, reads or merges the retained data. Demo calendar notifications are suppressed in the Exchange view. No Exchange item data is saved to SQL or browser storage. Admin theme previews remain independent, read-only illustrative content.

A disconnected view clears private data and shows unavailable; it never replaces it with demo rows or treats an unknown task count as zero. **تحديث** reloads access/calendar metadata and reconnects the stream, preserving the selected calendar/month when still allowed.

## Connection and delegation

Reuse the existing Exchange EWS URL, internal Outlook Web URL, approved Windows API service identity, scoped ApplicationImpersonation arrangement and trusted NTName-to-SMTP mappings. HTTP uses UseDefaultCredentials as the API process identity, not forwarded employee credentials. The EWS impersonation header represents the mapped, registered employee for every calendar/task data read.

Personal calendars use the default Exchange Calendar folder, and tasks use the default Tasks folder. Secondary calendar folders and Outlook’s aggregated To-Do view (including flagged mail) are future extensions.

Shared-calendar candidates are configured per Windows account initially. A configured candidate is NOT an authorization grant: the API probes that folder in the employee's EWS context and excludes inaccessible calendars. The request uses the manager as the folder owner while retaining the employee in ExchangeImpersonation. The browser sends only the configured calendar key, never a mailbox address. Personal tasks always come from the signed-in employee's Tasks folder; delegated task folders are outside this version.

EffectiveRights are read from Exchange, not inferred from portal roles. Reported folder flags are informational; any future write operations must reauthorize the individual item/action, including owned-versus-all-item rights and meeting handling. Private shared items are masked (subject becomes موعد خاص, location/organizer/response cleared) unless Exchange explicitly reports private-item visibility on the item or, when absent there, the folder. The mailbox owner retains their own private details. Actual private/delegate behaviour still needs verification against the internal Exchange installation. Read-only API scope remains read-only even when Exchange reports editor rights.

## Streaming and shared-calendar limitation

A normal personal schedule stream subscribes to the employee's Calendar and Tasks folders before the initial snapshot. EWS Created/Modified/Deleted/Moved/Copied/FreeBusyChanged events invalidate the snapshot; the API then reads current data and sends SSE to the browser. Status-only events do not read items. Held Exchange requests renew after timeout; browser reconnects subscribe again and obtain fresh data. There is no periodic folder-item polling or unattended mailbox worker. Closing the page cancels subscriptions; notifications require an active portal connection.

Ordinary EWS delegate access cannot subscribe to another mailbox's events. A shared calendar therefore has `EnableNotifications=false` by default: its initial/manual data reads work through delegation, and the UI explicitly says the shared calendar needs manual refresh. To enable shared live updates, the Exchange administrator must approve and scope owner-mailbox subscriptions and set that flag true. The owner session performs Subscribe/GetStreamingEvents/Unsubscribe only; it yields invalidation signals, not owner item IDs/content. Every resulting snapshot is read again as the viewing employee, enforcing delegate/private rights. Employee calendar/tasks subscriptions remain active while a shared calendar is selected.

Every event/15-second heartbeat rechecks registration and mailbox mapping; schedule authorization is also rechecked against Exchange. These are authorization/connection checks, not calendar-item polling. Detected rights changes close the stream and clear the browser before reconnecting. A ten-minute stream lifetime forces fresh authentication. SSE responses are private/no-store and accept only configured origins when supplied. IIS/proxy buffering must be disabled, as for email.

The shared mail/schedule stream budget defaults to four browser streams per account and 100 per API process (configurable, bounded). A normal tab uses one email SSE plus one schedule SSE; navigation may briefly overlap old/new streams during cancellation. Shared live calendars additionally require an owner EWS subscription. Review Exchange throttling, scopes, server load, tabs and API instance count before broad rollout; exceeded limits return429 and reconnect with backoff.

## Configuration

Keep all features off until the internal Exchange prerequisites from EMAIL.md are complete. No passwords belong in appsettings. Example only; replace every example account/address with approved real values:

```json
{
  "Exchange": {
    "Enabled": true,
    "ScheduleEnabled": true,
    "EwsUrl": "https://exchange.internal.example/EWS/Exchange.asmx",
    "OutlookWebUrl": "https://mail.internal.example/owa/",
    "AccessMode": "ScopedServiceAccountImpersonation",
    "MailboxAddresses": {
      "COMPANY\\secretary": "secretary@company.example",
      "COMPANY\\manager": "manager@company.example"
    },
    "ScheduleTimeZone": "Asia/Muscat",
    "MaximumStreamsPerAccount": 4,
    "MaximumStreams": 100,
    "SharedCalendars": {
      "COMPANY\\secretary": [
        {
          "Key": "manager",
          "Name": "تقويم المدير",
          "Mailbox": "manager@company.example",
          "EnableNotifications": false
        }
      ]
    }
  }
}
```

Existing mail settings (inbox URL, message-opening mode, count, etc.) remain in the same Exchange section. `ScheduleEnabled` is separate so enabling email does not silently enable schedule requests. Use an installed timezone (IANA recommended); Windows IDs are converted to IANA in browser responses. Up to ten shared candidates per employee are accepted; keys are unique, case-sensitive, 1–40 ASCII letters/digits/underscore/hyphen and cannot be own. Names are at most200 characters. Actual shared-calendar membership/discovery from Outlook is not implemented; replace this trusted candidate lookup later if the internal directory provides it, keeping Exchange permission checks.

## API

All require Windows authentication and an active registered/mapped employee. No client-selected UserId or SMTP target is accepted.

| Endpoint | Purpose |
| --- | --- |
| GET /api/schedule/calendars | Allowed calendar keys/names, effective rights and live-update capability |
| GET /api/schedule?from=2026-10-01&to=2026-11-01&calendar=own | Selected calendar date range plus employee's outstanding tasks |
| GET /api/schedule/stream?from=2026-10-01&to=2026-11-01&calendar=own | SSE schedule snapshots, with the same permissions |

`from` is inclusive and `to` exclusive, local dates in ScheduleTimeZone; ranges are1–42 days, years1900–2100. Default calendar key is own. Appointment results cap at1000; outstanding tasks page in batches of100, up to500. Responses and UI explicitly indicate truncation rather than claiming a complete schedule. Disabled/unconfigured connection returns503, inaccessible calendar403, invalid range/key400, excess streams429. Errors do not return SOAP, credentials or mailbox addresses. No write endpoints exist.

## Verification and internal acceptance

- Both Release apps build; no new runtime packages or SQL migration.
- `dotnet run --project Backend/tools/ScheduleChecks/ScheduleChecks.csproj -c Release --no-restore` uses fake Exchange responses to verify employee-context delegate access, effective/private rights, CalendarView UTC boundaries and occurrences, all-day/cancellation, task paging and due dates, denied/revoked rights, owner-only subscription invalidations, event-driven refresh and unsubscribe/cancellation. NuGet audit metadata may be unavailable on the disconnected development machine; no new package dependencies were introduced.
- `node tools/verify-schedule.mjs` checks day/month/all-day rendering, task filters, literal text, notifications, authenticated SSE, no polling/storage, stale-month protection, manual shared refresh, invalid-data clearing and reconnect lifecycle.
- Existing MailChecks and verify-email.mjs remain regression checks for email.
- `powershell -NoProfile -File Backend/tools/Test-Schedule.ps1` verifies the real local HTTP/Swagger/auth/origin/disabled configuration paths without contacting Exchange.

Internal acceptance still requires real EWS authentication/TLS, mailbox mappings and service scope; two employees; read-only versus editor delegates; private-item denial/allowance and permission revocation; recurring exceptions/all-day/timezone/DST; new/changed/deleted/completed items; notification latency/reconnect/IIS buffering; owner-scoped shared notifications; and Exchange throttling. This implementation does not provision or validate those internal rights automatically.

References: [EWS CalendarView](https://learn.microsoft.com/en-us/exchange/client-developer/web-service-reference/calendarview), [effective rights](https://learn.microsoft.com/en-us/exchange/client-developer/web-service-reference/effectiverights), [delegate notification limitation](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/handling-delegation-related-errors-in-ews-in-exchange), [streaming notifications](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/how-to-stream-notifications-about-mailbox-events-by-using-ews-in-exchange).

Local acceptance completed: authenticated HTTP/Swagger/disabled/origin/range checks passed; portal parity passed (328 baseline files unchanged, six routes,313 original resources); the actual browser displayed the unavailable/read-only planner, expanded it, navigated months/today and reported no JavaScript errors. Simulated protocol and frontend lifecycle tests passed. Screenshot: E:/GatePortal/outlook-calendar-tasks.png. These checks are not a live Exchange connection.
