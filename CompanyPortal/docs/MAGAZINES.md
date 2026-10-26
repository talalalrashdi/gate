# مجلة الشهر — database catalog and file roots

The issue selector, magazine name and file selection now read SQL. The current magazine is registered as a local sample; there is no fixed issue/manifest/PDF URL, local file upload or browser-stored issue override in the reader.

## Database contract

Migration **030_Magazines.sql** creates `Portal.Magazines`:

| Column | Type / meaning |
|---|---|
| MagazineID | int IDENTITY, primary key, first column |
| MagazineName | nvarchar(300), required display name |
| IssueNumber | nvarchar(100), required; supports e.g. 50/2026 |
| IssueDate | date, required |
| FileName | nvarchar(1000), required PDF basename, e.g. 39.pdf |
| DisplayOrder | int/default0, nonnegative; orders matching issue dates |
| LastChangeAt | datetime/default GETDATE; maintenance writes should update only for actual changes |
| Active | bit/default1, last column |

**`Portal.Magazines_GetAll @MagazineID int = NULL`** returns the exact columns above. NULL lists active issues, sorted IssueDate descending, DisplayOrder ascending, MagazineID descending. Supplying an ID returns that active issue only. Keep aliases/types and this optional parameter when changing the SELECT to another database. The migration creates the adapter only if absent, preserving custom mappings on rerun. There is no magazine admin/write API in this version.

All active registered portal users can read published issues. The API resolves their Windows NTName using the existing Security.User_getByUsername on every request. A hidden issue cannot be read by its old PDF/page URL. No employee ID is accepted from the browser. Employee JSON omits filenames and physical paths.

## Folder setting

Use **CompanyPortal.Mstr.Utls, Key = Magazines**, with `strVal` containing an absolute local folder or UNC share; the existing **Mstr.Utls_GetFolderPaths** supplies the roots. Multiple active roots are supported. FileName must be a basename, not an absolute path or directory traversal. Copy the real files to an approved root and grant the API account read access (both share and NTFS permissions for UNC). Do not expose internal magazine folders as public IIS directories.

PDFs are served by ID through `GET /api/magazines/{id}/pdf`, with active-user/publication rechecks, signature validation, root boundaries, reparse/device/alternate-stream rejection, inline disposition, nosniff, private/no-store and range processing. Catalog endpoint: `GET /api/magazines`. Invalid/hidden/missing files return404, source/configuration/access failures return sanitized503. API logs provide a trace reference.

## Retaining page turns and thumbnails

The existing viewer uses prepared page images. To retain its two-page display, page turns, page navigation and thumbnail grid for an issue, place an optional companion folder beside its PDF:

```
Magazines root/
  39.pdf
  39-pages/
    manifest.json
    001.webp
    002.webp
    ...
```

The folder name is the PDF stem plus **-pages**. manifest.json is UTF-8 JSON with `pages` entries: `{ "file": "001.webp", "width": 411.024, "height": 595.276 }`. Width/height preserve aspect ratio. Only safe basenames and PNG/JPEG/WebP images are accepted. Manifest limit256KB, 1–2000pages, bounded positive finite dimensions. The API returns dimensions only; image filenames/directories are never sent to employees.

- `GET /api/magazines/{id}/pages` returns page dimensions, or404 if no companion manifest exists.
- `GET /api/magazines/{id}/pages/{page}` returns a signature-checked page image and rechecks current publication and approved roots.

If no companion exists, the PDF opens in the reader’s native browser PDF frame. Its own toolbar handles page navigation; the external thumbnail/page-count controls are disabled because the browser does not expose an authenticated PDF’s page count to this script. Zoom/fullscreen and opening the PDF separately remain available. Actual native PDF rendering depends on the destination browser; current sample page-image rendering was verified in IAB. There is no PDF conversion service, new NuGet package or internet dependency. Prepared page images can be generated offline as a separate publishing step.

The catalog loads once on page load (or explicit retry/history restoration); ordinary tab-focus/visibility changes do not reload it. It selects the latest active issue first. Changing issues clears the previous pages/frame/zoom/thumbnails and cancels pending requests. Empty catalogs show an Arabic empty state; source failures show retry. No sample/static fallback or localStorage catalog is used. Original frontend assets remain preserved as migration baseline/fixture inputs; runtime magazine URLs use the API and the copied external root.

## Local sample and deployment

