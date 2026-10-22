# Authorized electronic systems directory

Implemented 22 October 2026. The top navigation button **الأنظمة الإلكترونية** opens the current employee's authorized applications, with descriptions and category filters. It replaces the illustrative systems and their demonstration launch dialog. No app permission or launch URL is edited by this feature.

## Employee behavior

- Opening the sheet fetches `/api/applications` using Windows credentials and `cache: no-store`. Every reopening fetches again; no polling or localStorage directory cache is used. Closing aborts pending requests and clears the rendered app/category list. Stale responses cannot populate a closed/reopened sheet.
- Search matches app names, descriptions and category names. Every whitespace-separated term must match. Arabic diacritics/tatweel, common alef variants, alef maqsura and letter case are normalized.
- Category buttons are derived only from the returned authorized apps, in the catalog order. Categories with no authorized apps are not disclosed. Everyone sees **جميع الأنظمة**; an unclassified app uses **غير مصنف**.
- Loading, no assigned apps, no matching search/category, and unavailable/unauthorized states are distinct. Failed requests clear the grid and offer retry; sample systems never serve as a fallback.
- Launch is a normal link opening `/api/applications/{id}/launch` in a new tab with `rel=noopener`. That API resolves the employee and rechecks current grants before redirecting. Returned directory JSON does not expose launch URLs, Windows names or UserIds. The target application must still enforce its own authorization.
- Escape/native dialog behavior, close/outside click, focus return, result counts and keyboard-visible focus are retained. Text is inserted through textContent; descriptions/categories cannot introduce HTML, script or arbitrary CSS.

The hidden legacy `#library` anchor remains for existing navigation. Links to it open the same header sheet. The static illustrative directory markup was removed from MVC; original `dist` comparison files remain untouched. Theme previews omit employee business scripts and do not fetch directory data.

## Metadata ownership

The external security database remains authoritative for app identity/name/URL and employee permissions, including whatever effective direct/group grants its adapter implements. Category/description presentation metadata is stored in CompanyPortal, keyed by the external stable AppId. There is no duplicated permission table or new permission source.

Migration `Backend/Database/Scripts/020_ApplicationDirectory.sql` adds:

| Table | Main fields |
|---|---|
| `Master.ApplicationCategories` | ApplicationCategoryId identity first; CategoryName nvarchar(200); DisplayOrder; Active bit default 1; LastChangeAt datetime default GETDATE() |
| `Master.ApplicationDetails` | ApplicationDetailId identity first; unique external AppId; nullable ApplicationCategoryId FK; AppDescription nvarchar(2000); Active bit default 1; LastChangeAt datetime default GETDATE() |

Missing/inactive description metadata yields an empty description. An absent/inactive category yields **غير مصنف** and null CategoryId; deactivating a category does not hide apps or revoke grants. Metadata for removed apps can remain in SQL without making those apps appear: the directory always starts with current authorized apps.

The `Security.Apps_getForUser` contract deliberately remains **AppId, AppName, LaunchUrl**, since personal and master card procedures consume it using INSERT EXEC. The admin adapter remains **AppId, AppName**. Neither adapter is replaced by migration 020.

## Administration

`/admin/applications`, also available from the admin sidebar **الأنظمة الإلكترونية**, supports:

- Create/edit categories, display order and active status.
- Choose an app's category or leave it unclassified.
- Edit a plain-text description, up to 2000 characters.
- Search the administrative app list by name.
- Independent row saves, unsaved indicators/navigation warning, and preserving other row drafts when saving an app/category. Category saves update existing app selection choices without replacing drafts.

Applications/names come from the existing protected `Security.Apps_getForAdministration` catalog. The editor does not create apps, change grants/roles, edit launch addresses, or permanently delete categories. Admin reads/writes require the employee's current effective `CompanyPortal.Admin` role on every request. The MVC page is a public shell only; protected data comes from the API using the visitor's identity.

Last-save-wins remains the concurrency policy. Category saves serialize through an application lock; per-app details upserts lock the unique AppId range. Actual changes update LastChangeAt; repeated identical saves preserve it. A duplicate category name is rejected by the save procedure. No audit-history feature is introduced.

## Procedures and API

Procedures: `Master.Applications_getForUser`, `Master.Applications_adminGet`, `Master.Applications_save`, `Master.ApplicationCategories_save`.

