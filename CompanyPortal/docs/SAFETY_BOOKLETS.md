# تعليمات السلامة

Safety booklets now read selected existing PDFs using the same document records, authorization and file reader as وثائق تهمك. The six original cover designs, titles, icons, colours, hover/focus effects and responsive grid remain. Additional booklets use the same covers and six-icon/colour cycle, filling the next grid position and wrapping to another row when needed.

## Administration

Open **إدارة البوابة → تعليمات السلامة** (`/admin/safety`). Choose **إضافة كتيب**, enter the display title, choose a folder and **one registered active PDF**, set its order and **إظهار الكتيب**, then save. Each booklet saves independently. Hiding retains settings. The next page load reflects saved changes.

This selects records already registered in `Mng.Document`; it does not scan folders or upload PDFs. Existing `Mng.Folder`, `dbo.VFolder`, `App.CreateFolderPath` and the **docs** root(s) in `Mstr.Utls` are reused. Titles are plain text. No editing, document writes or new grants are introduced. The PDF opens in a reader dialog with a separate-window link; the native reader may allow save/print, so view-only does not prevent copying.

## Shared implementation and security

Migration **026_SafetyBooklets.sql** extends `Portal.DocumentTabs` with internal `SectionKey` (`documents` / `safety`), defaulting existing rows to `documents` without changing their settings or timestamps. It reuses `Portal.DocumentTabItems`, `Portal.DocumentTabs_Get` and `Portal.DocumentTabs_Save`. For safety, one entry is one booklet with exactly one selected PDF. The server supplies the section from the route; clients cannot move another section's entry by submitting its ID or an extra JSON field. Writes to an ID in the other section return 404. Saves remain last-save-wins, updating LastChangeAt only for actual metadata/membership changes.

Routes:

- `GET /api/safety-library` — current permitted visible booklet titles and selected PDF IDs.
- `GET /api/safety-library/{documentId}/file` — current membership and permissions rechecked before signature-checked inline/range-enabled PDF serving.
- `GET /api/admin/safety-library` — booklet metadata and the administrator's permitted PDF catalog.
- `POST /api/admin/safety-library`, `PUT /api/admin/safety-library/{id}` — validate and save a booklet.

The existing controllers/store and the shared admin editor serve both sections with isolated scope. Employee Windows NTName still resolves to the active external UserId, and `Portal.Document_GetAll` remains the permission adapter. Folder **74 and descendants** still require its existing explicit rule. Admin status does not grant document access. Library and safety publication are independent: listing a PDF in one does not publish it in the other. Both may deliberately select the same permitted PDF.

Every admin request requires the current external `CompanyPortal.Admin` role. Safety writes require `X-CompanyPortal-Request: safety-library` and an allowed Origin. Employee responses are private/no-store, clear on hide/failure, and reread on return. No browser catalog cache, EWS change, external asset or new package is required.

## Local samples and deployment

Development-only `Database/Development/012_CreateSampleSafetyBooklets.sql` and `tools/Initialize-SafetyFixture.ps1` create folder 110 **تعليمات السلامة**, six registered sample PDFs and six initial booklets using the existing titles. The samples contain fictional development content, not approved safety guidance. The initializer requires the existing marked document fixture and writes only under its local `artifacts/document-fixture` root. Existing PDFs are not overwritten. A database fixture marker makes booklet creation one-time, preserving later admin changes on rerun; the permission procedure and docs root are never replaced.

For an existing environment, apply pending migration 026, then rebuild/republish both apps. The fresh-install `Deployment/CompanyPortal-Setup.sql` includes 026; never replay it over an existing database. Historical CurrentData exports and Airgap publish folders were not refreshed. A new offline bundle needs a refreshed snapshot and the external docs files as well as the updated applications. Use actual registered safety PDFs internally, rather than installing development fixtures over internal records.

## Verification

Local Release builds, Swagger, authenticated API save/edit/hide/order/reload, no-op timestamps, single-PDF validation, invalid folder/file rejection, origin/header enforcement, cross-section reads/writes/file isolation, folder74 revocation/direct-link enforcement, admin revocation and the existing document-library regression checks passed. Migration/fixture rerun preserves settings, memberships and the document authorization procedure. Temporary test entries were removed and sample permission flags restored.

Actual browser checks cover the original six covers, adding a seventh with identical dimensions/cycled style, admin save/hide, single-PDF selection, reader dialog and Escape. The automation browser cannot paint native PDF pages; PDF response validity is checked, while native rendering remains an Edge/Chrome destination check.

Run `Backend/tools/Test-SafetyLibrary.ps1` only against the marked local development fixture, with a temporary local API on port 5091. Do not run these mutation tests against production data.
