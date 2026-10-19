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

The existing opening news panel and editorial news section now load database summaries. Titles with a PDF are links opening a new tab; titles without one are plain text. A separate preview action selects a summary/picture in the existing editorial layout. The list pages through the API in groups of eight; the opening carousel uses the latest eight and keeps its existing animation, reduced-motion handling and manual controls. Date headings remain live. Source news dates preserve their calendar day without assuming a database timezone.

Database subjects are rendered as text, not HTML. Pictures with a failed file request are removed. Empty/error states are Arabic and errors offer retry; the old demonstration news and outbound source links are no longer used as a fallback. This does not change the separate video/photo/magazine sections, calendar or notices. Theme/card settings and existing storage are retained.

## File configuration and IIS

Production defaults to an empty `News:AllowedRoots`; files remain unavailable until explicitly configured. Example environment configuration:

```json
{
  "News": {
    "AllowedRoots": ["D:\\PublishedNews\\PDF", "D:\\PublishedNews\\Pictures"]
  }
}
```

Source paths must be fully qualified local/server filesystem paths accessible from the API server. A path on a different machine's drive is not automatically available on the API server. AllowedRoots are filesystem boundaries, not a mapping that rewrites old source paths. Relative configured roots resolve against the API content root (used only by the local fixture configuration). Give the API IIS identity read access to source folders. Employees must not have write access to these trusted directories. SQL and filesystem identities are the API service identity, distinct from employee identity.

The file reader checks canonical paths against allowed directory boundaries, rejects Windows device/alternate-stream paths and reparse points in the file/parent chain, and verifies extension plus file signature. Supported pictures: PNG, JPEG, GIF and WebP; SVG/HTML are not served. Files are streamed rather than loaded wholly into memory. Trusted server-managed folders are required; concurrent malicious changes to source directories are not an intended operating model.

## Local sample database

At implementation time neither Pubs_Info_V4 nor dbo.VNews existed locally. The user explicitly authorized creating the missing database locally. `Backend/tools/Initialize-NewsFixture.ps1` creates fixture PDF/image files under ignored `Backend/artifacts/news-fixture` and runs `Database/Development/004_CreateSampleNews.sql`. It creates a marked local Pubs_Info_V4 with minimal inferred tables and a marked dbo.VNews in CompanyPortal. This is a development contract fixture, not the actual internal database schema or a backup.

The fixture includes published/no-PDF/inactive-attachment news, excluded publication flags, duplicate production join rows, conflicting PDFs, missing/out-of-root/invalid files and a literal-markup title. Twelve source items yield nine visible news items. Test scenarios are labelled explicitly in Arabic. The initializer refuses to seed an unmarked existing news database or replace an unmarked existing view. Reruns preserve existing sample rows and recreate fixture files. The Development configuration allows only the fixture directory.

For local setup after migration 012:

```powershell
powershell -NoProfile -File Backend/tools/Initialize-NewsFixture.ps1
sqlcmd -S localhost -E -b -I -f 65001 -i Backend/Database/Scripts/013_NewsRead.sql
```

For the internal network, never run Development/004 or the initializer. Use the real existing dbo.VNews, apply migration 013, configure connection string and News:AllowedRoots, and provision SQL/filesystem rights. The deployment identity owns schema changes. The API SQL identity needs EXECUTE on News.Items_get and Security.User_getByUsername plus deliberately provisioned read access through the existing cross-database view. Do not use db_owner/TRUSTWORTHY to bypass permissions. No runtime writes are made to either news source or CompanyPortal news data.

## Verification

- Local Release builds: both solutions succeeded with zero warnings/errors.
- Fixture initializer and migration 013 reruns passed; source rows retained.
- `Backend/tools/Test-News.ps1 -TestSampleData`: anonymous rejection, pagination bounds/counts/order, deduplication, no path disclosure, publication/attachment filters, PDF/image bytes, inline/no-store/nosniff headers, PDF ranges, missing/unsafe/invalid files and conflict409 passed. The sample publication flag was temporarily changed and restored in finally, proving previously listed file IDs are rechecked. Run the sample switch only against the isolated marked local fixture with no concurrent editing; the base test is read-only.
- Actual browser: picture loads, literal-markup subject remains text, news without an attachment has no title link, pagination reaches the second page, PDF title opens a new tab and the browser PDF viewer renders the attachment. At the checked desktop width, existing floating notices/calendar overlap the left news area; keyboard pagination was verified. Those unrelated overlays were not changed.
- With the test API stopped, reloading displayed Arabic unavailable/retry states and zero news titles, without restoring old demonstration stories. Agent-started test API and frontend processes were stopped after verification.
- Existing frontend parity: 328 baseline files unchanged, six existing routes/313 static resources checked. Offline source scan passed. Internal SQL/view semantics, IIS file access and internal browser authentication still require destination verification.
