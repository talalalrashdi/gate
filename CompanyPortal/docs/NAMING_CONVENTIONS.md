# CompanyPortal frontend naming

Applied on 18 October 2026 after user approval. Scope: the MVC frontend; the original dist source and baseline inventory remain unchanged.

## Files

Names describe responsibility. CSS stays under wwwroot/css and JavaScript under wwwroot/js. Existing loading order is preserved; this refactor does not merge files or remove unused code.

| Previous | Current |
| --- | --- |
| `design-b-calendar-integrated.css` | `personal-workspace.css` |
| `design-b-documents-sheet.css` | `documents-dialog.css` |
| `design-b-documents-sheet.js` | `documents-dialog.js` |
| `design-b-editorial.css` | `editorial.css` |
| `design-b-editorial.js` | `editorial.js` |
| `design-b-electronic-services.js` | `electronic-services.js` |
| `design-b-floating-calendar.css` | `floating-calendar.css` |
| `design-b-floating-notices.js` | `floating-notices.js` |
| `design-b-formal-theme.css` | `theme-work.css` |
| `design-b-header-scroll.css` | `header-scroll.css` |
| `design-b-header.css` | `header.css` |
| `design-b-intro.js` | `personal-workspace.js` |
| `design-b-layout.css` | `layout.css` |
| `design-b-library.css` | `library.css` |
| `design-b-library.js` | `library.js` |
| `design-b-magazine.js` | `magazine.js` |
| `design-b-majestic-news.js` | `news-headlines.js` |
| `design-b-majestic-theme.css` | `theme-official.css` |
| `design-b-national-theme.css` | `theme-national-day.css` |
| `design-b-notice-strip.css` | `notice-strip.css` |
| `design-b-notice-strip.js` | `notice-strip.js` |
| `design-b-palette.css` | `palette.css` |
| `design-b-personal-carousel.js` | `navigation-controls.js` |
| `design-b-planner.css` | `planner.css` |
| `design-b-policies-sheet.js` | `policies-dialog.js` |
| `design-b-safety.js` | `safety.js` |
| `design-b-section-nav.css` | `section-navigation.css` |
| `design-b-section-nav.js` | `section-navigation.js` |
| `design-b-status.js` | `organization-status.js` |
| `design-b-systems.css` | `systems-catalog.css` |
| `design-b-systems.js` | `systems-catalog.js` |
| `design-b-themes.css` | `themes.css` |
| `design-b-typography.css` | `typography.css` |
| `design-b-widget-layout.js` | `workspace-pagination.js` |
| `design-b-workspace-groups.js` | `workspace-groups.js` |
| `design-b-workspace-order.js` | `workspace-order.js` |
| `design-b-workspace.css` | `workspace.css` |
| `design-b.css` | `site.css` |
| `design-b.js` | `site.js` |

## Code identifiers

| Previous | Current |
| --- | --- |
| b-* | portal-* |
| b-intro-switch / b-intro-options / b-intro-panel | portal-theme-switch / portal-theme-options / portal-theme-panel |
| bt-task* | planner-task* |
| bt-majestic-* / bt-formal-* / bt-national-* | theme-official-* / theme-work-* / theme-national-day-* |
| Other bt-* | personal-* |
| bn-* | news-* |
| ed-* | editorial-* |
| sc-* | systems-* |
| dl-* | documents-* |
| data-intro-option / dataset.introOption | data-theme-option / dataset.themeOption |
| intro-option-4 / intro-option-2 / intro-option-3 | theme-official / theme-national-day / theme-work |
| clerio:theme-change | companyportal:theme-change |
| sc:reveal | systems:reveal |

The matching data attributes, dataset property names, CSS custom properties, dynamic class prefixes, and event producers/consumers were changed together. Previously inactive business/news theme metadata has descriptive identifiers too; no removed theme was restored.

## Compatibility

- Current display order and canonical names are 1 — الرسمي (`official`, default), 2 — العملي (`work`), 3 — اليوم الوطني (`national-day`). Migration 006 updates stored table values. Browser v2 preferences use these names; v1 values are translated without changing their design or deleting old storage.
- All localStorage key names are retained, including clerio-design-b-pinned-systems-v1. Changing a filename or selector does not authorize deleting user data.
- The old /design-b.html address temporarily redirects to / and retains query parameters. Existing /index.html and /user-profile.html aliases remain.
- Original source, historical reports and baseline JSON retain historical names intentionally. tools/frontend-names.mjs maps them to current names for verification; it is not loaded by the application.
- CompanyPortal is the project name. This refactor changes design-era labels, not sample article text or unrelated content branding.

## Verification

Use the commands in ../README.md. The HTTP verifier checks renamed resources and remaining page/source parity; verify-theme-selection.mjs executes actual theme selection code with a minimal DOM. Desktop/mobile browser checks remain necessary.
