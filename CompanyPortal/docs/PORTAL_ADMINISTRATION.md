# Portal administration

27 October 2026 — **change history (admin Phase 2).** Migration 044 adds `Portal.AdminChanges` (AdminChangeId, ChangedAt, ChangedBy, Section, Action create/update/delete/apply-to-all, ItemType, ItemId, ItemTitle, OldJson, NewJson). The 19 admin save procedures take a trailing `@ChangedBy nvarchar(512)=NULL` (the API passes the signed-in Windows name; direct SQL calls fall back to `ORIGINAL_LOGIN()`), snapshot the item with `Portal.AdminSnapshot_*` after taking their locks and again just before COMMIT, and call `Portal.AdminChanges_Add` inside the same transaction. No-op saves and failed saves write nothing. Snapshots exclude `LastChangeAt` and image bytes; child lists are included (card apps/roles, image-group items, theme preview roles, tab documents).

| Section | Item types (procedures) |
| --- | --- |
| `cards` | card (`Master.Cards_save`) |
| `applications` | category, application (`ApplicationCategories_save`, `Applications_save`) |
| `documents` / `safety` | tab (`Portal.DocumentTabs_Save`, section from the tab) |
| `fixed-orders` | directive (`Portal.FixedOrders_Save`) |
| `notices` / `alerts` | notice-settings, notice-window (channel 1 / 2) |
| `media` | media, album (`Media_Save` also records an album whose cover it clears) |
| `images` | image (`Images_add`, `Images_delete`), image-group, theme (`Themes_setImageGroup`) |
| `themes` | theme (`Themes_save`, `Themes_delete`, `Themes_applyToAll` = `apply-to-all` with `UsersUpdated`; a replaced default is recorded too) |
| `header-content` | important-number, status-level |

Not recorded: employee settings (theme choice, card order, personal cards) and rows changed directly in SQL without these procedures (e.g. a magazine row or the current status colour). Read procedures for later phases: `Portal.AdminChanges_GetRecent(@Top, @SectionsJson)`, `Portal.AdminChanges_Search(@SectionsJson, @Section, @ChangedBy, @FromAt, @ToAt, @Page, @PageSize)` (one result set with a repeated `Total`), `Portal.AdminChanges_GetLatestByItem(@Section)`. `@SectionsJson` limits results to the sections an admin may see. **Any later migration that alters one of these save procedures must keep its `-- history` lines.** The API runtime identity needs EXECUTE on the read procedures when the overview/history pages are added (the save procedures call `AdminChanges_Add` under ownership chaining).

Verified: `.local/admin-history-sql-test.sql` (34 checks across every procedure: create/update/delete rows, no-op and failed saves write nothing, image bytes excluded, cover side effect, apply-to-all + previous default, fallback name, read procedures) runs inside a transaction that is rolled back; admin UI and API saves record the real Windows name; both Release builds clean.

27 October 2026 — **section permissions (admin Phase 1).** Every admin endpoint now uses the shared `[AdminSection]` attribute (`Backend/CompanyPortal.Api/Infrastructure/AdminSectionAttribute.cs`) instead of a copied check. It resolves the Windows account through `Portal.AdminAccess_get` (migration 043) in **one** database round trip with **no cache**, so revoking a role applies on the next request. `CompanyPortal.Admin` manages every section. Other roles can be given single sections by adding rows to `Portal.AdminSectionRoles(SectionKey, RoleName)`; the table ships empty (roles not yet agreed). Section keys: `cards`, `applications`, `documents`, `safety`, `fixed-orders`, `header-content`, `notices` (decision-notice channel 1), `alerts` (channel 2), `media`, `images`, `themes`. The image library is also readable by `themes`. Diagnostics stays super-admin only.

Order of checks: account (401) → access lookup (503 on failure, never grants) → section (403) → for writes, `X-CompanyPortal-Request` (400) and Origin (403). The attribute runs before model binding, so a non-admin gets 403 even for an invalid body. Section-specific SQL errors remain in each controller. `GET /api/access` now returns `{isAdmin, isSuperAdmin, sections}`; `isAdmin` is true when at least one section is manageable and drives the portal admin icon.