| Endpoint | Behavior |
|---|---|
| GET `/api/applications` | Enriched authorized list: appId, appName, description, categoryId, categoryName, categoryOrder |
| GET `/api/applications/{id}/launch` | Existing grant-checked redirect, unchanged |
| GET `/api/admin/application-directory` | Active source app catalog with saved metadata, plus all categories |
| POST `/api/admin/application-directory/categories` | `{categoryName,displayOrder,active}`; returns categoryId with 201 |
| PUT `/api/admin/application-directory/categories/{id}` | Same category fields; 204 |
| PUT `/api/admin/application-directory/applications/{id}` | `{description,categoryId}`; null category permitted; 204 |

Employee lookup is authenticated NTName → active external UserId. Client-supplied owners, grants and launch URLs are not accepted. Admin writes require JSON, `X-CompanyPortal-Request: application-directory` and existing exact-origin validation. Unmapped JSON fields are rejected. Category name is trimmed/nonblank, max 200 characters; display order is a nonnegative integer; Description is nonnull, optionally empty, max 2000 characters. Body limit 16 KiB. Missing source app/category returns 404; invalid/duplicate category/details return 400; non-admin 403; anonymous 401; integration failure 503. Responses use no-store.

The new employee procedure reads existing per-user permissions before joining metadata, so personal cards, master app cards and the directory continue sharing the same permission adapter. Existing card consumers can ignore the additional fields on `/api/applications`.

## Local and offline deployment

1. Apply migrations through 019, including its approved admin app-catalog adapter.
2. Apply `020_ApplicationDirectory.sql`. Reruns do not reseed or overwrite categories/descriptions.
3. For the **local sample environment only**, `Development/006_SeedApplicationDirectory.sql` annotates the four existing explicit sample app keys. It preserves existing metadata and never changes external app URLs, users or grants. The fourth sample app/category remains absent from the employee directory because that app is not granted.
4. Internally, skip that development seed. Configure the existing external app/role/identity adapters for the real source, then enter real descriptions/categories in administration. No change to the external permission procedure's three-column contract is required. When replacing the sample security source, verify/remap AppIds so sample metadata and card memberships are not accidentally attached to different real applications.
5. Grant the API runtime EXECUTE on the four new procedures, alongside existing adapter permissions. Do not grant employees direct SQL rights or runtime db_owner.
6. Publish/deploy both updated .NET 10 projects. The admin route and enriched directory require the new migration/API/frontend together.

Fresh-install `Deployment/CompanyPortal-Setup.sql` is regenerated through 020, with optional sample metadata only in TestSources mode. The older exact CurrentData snapshot and previously published Airgap bundle were not refreshed by this task: existing installations/snapshot restores need pending migrations 019/020 as applicable, the approved admin adapter, and updated app publishes. Do not rerun fresh setup on an existing database. SQL Server 2017 remains the offline engine target.

No Exchange configuration, EWS authentication or SQL permission grants are changed by the metadata migration.

## Verification

Local test command (isolated local sample environment only):

```powershell
powershell -NoProfile -File Backend/tools/Test-ApplicationDirectory.ps1 -BaseUrl http://localhost:5091 -TestSampleRevocation
```

The suite checks metadata/category round trips, inactive-category fallback, permitted/denied launches, no-op timestamps, strict validation, origin/header/anonymous controls, no exposed launch URLs, Swagger generation, and optional sample app/admin-role revocation. It restores grants, metadata and timestamps and removes only its uniquely named category. Do not use the sample SQL cleanup/revocation mode against the real internal security database.

Actual browser checks cover header opening, Arabic description search, category filtering, no-results state, Escape/return focus, cleared data on close, admin category creation, description/category save appearing on reopening, literal HTML text and independent row drafts. The original sample metadata is restored afterward. Real internal direct/group access mappings, target-application sign-in and destination IIS remain environment acceptance checks.

Local results: both Release builds passed with zero warnings/errors; migration/seed reruns preserved existing metadata; HTTP suite including sample app/admin revocation passed; master-card regression and rollback-only personal ownership tests passed; workspace synchronization, offline asset scan and frontend parity passed (328 original files unchanged, six routes and 313 resources). Browser showed only three granted sample apps and their categories, excluding the fourth ungranted app/category, with no horizontal overflow. Stopping the isolated API and reopening the sheet produced the Arabic connection error/retry state with zero app cards retained. The temporary HTTP/browser categories were removed and an exact JSON comparison confirmed original app metadata/category timestamps restored. Own test servers were stopped.
