# Read-only Exchange inbox

For the plain-language flow, unread-count examples and click behavior, read [How portal email works](HOW_EMAIL_WORKS.md).

Implemented locally on 19 October 2026. Live Exchange access is disabled pending internal configuration. The user deferred EWS/Outlook Web addresses and access setup until the air-gapped deployment and requested these settings in appsettings. No Exchange or AD permissions have been provisioned by this work.

## Behavior

- Latest inbox messages show subject, sender, received time and read/unread state. Message bodies, attachments and sending remain outside the email feature. Calendar editing is documented separately.
- The badge displays Exchange's unread count for the entire Inbox, not a count of visible messages. New unread mail is counted once, not added again to the unread total. Listing messages does not mark them read. Opening one in Outlook Web may mark it read according to Outlook Web settings.
- Exchange EWS streaming notifications report arrivals, read-state changes, moves and deletes. The API rereads the count/latest items when a change event arrives and sends a snapshot to the employee's browser. No timer polls the inbox.
- Native server-sent events (SSE/EventSource) deliver this one-way browser stream without a new JavaScript library, SignalR package, CDN or cloud service. This replaces the earlier proposed SignalR mechanism, keeping the same event-driven behavior with fewer dependencies.
- The initial subscription is created before the first snapshot. Exchange status-only messages do not fetch inbox data. A normal held-connection timeout renews GetStreamingEvents on the same subscription. Failure causes a new subscription and full snapshot after reconnect, reconciling events missed while disconnected.
- Browser disconnection clears private message rows/count, disables the open button and retries only the event-stream connection with 5–30 second backoff. No mailbox data is stored in browser storage or SQL. Unknown count displays `—`; zero is shown only when Exchange actually returns zero.
- Updates target seconds while both connections are healthy; delivery latency, Exchange throttling, browser suspension and actual event support must be tested internally. Closed browsers receive no updates.

## Configuration

Edit the API's `CompanyPortal.Api/appsettings.json`, an environment-specific appsettings file, or equivalent deployment configuration. The checked-in defaults keep Enabled=false, empty URLs and mappings, and AccessMode=WindowsDelegation. Example only:

```json
{
  "Exchange": {
    "Enabled": true,
    "EwsUrl": "https://exchange.internal.example/EWS/Exchange.asmx",
    "OutlookWebUrl": "https://mail.internal.example/owa/",
    "OutlookWebInboxUrl": "",
    "AccessMode": "WindowsDelegation",
    "MailboxAddresses": {
      "COMPANY\\employee1": "employee1@company.example",
      "COMPANY\\employee2": "employee2@company.example"
    },
    "LatestMessageCount": 10,
    "OpenMode": "Message",
    "InboxSelectedUrlTemplate": ""
  }
}
```

Do not copy example addresses as real employee mappings. NTName resolves an active UserId through the existing Security.User_getByUsername procedure before access. The SMTP address is then looked up from the server-side MailboxAddresses dictionary, case-insensitively. No address is inferred from a username or accepted from a browser. An unknown/inactive employee is denied; an unmapped employee is unavailable. This explicit configuration mapping is the initial small implementation. If the internal security database exposes mailbox addresses, replace the mapping portion of MailIdentityStore with that trusted lookup; no frontend change is needed.

LatestMessageCount must be1–20 (default10). Addresses must be HTTPS with no embedded credentials. There are no Exchange passwords in this application. Every EWS send now runs as the authenticated employee through WindowsIdentity.RunImpersonatedAsync, including streaming and cleanup. Each session retains/disposes its token and isolates HTTP connections/cookies. No EWS ExchangeImpersonation header or process-account fallback is used. The API's SQL connection still runs as its process identity.

IIS-to-Exchange requires configured Kerberos constrained delegation, matching HTTP SPNs and IIS settings; NTLM/automatic portal sign-in alone does not solve the double hop. No ApplicationImpersonation role is used. Keep features disabled until these prerequisites are tested remotely. See [calendar/authentication setup](EXCHANGE_CALENDAR_TASKS.md) for the current deployment instructions.
No additional tables/migrations/packages were added. Employee profiles/portal settings remain unchanged.

## Outlook Web opening behavior

Clicking a message opens an authenticated API redirect in a new tab. The API uses the caller's mapped mailbox, retrieves the current Inbox folder and the requested item metadata, and requires the item's parent folder to match that Inbox before redirecting. Deleted, moved or foreign-folder/mailbox IDs do not open. Browser-supplied mailbox addresses or URLs are never used. IDs are opaque and URL-encoded.

- `OpenMode: Message` (default): use Exchange's WebClientReadFormQueryString with the configured Outlook Web base address to open that exact message.
- `OpenMode: InboxSelected`: requires an internally tested InboxSelectedUrlTemplate containing `{itemId}`. The ID is encoded and the final URL must remain on the configured Outlook Web origin. No guessed route is shipped. Without a valid template, this mode is unavailable. This option cannot yet be promised to show the whole inbox with the clicked message selected on the actual installation.

The user requested an admin choice between these behaviors later. There is no admin UI/database setting in this milestone; appsettings is the configuration point. Keeping URL construction separate allows the future admin setting to reuse the same behavior. The separate `فتح البريد` button opens `OutlookWebInboxUrl`, independently of message-opening mode. Fill that field with the actual verified inbox URL from your internal Outlook Web. It must be HTTPS on the same origin as OutlookWebUrl. A missing inbox URL returns unavailable rather than silently opening the general Outlook homepage. No version-specific inbox route is assumed.

## Endpoints

All require Windows authentication and responses use private/no-store:

