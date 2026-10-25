# أخبارنا: videos, photos and albums

The existing **أخبارنا** carousel and photo presentation now read database records. The database stores names and file paths, not file BLOBs. All registered active portal users can view published media. **أخبار عامة** news/PDFs and **مجلة الشهر** remain separate.

## Using administration

Open **إدارة البوابة → أخبارنا** (`/admin/media`). The two views are **الفيديوهات** and **الصور والألبومات**.

- Add/edit a video or photo: enter a name, file path, display order and visibility. Images may belong to an album or remain independent. Videos are independent.
- Add an album first, then add/move its photos and select its cover. The cover must be a photo in that album. Automatic cover uses the first visible photo by order, then ID. A hidden preferred cover falls back to a visible photo; an empty album is omitted.
- **تحقق من الملف ومعاينته** checks a draft path and displays the real image/video without saving or publishing it. Missing files, invalid paths/signatures, unsupported types, unreadable folders and unconfigured roots have distinct Arabic messages.
- Visible saves validate the physical file before publishing. Hidden records can be saved while preparing or repairing their paths. Hiding a record/album does not delete data. Album hiding also hides its photo bytes from direct employee file URLs.
- Name/path/order/visibility changes and cover selection use the existing last-save-wins convention. LastChangeAt changes only for actual metadata changes. Moving a cover photo out of its album clears that album's preferred cover atomically.

The editor warns before discarding unsaved changes. A photo in a hidden album is labelled **مخفي مع الألبوم**, with an editor warning and corresponding save caption. Save/publish changes appear to employees when the section/page is reloaded. There is no employee file picker, upload, deletion, external video embedding, automatic background polling or transcoding in this version.

## Photo navigation and video thumbnails

Opened albums support Left/Right arrows (RTL: Left advances), Home and End, including when toolbar or thumbnail buttons have focus. Number/range inputs retain their native keyboard behaviour. Opening an album focuses the image stage. Zoom the image, then hold the left mouse button and drag to pan horizontally or vertically; releasing the pointer, changing photos, closing or resetting zoom ends the drag. Native scrollbars remain available.

Videos preload metadata and seek to 0.1 seconds (half the duration for shorter clips) to display a decoded frame while paused, both in the employee carousel and admin draft preview. This fetches video bytes from the same authenticated database-backed API file URL; there is no separate poster URL, static fallback, autoplay, thumbnail server or runtime FFmpeg dependency. Codec/file/access errors still appear as errors. A video whose opening frame is black can still have a black preview; supplying well-encoded files with suitable opening content is recommended.

The admin media screen includes catalog counts, searchable typed records, publication states, an initial empty editor prompt, structured content/publication/preview sections and sticky save controls. Counts include hidden records because this is the administrative catalog.

## File location and offline operation

The API reads approved roots using the existing `Mstr.Utls_GetFolderPaths` SP. Configure **Key = PortalMedia**, with `strVal` containing the absolute local folder or UNC share path. Do not change the existing PubsInfo, LegalAffairs or docs keys.

Prefer storing **relative** paths, for example `events\opening\photo.jpg` or `team.mp4`. After copying the files to another machine, change the PortalMedia root value/its SP mapping. Fully qualified local or UNC paths are also accepted if they remain inside an approved root. Changing the allowed root does not rewrite old absolute MediaPath values: normalize those in the source SP if necessary.

Copy the actual media folder along with database metadata. Files are not included in a SQL backup/export. The API process/app-pool identity needs read access; for UNC shares, both share and NTFS permissions must allow it. Use UNC paths rather than employee-mapped drive letters. Do not expose the folder as an unrestricted IIS virtual directory; the API serves it after checking publication. No Exchange impersonation/delegation or separate media service is used.

Supported photos: PNG, JPEG, GIF and WebP. Videos: MP4 with an initial valid ftyp box; use H.264 and AAC for broad browser compatibility (audio is optional). Extension/container signatures are checked, but the API does not decode/transcode or guarantee every MP4 codec. A file/permission/codec problem cannot be fixed solely by changing a database SP.

Image and video responses stream through the API by ID with correct MIME, inline Unicode filenames, nosniff, private/no-store and range support for seeking. The whole video is not buffered into application memory. Root boundaries, traversal, device paths, alternate streams and reparse points are rejected. Physical paths are omitted from employee JSON and URLs.

## Tables and source SP contract

Migration **028_PortalMedia.sql** creates:

