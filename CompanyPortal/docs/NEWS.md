# Published news

Implemented 19 October 2026. Read-only news uses CompanyPortal.dbo.VNews, backed by the existing Pubs_Info_V4 database. News is available to every active registered portal user with Windows authentication; no admin/news role is required. No news editing, Exchange or calendar integration is included.

## Source and assumptions

The user supplied the view columns and its approximate join: Public_info_News left joins Attachment on PIN_ID and inner joins Public_info_News_Prodc on News_ID. The internal definition, column types and example paths were unavailable. The application does not reconstruct or replace the internal view; its existing production-table filtering stays in effect.

The initial assumed publication rule is PIN_Publish=1 AND PIN_Active=1 AND PIN_Portal=1. Confirm these meanings against real internal data before rollout. ATT_Active=1 applies only to attachment selection; news without an active attachment remains visible. PIN_IsImportant produces a `خبر مهم` indicator. The title comes from PIN_Subject; the date from PIN_Date; optional picture from PIN_PicturePath. PIN_Detailes, Expr1, ATT_Note and production IDs are not exposed or interpreted.

`News.Items_get` (numbered migration 013) reads only dbo.VNews. It normalizes numeric IDs/dates/flags and groups duplicate join rows into one record per PIN_ID before pagination. Sort order is date descending, then ID descending. Identical duplicate PDF paths count as one. Multiple different active PDF paths produce AttachmentConflict; the API never silently selects one. Conflicting picture paths suppress the picture. Repeated news metadata is expected to agree; MAX supplies deterministic values across join rows. An active PDF is currently identified by a case-insensitive `.pdf` path extension; ATT_FileType is not assumed to have a particular encoding. Confirm real paths/extensions and source field lengths (paths/subjects are normalized to nvarchar(4000)). No future-date scheduling filter has been inferred.

## API and interface

| Address | Result |
| --- | --- |
| GET `/api/news?page=1&pageSize=8` | Items, page, pageSize and totalCount; page 1–1000000, pageSize 1–50 |
| GET `/api/news/{id}/pdf` | Existing PDF, inline, range requests supported |
| GET `/api/news/{id}/picture` | Existing supported raster picture |

List items contain newsId, publishedAt, subject, isImportant, hasPicture, hasPdf and attachmentConflict. Physical file paths never appear in JSON or file names. Files are requested by news ID; every request rechecks user registration, current publication flags and attachment activity. Unknown/unpublished/missing/unsafe/unsupported files return 404; conflicting PDFs return 409; SQL or configuration/access failures return 503. Unregistered/inactive employees receive 403 and anonymous requests receive 401. Responses use private/no-store; file responses include nosniff.

The existing opening news panel and editorial news section load database summaries. In أخبار عامة, clicking anywhere on a left-hand list item selects it and updates the large right-hand title, date and optional picture; selection does not open a PDF. The selected item has a visible highlight and an aria-pressed button, with Enter/Space activation. The right-hand title opens its PDF in a new tab if available, otherwise it is plain text. The first item is selected initially and on changing pages. The separate معاينة action was removed. Opening hero headline links keep their existing direct-PDF behavior. The list pages through the API in groups of eight; the opening carousel uses the latest eight and keeps its existing animation, reduced-motion handling and manual controls. Date headings remain live. Source news dates preserve their calendar day without assuming a database timezone.

Database subjects are rendered as text, not HTML. Pictures with a failed file request are removed. Empty/error states are Arabic and errors offer retry; the old demonstration news and outbound source links are no longer used as a fallback. This does not change the separate video/photo/magazine sections, calendar or notices. Theme/card settings and existing storage are retained.

## File configuration and IIS

Folder roots come from **CompanyPortal.Mstr.Utls**, through **Mstr.Utls_GetFolderPaths** (migration014). The procedure returns `[Key]` and `strVal AS [Path]` for active rows; news uses only the `PubsInfo` key. Multiple PubsInfo rows may provide separate PDF/picture directories. See [database folder paths](FOLDER_PATHS.md) for the table and setup. Example configuration SQL only:

```sql
INSERT Mstr.Utls ([Key], strVal)
VALUES (N'PubsInfo', N'D:\PublishedNews\PDF'),
       (N'PubsInfo', N'D:\PublishedNews\Pictures');
EXEC Mstr.Utls_GetFolderPaths;
```

