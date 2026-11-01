# Portal performance — images, logo, card saves, refresh on return

Implemented 1 November 2026 in two rounds. Round one: frontend files plus one API string change (theme template thumbnails). Round two: WOFF2 fonts and migration 064 (display copies of oversized database images). No package, setting or internet dependency. Apply 064, then republish both API and MVC.

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

## Fonts — WOFF2 (1 November 2026, second round)

The user confirmed the GT America Arabic licence (the font metadata names Grilli Type). The former `assets/fonts/LICENSE.txt` (an IBM Plex OFL text that did not describe these files, referenced by nothing) was removed at the user's request and recorded in `docs/frontend-cleanup.json`; fonts load unchanged without it and the file now returns 404. `GTAmericaArabic-Regular.woff2` (73 KB, was 359 KB) and `-Bold.woff2` (76 KB, was 362 KB) are lossless fontTools repackagings: identical tables, glyph order, outlines, names, metrics and GSUB/GPOS shaping. `site.css`, `admin.css` and `error-pages.css` list `format('woff2')` first and keep the TTF as fallback (browsers download only the first format they support); the portal preload points to the WOFF2. Same-text specimens drawn through each page's own `@font-face` (portal, admin, error page; weights 400/700; 13–34 px; Arabic, Arabic-Indic and Latin digits) are **pixel-identical** before and after (0 differing pixels), and only `.woff2` files are requested.

## Version stamps on every local CSS/JS (1 November 2026, third round)

Fifteen `<link>`/`<script>` tags had no `asp-append-version`, so after a deployment browsers could keep old copies by heuristic caching (the server sends ETag/Last-Modified but no Cache-Control): `site.css` (font rules), `admin.css` (also on the health page), `connection-check.css`, the portal's `section-navigation/notice-strip/themes/palette/planner/personal-workspace/theme-work/library/header-scroll.css` and `notice-strip/navigation-controls/section-navigation.js`. All now carry the tag helper; a browser check on `/`, `/admin`, `/admin/health`, `/errors/404` and `/diagnostics/connection` found no same-origin CSS/JS request without `?v=`. Admin section assets already used the build-ID `?v=` in `admin-sections.js`.

## Database theme images — display copies (migration 064)

Images uploaded before migration 050 (the bundled imports 25, 27, 28, 29) were stored at full size, and the portal always downloaded `/content`. Migration 064 adds an optional **display copy** next to the untouched original, made once by the admin browser with exactly the same settings as new uploads (long side at most 2560 px; JPEG stays JPEG, other formats WebP; quality 0.86; stored only when smaller; SVG never). See [INTERFACE_IMAGES.md](INTERFACE_IMAGES.md#display-copies-migration-064).

| Image | Original | Display copy | PSNR vs original at the same size |
| --- | --- | --- | --- |
| 28 (theme 1) | 2172×724 PNG, 1,843 KB | same size WebP, 136 KB | 40.0 dB |
| 25 (theme 1) | 3276×2182 JPEG, 1,298 KB | 2560×1705 JPEG, 830 KB | 37.6 dB |
| 27 / 29 | 2048×768 PNG, 2,301 / 1,839 KB | same size WebP, 174 / 97 KB | 39.3 / 40.6 dB |

Full-resolution crops side by side show no visible difference. Image 25 stays a fairly large JPEG because the upload rule keeps JPEG as JPEG; images 30/31 (under 1.5 MB and 2560 px) and the SVG 41 are not candidates under that rule.

**Deployment:** apply `064_ImageDisplayCopies.sql` and republish API and MVC (any order: older API builds ignore the extra result sets, and the new API tolerates a database without them). Then an images administrator opens صور الواجهة once and clicks **إنشاء نسخ عرض أصغر (n)**; the button appears only while candidates exist.

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

After the second round (WOFF2 fonts and display copies) the same first visit downloads **3.1 MB in total** (was 14.4 MB including API data): fonts 365 KB (was 936 KB; 214 KB of it is the Iconsax icon font), theme images from the API 1.27 MB (was 3.4 MB), static images 162 KB. Remaining large downloads: theme image 25's display copy (830 KB JPEG), PDF.js (345 KB, cached after first use) and image 92 (266 KB, already within limits).

Theme layouts: all three layouts' markup and CSS are part of every portal page (theme CSS about 93 KB, cached after the first visit; the national-day panel about 21 KB of HTML including its inline calligraphy SVG). Switching layouts is instant because nothing is fetched; the heavy parts — layout images and theme image groups — already load only when shown. Loading theme layouts on click was considered and not done: it would add a delay or flash on every switch to save under 100 KB that is mostly cached.

## Verification

- MVC and API Release builds: 0 warnings, 0 errors. All 26 `CompanyPortal/tools/verify-*.mjs` suites pass (verify-frontend needs a running server and was not run).
- New checks: `verify-news-board.mjs` (five-minute minimum, hidden skip, one quiet request, new stories, failure keeps content, simulation guard — confirmed to fail on the previous code), `verify-header-events.mjs` (refresh, pageshow, failure keeps links), `verify-workspace-settings.mjs` (catalog refresh with a new card, no writes, failure reported without breaking the catalog, queued order save first). The last one found and fixed a deadlock where a queued order save awaited the refresh that was waiting for it.
- Second round: migration 064 applied locally twice (rerunnable), older API build verified unchanged against the migrated database (9 library images, theme 1 with 3 images and settings). Display-copy button created exactly the 4 expected copies (four 204s); second valid copy 409, invalid bytes 400, `/display` without copy 404; portal and the theme-editor preview request `/api/images/28|25/display`. Fixed in the same change: the browser-side copy step (and the existing «إنشاء نسخ معاينة صغيرة» button) now reads originals with a fresh credentialed `fetch` because a library tile could already have cached the same URL as a plain `<img>` without CORS headers, which made the canvas read fail. Setup.sql regenerated 001–064 (diff additive; regenerating the committed file first reproduced it byte for byte). 28 verify suites and the functional browser checks pass again.
- Browser: no PNG hero/portrait/silk/logo requests; mosque/desert not fetched while theme images are configured; national-day images load when shown (700×1438, 1254×1254); fallback rotation fetches the next scene 3–6 s after a switch; personal card create/rename/delete with zero navigations, focus on the saved card, test card removed (account card list identical before/after); return refresh = exactly one request per module after five minutes and none before; admin themes page and template thumbnails without 404s; no JS errors.
