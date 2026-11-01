# Institution status administration

Implemented 1 November 2026.

## Pages and permissions

`/admin/important-numbers` manages only important phone numbers. `/admin/institution-status` manages the current institution status and the four status definitions. Both use the existing `header-content` administration permission and API header, preserving current grants. The old `/admin/header-content` route/hash opens numbers. Overview status links open institution status. The global refresh/last-load toolbar and sidebar إدارة البوابة label are removed; error retries remain.

## Changing the live status

Select a new status and choose تطبيق الحالة. Confirmation names the old and new status; red uses destructive confirmation styling. Status changes are visible through the existing employee status reader when the portal loads. No scheduling or date-range feature was added: “from/to” means previous/new status.

Protected endpoints: GET and PUT `/api/admin/header-content/current-status`. PUT accepts `{ "colorValue": 1 }` with values1–4; identity is taken from the authenticated request, never a posted user ID/account. Existing Windows authentication, header and origin checks apply.

Migration `062_CurrentStatusAdministration.sql` adds nullable ChangedBy nvarchar(512) and UserId int to existing Mng.CurrentStatus rows. Old rows are retained and do not receive invented authors. `Mng.CurrentStatus_Set` resolves the authenticated account using Security.User_getByUsername, serializes current-status changes, appends a new current-status row and records old/new snapshots in Portal.AdminChanges in the same transaction. The employee-facing Mng.CurrentStatus_get contract stays unchanged. Saving the same status creates no row, timestamp update or audit entry.

`Mng.CurrentStatus_AdminGet` returns the current record and latest50 status audit entries. The API uses Portal.AdminAuthors_Get for display names, with account fallback. The page shows from, to, person and date/time. Full history remains in the existing super-admin change-history page. Timestamps are displayed in Asia/Muscat. Existing last-save-wins behavior is retained; the transaction records the actual previous committed status.

Local migration062 is applied. Fresh Setup.sql includes it; existing installations should apply only migration062. Existing runtime accounts need EXECUTE on Mng.CurrentStatus_Set and Mng.CurrentStatus_AdminGet. Fresh setup now includes Mng procedures in its existing runtime EXECUTE grants. No new role, database or appsettings setting was introduced. Historical CurrentData exports/ZIPs were not rebuilt.

## Discarding drafts

Section navigation and Back/Forward warn before leaving an unsaved editor. Cancel keeps editing. Confirm performs a fresh navigation/reload to the destination, discarding in-memory editor models and selections. A dedicated reload helper suppresses a second native unload prompt after the explicit confirmation. Clean section navigation still benefits from lazy-loaded assets. Unsaved drafts are not written to browser storage or the database.

## Verification

Both builds pass with zero warnings/errors. Shared admin/core/asset/history/label/offline checks pass, including alias authorization. Actual HTTP checks cover current-status read, invalid/missing values400, unauthenticated401, missing write header400 and valid Swagger. SQL rollback checks cover same-status no-op, correct actor/user ID/time, old/new audit and invalid status rejection; the live status and history remained unchanged.

Desktop browser acceptance confirmed separate sidebar items, removed label/toolbar, status selection confirmation, leave-without-save warning, discarded selection on returning, and no browser errors. No live status change was committed during browser tests.
