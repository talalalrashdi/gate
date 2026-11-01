# Portal loading and optional application descriptions

Implemented 1 November 2026.

## What employees see

The hero and navigation appear immediately. Workspace cards retain their normal height, with quiet placeholder rows while offscreen. Content is prepared roughly 300px before reaching the viewport; horizontal cards prepare when they come into view. Selecting a section link also prepares that section before scrolling. Once prepared, it stays ready for the page lifetime. Existing refresh and authorization rules still apply.

الرئيسية returns to the absolute page top, including the hero/header.

## What waits

- Forms and correspondence: counts and app links load immediately through authenticated `/api/forms/count` and `/api/correspondence/count`; full inbox rows load near the card. Count endpoints use the existing unread-count SPs and do not execute the full inbox SPs.
- Email: live SSE and unread count remain immediate; offscreen row rendering waits. Calendar/task live connections and notifications remain immediate.
- Decisions: source metadata and floating notices remain immediate; offscreen decision list rendering waits.
- Technical services: dropdown catalog waits until the card approaches view.
- Magazine: the issue catalog and unread badge load immediately, then the selected PDF and reader libraries prepare immediately so the reader is ready sooner. Individual pages near the current spread and visible thumbnails are still drawn lazily.
- Documents/safety: authorized catalogs and unread badges remain immediate; offscreen cover/tab rendering waits. PDF files continue loading only when opened.
- أخبارنا: catalog and unread badge remain immediate; carousel rendering waits. Video thumbnail metadata loads near each video; actual playback remains in its dialog. Photo thumbnails retain native lazy loading.

The shared helper uses IntersectionObserver, not a polling timer. No packages, CDNs or internet requests were added. Without IntersectionObserver, existing immediate behavior is retained. Repeated waiting updates replace the pending render so stale snapshots are not replayed; failed/revoked loads clear pending private content.

## Application description

Apply `Backend/Database/Scripts/060_OptionalApplicationDescription.sql` to existing installations. Fresh `Deployment/CompanyPortal-Setup.sql` includes it. Local development database has already been migrated.

`Master.ApplicationDetails.AppDescription` remains nvarchar(2000), now nullable. Save accepts omitted, NULL or whitespace-only descriptions and stores NULL. Read procedures retain empty-string normalization for existing clients. Names, identifiers, permissions and required file/link fields retain their validation. No other field requirements were relaxed.

The migration preserves timestamps when normalizing empty descriptions. Repeating an equivalent NULL/blank save does not change LastChangeAt or add an audit entry.

## Verification

Both projects build with zero warnings/errors. Automated tests cover deferred/latest-only gates, hash activation, cleanup, absolute-top navigation, immediate and deferred inbox loading, filters/read state, live mail/schedule, library, decision popups, media unread tracking and offline assets. Real local API checks confirm count parity, no inbox items in count responses, anonymous 401 and valid Swagger. Optional description binding and transactional SQL no-op behavior passed; SQL test writes were rolled back.

Visual browser acceptance remains pending: the browser automation tool could not initialize. Check scrolling into the workspace, moving its horizontal cards, clicking section links and returning to الرئيسية. Confirm no layout jumps and that magazine/media assets begin loading near their sections. Existing CurrentData snapshots and offline ZIPs were not rebuilt; rebuild the deployment package before copying this version internally.
