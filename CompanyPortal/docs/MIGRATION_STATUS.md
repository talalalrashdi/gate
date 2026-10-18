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
| 4. Behavior verification | Pending | Requires an available browser for desktop/mobile appearance and actual JavaScript interaction checks. HTTP checks do not satisfy this gate. |
| 5. Shared layout / partials | Pending | Deliberately deferred until the initial frontend passes browser verification. |
| 6. Cleanup | Pending | No original source, tooling, preview, helper, font, or asset has been deleted. |

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

Required external Iconsax resources and externally hosted imagery still need review/local hosting before an air-gapped rendering claim. No remote resource was replaced during initial parity work.

Next: obtain browser verification of the initial migration, resolve any regressions, then organize layout/partials and verify again. Review and delete proven unnecessary files/code only as the final step.
