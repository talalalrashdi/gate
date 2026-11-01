# Admin loading and layout

Implemented 1 November 2026. Frontend-only change; republish frontend and reload the admin page. No migration, API change, new package or internet dependency.

## Loading

The shell, permissions, sidebar, shared controls and overview load immediately. Each editor's CSS and scripts load on first opening, once per page session. CSS precedes its editor script; shared dependencies are loaded in order and reused. Direct section URLs and Back/Forward navigation retain existing routing. A loading failure offers retry, and changing section while assets load cannot reveal the old section afterward. Every API endpoint retains its existing server authorization.

Editor markup stays mounted for clean navigation. If the current section has unsaved changes, leaving warns first. Cancelling stays in the editor; confirming reloads the destination section so the draft is discarded. The work defers editor assets and data/rendering, not every byte of blank form markup. No employee or business writes are made by previews/loading.

Gallery, list and editor placeholders show while assets and initial data prepare. They respect reduced motion and disappear on completion or error. Existing section-specific errors/empty messages and retries remain. The shared transport coordinates read loading; history/access metadata calls do not masquerade as editor refreshes.

## Large lists

Images initially render24 tiles, then24 more per click. Events initially render8 cards, then8 more. PDF pickers initially render40 choices, then40 more. These are browser rendering batches: the existing authorized API catalog contracts remain unchanged. Selection lives in the editor model, so unmounted choices remain selected and saves include them. Existing500-PDF limit is retained. Document and safety forms collapse into compact named rows; expanding edits that item's retained form. Existing image split view and theme preview layout remain.

## Freshness and drafts

The global refresh/last-load toolbar was removed at the user's request. Existing error retry controls remain. Clean editors retain loaded data on revisits; overview/history retain read-on-open behavior. Unsaved section navigation warns and then reloads the chosen destination on confirmation, clearing in-memory drafts and selections. A cancellation preserves the current editor. Browser Back/Forward uses the same warning/discard behavior. No polling was introduced.

## Layout

Existing sidebar/sticky header remain. Sidebar navigation can scroll independently. Document/safety editors are compact when collapsed, with sticky save buttons in long forms. Existing media/directive/theme action bars remain. Image-group save remains visible in the split editor. Event cards retain their square grid and publication controls with tighter padding.

## Verification and visual feedback

MVC builds with zero warnings/errors. Automated checks cover once-only ordered assets, failure/retry, revocation, incremental controls, compact editors, shared transport/confirm/draft protection,20 PDF tabs with501 choices including499 preserved selections and500-file enforcement, labels/history and offline assets. JS syntax and diff checks pass.

IAB desktop acceptance opened all13 editors. Direct documents load was verified to include its editor script without downloading image/theme/event editor scripts. Screenshots show image/theme columns and document expanders; no horizontal page overflow was observed. Header and sidebar remain at viewport top after scrolling. An image draft survived switching away and back and was reset without saving. Refreshing a modified document showed the discard warning; cancelling retained the editor.

Visual feedback: the image split view and theme gallery are balanced; compact document rows make scanning multiple tabs substantially easier. Source paths remain explicit for administrators. Large-list stress is covered by the automated501-document fixture; the real local image and event catalogs were smaller than a full batch. Asset failure/retry and restricted access were automated rather than broken intentionally in the working database.

Screenshots: `.local/admin-lazy-images.png`, `.local/admin-lazy-documents.png` under repository root. No business records or permissions were changed during the visual checks. Existing offline ZIPs and SQL exports were not rebuilt.

## Follow-up: split settings and current status

أرقام تهمك and حالة المؤسسة are separate sections and direct routes `/admin/important-numbers` and `/admin/institution-status`. The legacy header-content route/hash resolves to numbers. Both retain the existing header-content permission and audit section; no role grant changed. Overview's organization-status card goes to institution status. Preview and last-author labels retain their original permission/data contracts.

Migration062 adds the ability to change the current institution status and show the last50 status changes. See INSTITUTION_STATUS_ADMIN.md. The old sidebar إدارة البوابة label is removed. Old notes above about retaining drafts describe the initial implementation; the warning-and-discard policy in this follow-up is current.