| Table | Fields |
|---|---|
| `Portal.MediaGroups` | MediaGroupID int identity PK; GroupName nvarchar(200); CoverMediaID int NULL; DisplayOrder int; LastChangeAt datetime/default GETDATE; Active bit/default 1 |
| `Portal.Media` | MediaID int identity PK; MediaName nvarchar(300); MediaPath nvarchar(2000); MediaType nvarchar(20), image/video only; MediaGroupID int NULL; DisplayOrder int; LastChangeAt datetime/default GETDATE; Active bit/default 1 |

Foreign keys protect membership/cover IDs. Videos cannot belong to photo albums. Orders are nonnegative. Metadata saves are transactional and serialized with a transaction-owned SQL application lock to avoid competing cover/move updates.

**All media persistence/source reads are behind these SPs.** Adapt their SELECTs/writes to the internal database while keeping parameters, field names, types and result shapes unchanged:

| Procedure | Contract |
|---|---|
| `Portal.Media_GetAll @IncludeHidden bit=0` | **Two result sets**: groups first (MediaGroupID, GroupName, CoverMediaID, DisplayOrder, LastChangeAt, Active); media second (MediaID, MediaName, MediaPath, MediaType, MediaGroupID, DisplayOrder, LastChangeAt, Active). Ordered by DisplayOrder then ID. |
| `Portal.Media_GetById @MediaID int, @IncludeHidden bit=0` | Zero/one media row with the same media fields. At IncludeHidden=0, return nothing for a hidden item or a photo whose album is hidden. This check also applies to previously known/cached IDs. |
| `Portal.Media_Save` | MediaID nullable for creation; MediaName, MediaPath, MediaType, MediaGroupID nullable, DisplayOrder, Active. Return one scalar int ID. Validate group membership and clear an invalidated cover on a move/type change. |
| `Portal.MediaGroups_Save` | MediaGroupID nullable for creation; GroupName, CoverMediaID nullable, DisplayOrder, Active. Return one scalar int ID; cover must belong to this photo group. |

MediaType is lowercase `image` or `video`. IDs must be stable positive ints, names/paths nonnull; group references must be consistent. IncludeHidden=1 is used only after current administrator authorization. If the internal source lacks portal metadata such as ordering, aliases/defaults or retained portal metadata can supply the fixed contract. Adapt **both read and write SPs** if the admin page should save to another database; changing only a read SP will not redirect saves. SQL 50011 means missing record; 50012 means invalid/conflicting fields. The default scripts implement the contract against CompanyPortal tables.

## HTTP and preview protection

- `GET /api/media`: published groups, cover IDs and items; no physical paths.
- `GET /api/media/{id}/file`: current employee registration plus current item/album publication rechecked before reading bytes.
- `GET /api/admin/media`: all administrative metadata, including hidden records.
- `POST /api/admin/media/items`, `PUT /api/admin/media/items/{id}`: create/edit media.
- `POST /api/admin/media/groups`, `PUT /api/admin/media/groups/{id}`: create/edit albums.
- `POST /api/admin/media/preview`: validate draft path and issue an encrypted, authenticated-account-bound 30-minute preview token. It writes no portal data.
- `GET /api/admin/media/preview/{token}`: recheck the **current** admin role, token account/expiry and approved file roots, then stream bytes with range support. Native image/video controls can preview without loading an entire video into a JavaScript blob. Tokens may become invalid after API recycling/key changes; request a new preview.

Every admin endpoint requires the current external `CompanyPortal.Admin` role. JSON writes/previews additionally require `X-CompanyPortal-Request: media` and an allowed Origin. The browser cannot submit a user ID or admin flag. Unknown JSON fields, invalid lengths/types/IDs and videos assigned to albums are rejected. Browser catalog/gallery state is cleared on hide/failure and refreshed on return; no media catalog is saved in localStorage.

## Samples and deployment

`Database/Development/013_CreateSamplePortalMedia.sql` and `tools/Initialize-PortalMediaFixture.ps1` create a marked **development-only** catalog: one visible three-photo album, two independent photos, three videos, and explicit hidden examples for checks. Photos reuse the existing local artwork. The four-second H.264 MP4 is a generated test pattern, not footage of real company events.

The initializer copies files under `Backend/artifacts/media-fixture`, preserves existing files, configures PortalMedia only if absent, and refuses to overwrite a non-fixture catalog or write through a different configured root. Reruns preserve all admin changes. It can reuse an existing fixture `team.mp4`, accept `-SampleVideoPath`, or use the development-generated `.local/media-tools/sample.mp4`. FFmpeg was used only to generate that sample; it is **not** a runtime/NuGet/offline dependency. To regenerate with a trusted local FFmpeg binary:

```powershell
ffmpeg -f lavfi -i testsrc2=size=640x360:rate=15 -t 4 -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an sample.mp4
powershell -File Backend/tools/Initialize-PortalMediaFixture.ps1 -SampleVideoPath sample.mp4
```

