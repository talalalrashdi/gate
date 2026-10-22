# Master application-card administration

Implemented 22 October 2026. This extends [portal administration](PORTAL_ADMINISTRATION.md) and supersedes its original update-only card endpoint description.

## Scope and administration

At `/admin/cards`, an administrator can create an **applications** card, select applications, choose everyone or exact external role names (any matching role), save it hidden or visible, and set default order/fixed position. New cards start hidden in the editor. Existing five connected cards retain their original keys/rendering and can also be hidden or audience-restricted. The editor does not create new integrations, roles or employee application grants. Permanent deletion and a separate card preview remain deferred.

Each card saves independently, retaining other row drafts. Unsaved changes trigger a navigation warning. Role names are entered one per line, matching the existing effective-role procedure, case-sensitively. Hidden cards stay in the admin list and retain their memberships/employee order records. No catalog reset or apply-to-all order operation is included.

## Identity, permissions and employee behavior

Every admin endpoint checks the authenticated employee's current external `CompanyPortal.Admin` role. The employee catalog resolves current NTName → UserId, then current effective roles. No browser-supplied identity/role is accepted. App memberships are intersected with `Security.Apps_getForUser` on every catalog read; the launch endpoint independently rechecks the employee's app grant. Making a card public never grants its applications. A visible card with no permitted apps shows an empty state rather than revealing unpermitted app names.

Employee master definitions and app names are not restored from localStorage or cached there. Catalog failure leaves master cards unavailable until a successful reload, rather than treating an old account's browser data as permission. Existing browser storage remains untouched. Personal cards remain owner-scoped and separate; only the combined order includes both types.

Catalog/visibility changes take effect on portal reload. This does not push a live card-removal event to already open pages. App launch always reauthorizes independently; target applications must enforce their own access too. Hiding a connected card is a portal display rule, not a new restriction on that integration's underlying API.

## Order and fixed positions

Global active master positions are one-based. Fixed slots must be unique and within the active master count. If hiding a card would leave another fixed card beyond the new count, save is rejected: move/unfix the affected card first. Hidden drafts retain their intended order (1–200) and are validated against the active count when activated.

The server first places global fixed cards and fills remaining slots with movable defaults. It then filters by audience and compacts the resulting master list. Therefore a fixed card in global slot 4 can appear in slot 3 for an employee who cannot see a preceding card. No blank gaps are reserved for inaccessible cards. Fixed visible slots are enforced for combined master/personal ordering in both SQL and the browser. Saved movable order wins over defaults; new cards use their default priority among unsaved definitions. Hiding and later showing a card retains its saved record, subject to current fixed-slot normalization and current visible catalog.

Admin saves and employee order writes coordinate through a transaction-owned `CompanyPortal.MasterCards` application lock. Admin edits remain last-save-wins. Actual details, membership or role changes update LastChangeAt; no-op saves preserve it. No history/audit feature was added in this milestone.

## SQL and deployment

Apply `Backend/Database/Scripts/019_MasterApplicationCards.sql` after 018. It adds:

- `Master.Cards.CardType` (`nvarchar(30)`) and `Audience` (`nvarchar(20)`), preserving existing connected cards and timestamps.
- `Master.CardApplications` and `Master.CardRoles`, identity first, explicit string sizes, Active default 1 and LastChangeAt datetime default GETDATE().
- Updated `Master.Cards_get/save`, `Portal.UserCardOrder_get/set` and internal table-valued function `Master.Cards_visible`.
- A fail-closed placeholder `Security.Apps_getForAdministration` only if the adapter is absent.

The admin catalog adapter returns **AppId, AppName** for approved active applications, not launch URLs or grants. For local sample SecurityDB only, apply `Backend/Database/Integration/ConfigureAdminAppCatalog.sample.sql` after 019. Internally replace its SELECT with the real approved application catalog. Do not overwrite an existing real-source adapter with the sample. Employee access continues through the independent `Security.Apps_getForUser` adapter. No external SecurityDB data is changed by this adapter.

