# CompanyPortal

ASP.NET Core MVC frontend targeting .NET 10. The future Web API will have its own solution under `Backend/` beside `Frontend/`; it has not been created.

## Current migration stage

The MVC foundation and initial page/asset migration are implemented. Browser verification, shared layout/partial extraction, and final cleanup remain pending. Original source in `../dist/` and Vite tooling are retained for comparison. Do not edit both copies as parallel sources of truth; record intentional changes to the MVC copy and reconcile them before removing the original.

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

The local development profile intentionally uses HTTP on loopback. Production HTTPS hosting is a later configuration task. No authentication or API integration is implemented; existing employee/business content remains illustrative.

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
- `Frontend/CompanyPortal.Web/Views/`: portal, profile, and safe error views. Full-page views are retained initially to simplify comparison; shared layout/partials are the next organization step after browser verification.
- `Frontend/CompanyPortal.Web/wwwroot/css/`: copied styles, with asset URLs adjusted for their new directory.
- `Frontend/CompanyPortal.Web/wwwroot/js/`: feature-named JavaScript, including `site.js` and `personal-workspace.js`. Selectors/events use descriptive names; saved browser keys retain compatibility.
- `Frontend/CompanyPortal.Web/wwwroot/assets/`: copied images, fonts, magazine pages, and licenses. Unused asset review is deferred until final cleanup.
- `docs/frontend-baseline.json`: original file hashes and ordered stylesheet/script dependencies.
- `tools/verify-frontend.mjs`: optional migration verification; requires Node.js and the retained original `../dist/`.
- `tools/frontend-names.mjs`: old-to-new naming map used by migration checks, not a browser dependency. See [naming conventions](docs/NAMING_CONVENTIONS.md).
- `tools/verify-theme-selection.mjs`: executes theme selection with a minimal DOM to check defaults, saved preference compatibility and all theme buttons.

Models and backend service layers will be introduced when real data requirements need them. No empty model/repository/API scaffolding is included.

## Verify the migration

With MVC running, execute from this directory:

```powershell
node tools/verify-frontend.mjs
node tools/verify-theme-selection.mjs
```

The frontend check verifies original source hashes, rendered page parity with approved naming/tab/theme changes, static resources, CSS asset paths, expected route status codes, and absence of API/Vite review routes. The theme check covers selection logic and preference compatibility with a minimal DOM. Neither replaces desktop/mobile browser checks. The original baseline remains frozen; intentional MVC changes are recorded separately.

## Publish and internal network preparation

From `Frontend/`:

```powershell
dotnet publish CompanyPortal.Web --configuration Release --output ../artifacts/publish
```

Copy the publish output and run `dotnet CompanyPortal.Web.dll` from that output directory with a supported .NET 10 ASP.NET Core runtime. Windows IIS deployment additionally needs the matching Hosting Bundle and server configuration. A different OS/architecture or self-contained deployment requires a separately selected publish target.

Copying the parent folder transfers source for both eventual solutions, but offline building also needs the selected SDK and any future NuGet packages. This frontend currently uses only the installed shared framework. Prepare an offline package feed when package references are introduced; the future API has its own restore requirements.

**Air-gapped readiness is not complete.** Iconsax CSS/fonts and some news imagery still use external URLs, preserved for initial parity. Inventory/local hosting and licensing review of required remote resources, plus an actual offline browser check, remain pending. Outbound news source links also cannot work without network access. Do not assume that a successful .NET build proves offline rendering.

## Next steps

1. Verify portal/profile appearance and existing interactions on desktop/mobile, including visible themes 1/2/3 and storage behavior. Theme 1 (`majestic`) is the default.
2. Extract the shared layout and coherent partial views in small verified changes.
3. Resolve required external resources for offline use.
4. Perform dependency-based cleanup last; retire original source and Vite only after the replacement is verified.
