# CompanyPortal

ASP.NET Core MVC frontend and a separate .NET 10 Web API foundation. Open `Frontend/CompanyPortal.Frontend.slnx` for the portal or `Backend/CompanyPortal.Backend.slnx` for the API. See the [API run instructions](Backend/README.md), [API/Exchange decisions](docs/API_FOUNDATION.md) and [frontend → API → SQL connection check](docs/CONNECTION_CHECK.md).

The current [theme catalog implementation](docs/MASTER_THEMES.md) separates stable ThemeId, editable ThemeName and LayoutKey. Migration 007 was applied locally by the user; direct SQL reads and constraint checks passed on 19 October 2026. Other environments require the migration before running the updated API. Code checks passed; Authenticated API save/read, validation and timestamp checks passed on 19 October 2026; ThemeId 1 was restored and verified in SQL. Migration rerun and browser/IIS acceptance remain pending.

The first employee feature now saves the selected theme through the API using the employee's Windows identity and external SecurityDB UserId. See [theme settings setup and deployment](docs/THEME_SETTINGS.md); sample SecurityDB creation is development-only.

The [master card policy](docs/MASTER_CARD_POLICY.md) now limits the workspace to five active master cards and enforces administrator-selected fixed positions. All five currently remain movable. Custom cards will be per employee and use server-authorized apps; the former local-only editor is gated off until that is implemented.

Built-in card ordering now saves through the authenticated API to SQL Server. See [card order setup and verification](docs/CARD_ORDER.md). Migration 008 was applied locally; browser/API/offline-fallback checks passed. Content concealment remains local. Previous local group and pin records are retained, but do not define current master cards or permissions.

## Current migration stage

The MVC frontend is organized into a shared layout and feature partials, essential assets are local, and the new project has been cleaned. Verification evidence and remaining recorded checks are in the [frontend acceptance checklist](docs/FRONTEND_ACCEPTANCE.md). The user authorized proceeding to the API foundation on the assumption that frontend browser/IIS acceptance is complete. The API foundation now builds independently; its actual domain/IIS deployment, database and Exchange integration are later steps.

The portable application is this `CompanyPortal` folder. Original source in `../dist/` and legacy tooling outside it remain retained as a comparison baseline; they are not required to build, publish or run either solution. The API introduces NuGet dependencies: include its offline package bundle when delivering source for offline builds.

See [migration status](docs/MIGRATION_STATUS.md) and the [agreed plan](../docs/COMPANYPORTAL_MVC_MIGRATION_PLAN.md).

## Run locally

Install the .NET 10 SDK. `Frontend/global.json` selects a stable 10.0.4xx SDK, accepting its latest installed servicing patch. The current project has no additional NuGet package references and does not require npm, Node.js, Vite, or a database to build/run.

