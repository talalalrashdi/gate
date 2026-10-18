# Employee theme settings

Implemented: 18 October 2026. This first feature saves only the employee's selected theme. It does not integrate Exchange, import browser tasks, or introduce other preferences.

## Data and schemas

`SecurityDB` is an external identity source on the same SQL Server. Local development uses the sample `SecurityDB.dbo.Users`; the real internal security database will replace that mapping. There is no duplicate users table in CompanyPortal.

| Object | Purpose |
| --- | --- |
| `CompanyPortal.Security.User_getByUsername` | Accepts `@Username nvarchar(512)`, matches the authenticated NTName, returns one active user's `UserId int` |
| `CompanyPortal.Portal.UserSettings` | Stores one theme setting per external UserId |
| `CompanyPortal.Portal.UserSettings_getTheme` | Reads an active theme setting |
| `CompanyPortal.Portal.UserSettings_setTheme` | Inserts/updates a theme, serializing writes to avoid duplicate user rows |

UserSettings columns, in order:

| Column | Definition |
| --- | --- |
| UserSettingId | `int IDENTITY(1,1)`, primary key |
| UserId | `int NOT NULL`, unique; external user reference |
| ThemeName | `nvarchar(50) NOT NULL DEFAULT (N'official')`; check permits official, work, national-day |
| Active | `bit NOT NULL DEFAULT (1)` |
| LastChangeAt | `datetime NOT NULL DEFAULT (GETDATE())`; advances on theme/active-state change |

There is no SQL foreign key across databases. The API resolves UserId through the lookup procedure for every read/write. The development user table has UserId first, NTName `nvarchar(512)` unique, Active/default 1, and CreatedAt/default GETDATE(). NTName is the full Windows name (`DOMAIN\username`), not a browser-supplied username. Local comparison follows the SQL database's case-insensitive collation. Confirm real identity format, uniqueness and UserId type during internal mapping; do not infer that an email address is the NTName.

## Local setup

From `Backend/`, with a database deployment account, execute scripts using SSMS or `sqlcmd -S localhost -E -b -i <path>` in this order:

1. `Database/Scripts/001_CreateDatabase.sql` (already applied).
2. `Database/Development/001_CreateSampleSecurityDB.sql` — **local sample only**; creates SecurityDB/dbo.Users and inserts the current Windows SQL login if absent. It does not reactivate an existing inactive user.
3. `Database/Scripts/002_CreateSchemas.sql`.
4. `Database/Scripts/003_CreateUserSettings.sql`.
5. `Database/Scripts/004_UserSettingsProcedures.sql`.
6. `Database/Scripts/005_RenameThemeColumns.sql` — renames the deployed columns/constraints and updates the procedures.
7. `Database/Scripts/006_RenameThemeNames.sql` — migrates the stored names/default/validation to official, work, national-day.
8. `Database/Integration/ConfigureSecurityLookup.sample.sql` — installs the local sample lookup mapping.

This list describes a fresh setup. On the existing local database, scripts through 004 were already applied, so migration 005 handled the column changes, and migration 006 now handles the theme-name change. Apply pending migrations in order and track which were applied; do not rerun historical 003/004 after migration 005. Future alterations belong in new numbered scripts. No schema changes occur automatically on application startup.

## API and employee identity

| Request | Result |
| --- | --- |
| `GET /api/user-settings/theme` | Windows authentication required; returns `{ "themeName": "official", "isSaved": false, "lastChangeAt": null }` when the active user has no active saved setting |
| `PUT /api/user-settings/theme` | JSON `{ "themeName": "work" }`, header `X-CompanyPortal-Request: theme`; returns 204 after saving |

Use the same header value in Swagger when testing PUT. Visible themes and stored/API names: **1 — الرسمي** (`official`, default), **2 — العملي** (`work`), **3 — اليوم الوطني** (`national-day`). The same names are used by frontend controls/events, CSS/DOM identifiers, the API and the table. Body properties selecting a UserId/NTName are rejected. Invalid themes are rejected. Unknown/inactive users receive 403 on reads and writes; the API does not automatically register them. SQL failures return generic 503 responses and are logged server-side. An inactive settings row reads as default; an explicit save by a valid active user reactivates that user's row.