| Address | Behavior |
| --- | --- |
| GET `/api/mail/inbox` | Current employee's unread count and latest messages; initial/manual diagnostic read |
| GET `/api/mail/stream` | SSE `inbox` snapshots; browser's normal live-data connection |
| GET `/api/mail/open?itemId=...` | Recheck item against caller's Inbox, then redirect to the selected Outlook Web view |
| GET `/api/mail/inbox/open` | Redirect to the explicit OutlookWebInboxUrl |

No POST/PUT/DELETE/send/mark-read endpoints exist. Disabled configuration returns 503 without contacting Exchange. Missing IDs are rejected. Deleted/malformed IDs return 404 when Exchange reports those errors; other Exchange/access failures yield a generic 503 without response XML or mailbox configuration. The stream requires an allowed Origin when supplied; exact credentialed CORS origins apply as for existing API calls.

An SSE connection belongs only to its authenticated Windows account. Every message/15-second heartbeat rechecks registration and the mapped mailbox. Those heartbeat checks query identity/configuration, not the inbox. The combined mail/schedule default is four streams per account and 100 streams per API process; excess streams receive 429. Each active browser tab owns one EWS subscription. Disconnect triggers cancellation/unsubscribe (best effort if Exchange has already lost the subscription). A ten-minute connection lifetime forces reauthentication/reconnect and a fresh snapshot. There is no background mailbox worker after all tabs disconnect. This first implementation targets one IIS API instance; capacity limits, Exchange limits and mailbox counts must be reviewed before broad rollout.

The SOAP client uses built-in HttpClient/XML APIs with normal TLS validation, disabled HTTP redirects and isolated affinity cookies per session. The mail feature uses GetFolder, FindItem, GetItem, Subscribe, GetStreamingEvents and Unsubscribe. Calendar operations use the same authenticated transport. Streaming SOAP frames are bounded, reconstructed independently of HTTP chunk boundaries and parsed with DTD resolution disabled.

## Internal IIS setup

1. Confirm EWS is enabled for the employee mailboxes. Verify the exact EWS/Outlook Web URLs and the employee Windows delegation arrangement with the Exchange administrator.
2. Configure HTTP SPNs, IIS Windows authentication and constrained delegation from the API identity to Exchange HTTP. Trust the internal HTTPS certificate chain on the API server; never bypass certificate checks. Ensure DNS/network access and correct Windows authentication/SPN policies.
3. Supply trusted NTName→SMTP mappings and the settings above. Use environment configuration appropriate to the deployed server; no internet/cloud access is required at runtime. Keep MVC→API CORS origins exact and credentialed.
4. Use IIS in-process ASP.NET Core hosting, and verify response flushing and long-lived streaming through every proxy/load balancer. Disable buffering/compression for the event-stream route where necessary. A 15-second SSE heartbeat keeps the browser connection active; the upstream Exchange held request lasts up to one minute and renews. App-pool recycles interrupt streams and clients must reconnect.
5. Test two employees simultaneously, foreign/guessed message IDs, mailbox revocation, new arrivals, read/unread changes in Outlook Web/desktop, moving/deleting items, zero/large unread counts, reconnects and actual latency. Confirm specific-message links and separately test a full-inbox-selection template before enabling that mode.

## Verification and current limits

- Both Release projects built with zero warnings/errors; frontend parity preserved 328 original baseline files, six existing routes and 313 existing static resources. Portal script count is now 24. Offline source scan passed; no package additions.
- `dotnet run --project Backend/tools/MailChecks/MailChecks.csproj -c Release`: deterministic fake HTTP/Exchange responses verify protocol requests, authoritative count (greater than visible rows), safe link modes, explicit mapping, foreign-folder rejection, fragmented streaming, new/read/delete events, no inbox reads for status events, unsubscribe and stream limits. This is not a connection to real Exchange.
- `node tools/verify-email.mjs`: credentialed EventSource, count updates, literal text/encoded links, no polling or storage, disconnect clearing and reconnect lifecycle passed.
- `powershell -NoProfile -File Backend/tools/Test-Mail.ps1 -ExpectDisabled`: actual Windows-authenticated local HTTP tests passed anonymous rejection, origin protection, missing-ID validation, absent write routes and disabled503 responses.
- Actual browser on a separate test frontend port: unknown-count badge, unavailable Arabic state, disabled open button and zero demonstration email rows verified. An existing user frontend on port5080 was left running; the separate test port5082 used a process-only temporary CORS origin.

Real Exchange authentication, certificate/SPN setup, event delivery timing, successful end-to-end SSE data and real Outlook Web navigation remain unverified until internal details are supplied. No claim of completed air-gapped Exchange acceptance is made.

## Protocol references

- [EWS streaming notifications](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/how-to-stream-notifications-about-mailbox-events-by-using-ews-in-exchange)
- [GetStreamingEvents operation](https://learn.microsoft.com/en-us/exchange/client-developer/web-service-reference/getstreamingevents-operation)
- [Outlook Web read-form links](https://learn.microsoft.com/en-us/dotnet/api/microsoft.exchange.webservices.data.item.webclientreadformquerystring)
- [Employee delegate access](https://learn.microsoft.com/en-us/exchange/client-developer/exchange-web-services/delegate-access-and-ews-in-exchange)

## Calendar/task extension

Calendar/tasks now reuse the same Exchange configuration and authentication; see [EXCHANGE_CALENDAR_TASKS.md](EXCHANGE_CALENDAR_TASKS.md). ScheduleEnabled remains false until configured. Mail/schedule now share a configurable stream budget (default4 per account,100 per process), superseding the earlier fixed two-stream description. A normal tab has one mail stream plus one schedule stream.
