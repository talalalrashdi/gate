# Role lifecycle, workstation history and custom popups

Implemented 1 November 2026. Existing installations apply migration065 after064. Fresh `Deployment/CompanyPortal-Setup.sql` includes001–065. Historical CurrentData exports and offline ZIPs are not rebuilt by this change.

## Roles

Super admins can create a role and select its sections in الأدوار والصلاحيات. New names start with `CompanyPortal.`. Creation does not assign employees or groups. Existing memberships remain managed by the security source.

Deleting a portal-managed role sets its source Active to0 and deactivates its section mappings. Membership rows remain. `CompanyPortal.Admin` is protected. Unrelated security roles can still be mapped to portal sections but cannot be deleted here. Portal.ManagedRoles records which role names this editor owns; the seven standard scoped portal roles are registered initially. Deleted names are not silently reused or reactivated. Role/permission changes do not create admin-history entries, as requested.

Development031 installs `Security.Role_Create` and `Security.Role_Deactivate` against local SecurityDB. **Internally these two procedures must be mapped to the approved security database** alongside the existing role catalog and effective-membership readers. Migration065 installs clear failing placeholders if the writers are absent; it does not assume the internal schema matches the sample. Each writer participates in its caller's transaction and must reject duplicates/protected names. Runtime SQL EXECUTE grants follow the existing installation approach; no new connection string is added.

## Machine names

CentralLog.ApplicationError, DatabaseError and fallback error files already use the actual `Environment.MachineName` in both applications. Migration065 adds nullable WorkStation metadata to Portal.AdminChanges and Mng.CurrentStatus, plus dismissal records for custom popups. Old rows are left null, rather than inventing past machine identities.

The API explicitly sets the SQL connection's WorkstationID to `Environment.MachineName`. New record defaults use SQL HOST_NAME(), which receives that application-host value. On IIS this is the **API server**, not the employee's workstation. User settings and existing read-tracking records are unchanged. History details display the machine when recorded. Permission changes still have no history entries.

## Custom popups

Under التنويهات, the new تنويهات مخصصة editor accepts a free-text type and details, start/end dates and display flag. Plain text only: no HTML or links are interpreted. The checkbox makes it visible to registered portal users within the chosen period; unchecked saves a hidden draft. Deleting sets Active0. Editing a dismissed popup does not resurrect it; create a new popup for a separate announcement.

Mng.CustomPopups stores definitions. Portal.UserPopupDismissals stores one dismissal per UserId/PopupId. Dismissal resolves the employee server-side, is idempotent, persists across reloads and does not hide the popup for other employees. Closing failures stay visible with retry text. These records are independent from decisions and their read/dismiss behavior. Popup administration uses the existing notices permission and records normal business change history; role operations remain unlogged.

Employee GET `/api/custom-popups` returns only currently visible, undismissed rows. POST `/api/custom-popups/{id}/dismiss` requires the popup-dismiss header and allowed origin. Administration GET/POST `/api/admin/custom-popups` and PUT/DELETE `/{id}` require notices access and the custom-popups write header. Dates are stored in UTC; admin inputs and display use Oman time. Visible pages refresh once per minute with failure backoff, pause when hidden, and refresh on return. This is not an immediate push service. Existing popup-stack styling is reused without PDF actions.

## Hero loading

The selected database image loads first. The next rotating image is prepared two seconds before its turn and reused on rotation. Hidden pages cancel rotation/preload timers. Existing focal positions, image display copies, SVG animation and appearance settings remain intact.

Built-in fallback markup no longer starts its first image download before the account's image group is known. An empty/failed image-group lookup selects the original fallback; a1.5-second safety timeout also supplies that fallback when metadata is slow or unavailable. Fast managed themes leave all built-in image src attributes unset. Slow metadata can still cause a fallback download, deliberately favoring a visible hero over an indefinite blank area.

## Verification

Both builds pass with zero warnings/errors. Extended disposable SQL/API checks cover role creation, duplicate rejection, protected role, soft deletion, no permission audit, popup create/display, invalid dates, hidden drafts, per-user idempotent dismissal, workstation history, existing permission isolation/revocation,401/403 and Swagger. The disposable database is removed afterward.

Frontend checks cover role creation/deletion payloads and draft handling; safe popup text, stale-response dismissal protection, retry, visibility pause and access clearing; first/next image loading and rotation; existing theme framing/catalog/selection, decision notices, admin core/assets/labels and local offline assets.

Desktop browser checks confirm custom-popup save, readable rendering, dismissal across reload, new-role draft/discard, protected-super deletion control and no redundant built-in hero downloads for the selected managed theme. The temporary browser popup was soft-deleted afterward; its ordinary business history remains. No live employee role memberships or existing permission grants were changed for browser tests.
