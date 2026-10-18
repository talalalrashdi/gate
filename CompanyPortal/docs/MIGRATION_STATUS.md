# Frontend migration status

Date: 18 October 2026. Target: ASP.NET Core MVC / .NET 10, CompanyPortal.

## Scope and baseline

The user authorized starting the agreed frontend-only migration. No API, authentication, database, or business integration is included. The existing `dist/` source is retained intact. Previous dependency fixes and the agreed plan are preserved.

The new source is under `CompanyPortal/Frontend/CompanyPortal.Web/`. The future backend will be an independent solution under `CompanyPortal/Backend/`; no backend project was created.

`frontend-baseline.json` records SHA-256 hashes of all 328 original frontend files, including 286 assets. It also records ordered portal dependencies (19 local stylesheets, one external stylesheet, and 19 classic scripts), plus the profile page's shared styles. No browser storage was inspected or exported.

## Step progress

| Step | Status | Evidence / remaining work |
| --- | --- | --- |
| 1. Baseline | Source inventory complete; browser baseline pending | File hashes and load-order inventory captured. Browser runtime reported no available browser, so no screenshots or interaction baseline were captured. |
| 2. MVC foundation | Complete | SDK 10.0.402 found. Minimal solution, controllers, launch settings and initial views built and served at port 5080. |
| 3. Initial frontend migration | Implemented; HTTP/static checks passed | Full-page MVC views, copied assets, adjusted paths, and old page route aliases. |
| 4. Behavior verification | Logic/HTTP checks passed; visual acceptance pending | Theme logic, source parity, resource checks and IIS Express root/sub-application checks passed. Actual desktop/mobile browser interactions remain unverified. |
| 5. Shared layout / partials | Implemented and compiled | Shared layout/header/footer, coherent feature partials, profile stylesheet, and ordered script section. |
| 6. Cleanup | New MVC project cleaned; legacy retirement pending | Removed 12 proven unused files from MVC and publish output after reference checks. Original source/tooling outside CompanyPortal remains retained for browser acceptance. |

## Changes in the initial migration

- Created one independent frontend `.slnx` and one `net10.0` MVC project; no external package references.
- Added `HomeController` and `ProfileController`, preserving old HTML URLs as aliases while providing `/` and `/profile`.
- Converted full HTML pages to `.cshtml` views with `Layout = null` for initial parity. Escaped literal Razor `@` characters and generated application-relative URLs using `Url.Content`.
- Copied all original CSS/JavaScript/assets. CSS now lives under `/css` and resolves assets via `../assets`; scripts live under `/js` and remain byte-identical to the originals.
- Added a generic error view for production exception handling and .NET build-output ignore rules.
- Kept the frontend business data local, with no speculative model/service layers.

## Verification performed

- The initial foundation built with zero warnings/errors and returned HTTP 200 for its home and profile views before the real pages were migrated.
- The migrated application built with zero warnings/errors.
- Automated HTTP comparison matched portal HTML at `/`, `/index.html`, and `/design-b.html`, and profile HTML at `/profile`, `/profile/`, and `/user-profile.html`, allowing only the expected asset/navigation URL substitutions and outer whitespace normalization.
- All 325 copied non-HTML resources returned HTTP 200 with matching SHA-256 content, accounting for the deliberate CSS path adjustment. This includes assets not immediately loaded by the page, such as magazine pages.
- Seven local CSS URL references resolved successfully. Embedded SVG data URLs were excluded from HTTP resource checks.
- All 328 original frontend files matched their captured hashes after migration.
- `/api/v1/me` and `/__review` returned 404; the application does not expose a backend API or the Vite layout helper.
- `/error` returned a generic HTML response with status 500.
- Release publishing completed successfully with no additional package references. The published output was started in Production on a separate loopback port and passed the same six-route, 325-resource, CSS reference, original hash, and status-code checks. Its temporary verification server was stopped afterward.

Verification commands and publishing instructions are in `../README.md`. The optional verification tool intentionally depends on the retained original source and is for this migration stage.

## Limitations and continuation

The in-app browser could not connect: browser selection reported no available browser. Browser screenshots, responsive layout, console errors, task CRUD, themes, search, notices, groups, media, and persistence across reloads have **not** been runtime-tested. Do not claim milestone completion or delete the original based on HTML parity alone.

Browser storage is origin-specific. Port 5080 intentionally isolates this initial MVC run from the original port 5173. Existing data is not automatically transferred. The README documents the origin-preserving option after stopping Vite; do not clear storage to resolve differences.

External resource localization was deferred during initial parity work. It is now implemented as described in the completion work below; an actual offline browser check remains outstanding.

Current next step: complete `FRONTEND_ACCEPTANCE.md` in a browser and validate the actual internal IIS environment. The source organization and new-project cleanup described below are implemented; preserve the original comparison baseline until visual acceptance.

## User-requested theme and tab update

- The current majestic theme (legacy internal option/panel 4) is now the default, displayed as theme **1**. Official/national is **2**, and formal is **3**. Stable internal panel IDs are retained because existing CSS and JavaScript reference them.
- CompanyPortal saves theme selections under `companyportal-opening-theme-v1`, so its new default applies on first use without changing the original `clerio-opening-theme` preference. Subsequent explicit selections persist normally. Task and other storage keys are untouched.
- Portal, profile, and error views use the browser title `البوابة` and the existing local `oman-khanjar.png` favicon.
- These are intentional differences from the frozen original source. The migration verifier accounts for the tab/theme changes while continuing to check remaining HTML and assets against the original baseline. The changed intro script is checked against its current MVC source.

## User-authorized naming refactor