**The browser calls the API directly with Windows credentials.** The API obtains NTName from `User.Identity.Name`, then resolves the external UserId. This avoids treating the MVC app-pool account as the employee. The existing MVC server-to-server connection diagnostic still uses process credentials and remains separate from this feature. No visitor identity is forwarded in a custom header or accepted from request JSON. SQL access uses the API's process/service identity; database and employee identities are separate.

Writes require JSON and the custom request header, with validation of a supplied Origin. The credentialed CORS allowlist accepts only configured portal origins, GET/PUT, Content-Type and that header. Disallowed origins cannot obtain a preflight grant; actual write requests with a disallowed Origin are rejected as well. No wildcard credentialed policy is used. Same-origin Swagger and non-browser Windows-authenticated test clients may supply the header without an Origin.

## Frontend behavior

The original 19 scripts keep their order; `theme-settings.js` runs last. It reads the configured API base from MVC metadata, fetches the employee's saved theme, and applies it through the existing theme controls. With no saved row it uses the default theme, without creating a row on a read.

Selecting a theme updates the existing local preference and saves to the API. A status in the theme menu distinguishes account loading/saving, success, account-registration problems and temporary local-only fallback. An API failure leaves the portal/theme controls usable and does not clear any existing browser storage. Local selections made while the initial server read is pending take priority; queued writes serialize and collapse obsolete unsent selections. Existing browser-only choices are not silently bulk-imported into the database. When service returns and the page reloads, the account setting is authoritative.

## Run and deploy

Start both solutions with the existing development profiles. Open the frontend at `http://localhost:5080/` or `http://127.0.0.1:5080/`; the API is `http://localhost:5081/`. Those two frontend origins are allowed in the API development configuration. Set `Api:BaseUrl` on MVC to the **browser-reachable** API root, including any IIS application path, with HTTPS in the internal deployment. Set `Cors:AllowedOrigins` on the API to the exact frontend scheme/host/port; origins have no path or trailing slash. Same-origin deployment needs no cross-origin allowlist. Browser intranet policy must permit integrated authentication to the API address.

For cross-origin IIS hosting, Windows-only IIS settings can reject anonymous OPTIONS before ASP.NET sees CORS. Enable Windows authentication and allow anonymous requests to reach the application's authorization/CORS middleware, or configure the IIS CORS module appropriately. Application authorization still protects settings; preflight alone is anonymous. The current IIS Express Windows-only profile is suitable for Swagger/same-origin testing, not cross-origin browser preflight unless adjusted. Do not weaken endpoint authorization or enable wildcard CORS to work around this.

For internal SQL deployment:

- **Do not deploy/run the Development sample SecurityDB script.**
- Deploy normal CompanyPortal scripts and an environment-specific replacement for `ConfigureSecurityLookup.sample.sql`. Adapt only the lookup SELECT to the real database/schema/table/columns; maintain its parameter and single active UserId result contract.
- UserIds must retain their identity meaning. Never move sample UserSettings into the real security environment; unrelated numeric sample IDs could belong to other employees.
- Provision the API service identity for the lookup and Portal procedure execution, and the required read access to the real security database's identity columns. A procedure in CompanyPortal does not automatically grant cross-database SELECT rights. A DBA can use narrow SELECT grants or module signing as appropriate; do not enable instance-wide ownership chaining/TRUSTWORTHY or grant sysadmin as a shortcut.
- Configure the destination connection string and certificates. No source edits to API/frontend are needed if the stored procedure contract is preserved. The actual external mapping, permissions, domain/browser and IIS deployment require verification there.

## Verification

Local API checks passed for save/read persistence, Windows-authenticated user resolution, anonymous rejection, invalid theme/body rejection, missing custom header, disallowed write origin, credentialed preflight and inactive sample-user denial. Tests restored the sample user's active state and theme afterward.

