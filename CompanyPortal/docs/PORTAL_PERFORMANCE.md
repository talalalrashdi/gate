# Portal performance — images, logo, card saves, refresh on return

Implemented 1 November 2026. Frontend files plus one API string change (theme template thumbnails). No migration, package, setting or internet dependency. Republish both API and MVC.

## What changed

| Area | Change |
| --- | --- |
| Hero images | `hero-oman-fort/mosque/desert.webp` (2048 px wide, quality 82) replace the PNGs in the official backdrop, `themes.css` and `editorial.js`. Fort loads immediately; mosque and desert keep their file in `data-src` and `personal-workspace.js` attaches it 3 s before that scene shows (5 s into the 8 s scene). When a theme supplies its own images the fallback rotation stops and the deferred scenes are never fetched. |
| National-day | `sultan-haitham-cutout.webp` (700×1438, displayed at most 350×700) and `oman-national-silk-v2.webp` (1254 px) with `loading="lazy"`. Their panel is hidden for other themes, so they download only when the national-day layout is shown. |
| Theme templates | `GET /api/admin/themes/templates` thumbnails point to the WebP files. |
| Logo | `oman-khanjar-160.png` (160×149, 21 KB) replaces the 289 KB emblem in the portal header/footer, admin, health, error pages and favicons. |
| Personal cards | Create/rename/delete redraw in place: cards are fetched again and `window.CompanyPortalCardCatalog.refresh()` (workspace-settings.js) reloads the account card catalog/order after any queued order save. Any failure falls back to the former full reload. See [USER_CUSTOM_CARDS.md](USER_CUSTOM_CARDS.md). |
| Refresh on return | Header events, news (current page + today's headlines) and أرقام تهمك re-read when the tab becomes visible again (or `pageshow`) and the last successful load is at least five minutes old. One request each; failures keep what is shown; news skips while simulation items are shown or a page load is running and keeps the selected story; events skip while the event video is open. No timers or polling. |

Already refreshing on every return before this change (unchanged): decisions/notices, وثائق تهمك, تعليمات السلامة, أخبارنا, حالة المؤسسة (also every two minutes). التوجيهات السامية reloads each time its sheet opens. The magazine was deliberately excluded: its catalog load rebuilds the open reader.

The original PNG files remain in `wwwroot/assets` because `Backend/tools/Import-FrontendImages.ps1` and `Test-InterfaceImages.ps1` read them; pages no longer reference them.

## Not changed: fonts

The two `GTAmericaArabic-*.ttf` files (about 360 KB each) were **not** converted to WOFF2. Their embedded metadata reads "Copyright © 2024 by Grilli Type. All rights reserved." (commercial GT America Arabic), while `assets/fonts/LICENSE.txt` is the SIL OFL text for IBM Plex and does not belong to these files. Converting a commercial font may need the vendor's web licence. If the organization holds a Grilli Type web licence, use the WOFF2 files Grilli supplies and add `format('woff2')` sources before the TTF in `site.css`, `admin.css` and `error-pages.css`, plus the preload in `Views/Home/Index.cshtml`. A lossless fontTools conversion was tested (358 KB → 73 KB, identical glyphs/tables) and then discarded.

## Measured (local Release, headless Edge 1440×1000, Windows auth, Exchange disabled)

First visit, empty cache. Bytes are exact; timings are medians because single runs varied widely on this workstation (first content 636–1,508 ms across identical runs).

| | Before | After |
| --- | --- | --- |
| Static download (HTML/CSS/JS/fonts/images) | 10.9 MB | 2.45 MB |
| Images | 8.6 MB | 162 KB |
| Admin first visit, images | 289 KB | 21 KB |
| First content / largest content (median) | 976 / 1,660 ms (4 runs) | 844 / 1,596 ms (3 runs) |
| Personal card create / rename / delete | full page reload | 516 / 310 / 587 ms, no reload |

On localhost the byte saving barely moves the timings because there is no network transfer cost. On a real network the saving is roughly 0.07 s at 1 Gbps, 0.7 s at 100 Mbps and 3.4 s at 20 Mbps per first visit. Scrolling stayed at 59–60 fps at normal CPU; at 4× CPU throttling both versions varied between runs (old 56–59 fps, new 46–59 fps) and no per-scroll code changed.

Remaining large downloads are database theme images served at full size (`/api/images/28/content` 1.8 MB, `/25/` 1.3 MB — imported copies of the original PNGs), the fonts above, and PDF.js (345 KB, already cached after first use).

## Verification

- MVC and API Release builds: 0 warnings, 0 errors. All 26 `CompanyPortal/tools/verify-*.mjs` suites pass (verify-frontend needs a running server and was not run).
- New checks: `verify-news-board.mjs` (five-minute minimum, hidden skip, one quiet request, new stories, failure keeps content, simulation guard — confirmed to fail on the previous code), `verify-header-events.mjs` (refresh, pageshow, failure keeps links), `verify-workspace-settings.mjs` (catalog refresh with a new card, no writes, failure reported without breaking the catalog, queued order save first). The last one found and fixed a deadlock where a queued order save awaited the refresh that was waiting for it.
- Browser: no PNG hero/portrait/silk/logo requests; mosque/desert not fetched while theme images are configured; national-day images load when shown (700×1438, 1254×1254); fallback rotation fetches the next scene 3–6 s after a switch; personal card create/rename/delete with zero navigations, focus on the saved card, test card removed (account card list identical before/after); return refresh = exactly one request per module after five minutes and none before; admin themes page and template thumbnails without 404s; no JS errors.