Applied locally: migration030 and **Backend/tools/Initialize-MagazineFixture.ps1**, which runs Development/015_CreateSampleMagazine.sql. It registers the existing name/issue metadata (مجلة الفلق, 50/2026, 2026-10-01,39.pdf) once and copies the unchanged PDF plus258 existing page images/manifest to `Backend/artifacts/magazine-fixture`. It inserts the Magazines root only if absent. Reruns preserve records, timestamps, identity, root and existing files, refusing an unmarked existing catalog or a different configured root. The label follows the pre-existing UI; no new PDF content was generated.

Internally:

1. Apply pending migration030 to the existing CompanyPortal database.
2. Map Portal.Magazines_GetAll to the real source if necessary, retaining its contract; insert/map real issue metadata.
3. Copy PDFs and optional companion folders; configure Magazines in Mstr.Utls and file access.
4. Rebuild/republish both apps. Magazine JS now uses asset versioning to avoid an old static reader script remaining cached.

Fresh Setup.sql includes030 without the development sample. Historical CurrentData exports and Airgap publish folders were not regenerated; copy external media files as well as updated SQL/apps when preparing a handoff. Do not run the development initializer over internal production data.

## Verification

Both Release builds, JS syntax, Swagger, frontend parity and offline asset scan passed. `Backend/tools/Test-Magazines.ps1` verifies catalog/no-path exposure, anonymous denial for all routes, PDF ranges, preview MIME/page bounds, hidden-issue direct-file denial and unsafe filename rejection, restoring metadata afterward. Migration/initializer reruns retained catalog/timestamps/root/SP/identity; copied PDF hash matches the original.

Actual browser checks passed for the sample cover/258pages from API, two-page turn, thumbnails, page jump, zoom, keyboard navigation, final-page boundary and PDF link. A temporary newer PDF-only issue proved latest-first selection, native frame source and switching back to page images; its record/file were removed and identity restored. Native PDF page painting remains a destination Edge/Chrome acceptance check.


## Per-user جديد badge and read tracking (migration031)

The secondary-header badge is hidden until the catalog loads successfully, then shown only if the latest active issue has **HasRead=false** for the current employee. Catalog JSON now includes HasRead for every issue in the existing GET /api/magazines response; there is no separate badge/status HTTP request and no polling. Publishing a different latest MagazineID makes the badge appear again for that employee on the next page load. Replacing a PDF under the same ID does not reset its read status; revisions would require a separate future version field.

**Portal.UserMagazineReads** contains UserMagazineReadID int IDENTITY PK, UserId int, MagazineID int, ReadAt datetime/default GETDATE, Active bit/default1. A unique(UserId,MagazineID) prevents duplicates. No FK binds it to an external identity/magazine source.

- `Portal.UserMagazineReads_Get @UserId int`: active read MagazineIDs for this employee.
- `Portal.UserMagazineReads_MarkRead @UserId int,@MagazineID int`: transaction/unique-range lock inserts once; an already-active read causes no update and preserves ReadAt. A deliberately inactive record is reactivated with a new timestamp.
- `POST /api/magazines/{id}/read`: requires Windows authentication, current active employee lookup, current active issue, readable valid approved PDF, X-CompanyPortal-Request: magazine-read and an allowed Origin. It accepts no browser UserId. Returns204 only after the read is persisted; unavailable/hidden issues cannot be marked. All existing file GETs remain read-only.

A loaded page alone does **not** mark the issue read. The reader must be at least25% visible in an active browser tab and have a successfully loaded main page image/native frame. Explicitly opening its PDF also qualifies. This means viewed/opened, not completion of every page. The browser sends at most one mark attempt per unread issue per page lifetime, setting its attempt flag before starting the request. Further scrolls, page turns, zooms, issue reselection and tab-focus events do not repeat it. On success it remembers the read in page memory and hides the latest-issue badge; already-read issues from SQL cause no POST, including after reload. No personal read state is stored in localStorage.

A failed mark leaves the badge visible and does not retry automatically; a full page reload can retry. Multiple tabs can race with one attempt each, but SQL still keeps one record and its original timestamp. New publication in another session is reflected on the next catalog load rather than background polling. Browser page/file requests needed to display pages are separate from these read writes.

Validation: API header/origin/anonymous/current-user/hidden-issue tests and duplicate-timestamp checks passed. Request logging confirmed one catalog GET and one read POST after viewing, with no additional read POST on scroll/page/zoom/revisit/reload; a newer issue showed جديد independently of another employee’s read and made one write of its own. Temporary browser read rows/newer issue were identified by exact IDs/timestamps, backed up and removed; original unread state restored. Both builds, frontend parity and offline assets passed. Fresh Setup includes031; historical CurrentData/Airgap are unchanged. Test script: Backend/tools/Test-MagazineReads.ps1 (local marked fixture only).
