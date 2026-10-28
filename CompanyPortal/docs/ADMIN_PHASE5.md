# Administration Phase 5

Completed 28 October 2026. No new packages, CDN assets or internet services are required.

## Change history

Open `/admin/history` or **سجل التعديلات** in the sidebar. The overview's **آخر التعديلات** card links there. Per the user's final decision, the full history page/API are **super-admin only** and include all sections. Limited admins retain their existing section-scoped last-change labels and overview summaries.

- `GET /api/admin/changes?section=media&person=DOMAIN%5Cuser&from=2026-10-01&to=2026-10-28&page=1`
- `GET /api/admin/changes/{id}` returns snapshots for one entry, also super-admin only.
- Filters: exact section, free-text Windows-account substring, inclusive date range in the existing database/Oman wall-clock convention. Pages contain25 summaries, newest first. Person searches treat `%`, `_` and `[` literally. Empty/out-of-range pages retain the real total.
- Details load on demand and compare before/after with Arabic field labels. List additions/removals use stable IDs; changing image order does not falsely count an image as removed. HTML-looking values are rendered as text. Bigint IDs are strings to preserve precision.
- There is no undo, mutation endpoint or automatic history cleanup. Deleting an item retains its history.

Migration046 adds only `Portal.AdminChanges_GetPage` and `Portal.AdminChanges_GetById`. Existing audit/save behavior is unchanged; `Portal.AdminAuthors_Get` supplies friendly names with Windows-account fallback.

## Preview before saving — option A

Editors for **أخبارنا، التوجيهات السامية، التنويهات، التنبيهات، أرقام تهمك والحالة** offer **معاينة**. Themes keep their existing preview.

The shared modal loads `/admin/content-preview`, using real portal partials, CSS and the directive-text formatter. This first version uses the **الرسمي** template for content previews, stated in the banner. Draft values travel through same-origin messages to the exact frame; the frame rechecks section permission. Text uses DOM text APIs, never HTML interpretation. Media URLs must be protected API preview-token URLs; the existing root/file validation still applies to unsaved paths. Creating that short-lived token saves no database row.

The preview document loads only appearance, directive-text and preview scripts. It loads no employee preference, read-tracking, Exchange or business-action scripts. Drafts are never stored in the database or browser storage. Closing preserves in-memory edits/dirty badges. Repeated clicks cannot start overlapping previews; navigating away during a file check does not open an obsolete preview afterward.

Notice previews apply unsaved active/type/duration/window values to authorized decisions at the current time, showing up to three eligible examples or an empty-state explanation. Number preview includes current unsaved active rows/order; status preview shows the selected level's wording and steps. Preview does not publish hidden content or bypass file permissions.

## System health

Open `/admin/health` or **System health** in the super-admin sidebar. It is always available; `Diagnostics:Enabled` is no longer used. The old `/admin/diagnostics`, `/api/admin/diagnostics/run`, temporary portal button, view, assets and obsolete test were removed. The older Development-only `/diagnostics/connection` foundation check is separate from the retired admin setup page.

`GET /api/admin/health` runs read-only checks. Each returns **ok / warning / failed**, plain-English detail, ordered fix steps and a reference ID also logged by the API. The page shows **✓ OK / ⚠ Warning / ✗ Failed**, numbered lists, **Run checks** and **Copy report**, without polling. If clipboard access is unavailable, the selected report can be copied with Ctrl+C.

Checks cover Windows/browser/API identities, active UserId/roles, SQL connection/version/compatibility, the84 expected procedures through046, four folder roots (`PubsInfo`, `Magazines`, `docs`, `PortalMedia`), Exchange settings/live Inbox/Calendar/Tasks folder access, employee-photo response validity, API/frontend versions/build time, UTC server time and environment.

Important limits are stated in the report: there is no migration ledger, so schema coverage does not prove historical execution order; metadata visibility does not prove every business procedure executes; directory listing does not prove every file can be read; EWS folder probes do not test notification subscriptions, OWA browser sign-in or every delegate mailbox. Disabled integrations show warnings. Photo probes use the same Windows caller-credential flow as the portal and include no photo in the report.

Each probe has an8-second limit; the set has a55-second lifetime after authorization. Client cancellation is respected. Windows UNC enumeration may finish later if the operating system is waiting on a broken share. No permissions, certificates or service settings are changed automatically.

### Bootstrap setup

Normally CompanyPortal.Admin is required. If SQL/security authorization is unavailable, an explicitly approved Windows account in the API's `Diagnostics:BootstrapAccounts` can run only this read-only health endpoint:

```json
"Diagnostics": { "BootstrapAccounts": ["DOMAIN\\approved-setup-admin"] }
```

Restart the API after changing settings. This does not override a successful lookup denying super-admin access; a working security source must grant the real role. It grants no editor/history/mailbox access. Remove the entry when SQL and the admin role work. No bootstrap account is committed to appsettings.

Reports exclude passwords, connection strings, raw exceptions/SOAP and mailbox contents. Server/account names and reference IDs are deliberately available to the authorized IT operator; review reports before sharing them externally.

## Deployment

1. Existing database: apply `Backend/Database/Scripts/046_AdminHistory.sql` after045. Never run fresh-install Setup.sql over an existing database.
2. Republish API and MVC. Keep `HealthProcedures.json` in API publish output (copied automatically). The runtime identity needs EXECUTE on the two history readers and existing source readers; existing schema-level grants cover them, otherwise ask the DBA for object-level grants.
3. Open `/admin/health`, run checks and copy the report if needed. Correct source mappings, folders and Exchange settings internally.

Fresh installs use regenerated `Deployment/CompanyPortal-Setup.sql` through001–046. Historical CurrentData exports are unchanged. See [EXCHANGE_AUTHENTICATION_DECISION.md](EXCHANGE_AUTHENTICATION_DECISION.md) and [AIRGAP_IIS_GUIDE.md](AIRGAP_IIS_GUIDE.md) for the deferred Exchange/IIS configuration.

## Verification

- Both .NET projects build with zero warnings/errors; JavaScript syntax, shared-core/history/diff tests and offline assets pass.
- `Backend/tools/Test-AdminHistoryHealth.ps1 -BaseUrl http://localhost:5091 -TestLocalSampleRoles` checks401/403, full super-admin history, filters/totals/details, English health/steps/references/no-store and Swagger. Its optional localhost-only role test restores the exact sample grant Active/LastChangeAt in finally and removes its temporary role/grants. Never run that switch internally.
- `tools/verify-admin-history-diff.mjs` checks Arabic names, create/delete/no-op values, stable list IDs, additions/removals and literal HTML-looking text. Existing shared-core and batched-label tests still pass.
- An isolated disposable database/API tested30 history entries across25+5 rows, combined filters and literal wildcard searches. Missing procedures, four wrong folder paths and unreachable loopback Exchange/photo services produced English failures with steps/references. Actual portal settings were not changed for fault tests. A separate missing-database API with a process-only bootstrap account also returned an explicit SQL4060 message with server/process identity, steps and a reference. The disposable fixture database was removed after verifying its30 synthetic rows.
- Desktop browser: history/details/filtering; unsaved directive/media titles; notice, number and status previews; retained drafts; English health and Copy report. Audit count, read markers and complete employee theme settings matched the baseline after previews. No test preview was saved. Final checks also confirmed both retired admin diagnostics routes return404; history reset restores all records and local health reports13 OK checks plus5 expected warnings for disabled Exchange/photo integration.
- Real Exchange success, delegate permissions, live notification delivery and IIS delegation still need the internal environment; disabled/unreachable local tests do not prove those services work.
