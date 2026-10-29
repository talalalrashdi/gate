# Header events

Administration: `/admin/events` → الفعاليات. Events always follow وثائق تهمك, ordered by EventId, with the moving gradient and a جديد badge only until one minute after StartAt (publication start). Refreshing the page does not renew this deadline; older events render without the badge. Republished events use their new start time. Simulation remains a local one-minute timer. Employee catalog loads once per page; no polling. Visibility is evaluated on page load, and checked again whenever a file is requested.

## Types and targets

- **0 — عرض ملف PDF:** the title opens the authenticated inline PDF endpoint in a new tab, consistent with portal documents/decisions.
- **1 — رابط صفحة أو تطبيق:** opens an HTTP(S) URL in a new tab with noopener/noreferrer; embedded credentials and other schemes are rejected.
- **2 — فيديو في نافذة:** plays an MP4 in a modal. Escape, Close, or clicking the backdrop closes it; playback stops, page scroll unlocks and focus returns to the event. The same range-enabled endpoint serves video seeking.

`EventTarget` stores the full server file path or URL; `EventType` determines its meaning. Employees receive an event ID/type and file endpoint, never a disk path. Admins choose exactly one file source in two side-by-side cards:

- **اختيار ملف من جهازك:** browser file picker from any local folder. The file is transferred only when Save is pressed. PDF for type0, MP4 for type2;100MiB maximum. No pre-upload on selection or cancel. The original client path is never treated as a server path.
- **كتابة مسار الملف:** an existing absolute path on the API machine or UNC share readable by the API identity. Examples and the actual configured roots appear below the field. No saved-file list is used by the editor.

Validation errors appear in a red summary **inside the modal** and next to affected fields; source/title/date/URL/extension/size validation happens before a request. Server errors distinguish outside-root, missing file, wrong signature, missing root and read/write permissions. No repeated generic400 toasts obscure the cause.500-level responses include a diagnostic reference when available. The selected values and file remain in the editor for correction.

## Folder configuration and uploads

Manual files can come from active trusted paths returned by `Mstr.Utls_GetFolderPaths` for **Events, PubsInfo, Magazines, PortalMedia, docs**. Reuse configured stores or add a dedicated **Events** key. These are paths on the **API server**, not an employee workstation. API read access is required. Admins should publish only files intended for all portal users.

Uploads go to **EventUploads** beneath the first configured Events root, or the existing PortalMedia root when Events is absent. This fallback uses the configured database folder, never a hardcoded workstation directory. Grant the API service/app-pool account **Modify** on that upload directory. The upload API creates it if permitted. Files use generated GUID names with .pdf/.mp4 extensions; extension and actual signature are checked. The stored event path then uses the same protected reader as manually referenced files. Invalid uploads are removed. Confirmed database validation/not-found failures remove the new upload; if a database save outcome is uncertain, the file is retained and a warning is logged to avoid deleting a possibly committed event's file. Verify references before cleaning such files. Replacing/deleting an event does not delete previously published source files.

**IIS upload limit:** the application permits100MiB files and105,000,000-byte multipart requests. Set the API application's IIS Request Filtering → Edit Feature Settings → Maximum allowed content length (Bytes) to **105000000** if using larger files. IIS may reject a request before ASP.NET Core; the editor explains an unstructured upload404/413. Configure this once on the internal IIS deployment. No internet service is used.

Device paths, alternate streams, reparse points, out-of-root paths and invalid PDF/MP4 signatures remain rejected. Hidden/scheduled/expired events return404 for file access, including uploaded files.100MiB is an application limit, not a browser upload guarantee across an unconfigured proxy/IIS server.

## Dates and yearly reuse

Start dates use Muscat time (+04:00). End controls are date-only and show an explicit11:59PM note; every API save normalizes EndAt to23:59 of its Muscat date, and validates that this is after StartAt. Dates are transmitted with an offset and stored as UTC SQL datetime and evaluated using GETUTCDATE (start inclusive, end exclusive). LastChangeAt uses GETDATE; no-op saves preserve timestamps and history. Rows show **مخفية / مجدولة / ظاهرة للجميع / انتهت**.

Use **إعادة جدولة** to edit a new start/end period on the same EventId. Dates are entered manually; there is no next-year shortcut or automatic annual publication.

Non-live rows offer **نشر للجميع الآن**. A confirmation dialog identifies the event, explains that it will start now, and lets the admin choose its end date. It initially retains a future end date, or proposes seven days from now for an expired event; the proposal is visible and editable before confirmation. Confirming saves IsDisplayed=true and a current start time on the same record. Cancel/Escape makes no changes. File events are revalidated by the API before publication. Already-open employee pages still need reloading, consistent with the no-polling requirement.

Both the editor and publication dialog have **أسبوع من اليوم / 10 أيام من اليوم / 15 يوم من اليوم** end-date shortcuts. Each selects the local date7/10/15days from today, ending at23:59 (+04:00), rather than adding to the previous selection. Repeated clicks do not accumulate days; these buttons do not save. End must still be after start.

Displayed events also offer **إخفاء عن الجميع** with confirmation. It sets IsDisplayed=false (Active stays1) while retaining the same title, dates, target and EventId. Cancellation makes no changes; hidden rows omit the hide button and can be republished later. The API allows disabling an event even if its file is unavailable, while reactivation/publication still requires a valid existing file. Hiding stops file access immediately; an already-open employee header loses its cached link on reload.

