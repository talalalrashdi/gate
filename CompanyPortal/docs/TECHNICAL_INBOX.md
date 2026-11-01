# الإسناد الفني, section links and loading

Implemented 1 November 2026.

## Inbox contract

The new connected workspace card participates in the existing master-card administration, ordering, fixed positions, audience and user visibility mechanisms. It shows five requests per page, stable card height and borders between rows. Seven local samples exercise paging and optional values.

The details text is the row title. Each row includes its type, received date, source-owned read state, optional document number, optional office number and an attachment indicator. Empty optional values produce no empty labels. Long details are clamped with the full text available as a tooltip. The attachment indicator does not download a file; no attachment path or item-link contract has been supplied yet. The app-level opening link reuses `TechnicalServices:IsnadUrl`.

Employee identity resolves through `Security.User_getByUsername`. The API passes the resolved UserId, never a browser-selected employee ID, to:

- `Portal.Isnad_Inbox_Get @UserId`: returns TechnicalInboxId (bigint), RequestType, DocumentNumber (nullable), OfficeNumber (nullable), Details, HasAttachment (bit), ReceivedAt (datetime), IsOpened (bit).
- `Portal.Isnad_UnreadCount_Get @UserId`: returns a single integer count of unopened, active, due inbox entries belonging to that employee.

Read-only API routes: `GET /api/technical-inbox` and `GET /api/technical-inbox/count`. IDs serialize as strings. Both require Windows authentication and a registered active employee, and use private/no-store responses. Count returns no inbox rows. SQL exceptions are logged and return a clear Arabic 503 message.

The unread count is authoritative from the source. Portal clicks do not mark requests read. The source application updates IsOpened; the portal reflects it on the next refresh. While the page is visible, existing inbox refresh behavior checks approximately every60–65 seconds with failure backoff. Hidden tabs stop requests and clear content. This is visible-page refresh, not instant push. Newly arriving rows receive a temporary60-second جديد badge; unread coloring lasts until the source reports opened.

## Database setup

`061_TechnicalInbox.sql` is applied locally and included in fresh-install Setup.sql. It creates the master card and adapter stubs, and extends the existing audited admin card procedures. Existing mapped integration procedures are preserved on reruns. Existing installations should run only migration061, not the fresh-install Setup.sql.

`Development/029_CreateSampleTechnicalInbox.sql` is applied locally. It only modifies a database marked CompanyPortalDevelopmentFixture, creates IsnadDB if missing, and seeds seven rows for the current resolved employee if that employee has none. dbo.TechnicalInbox is separate from outgoing dbo.Requests; submitting a request does not incorrectly create an incoming item. Reruns preserve existing records.

Internally, replace only the two adapter SELECTs with the real application's inbox and authorization logic. Keep the above contract, per-user permissions, stable newest-first ordering, future/inactive filtering and identical count filters. Grant the API only the runtime EXECUTE/source access it needs; no read/write permission to update inbox state is required. CurrentData exports and offline ZIPs have not been regenerated.

## Section navigation and decisions loading

All five secondary links use the measured sticky-header/subnav edge rather than a fixed scroll margin. A final correction after smooth scrolling handles changed header height and lazy layout. Manual wheel/touch/keyboard interaction cancels the correction; home/history navigation also cancels it. أخبار عامة lands on its masthead, which sits above its news body. Scroll highlighting uses the same reference.

The decisions card now displays five real-sized, noninteractive skeleton rows while data or lazy rendering is pending. Shimmer is disabled for reduced-motion users. Skeletons are removed on success or failure; refreshes retain loaded content. Decisions metadata still loads immediately so floating notices are unaffected.

## Verification

Both builds pass with zero warnings/errors. Real authenticated API checks cover source samples, nullable fields, attachments, employee isolation, source read acknowledgement/count, inactive filtering, admin/employee catalogs, anonymous401 and Swagger. Unique verification records were removed. SQL admin save/no-op tests were rolled back, and migration/sample reruns produced no duplicates. VM tests cover all five navigation anchors (including header-height changes and cancellation), pending decision skeletons, deferred and immediate technical inboxes, safe literal rendering and no read writes. Existing inbox/notice/offline checks pass.

Visual browser acceptance is pending because the browser tool fails kernel asset initialization. Check all five links in each theme, then move to the new card: page1 should contain five rows and page2 two sample rows, with no internal vertical scroll.

## Startup and readability follow-up

The initial server-rendered workspace now contains three neutral skeleton cards, each with five shaped loading rows. Actual permitted cards and the add-card tile wait for the account catalog. The placeholders disappear on success or failure, and failure messages remain available. They are not master cards and cannot be reordered or saved.

Technical inbox rows are explicitly88px (five rows plus four4px gaps =456px), with larger type/date/metadata and15px titles. The workspace frame remains680px. Forms/correspondence use a subtle2px hover lift, with existing surfaces and unread colors retained. Text and numbers are slightly larger; reduced motion disables hover movement and loading shimmer.

Suggested alternative unread palette, not applied: soft blue background #EDF4FA, border #BDD0E0, dark blue text #173F5F.

### Follow-up: inherited height cap

The technical list inherited layout.css's340px preview cap, clipping the fifth row despite the correct page size. workspace-loading.css now explicitly sets max-height:none on #technical-inbox-list. Five88px rows with four4px gaps use456px within the existing680px card. Startup placeholders are320px wide rather than stretching across the viewport. The magazine now prepares the selected issue immediately after its catalog loads; individual PDF pages/thumbnails retain lazy rendering and read tracking still requires visibility or opening the PDF link.