`Portal.AdminAccess_get` captures the two identity contracts with `INSERT … EXEC`, so the internal versions of `Security.User_getByUsername` (one `UserId` column) and `Security.UserRoles_get` (one `RoleName` column) must keep returning exactly those single columns and must not use `INSERT … EXEC` themselves. Grant the API runtime identity EXECUTE on `Portal.AdminAccess_get`.

Verified: both Release builds clean; 28 API checks (all admin GETs, anonymous 401, header/origin/model validation, 404s, admin page routes); 18 section-role checks using a temporary local sample grant (only granted sections reachable, notices limited to channel 1, alerts PUT 403, employee image endpoints unaffected, revocation on the next request), restored afterwards; desktop browser opened all 12 admin sections without failed calls.

22 October directory update: [application directory administration](APPLICATION_DIRECTORY.md) at `/admin/applications` manages categories/descriptions only. It does not create apps or change grants/launch URLs.

22 October update: [master application-card administration](MASTER_APPLICATION_CARDS.md) now adds creation, app selection, everyone/role audiences and show/hide controls. The historical update-only contracts below are superseded by that document. The five connected cards retain their renderers.

The portal header now displays a shield/check admin icon immediately beside the theme button, only after `/api/access` confirms `isAdmin: true`. It opens `/admin`; the former workspace-toolbar admin text link has been removed. Failed/denied lookups leave the icon absent. Notices and alerts start hidden and can be shown with the existing bell toggle; no storage keys or visibility persistence were introduced.

Implemented 19 October 2026. `/admin/cards` manages existing active master cards: display name, one-based default order and fixed/movable policy. It does not create/delete master cards, manage app grants, edit themes or grant roles.

## Identity and permissions

Windows authentication supplies NTName. `Security.User_getByUsername` resolves the active external UserId. `Security.UserRoles_get(@UserId int)` returns distinct effective `RoleName` strings (`nvarchar(200)`). The exact stable role key `CompanyPortal.Admin` manages every section; see the 27 October section-permissions note above for per-section roles. Application access alone does not grant administration rights.

Users and roles remain in the external security database. Replace the role procedure's SELECT with the real source internally, combining active direct and group assignments as appropriate. The local sample implements direct user assignments only. AD group evaluation and the internal group/role schema are not supplied or implemented. Browser-supplied roles and user IDs are never trusted.

Every admin read/write resolves the user and checks current roles; there is no role cache. Inactive/unregistered users or missing roles receive 403; lookup failures yield 503 and never grant access. Anonymous API requests receive 401. Revocation takes effect on the next request; an already in-flight request may complete.

MVC serves a public HTML shell containing no protected card data. The browser calls the API with the visitor's Windows credentials; MVC's process identity is not used to authorize the visitor. The portal displays the admin icon only when the capability lookup succeeds. The API remains the authorization boundary.

## Endpoints and data

| Method/address | Purpose |
| --- | --- |
| GET `/api/access` | Authenticated current account's `{isAdmin}` capability |
| GET `/api/admin/cards` | Admin-only active definitions including CardId, stable CardKey, name, order, IsFixed and LastChangeAt |
| PUT `/api/admin/cards/{id}` | Admin-only update, returns 204 |

PUT accepts only `{cardName, displayOrder, isFixed}`; all three are required. Names are trimmed, nonblank and at most 200 characters. The request cannot select owner, role, CardKey, Active or timestamps. Writes require JSON and `X-CompanyPortal-Request: admin-cards`; existing exact-origin checks and credentialed CORS apply. Responses use no-store.

Migration 012 adds `Master.Cards_get` and `Master.Cards_save`. Save uses a transaction and existing locked `Master.Cards_setPosition` validation. Fixed slots must be within the active master count and cannot collide. Movable default ranks may tie; CardId breaks ties. Saved employee ordering remains for movable cards. Personal cards remain per-user, and fixed masters reserve global positions even alongside personal cards.

True no-op saves preserve LastChangeAt; actual name/policy changes update it, including case-only names. IDs/keys stay stable. Reload the employee portal to receive the updated catalog. Concurrent administrator edits use last-save-wins; editing locks and audit history are outside this first page.

