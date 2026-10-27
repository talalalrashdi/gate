# Admin Phase 4 — overview and navigation

Implemented 27 October 2026. All assets, including Iconsax fonts, are local. No new packages or internet services are required.

## Interface

The sidebar has المحتوى، المكتبات، الواجهة، الإعدادات. Overview opens by default at /admin and is reached again through the logo; it has no sidebar button. The former shared-settings sidebar note is removed. Only permitted sections appear; a group disappears when it has no permitted sections. Section titles/descriptions remain in `admin-navigation.js`. Back/Forward, draft guards, and the narrow horizontal sidebar remain supported.

The overview replaces the welcome block and overview card counts. Counts remain inside البطاقات الأساسية. It shows current database summaries and quick links to all permitted sections. It refreshes when opened or retried, without background polling.

| Summary | Who sees it | Source/meaning |
| --- | --- | --- |
| حالة المؤسسة | header-content admins | Current status and the matching configured level title; last update is the current-status timestamp |
| مجلة الشهر | Any admin | Latest active magazine, issue number/date; display-only, no magazine admin section |
| التنويهات / التنبيهات | Respective channel admins | Eligible decisions now, count and first three titles; same publication/window/type rules and source permissions, independent of personal reads/dismissals |
| أخبارنا | media admins | Three latest active photo/video records, ordered by LastChangeAt then ID; hidden albums exclude their images. This is not general news from dbo.VNews |
| آخر التعديلات | Any admin | Last ten change summaries across their permitted sections; no snapshots or physical paths |

## API and database

- `GET /api/admin/overview`: section-filtered summaries and recent change summaries.
- `GET /api/admin/changes/latest?section=media`: latest change per item for a permitted section; invalid section returns400. Unauthenticated requests return401 and unauthorized requests403. Responses use private/no-store.
- Existing `Portal.AdminChanges_GetRecent` and `Portal.AdminChanges_GetLatestByItem` are reused. Filtering happens server-side before returning data.
- Migration045 adds only read-only `Portal.AdminAuthors_Get(@NamesJson)`. It resolves distinct author names through existing `Security.User_getByUsername` and `Portal.UserProfile_Get` adapters, falling back to the recorded Windows account when no display name exists. It adds no table or sample grant. SQL adapters may perform one lookup per distinct author; browsers make one batch request per section.
- Runtime SQL identity needs EXECUTE on these three read procedures plus the existing source readers. Existing schema-level EXECUTE grants cover them. No SQL write permission is introduced by Phase4.

## Last-change labels

`admin-changes.js` uses the composite section/item-type/item-ID identity, so a category and application with the same number remain separate. Existing rows with no recorded history show «لا يوجد تعديل مسجل»; unsaved new rows have no history label. Editor forms also show the selected item's label. Deletions retain their audit entry in the overview.

History loads once per visited section for the current page. Successful writes invalidate the affected section and coalesce a short burst of refreshes; preview requests do not invalidate history. A reload fetches fresh history, including other administrators' edits. Authorization is still checked on every server request; the browser cache grants no access. Dates are displayed in Oman time. History labels do not change draft snapshots or save business data.

## Deployment

Existing installation: apply `Backend/Database/Scripts/045_AdminOverview.sql`, then republish both API and MVC. Migrations043/044 must already be applied. Fresh installation: regenerated `Deployment/CompanyPortal-Setup.sql` includes001–045. Historical CurrentData exports are unchanged. Keep real identity/profile mappings when moving internally.

## Verification

- Both .NET builds: zero warnings/errors; admin JavaScript syntax and offline asset scan.
- `node CompanyPortal/tools/verify-admin-core.mjs`: Phase3 transport/draft/dialog regression checks.
- `node CompanyPortal/tools/verify-admin-changes.mjs`: batch/cache, composite identity, new/seed labels, save refresh and revoked-access behavior.
- `CompanyPortal/Backend/tools/Test-AdminOverview.ps1 -BaseUrl http://localhost:5091 -TestLocalSampleRoles`: authenticated summaries/history, invalid sections,401/403, Swagger. The optional localhost-only sample role test temporarily replaces the current sample super-admin grant with media-only access, then restores the original Active/LastChangeAt in finally and removes its exact temporary role/grants. Never run the sample-role switch internally.
- Desktop browser: grouped navigation, overview data, all eleven sections, local icons, and author/time after saving a temporary inactive number. The exact temporary number is removed afterward; normal audit entries remain.
- One existing image-content SQL timeout appeared in the earlier API log. A focused concurrent read of all nine active database images then returned200 for every image (36–856ms); the timeout was not reproduced. No image-read procedure or timeout setting was changed.
