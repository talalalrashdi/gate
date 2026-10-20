# Theme catalog and employee selection

Prepared 19 October 2026. This document supersedes the ThemeName-based schema and API examples in THEME_SETTINGS.md; its Windows identity, CORS and deployment configuration still apply.

**Deployment status, 19 October 2026:** the user applied migration 007 in SSMS. Direct Windows-authenticated SQL access now works after changing Codex approval routing to manual approval. Verified all three catalog definitions, the saved ThemeId 1 setting, an enabled/trusted foreign key, no UserSettings constraint violations, and the getTheme procedure returning the saved definition. Authenticated API checks also passed: catalog reads, theme save/reload, timestamp change/no-op behavior, anonymous rejection, invalid IDs/legacy names/client-selected identity rejection, and write header/Origin checks. Direct SQL confirmed the original ThemeId 1 restored with no constraint violations. LastChangeAt advanced during the deliberate change and restoration. The test API process was stopped afterward. Migration rerun, inactive-definition scenarios, browser and IIS acceptance remain unverified.

## Current administration

Theme creation, editing/copying, appearance controls, activation/default/order and read-only desktop preview are implemented. See [THEME_ADMINISTRATION.md](THEME_ADMINISTRATION.md). Migration016 adds appearance fields and extends the catalog; earlier deployment notes below describe the original catalog milestone.

Visibility, role previews, soft deletion and an explicit default/apply-to-all action are now available; see [THEME_PUBLICATION.md](THEME_PUBLICATION.md).

## Simple model

`Master.Themes` contains available theme definitions. `Portal.UserSettings` stays in the Portal schema and references a definition using ThemeId. `Security.User_getByUsername` continues resolving authenticated NTName to the external SecurityDB UserId. No duplicate employee table is introduced.

| Master.Themes column | Meaning |
| --- | --- |
| ThemeId | First column, int identity primary key; stable reference |
| ThemeName | nvarchar(200); editable display name |
| LayoutKey | nvarchar(50); implemented layout: official, work or national-day |
| DisplayOrder | Nonnegative int; controls menu order |
| IsDefault | bit default 0; identifies the active fallback |
| Active | bit default 1; available for selection |
| LastChangeAt | datetime default GETDATE(); later administration must update it on actual changes |

Initial definitions are الرسمي / official, العملي / work, and اليوم الوطني / national-day, in that order. The first is the default. Menu numbers describe display order; they are not ThemeId values. Names never determine which layout renders.

Multiple definitions can reuse a LayoutKey. A new active record using an existing layout appears in the menu without a frontend code change. A completely new layout still requires implementing its markup/styles/behavior and extending validation. This step adds no admin interface or arbitrary CSS/JavaScript configuration.

UserSettings keeps UserSettingId, UserId, Active and LastChangeAt; ThemeName is replaced by a non-null ThemeId foreign key. Migration 007 maps existing choices while preserving row IDs and LastChangeAt. Saving a different theme or reactivating a setting advances LastChangeAt; saving the same active choice leaves it unchanged.

Exactly one active default must be maintained. A filtered unique index prevents multiple active defaults; the API also rejects a catalog without exactly one default. Future administration should change the default transactionally. A default cannot be inactive. If a user's saved definition becomes inactive, reads return the active default without overwriting the saved choice; inactive/unknown IDs cannot be saved.

## API and frontend

All three endpoints require Windows authentication. Employee settings resolve the external user on every request; the request body never chooses UserId or NTName.

| Endpoint | Contract |
| --- | --- |
| GET /api/themes | Active definitions: themeId, themeName, layoutKey, displayOrder, isDefault |
| GET /api/user-settings/theme | themeId, themeName, layoutKey, isSaved, lastChangeAt |
| PUT /api/user-settings/theme | JSON with only themeId, e.g. {"themeId":2}; use an actual ID from GET /api/themes |

PUT retains the required `X-CompanyPortal-Request: theme` header and configured Origin checks. Invalid IDs return 400; unknown/inactive employees receive 403 from the settings endpoints. SQL/configuration failures return generic 503 responses.

The browser builds menu buttons from the catalog, uses ThemeId for selection/persistence, and uses LayoutKey only to render an implemented layout. Display labels use textContent. Initial reads do not create settings. Queued writes preserve the latest choice; a delayed initial response does not overwrite a newer local selection. Existing local preference compatibility remains. A separate cached definition supports temporary offline rendering; if the API is unavailable, local layout controls remain usable. On a successful reload the account setting is authoritative.

## Database deployment

For an existing database through 006, apply only `Backend/Database/Scripts/007_MasterThemes.sql` using the deployment account. For a fresh environment, first apply 001–006 and configure the real external security lookup as described in THEME_SETTINGS.md. Keep the development sample SecurityDB out of internal deployment.

From Backend, the deployment command is:

```powershell
sqlcmd -S localhost -E -b -f 65001 -i Database/Scripts/007_MasterThemes.sql
```

Use the destination server and approved SQL authentication/certificate configuration internally. UTF-8 input (`-f 65001`) preserves the Arabic seed labels. The API does not migrate databases at startup. Grant its runtime identity execution rights on Master.Themes_getAll as well as the existing Security/Portal procedures, using the approved least-privilege deployment arrangement.

## Verification and remaining work

Browser acceptance completed 19 October 2026 after manual approvals resumed: all three catalog themes saved through the browser and survived refresh with account-loaded status. With the API stopped, the portal displayed local-only status and theme controls continued working. The starting saved choice was work (ThemeId 2), which was restored in the browser and confirmed directly in SQL; no constraint violations. Both test servers were stopped. This verifies API-unavailable fallback, not a full air-gapped/IIS deployment. Advanced delayed-response and catalog-administration scenarios remain covered only by code checks or pending live verification. This supersedes the partial browser attempt below.

Partial browser acceptance, 19 October 2026: the in-app browser loaded the MVC portal, authenticated to the API, displayed all three catalog labels in order, selected الرسمي, and reported تم تحميل مظهر حسابك. Automatic approval review failed at model capacity before the attempted work-theme click executed. Browser save/reload and offline acceptance remain pending; no theme was changed during this browser attempt. Both test servers were stopped afterward.

Live API acceptance passed on 19 October 2026 using `Backend/tools/Test-ThemeSettings.ps1`. Fixed Windows PowerShell 5 JSON array enumeration in the test harness. ThemeId 1 was restored and verified in SQL. This does not replace actual browser/IIS checks.

Completed: API and MVC Release builds (zero warnings/errors), JavaScript syntax check, theme catalog VM checks, original theme selection compatibility checks, offline asset checks and diff whitespace checks. `node tools/verify-theme-catalog.mjs` covers arbitrary IDs/names, shared layouts, renamed labels, latest-choice writes, delayed reads and offline fallback. These are automated code checks, not live browser or SQL acceptance.

Remaining acceptance checks:

1. Verify migration rerun behavior and historical selection/LastChangeAt preservation against a suitable baseline; current foreign key integrity and the saved row have been checked.
2. Completed locally: start the API and run `powershell -File tools/Test-ThemeSettings.ps1` from Backend using a registered test account. It saves/restores the starting choice; a previously unsaved account gains a saved row containing its initial default.
3. Verify an additional definition using an existing layout, renamed labels, inactive selected-theme fallback, and rejection of inactive IDs against SQL and the authenticated API.
4. Check actual browser menu selection/reload, delayed responses, offline fallback and internal IIS Windows authentication.

Card ordering was subsequently implemented separately in [card order](CARD_ORDER.md), using migration 008. Account-backed custom group creation/deletion and pin/conceal settings remain later steps.