## Local setup

After existing scripts through 011, run in order with your development Windows SQL login:

1. `Backend/Database/Development/003_CreateSampleRoles.sql`.
2. `Backend/Database/Integration/ConfigureRoleLookup.sample.sql`.
3. `Backend/Database/Scripts/012_MasterCardAdministration.sql`.

Development/003 creates SecurityDB Roles/UserRoles with identity keys, explicit nvarchar lengths, Active default 1 and LastChangeAt default GETDATE(). It explicitly assigns CompanyPortal.Admin to the existing sample user matching ORIGINAL_LOGIN(), not every employee. Reruns do not reactivate inactive existing grants. No role-management HTTP endpoint is included.

Start both solutions and visit `http://localhost:5080/admin`, or follow the portal's admin link. Swagger lists the API endpoints, subject to the same permissions.

## Internal / air-gapped deployment

Do not deploy Development/003 or sample grants internally. Configure `Security.UserRoles_get` against the approved real external database on the same server, returning effective roles for the resolved UserId. Confirm whether groups mean database or AD groups before adding group-specific integration. Provision the intended real administrator explicitly in that source.

Apply numbered migration 012 after 011 using a deployment identity. The API runtime SQL identity needs EXECUTE on Security.User_getByUsername, Security.UserRoles_get, Master.Cards_get and Master.Cards_save, plus existing employee-feature permissions. Do not grant employees direct SQL execution of administration procedures, broad Master-schema execution, or db_owner. Runtime SQL identity and employee Windows identity are separate: the API checks the employee role before calling admin procedures. Provision cross-database access to approved security views/tables deliberately; do not enable TRUSTWORTHY or broad cross-database ownership chaining as a shortcut.

Use existing Windows authentication, HTTPS, exact frontend CORS origins and environment-specific connection strings. No packages, remote assets, passwords or tokens were added.

## Verification

- Both Release builds: zero warnings/errors.
- `Backend/tools/Test-Administration.ps1 -TestSampleRevocation`: passed anonymous denial, current capability, strict fields, blank names, invalid IDs/positions, origin/header checks, change/no-op timestamps, case-only names, fixed-slot conflicts and changed names reaching the employee catalog.
- Temporary sample role revocation immediately produced admin GET/PUT 403 and capability false; ordinary app access remained available. Grant and original card names/order/fixed policy were restored in finally. This does not simulate a second interactive Windows account or actual AD group inheritance.
- Actual browser: name/fixed save, reload persistence, restoration of original name/movable policy. Five original active masters remain movable; user themes and personal data were not reset.
- Frontend parity: 328 original files unchanged, six existing routes and 313 original static resources verified; portal scripts now include the admin-capability check. Workspace synchronization checks passed.

The test temporarily changes shared master-card settings. Run only against an isolated development API/database with no concurrent editing. `-TestSampleRevocation` additionally changes the current local sample role grant; omit it to skip grant changes.

## Administration layout

The Arabic/RTL admin area has its own shared `_AdminLayout`, local fonts and responsive green sidebar, independent of employee-portal header styles. `/admin` opens the overview; `/admin/cards` opens card management directly. Section navigation uses URL fragments and supports browser back navigation.

The overview shows actual active/fixed/movable card counts after the protected catalog loads. The card editor has explicit labels, fixed/movable switches, unsaved-change indicators and per-card save buttons. Saving one row preserves unsaved edits in other rows. Authentication failures hide the workspace and leave section buttons disabled; the API remains the authorization boundary.

Image management is now implemented at `/admin/images`: upload/library, groups, membership ordering/activation, rotation/static defaults and theme-image assignments. See [INTERFACE_IMAGES.md](INTERFACE_IMAGES.md). Theme creation is implemented at `/admin/themes`; see [THEME_ADMINISTRATION.md](THEME_ADMINISTRATION.md). The shared layout still separates employee portal styling from administration.

Redesign verification: frontend Release build passed with zero warnings/errors; JavaScript syntax checks passed. Actual desktop browser checked section navigation, saved/restored a card name and confirmed another row's draft survived the save. Mobile layout checked at 390px without document overflow. Existing master-card names, order and fixed policy were restored.
