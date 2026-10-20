# Theme visibility, publication and defaults

Implemented 20 October 2026. This supersedes earlier fallback-only default, inactive-only publishing, and uncropped/contained hero descriptions.

## Admin controls

- **مخفي — للإدارة فقط**: unavailable in employee menus, preferences and image requests. Administrators can edit/preview it.
- **معاينة — لأدوار محددة**: selectable by employees whose current effective roles include any configured role. Enter the exact external role name, one per line (up to 50 names, each up to 200 characters). The API uses the existing `Security.UserRoles_get`; that procedure already encapsulates the external direct/group grants. This feature does not create roles or grant employees any external permission.
- **مباشر — متاح لجميع المستخدمين**: live and selectable by every active registered portal user. Publishing alone preserves their current choices.
- **افتراضي وتطبيق للجميع**: makes a live public theme the default and replaces every active saved ThemeId with it transactionally. New users use the same default. Employees see it when opening/reloading the portal; existing open tabs are not forcibly refreshed. They may choose another theme afterward. It is an application action, not a permanent theme lock.
- Choosing a different default in the editor has the same apply-to-all effect, with explicit confirmation. Editing the current default's colours/name does not repeatedly reset employee selections. The gallery action can deliberately reapply the existing default to everyone.
- **إخفاء** and **حذف** ask for confirmation. Delete sets Deleted=1 and Active=0, removes it from the admin gallery and employee catalog, and retains references for controlled database recovery. Images/groups are not deleted. Replace the current default before hiding or deleting it.

Badges, save-button captions and confirmation dialogs distinguish role preview, publishing and global application. New/copied themes start hidden and nondefault. The admin top bar remains sticky while scrolling.

## SQL and API

Apply `Backend/Database/Scripts/018_ThemePublication.sql` after 017. It preserves existing definitions/settings, marking existing active definitions public and inactive definitions hidden only on first application. Rerunning does not republish hidden themes. Existing ThemeId remains stable.

Added `Master.Themes.Visibility` (nvarchar(20)) and `Deleted` (bit), plus `Master.ThemePreviewRoles`: identity first, ThemeId FK, RoleName nvarchar(200), Active bit default1 and LastChangeAt datetime default GETDATE(). Roles use exact case-sensitive matching against effective role names. Catalog/default writes share the existing transaction application lock. No-op saves preserve timestamps; actual role/visibility/default changes update them.

Admin GET/POST/PUT `/api/admin/themes` includes visibility and previewRoles. DELETE `/{id}` soft-deletes, POST `/{id}/apply-to-all` applies a saved public theme globally. All mutations require the current external admin role, the admin-themes request header and the existing allowed-origin checks. Hidden/nonpublic defaults are rejected. Employee catalog, saved selection read/write, image-group metadata and image bytes enforce current visibility/roles server-side; guessing IDs cannot bypass it. Administrators retain library-image access for editing.

Grant runtime EXECUTE on `Master.Themes_delete`, `Master.Themes_applyToAll`, and updated existing theme/image procedures. Existing external user/role lookup access is required. Use the deployment identity for schema changes; no db_owner runtime grant is needed. Restart API/frontend after deployment. No packages were added.

## Hero display

Both photographic presentation modes now fill the hero width using cover while preserving image proportions. The complete-design mode additionally replaces the original decorative scene and disables the extra photo zoom. Some vertical content may crop when image and hero proportions differ; there are no empty side columns. Combined national-day SVG animation is retained, with separate original portrait/flag/calligraphy hidden.

## Validation

`Backend/tools/Test-ThemePublication.ps1` is local-development only. It verifies Swagger, hidden/role/public visibility, allowed/denied selection and metadata, protected default deletion, request header/origin checks, role save/no-op timestamps, and deletion. Global/default preference updates and private-image byte/fallback checks use rollback-only SQL transactions, so current defaults and employee choices stay intact. It removes only its own fixtures. Browser checks cover role-preview save, publish/hide/delete confirmations, cancellation of global application, full-width image fitting, and sticky top-bar placement.