Apply only pending migration 028 to existing CompanyPortal databases and rebuild/republish both apps. The generated `Deployment/CompanyPortal-Setup.sql` includes 028 for fresh installs only. Historical CurrentData exports/Airgap application folders were **not** refreshed; update the snapshot/published apps and copy the external media files when preparing a new offline bundle. Never replay fresh setup or development fixtures over internal production records.

## Verification

Both Release builds, Swagger, authenticated media/admin tests, MP4 seeking, Unicode filenames, no-op timestamps, cover fallback, photo moves, hidden album/direct-file denial, root/signature/path errors, header/Origin checks, role revocation and preview no-write/tamper checks passed locally. Tests remove their own records/files and restore sample grants; original metadata/timestamps are compared afterward. Migration/fixture reruns preserve current data. Frontend baseline preservation and local/offline-asset scans pass.

Browser checks verify actual MP4 playback to the end, album-only photos/thumbnails/keyboard navigation, draft image preview, clear missing-file errors, admin album/photo creation, cover selection and publication. Temporary browser records are removed afterward. Real destination UNC/IIS permissions and playback in its browser still need internal acceptance.

Run `Backend/tools/Test-PortalMedia.ps1` only against the marked local fixture and temporary local API, not production.

25 October UI follow-up: Release build and JS syntax checks, offline asset scan and original frontend parity passed. Actual browser checks verified toolbar-focused arrows/Home/End, zoomed drag (390px horizontal/180px vertical), paused decoded video frames, playback, and the revised admin editor/draft video preview. No database/schema or SP changes were needed, and these checks made no business-data writes.

Carousel correction: clicking any visible part of an adjacent video selects it without autoplay; only the selected card exposes its dialog play button. RTL scroll targets are clamped to actual scroll limits for selection as well as navigation, so the last video remains selected at the end without blank padding. Photo-stage double-click uses the same zoom toggle as the toolbar and retains drag-to-pan. Browser checks passed for adjacent selection, rapid advancement to 4/4, last-video playback and double-click in/out. No SQL/API changes.

## Modal viewing and scrolled header

The carousel displays paused video thumbnails only. Its play button opens a labelled native video dialog with controls and the same authorized media file URL; no video plays inline. Closing by Escape, close button or an outside click pauses the player, removes its source and restores focus. Photo dialogs also dismiss on outside clicks; an inside-to-outside drag does not dismiss them. Both dialogs lock root/body page scrolling while allowing their own content/zoomed image to scroll. Closing restores the existing page position and normal page scrolling. No database changes are required.

The shared header tracks the actual hero bottom and switches to dark navigation text on a light header after the hero passes behind it. Scroll and hero/viewport resizing update this state; returning to the hero restores its theme foreground. Browser checks passed for paused inline thumbnails, modal playback, wheel scroll locking at unchanged page positions, photo backdrop dismissal, double-click zoom, Escape cleanup and computed scrolled header contrast. Release/parity/offline asset checks passed.

The video carousel has subtle overlaid edge-arrow buttons with dark gradients fading toward the video. Physical left/right positions and SVG chevrons prevent RTL layout/text mirroring from reversing their appearance. At the user’s request, the overlaid directions are reversed: the right-edge left-pointing arrow advances, and the left-edge right-pointing arrow returns to the previous video. Hover/focus raises opacity, and boundary arrows are disabled. These controls share the existing toolbar state and keyboard navigation. Mouse dragging was removed at the user’s request; native touch/trackpad scrolling remains. Browser checks verified both edge directions, including 3/4→2/4.

Header polish: both rows inherit the same background, with an opaque white surface after the hero. Existing scroll-position tracking now has a clear green background on the current secondary-header section, with dark readable text. Manual browser scrolling verified أخبارنا → مجلة الشهر → وثائق تهمك; enlarged 34px/bolder edge chevrons, 64px gradient hit areas and reversed controls were also verified.

Latest edge styling: both controls use black backgrounds, 88px-wide full-height panels and 50px bold white chevrons. Both sides stay visible at list boundaries; an unavailable direction is disabled/dimmed rather than removed. Existing reversed directions are retained. Browser computed-style and screenshot checks confirmed both black panels and arrow sizes; frontend Release passed.

Current arrow layout correction: one shared CSS grid cell with explicit LTR alignment anchors the left and right overlays to opposite edges; the video track itself remains RTL. Left arrow points left/advances, right arrow points right/returns. Both retain 88px areas/50px chevrons. Black backgrounds now fade from 85% opacity at the outer edge to transparent inward. Browser measured separate left/right rectangles and verified both actions; Release passed. This supersedes earlier reversed-direction/solid-background notes.