For IDE development, use **Visual Studio 2026 (18.x), updated to a current servicing release**, with the **ASP.NET and web development** workload. Open `Frontend/CompanyPortal.Frontend.slnx`. Visual Studio 2022 does not support targeting .NET 10, even when the SDK is installed separately. Alternatively, build/run using the .NET CLI commands below. See [Microsoft's SDK/Visual Studio compatibility table](https://learn.microsoft.com/en-us/dotnet/core/porting/versioning-sdk-msbuild-vs).

From this directory:

```powershell
cd Frontend
dotnet build CompanyPortal.Frontend.slnx
dotnet run --project CompanyPortal.Web
```

Run .NET commands from `Frontend/` so its `global.json` SDK selection applies.

Open `http://127.0.0.1:5080/` for the portal and `http://127.0.0.1:5080/profile` for the profile page. Old `/index.html` and `/user-profile.html` links also resolve through MVC; `/design-b.html` redirects to `/` and preserves the query string.

The frontend local development profile intentionally uses HTTP on loopback. Its Development-only `/diagnostics/connection` page now checks MVC → Windows-authenticated API → SQL. Theme settings use direct browser-to-API Windows authentication; other employee/business content remains illustrative. See [the connection check instructions](docs/CONNECTION_CHECK.md).

## Browser data

Storage key names and JavaScript behavior are preserved. The migration does not inspect, export, clear, or replace browser storage.

The development port 5080 is a different origin from the original `http://127.0.0.1:5173`. Existing browser records remain at their original origin and are not automatically available on port 5080. Use a test browser/profile for comparisons.

If you intentionally want MVC to use the original origin after comparison, first stop Vite and then run:

```powershell
dotnet run --project CompanyPortal.Web -- --urls http://127.0.0.1:5173
```

Use the same browser profile and exact scheme/hostname/port. The existing scripts can initialize/update state when opened, just as the original application does; keeping the same origin is not a backup. Do not run Vite and MVC on the same port simultaneously.

## Project structure

- `Frontend/CompanyPortal.Frontend.slnx`: independent frontend solution.
- `Frontend/CompanyPortal.Web/Controllers/`: thin MVC controllers for page routes.
- `Frontend/CompanyPortal.Web/Views/Shared/_Layout.cshtml`: common Arabic document, tab metadata, app base URL and CSS/JavaScript section hooks.
- `Frontend/CompanyPortal.Web/Views/Shared/`: portal header/footer partials. Feature sections and overlay/script partials live under `Views/Home`; profile CSS is in `wwwroot/css/profile.css`. The generic error page stays independent for fault handling.
- `Frontend/CompanyPortal.Web/wwwroot/css/`: copied styles, with asset URLs adjusted for their new directory.
- `Frontend/CompanyPortal.Web/wwwroot/js/`: feature-named JavaScript, including `site.js` and `personal-workspace.js`. Selectors/events use descriptive names; saved browser keys retain compatibility.
- `Frontend/CompanyPortal.Web/wwwroot/assets/`: required images, fonts, magazine pages, PDFs and existing licenses. Twelve proven unused files were removed; the [cleanup manifest](docs/frontend-cleanup.json) records their hashes and reasons.
- `Frontend/CompanyPortal.Web/wwwroot/vendor/iconsax/`: local icon stylesheet, fonts and upstream notice.
- `docs/frontend-baseline.json`: original file hashes and ordered stylesheet/script dependencies.
- `tools/verify-frontend.mjs`: optional migration verification; requires Node.js and the retained original `../dist/`.
- `tools/frontend-names.mjs`: old-to-new naming map used by migration checks, not a browser dependency. See [naming conventions](docs/NAMING_CONVENTIONS.md).
- `tools/verify-theme-selection.mjs`: executes theme selection with a minimal DOM to check defaults, saved preference compatibility and all theme buttons.
- `tools/verify-offline-assets.mjs`: checks automatic external resource references and local icon font dependencies without a browser.

Models and backend service layers will be introduced when real data requirements need them. No empty model/repository/API scaffolding is included.

## Verify the migration

With MVC running, execute from this directory:

```powershell
node tools/verify-frontend.mjs
node tools/verify-theme-selection.mjs
node tools/verify-theme-catalog.mjs
node tools/verify-workspace-settings.mjs
node tools/verify-offline-assets.mjs
```

The frontend check verifies original source hashes, rendered page parity with approved changes, script order, retained/static resources, CSS paths, removed-file absence and route status codes. It optionally accepts a base URL, such as `http://localhost:5083/companyportal/`. It requires the retained original `../dist/` for comparison; the theme and offline checks work independently of that baseline. These checks do not replace desktop/mobile browser interaction testing.

## Publish and internal network preparation

From `Frontend/`:

```powershell
dotnet publish CompanyPortal.Web --configuration Release --output ../artifacts/publish
```

Copy the publish output and run `dotnet CompanyPortal.Web.dll` from that output directory with a supported .NET 10 ASP.NET Core runtime. Windows IIS deployment additionally needs the matching Hosting Bundle and server configuration. A different OS/architecture or self-contained deployment requires a separately selected publish target.

Copying the parent folder transfers source for both eventual solutions, but offline building also needs the selected SDK and any future NuGet packages. This frontend currently uses only the installed shared framework. Prepare an offline package feed when package references are introduced; the future API has its own restore requirements.

Required icon resources and imagery now load locally. Outbound news/source hyperlinks still require access to their destinations. Isolated Edge acceptance passed 16 interaction scenarios with all non-local requests blocked and no external requests detected. Testing on the actual disconnected workstation and internal IIS deployment remains required. See [frontend acceptance](docs/FRONTEND_ACCEPTANCE.md) for coverage and remaining checks.

See [IIS and offline deployment](docs/IIS_AND_OFFLINE_DEPLOYMENT.md) for prerequisites and delivery instructions.

## Next steps

1. Verify portal/profile appearance and existing interactions on desktop/mobile, including visible themes 1/2/3 and storage behavior. Theme 1 الرسمي (`official` layout) is the initial default.
2. Complete the offline browser and actual internal IIS acceptance checks.
3. Retire/archive legacy files outside `CompanyPortal` only after frontend acceptance is confirmed. Continue the authorized API milestone using [the backend plan](docs/API_FOUNDATION.md).
