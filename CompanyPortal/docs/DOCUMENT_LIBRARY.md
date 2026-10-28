# وثائق تهمك

The bottom library now reads saved tabs and selected PDFs rather than illustrative JavaScript entries. The existing header **الاستمارات والوثائق** and main authorized search continue to use the same document records.

## Administration

Open **إدارة البوابة → وثائق تهمك** (`/admin/documents`).

1. Choose **إضافة تبويب** and enter its Arabic display name.
2. Select an existing folder, then select one or more of its registered PDFs.
3. Set the display order and **إظهار التبويب**, then save.

Changing a folder clears the draft file selection. Each tab saves independently. Hidden tabs retain their selections. Saves use the existing last-save-wins convention; `LastChangeAt` changes only when the saved name, folder, order, availability or file membership actually changes. Files within a tab follow the existing document name order. Multiple tabs can select different subsets of the same folder.

Selection currently means **active PDFs already registered in `Mng.Document`**, within the administrator's current document permissions. Placing a file on disk alone does not register it. There is no upload, filesystem browser, folder creation, PDF editing or grant editor in this feature. Unavailable saved selections are labelled explicitly; removing their checkbox is an explicit removal, not an automatic cleanup.

Safety now reuses this infrastructure with an isolated `safety` section and one PDF per booklet; existing document tabs remain in `documents`. See [safety booklets and migration 026](SAFETY_BOOKLETS.md).

## Existing storage and authorization

- Reuses `Mng.Folder`, `Mng.Document`, `dbo.VFolder`, `App.CreateFolderPath` and the configured `Mstr.Utls` **docs** root(s).
- `Portal.DocumentTabs` stores identity, display name, folder, order, last change and active state.
- `Portal.DocumentTabItems` stores the selected `Mng.Document.DocumentID` values, with foreign keys and unique membership.
- `Portal.DocumentTabs_Get` reads tab metadata and memberships; `Portal.DocumentTabs_Save` validates and saves them transactionally.
- Current Windows NTName resolves to the existing active database UserId. `Portal.Document_GetAll` remains the only document authorization adapter. Its manual `VJobMainPeriod.ID` full-access list is unchanged.
- Folder **74 and its descendants** remain excluded unless that existing rule grants access. No new user/role permission system is introduced.
- Employee reads intersect visible tabs, exact selected folder, selected IDs and currently authorized active PDFs. Empty tabs disappear. Admin visibility does not grant document access. Hiding a tab affects this library; the underlying authorized document can still appear in the header/search.
- Administration requires the current external `CompanyPortal.Admin` role on every request. Writes also validate JSON, the `X-CompanyPortal-Request: document-library` header and allowed Origin.
- PDF requests re-read current document permissions, visible tab membership and PDF extension; safe-root path resolution and signature validation reuse `DocumentFiles`. No browser-supplied file paths are accepted.

## Routes and browser behavior

- `GET /api/document-library`: available tabs and permitted PDF titles/IDs only, no folder paths.
- `GET /api/document-library/{documentId}/file`: signature-checked `application/pdf`, inline Unicode filename, range support and private/no-store cache policy. Unknown, hidden-only, non-PDF or unauthorized IDs return 404.
- `GET /api/admin/document-library`: all tab metadata plus the administrator's authorized PDF selection catalog.
- `POST /api/admin/document-library` and `PUT /api/admin/document-library/{tabId}`: save name, folder, order, active and selected document IDs.

Titles are rendered as text. Clicking **استعراض الملف** opens a dialog with the browser PDF reader and a separate-window link. No editor or document-write endpoint exists. A browser PDF reader may still allow saving/printing; view-only is not DRM. Native PDF painting depends on the destination browser and should be checked in Edge/Chrome there.

The library has loading, unavailable/unauthorized, empty and retry states. It clears data on page hide and reloads current permissions on return; it stores no catalog or file data in localStorage. There is no external asset dependency.

## Local samples and installation

Migration `Backend/Database/Scripts/025_DocumentTabs.sql` adds metadata/procedures without replacing the existing document lookup or permissions. Apply only pending migrations to an existing database, then rebuild/republish **both apps**. Do not replay the fresh-install setup on existing databases.

Development-only `Backend/Database/Development/011_CreateSampleDocumentTabs.sql` and `Backend/tools/Initialize-DocumentTabsFixture.ps1` add three initial folders/tabs and valid fictional PDFs:

| Folder/tab | PDF |
|---|---|
| قوانين المؤسسة | لائحة تنظيم العمل.pdf |
| قوانين التقاعد | دليل شؤون التقاعد.pdf |
| الدراسات | دراسة تطوير الخدمات.pdf |

Run the initializer only after the existing marked document fixture and migration 025. It writes only to the local `artifacts/document-fixture` root, preserves existing files, and never rewrites the manual permission SP. PDF contents are development examples, not official legal documents. Reruns preserve saved tab selections/visibility/order and timestamps.

The generated `Deployment/CompanyPortal-Setup.sql` includes migration 025 for fresh installations. Existing `CompanyPortal-CurrentData.sql` and previously published Airgap folders are historical artifacts and were not regenerated by this change; they do not include these new tabs/files. Transfer a refreshed snapshot plus the external docs-root files when preparing a new offline bundle. For real content, register actual authorized folders/documents and select them in admin; do not install development fixtures over internal records.

## Verification

### Multiple PDFs and more tabs — 28 October 2026

Tabs already use a one-to-many `Portal.DocumentTabItems` selection, not a single PDF column. Each document tab accepts 1–500 distinct authorized PDFs from its selected folder. There is no three-tab restriction. Safety booklets deliberately retain their separate one-PDF rule. No schema migration is required.

The admin now shows the selected-file count and prevents selecting more than500. Lists with over50 available PDFs start collapsed and build their checkboxes only when expanded; closing/reopening retains selections. This avoids building every large file list for every tab at startup. Small lists remain expanded. Employees continue receiving a `documents` array per tab and a reader button for every file; tab buttons wrap onto additional rows.

An approved disposable database, using copies of the current library read/save procedures and isolated synthetic metadata, verified20 tabs,500 PDFs in one tab, save/reload, no-op timestamps/history, remove/hide/reactivate/order and invalid selections. Identity/admin/root lookups were read-only wrappers to the local source; this is capacity/persistence coverage, not a replacement for real permission-source tests. Browser checks confirmed20 tabs,499 remaining rows after removal, lazy admin lists with501 available choices, the500 selection cap and preserved selections after collapse/reopen. The fixture reuses an existing valid PDF file; it does not contain500 different PDF contents. The disposable database was removed after testing.

Repeatable checks: `node tools/verify-document-library.mjs`, `node tools/verify-admin-documents.mjs`; `Backend/tools/Test-DocumentLibraryCapacity.ps1` requires the explicitly marked disposable fixture and refuses the real CompanyPortal database. See [the regression report](PORTAL_REGRESSION_2026-10-28.md) for the wider scope and limits.

Release builds, Swagger, authenticated HTTP create/edit/hide/order/reload, no-op timestamp, non-PDF/cross-folder/empty-selection rejection, origin/header enforcement, folder74 access and revocation/direct-link checks, admin revocation, and existing document/search regressions were checked locally. Tests restore sample grants and remove their own temporary tabs. Browser checks cover tab switching, reader dialog/link wiring, creating an inactive tab and reloading saved settings. The automation browser did not paint the native PDF pages; native rendering remains a destination browser check, although the PDF bytes, MIME, signatures and range handling were verified.

Run `Backend/tools/Test-DocumentLibrary.ps1` against a temporary local API (default port 5091) with the explicit local fixture admin. Never run mutation tests against internal production data.