The naming refactor supersedes the numeric internal theme IDs and original MVC asset filenames mentioned in the earlier stage notes above. See `NAMING_CONVENTIONS.md` for the full mapping.

- Renamed all 39 top-level CSS/JavaScript files from design-era names to feature names; preserved their loading order and feature boundaries.
- Updated MVC view references, CSS selectors/custom properties, JavaScript IDs/classes/data attributes/dataset access, inline markup/styles, and the affected SVG's internal classes together. No assets or features were removed.
- Theme keys are `majestic`, `official`, and `formal`; their panel IDs are `theme-majestic`, `theme-official`, and `theme-formal`. Visible numbering remains 1/2/3 with majestic first/default.
- Numeric values previously saved in `companyportal-opening-theme-v1` are mapped to the same themes before writing semantic values. Existing legacy browser storage keys and all unrelated data remain intact.
- Renamed custom events to `companyportal:theme-change` and `systems:reveal`, updating producers and consumers.
- Replaced visible Design B navigation/footer wording with portal wording. The title/favicon remain as requested.
- `/design-b.html` now redirects temporarily to the portal root and retains its query string. No active MVC CSS/JavaScript filename uses `design-b`; the intentionally retained storage key and compatibility route are exceptions.
- Build passed with zero warnings/errors. All 19 JavaScript files passed syntax checks. Theme logic checks passed for the default, numeric and semantic preferences, invalid/retired values, all three buttons, panel visibility, active state, custom events, and legacy-key preservation.
- HTTP verification passed for six page routes, all 325 static resources, seven CSS resource references, renamed asset paths, the legacy redirect/query string, and expected error/absent routes. All 328 original source hashes remain unchanged.
- Browser selection again reported no available browser. Desktop/mobile rendering and complete browser interactions remain pending; this is not a visual verification claim.

## Default-theme header spacing

At the user's request, the majestic/default theme's shared header/personal-area frame now reaches the top and sides of the viewport. Removed the original 12px desktop / 6px mobile outer gaps and frame border, and squared the top corners of the frame, header and photographic backdrop. Retained internal header padding, bottom rounding/spacing and existing pinned-scroll behavior. Edited the existing theme rules rather than adding competing overrides. The retained original source contains the former gaps; it remains unchanged. Browser access is still unavailable, so no desktop/mobile visual verification is claimed.

The user clarified that the header must use the same layout as the other themes while remaining continuous with the photos. Removed the default-theme header reparenting and its separate sizing/grid/avatar/control spacing rules, including the special two-row layout on laptop screens. The header now remains in the shared root position and inherits common desktop/mobile fixed positioning and sizing. The photographic frame retains the original content offsets (88px on wide desktops, 132px on laptop/mobile breakpoints), so the existing 52px separation and unchanged backdrop offsets keep the image composition continuous at the top. Background image files, image positioning, animation, overlays and backdrop styles were not changed by this correction. Theme selection checks now also verify that the header stays outside the photo frame through initialization and every theme switch. Visual verification remains pending.

## Frontend completion work

The user requested completing the frontend before any API work. No API/authentication/database project or dependency was introduced.

- Created `Views/_ViewStart.cshtml` and `Views/Shared/_Layout.cshtml` for the common Arabic document, tab metadata, application base URL and page sections. Header/footer are shared partials; home feature markup is split into personal workspace, workspace cards, news/media, safety, systems catalog, documents and overlays. The main home view is now approximately 48 lines instead of a full HTML document. Profile presentation is in `css/profile.css`.
- All dialog markup now precedes the ordered script section. This fixes a source-observed initialization problem: `personal-workspace.js` previously queried the announcement dialog before the parser reached it. The original 19-script sequence is preserved and verified.
- Copied the existing Iconsax stylesheet and all five font formats locally, retaining its original notice and documenting sources/official developer terms. Removed the automatic external news-image request by using an existing local illustrative thumbnail with an appropriate credit; photographic backgrounds are untouched. Outbound source links remain intentional.
- Removed two unavailable theme descriptors and an unreachable news-theme branch. Older numeric preferences still translate and invalid/retired choices fall back to majestic; all relevant logic checks pass.
- Performed final reference-based cleanup in the new MVC project: one unloaded stylesheet, five unreferenced font weights, four unreferenced generated image/SVG alternatives, and two image-generation prompt files. `frontend-cleanup.json` records paths, original mappings, hashes and reasons. Original `dist/` and unrelated legacy tooling are not deleted.
- Restore succeeded against an empty local NuGet feed and isolated package directory using the installed .NET 10 SDK/reference packs. Release publish succeeded. No NuGet application packages were needed.
- The clean published output passed checks through local IIS Express with ASP.NET Core Module V2 and in-process hosting in Production, at both `/` and `/companyportal/`: six page routes, query-preserving legacy redirect, 313 retained original resources, seven CSS resource references, local profile/icon resources, and removed-file absence. All 328 original source hashes remain unchanged.
- A static offline scan passes for application views, CSS, JavaScript and SVG resources. This is evidence that required assets are local, not a claim of an executed offline browser session.
- IIS Express used a temporary configuration under ignored `.local/`; no permanent IIS site was installed. Verification servers are stopped after checks so Visual Studio builds are not blocked.

Remaining acceptance is explicit in `FRONTEND_ACCEPTANCE.md`: real-browser desktop/mobile/offline interaction checks and testing the actual internal Windows Server/IIS environment. Browser automation is unavailable; source and local hosting checks do not substitute for those acceptance steps. Full legacy-folder retirement remains deferred until browser acceptance. See `IIS_AND_OFFLINE_DEPLOYMENT.md` for delivery instructions.