Source paths and database folder values must be fully qualified filesystem paths accessible from the API server. A path on a different machine's drive is not automatically available on the API server. PubsInfo roots define permitted filesystem boundaries; they do not rewrite source paths. The API queries the procedure on each file request, with no appsettings fallback. Missing/inactive/invalid roots make files unavailable while summaries remain independent. Give the API IIS identity read access to the folders. Employees must not have write access to these trusted directories. SQL and filesystem identities are the API service identity, distinct from employee identity. The previous News:AllowedRoots configuration has been removed.

The file reader checks canonical paths against allowed directory boundaries, rejects Windows device/alternate-stream paths and reparse points in the file/parent chain, and verifies extension plus file signature. Supported pictures: PNG, JPEG, GIF and WebP; SVG/HTML are not served. Files are streamed rather than loaded wholly into memory. Trusted server-managed folders are required; concurrent malicious changes to source directories are not an intended operating model.

## Local sample database

At implementation time neither Pubs_Info_V4 nor dbo.VNews existed locally. The user explicitly authorized creating the missing database locally. `Backend/tools/Initialize-NewsFixture.ps1` creates fixture PDF/image files under ignored `Backend/artifacts/news-fixture` and runs `Database/Development/004_CreateSampleNews.sql`. It creates a marked local Pubs_Info_V4 with minimal inferred tables and a marked dbo.VNews in CompanyPortal. This is a development contract fixture, not the actual internal database schema or a backup.

The fixture includes published/no-PDF/inactive-attachment news, excluded publication flags, duplicate production join rows, conflicting PDFs, missing/out-of-root/invalid files and a literal-markup title. Twelve source items yield nine visible news items. Test scenarios are labelled explicitly in Arabic. The initializer refuses to seed an unmarked existing news database or replace an unmarked existing view. Reruns preserve existing sample rows and recreate fixture files. Development/005 seeds the absolute fixture directory in Mstr.Utls under PubsInfo only if that key has no rows; existing path/active choices are preserved.

For local setup after migration 012:

```powershell
sqlcmd -S localhost -E -b -I -f 65001 -i Backend/Database/Scripts/013_NewsRead.sql
sqlcmd -S localhost -E -b -I -f 65001 -i Backend/Database/Scripts/014_UtilityFolderPaths.sql
powershell -NoProfile -File Backend/tools/Initialize-NewsFixture.ps1
```

For the internal network, never run Development/004, Development/005 or the initializer. Use the real existing dbo.VNews, apply migrations013/014, configure the connection string and PubsInfo folders in Mstr.Utls, and provision SQL/filesystem rights. The deployment identity owns schema changes. The API SQL identity needs EXECUTE on News.Items_get, Security.User_getByUsername and Mstr.Utls_GetFolderPaths, plus deliberately provisioned read access through the existing cross-database view. Do not use db_owner/TRUSTWORTHY to bypass permissions. No runtime writes are made to the news source or folder settings.

## Verification

- Local Release builds: both solutions succeeded with zero warnings/errors.
- Fixture initializer and migration 013 reruns passed; source rows retained.
- Migration014 application/rerun and `Test-News.ps1 -TestSampleData -TestFolderPaths` passed: SQL PubsInfo roots, other-key isolation, inactive/missing/relative roots, live root updates and restored file access. Original folder/active state was restored and the temporary test-key row removed.
- `Backend/tools/Test-News.ps1 -TestSampleData`: anonymous rejection, pagination bounds/counts/order, deduplication, no path disclosure, publication/attachment filters, PDF/image bytes, inline/no-store/nosniff headers, PDF ranges, missing/unsafe/invalid files and conflict409 passed. The sample publication flag was temporarily changed and restored in finally, proving previously listed file IDs are rechecked. Run the sample switch only against the isolated marked local fixture with no concurrent editing; the base test is read-only.
- Actual browser: picture loads, literal-markup subject remains text, news without an attachment has no title link, pagination reaches the second page, PDF title opens a new tab and the browser PDF viewer renders the attachment. At the checked desktop width, existing floating notices/calendar overlap the left news area; keyboard pagination was verified. Those unrelated overlays were not changed.
- With the test API stopped, reloading displayed Arabic unavailable/retry states and zero news titles, without restoring old demonstration stories. Agent-started test API and frontend processes were stopped after verification.
- Existing frontend parity: 328 baseline files unchanged, six existing routes/313 static resources checked. Offline source scan passed. Internal SQL/view semantics, IIS file access and internal browser authentication still require destination verification.

26 October 2026 selection update: frontend Release, syntax, original frontend parity and offline asset checks passed. Actual browser verified first-item selection, mouse selection without an attachment, keyboard selection of an attached item, exactly one highlight/pressed state, right-side PDF URL and first-item selection after pagination. No SQL/API or news-source changes were required.