An isolated Edge session passed the actual browser → Windows-authenticated API → SecurityDB lookup → CompanyPortal save/reload path. Desktop/mobile screenshots were captured under ignored artifacts and reviewed; no page errors or automatic external requests were detected. Original migration checks passed for six routes, 313 retained resources and all 328 unchanged baseline files. API and MVC builds passed without warnings/errors. No actual air-gapped/domain IIS acceptance is claimed by these localhost tests.

Additional browser checks passed for rapid repeated selections, a user selection made during a delayed initial account read, and API-unavailable fallback/recovery. These used disposable browser contexts; no existing browser profile/storage was read or cleared. The sample account was left active with theme 1 (official). The local fixture is not production employee data.

Sources: [Windows authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/windowsauth?view=aspnetcore-10.0), [credentialed CORS and IIS preflight](https://learn.microsoft.com/en-us/aspnet/core/security/cors?view=aspnetcore-10.0), [cross-database ownership chaining](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/cross-db-ownership-chaining-server-configuration-option).

## Theme names and last-change migration — 18 October 2026

Script 005 preserves rows and stored design keys while renaming `Theme` to `ThemeName` and the settings table's `CreatedAt` to `LastChangeAt`, including the related default/check constraint names. Scripts 003/004 remain historical deployment steps; apply 005 after them on both existing and fresh databases. Reapplying 005 is safe. The rename/check-constraint changes run in a transaction.

The API request/response field is now `themeName`; GET also returns `lastChangeAt` (null when no row exists). API examples, Swagger, browser synchronization and tests follow this contract. `LastChangeAt` uses SQL Server datetime/GETDATE(), not UTC. Initial save records its creation/change time; an actual theme change or reactivation updates the timestamp. Saving the same active theme again does not. Use the settings procedure for writes; ad-hoc SQL updates do not automatically maintain the date.

For existing rows, the previous date is preserved as a baseline because past updates were not tracked. Their true historical last-change time cannot be reconstructed; subsequent changes are tracked correctly.

The original numeric localStorage compatibility mapping still refers to the original legacy theme identities. Reordering the current buttons does not reinterpret or erase existing saved values. The sample SecurityDB user's `CreatedAt` remains a creation date; only the settings table was changed.

Migration 005 was applied locally and safely rerun. The renamed column types, identity order and enabled/trusted check constraint were verified. API tests confirmed actual-change timestamp advancement and no-op timestamp stability. Browser tests verified all three Arabic labels, the new 2/3 design mapping, save/reload and fallback/race behavior; the original frontend parity and theme compatibility checks passed.

## Canonical names — supersedes the original internal keys

Migration 006 translates existing values once: `majestic` → `official`, `formal` → `work`, and old `official` → `national-day`. The old `official` value meant the national-day design, so migration is guarded by the old check constraint and runs transactionally. Reapplying it does not remap the new official theme. It preserves row IDs, active state and LastChangeAt because the selected design has not changed. The table default, check constraint and write procedure now accept only the new names. Historical migrations 003–005 remain unchanged.

Frontend stylesheet names are `theme-official.css`, `theme-work.css` and `theme-national-day.css`. Matching DOM IDs/classes, data attributes, JavaScript keys/variables and view references use the new identifiers. Existing photographs and layout rules are unchanged. General calendar `official` flags still mean official observances and are unrelated to theme names.

New browser selections are stored under `companyportal-opening-theme-v2`. If absent, the old v1 numeric/semantic value is translated to the same design and written to v2. The original v1 and other legacy keys remain untouched; in particular, old v1 `official` becomes `national-day`, while new v2 `official` remains the default official theme. Account data is migrated by SQL before running the new API/frontend. Deploy both applications together because the old theme values are no longer accepted by the new API.

Verification: SQL migration ran twice with row ID/time preservation checks; API validation/save and LastChangeAt tests passed; browser label, selection, save/reload, rapid-change, delayed-read and offline-fallback checks passed. Frontend compatibility checks passed for both v1 and v2 preferences, six routes, 313 baseline resources and all 328 unchanged original files.
