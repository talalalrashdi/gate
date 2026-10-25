# Main authorized search

The main **البحث العام** button searches only **الاستمارات والوثائق** and **الأنظمة الإلكترونية**. It no longer indexes portal headings, news, decision cards, calendars or illustrative page content. The separate phone-directory search keeps its existing sample contacts, directory button and phone-search history.

## Data and actions

Opening the main search reads these existing APIs in parallel, using the current employee's Windows credentials and no-store:

- `GET /api/documents`: already filtered through active employee lookup and `Portal.Document_GetAll`, including folder 74/descendant restrictions.
- `GET /api/applications`: current authorized app catalog with descriptions/categories, without launch URLs.

No new table, procedure or backend endpoint is needed. Matching uses Arabic normalization and all entered search terms. Documents match names, filenames and folder paths. Apps match names, descriptions and category names. The three filters are **الكل، الاستمارات والوثائق، الأنظمة الإلكترونية**. Results are grouped by source and update after a 200 ms typing delay; typing does not issue a database/API request per character. Empty queries show an instruction to type a query.

Document results display the filename without the folder path; folder paths remain searchable. PDF files use a red PDF icon, DOCX files use a blue Word/DOCX icon, both self-contained local SVG assets. The main-search caption «نتائج حسب صلاحيات حسابك» was removed.

The X button clears the query and keeps the sheet open. Clicking headings, empty space, filters or results inside the sheet does not dismiss it. Clicking outside the sheet closes it (even within the surrounding header); Escape also closes it. Focus leaving the input does not dismiss search.

| Result | Action |
|---|---|
| PDF | `GET /api/documents/{GUID}/file` in a new tab, inline viewing |
| DOCX or another non-PDF file | Same file endpoint, original Arabic filename as an attachment download |
| App | `GET /api/applications/{AppId}/launch` in a new tab; API rechecks the grant before redirecting |

The browser builds links only to these API routes using validated IDs. It never receives a physical root or trusts a client-provided launch URL. Source fields render as text, including names containing HTML. Existing file safety, `docs` folder settings, Arabic download headers and PDF signature/range handling are unchanged. Inline PDF viewing does not prevent saving or printing by the browser.

## Permission lifecycle and failures

Catalogs are held only while main search is open. Closing, hiding or leaving clears result titles, source data and keyboard selection and cancels pending requests. Returning to an open sheet or a page restored from browser history rereads permissions. Old or canceled responses cannot restore a cleared catalog. Every download/view/launch checks current access server-side, including after results were listed. A currently open list is not continuously polled for permission changes.

Main search does not write query history, preferences or business data. Existing historical storage is retained; old main-search recents are not shown or appended to. Phone-search history retains its prior behaviour.

If one source fails, that source contributes no records. The sheet identifies the unavailable source, offers retry and labels any remaining result count as coming from available sources. When both fail, no prior results remain. There is no illustrative fallback or cached permission catalog. Arrow keys select results; Enter activates the selected native link; Escape closes and returns focus to the originating button.

## Deployment and verification

Republish the frontend; the existing backend must already provide the authorized applications and documents endpoints (documents require migrations through 024 and configured views/access list/`docs` roots). No new SQL migration or NuGet/npm dependency was introduced by search. Previously published Airgap folders are not refreshed automatically.

`tools/verify-authorized-search.mjs` executes the real renderer for source isolation, Arabic/multi-term matching, grouping/filters, literal HTML safety, validated IDs, PDF/download/app links, keyboard navigation, partial failure/retry, close/hide/history refresh and late-response rejection. `Backend/tools/Test-AuthorizedSearch.ps1` tests the marked local sources, anonymous rejection, unauthorized apps/folders, actual inline/attachment/redirect responses and immediate action denial after grant revocation. It restores all changed fixture flags and does not modify metadata/timestamps or create records.

The frontend Release build passed without warnings. Renderer, authenticated HTTP access/action checks, offline asset scan and original frontend parity passed. Browser checks cover grouped results, scope filters, Arabic search, unauthorized-app exclusion, keyboard/close behaviour, the separate phone directory, desktop layout and cleared connection-failure state. Actual internal source mapping and IIS remain destination checks.
