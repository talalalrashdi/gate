# Temporary event links in the secondary header

Administration: `/admin/events` → الفعاليات. Employee links appear immediately after وثائق تهمك, always last after the fixed links (multiple events follow creation/EventId order), and open the event application in a new tab with noopener/noreferrer. Titles are plain text. HTTP(S) only, no embedded credentials; destination applications enforce their own access.

## Admin settings

Title (nvarchar150), application URL (nvarchar2048), start/end and Active. Admins see hidden/future/expired rows as well as current rows. Labels distinguish مخفية / مجدولة / ظاهرة للجميع / انتهت. Edit, hide via Active, delete, styled confirmation, shared save/error feedback and unsaved-change guard reuse AdminCore. Each row gets its last-change label. History uses section `events`, item type `event`, before/after JSON, and records only actual changes. No-op updates retain LastChangeAt. Last-save-wins is unchanged.

Admin dates explicitly use **Asia/Muscat (+04:00)** independent of the browser time zone. They are transmitted with an offset, stored as UTC SQL datetime and compared using GETUTCDATE (start inclusive, end exclusive). LastChangeAt uses GETDATE like existing portal audit timestamps. Empty dates, invalid ranges/SQL datetime bounds, unsafe URLs are rejected.

## Database / API

Apply `Backend/Database/Scripts/051_HeaderEvents.sql` after050, then `052_HeaderEventsLast.sql`. Migration052 removes the old order column and parameter; it preserves existing events. It creates Mng.HeaderEvents (identity first, Active last, default1), GetActive/GetAll/Save/Delete procedures and extends the existing per-section role constraint with `events`. No sample live event is seeded. Existing super admins can manage events; limited roles require an explicit Portal.AdminSectionRoles entry. All endpoints retain Windows authentication; employee catalog also resolves a registered portal user. Write actions require the `events` request header and allowed Origin.

- GET /api/header-events: current active events for portal users.
- GET /api/admin/events: all rows, events admins only.
- POST /api/admin/events: create.
- PUT /api/admin/events/{id}: update/hide.
- DELETE /api/admin/events/{id}: delete.

Fresh CompanyPortal-Setup.sql contains052; do not run that fresh setup on an existing database. Current-data export is historical and unchanged. Required-procedure health checks include the four new procedures.

## No refresh

The employee page requests the catalog **once at page load**. There is no polling, stream, background refresh, expiry timer or extra call when simulating. Scheduling is evaluated by SQL when the page is opened; already-open pages retain their links until reloaded. Admin changes appear on the next page load.

## Simulation / breaking news

Existing Development-gated simulation menu has a ready **فعالية جديدة** button. Each click adds an explicitly labelled temporary link beside the real links. Clicking opens the existing local simulation dialog, not an external application. Reset clears only simulated links; reload also clears them. No writes or event-catalog refresh. All news importance labels now read **خبر عاجل**; importance eligibility and the maroon featured badge are unchanged.

## Verification

`node CompanyPortal/tools/verify-header-events.mjs`: safe link rendering, one fetch/no polling, simulation/reset/disabled guard and asynchronous load-race handling.

`CompanyPortal/Backend/tools/Test-HeaderEvents.ps1 -ApiBase http://localhost:5877`: local authenticated CRUD, anonymous/header/origin protections, URL/date validation, windows/visibility, no-op timestamp/audit, deletion and Swagger. Uses unique disposable events/audit entries and removes only those rows. Requires a local super-admin fixture user and SQL test permissions. Generic admin-core and admin-changes tests also cover shared permission and feedback behaviour.

Browser acceptance: event section/editor and field labels, unsaved-change confirmation/cancel/discard; local new-event simulation link immediately after وثائق تهمك, click preview and reset; no console errors. Browser draft was discarded without saving. API fixture test rows removed. Actual destination application links require internal acceptance after configuration.


## Event emphasis
Real and simulated event links have a moving green/maroon/bronze background with white text and a distinct جديد badge. The badge is shown for60 seconds from the link’s first appearance on that page, then hides while the link stays. It is not a per-user read tracker. Re-rendering does not restart the minute; a new page load starts a new minute. Reduced-motion preferences disable the animation. No order field remains in the editor, API contract or table; event links are appended after all fixed header items. Browser verified last position, actual changing gradient position, readable scrolled header and removed editor field; updated CRUD/no-op/history tests passed.

Event expiry uses a local one-shot timer only, no API refresh. Visibility/page-cache restoration recomputes elapsed time. Simulation links follow the same rule and reset preserves real links’ deadlines.