Runtime needs EXECUTE on the updated procedures and the new admin catalog adapter, plus its existing identity/role/app lookup rights. Preserve normal ownership chaining for the internal function; do not grant employees direct SQL privileges or runtime db_owner. Cross-database access must be provisioned deliberately for the actual security source.

Migration reruns preserve cards, memberships, roles, selections and the existing admin catalog adapter. The five connected keys and retained inactive baseline definitions are not reseeded or reactivated. Only the five supported connected cards and application cards appear in this editor. New application keys are generated internally as lowercase `master-<guid>`; users never enter a renderer key or HTML.

`Deployment/CompanyPortal-Setup.sql` is regenerated through 019 for fresh installs and includes the new adapter in sample-source mode. **The older CurrentData snapshot and previously published Airgap folders are not refreshed by this feature.** For an existing internal database/snapshot restore, apply 019 and configure the new adapter, then publish/copy both updated apps. Never rerun fresh setup over existing data.

SQL Server 2017 compatibility 140 remains the offline target; JSON/STRING_AGG features require an appropriate engine/compatibility setting. No SQL 2019-only table option or new package was added.

## Endpoints and contracts

| Endpoint | Purpose |
|---|---|
| GET `/api/admin/cards` | All supported cards, including hidden; type, audience, app IDs and role names |
| GET `/api/admin/cards/applications` | Protected administrative app-selection catalog |
| POST `/api/admin/cards` | Create application card; returns `{cardId}` with 201 |
| PUT `/api/admin/cards/{id}` | Update supported connected/application card; 204 |
| GET `/api/user-settings/card-order` | Only visible masters plus employee-owned cards, with filtered application metadata |

POST/PUT JSON: `cardName`, `displayOrder`, `isFixed`, `active`, `audience` (`everyone`/`roles`), `appIds`, `roleNames`. These are full saves; old clients omitting required active state must be updated with the frontend. Connected cards accept no app IDs. Application cards require 1–100 current catalog apps. Role audiences require 1–50 exact names of at most 200 characters; everyone uses an empty role list. Names are trimmed, nonblank, at most 200 characters. App/role entries must be unique. Body max 32 KiB. There are at most 100 created application-card definitions.

Writes require `X-CompanyPortal-Request: admin-cards`, JSON, and existing exact-origin validation. Anonymous 401, non-admin 403, invalid card details/fixed conflicts 400, integration failures 503. Protected responses use no-store. Employee order accepts an empty array only when the employee genuinely has no visible master/personal cards. Saved identifiers must exactly match the current authorized catalog.

## Verification and limits

Use isolated local development data for tests:

```powershell
powershell -NoProfile -File Backend/tools/Test-MasterApplicationCards.ps1 -BaseUrl http://localhost:5091
sqlcmd -S localhost -E -b -I -i Backend/tools/Test-MasterCardAudience.sql
node tools/verify-workspace-settings.mjs
```

The HTTP test creates its own uniquely named card, checks hidden creation/no-op/activation/roles/fixed slots/app filtering/launch denial/validation/Swagger and removes only its fixture. The SQL test uses a synthetic unused identity and rolls back role cases, per-audience slot compaction and preference preservation. Existing admin regression tests require an isolated database because they temporarily rename/fix original cards and optionally revoke sample roles.

Verified locally: both Release builds with zero warnings/errors; migration 019 application/rerun; full HTTP suite including valid order persistence for a generated card key; rollback-only role allow/deny/case, fixed-slot compaction and combined personal/master hidden-preference preservation; workspace synchronization regression; offline asset scan; frontend parity (328 baseline files unchanged, six routes and 313 resources). Actual browser created a hidden Arabic card, activated it for the admin role, selected granted/ungranted apps and confirmed only the granted app appeared in the employee portal. Saving that card preserved another row's unsaved draft. Final portal rendering showed the original five cards without horizontal overflow or JavaScript errors. All test cards were removed; original five names/order/fixed flags/LastChangeAt values remained unchanged. Real internal app/role mappings, actual AD group inheritance and target IIS deployment still need internal verification. No Exchange authentication configuration changed.