Cards use fixed400px grid tracks (shrinking only when the viewport cannot fit400px), so one or two cards never expand to consume unused space, with العنوان above the title, clear status badges, type, dates and grouped actions. Add, Edit and Reschedule open the same modal editor with a fixed header/actions, internally scrolling body and page scroll lock. Closing, backdrop click or Escape respects busy/unsaved-change guards; approved section navigation closes the modal. The full URL/path is always visible directly on each card and wraps safely. Existing history, shared feedback and unsaved guards remain.

## Migration and API

Apply **055_HeaderEventTypes.sql** after054 to an existing installation. It renames AppUrl→EventTarget, adds EventType default1 and updates the existing four event procedures, preserving existing links. The API accepts legacy AppUrl link requests during rollout; new admin/public contracts use EventTarget. Migration **056_HeaderEventEndOfDay.sql** aligns existing end times to23:59 on their existing Muscat date, through the audited save procedure; rerunning makes no changes. It stops rather than changing the day if an existing start is later than23:59 on that day. Fresh CompanyPortal-Setup.sql contains migrations001–057; never run that fresh script against an existing database. The historical CurrentData snapshot is unchanged.

- GET `/api/header-events`: active events for a registered Windows portal user.
- GET `/api/header-events/{id}/file`: currently visible PDF/video, authenticated, inline and range-enabled.
- GET `/api/admin/events`: all rows.
- GET `/api/admin/events/file-options`: folder hints and upload limit; event admins only.
- POST `/api/admin/events/upload`: protected multipart `file`, JSON `payload`, optional `eventId`; validates and saves an uploaded event.
- GET `/api/admin/events/files`: older bounded catalog endpoint retained for existing tooling; not used by the editor.
- POST `/api/admin/events`: create.
- PUT `/api/admin/events/{id}`: edit, reschedule, reactivate or hide the same record.
- DELETE `/api/admin/events/{id}`: soft delete (Active=0); retain the row and files.

Admin routes use the events section permission. Writes require the events request header and allowed Origin. History uses section events/item type event with before/after snapshots and last-save-wins semantics. Existing Development event simulation remains memory-only, with no new simulation controls or refresh requests.

## Verification

`node CompanyPortal/tools/verify-header-events.mjs` covers catalog rendering, unsafe links, new badges, expiration, one fetch, simulation/reset and load races.

`Backend/tools/Test-HeaderEvents.ps1` checks CRUD, windows, authorization/header/origin gates, invalid URL/type/path/date rejection, no-op timestamps/history, PDF/video catalog and MIME types, range delivery, hidden/scheduled file denial, reactivation without duplication, delete/history and Swagger. It uses uniquely marked temporary events and removes only its own records/history.

Browser checks cover file selection, status badges, rescheduling, confirmed publication/cancellation, hiding/cancel, all three fixed-from-today shortcuts and repeat-click stability, dirty editor, and video modal/scroll lock/stop-on-close/focus return. Destination file permissions and external app links still require acceptance on the internal machine.

Upload regression: `Backend/tools/Test-HeaderEventUploads.ps1` verifies PDF/MP4 upload/delivery, generated safe names, header/origin gates, folder hints, signature/root/metadata errors and Swagger. It removes only uniquely marked test records/history and generated files under the local workspace. Browser checks cover both source cards, required-source/title messages, detailed out-of-root rejection and successful manual-path save. Actual native file-selection interaction is complemented by the multipart API tests.

Secondary header layout: when event tabs are present, navigation uses the available row width rather than the old700px cap. Safe centring preserves RTL overflow access; a thin horizontal scrollbar appears only if the complete set does not fit. Small edge padding protects tab borders/focus outlines.

The events page hides the redundant إعدادات البوابة badge and authorization-success banner. Loading, authorization errors and other admin sections keep their existing feedback.

The editor shows a small غير محفوظ badge beside its title. The path-source card includes setup guidance: add the folder only to CompanyPortal.Mstr.Utls with Key=Events, strVal=absolute local/UNC folder, Active=1; reload and enter the full filename in the editor. API read permission is required.

## Event table and deletion (migration057)

The current table is **Mng.Events** (renamed from Mng.HeaderEvents), with separate flags:

- **IsDisplayed bit NOT NULL DEFAULT(1):** show/hide. Publish, hide and editor checkbox use this field in both JSON and the save procedure.
- **Active bit NOT NULL DEFAULT(1):** retained record. Delete sets0 and updates LastChangeAt; it never removes the row or file.

Employee reads require Active=1, IsDisplayed=1 and the current date window. Admin lists show only Active=1, including hidden/future/expired records. Normal updates cannot edit or republish an Active=0 record; no restore/trash feature was added. Delete history contains both before/after snapshots, including Active=false. Repeated deletion returns404 without another history entry.

Apply **057_EventsDisplayAndSoftDelete.sql** after056. It preserves IDs and maps every existing row's former Active value into IsDisplayed, then sets Active=1 for those retained records; existing hidden events remain hidden. Visibility mapping does not change LastChangeAt. Rerunning does not remap or revive deleted rows. Existing earlier hard-deleted events cannot be recovered by this migration. The four Mng.HeaderEvents_* procedure names and HTTP routes remain stable; their table references, parameter (`@IsDisplayed`), filters and delete logic are updated. Do not replay older migrations after057. Restart both API and MVC so their new JSON/checkbox contract loads together.

Test-HeaderEvents checks migration-era visibility semantics, Active retention on hide, Active=0 row retention after delete, admin/employee exclusion, deleted-file denial, normal-update non-restoration and deletion history snapshots. Test cleanup physically removes only uniquely identified disposable fixtures, never real event records.
