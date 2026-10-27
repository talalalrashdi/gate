# Shared admin behaviour — Phase 3

The admin shell uses `wwwroot/js/admin-core.js` and `wwwroot/css/admin-core.css` for confirmations, feedback, API transport, section access and unsaved-change guards. No API contracts, SQL schema, business procedures or role grants changed in this phase.

There are12 navigation entries: overview and11 editable sections. Nine editor scripts serve them; documents/safety share one script and notices/alerts share another.

## Shared controls

- `AdminCore.request(path,{method,body,header,timeout})` returns the original Response. It sends Windows credentials, no-store requests, the existing section-specific X-CompanyPortal-Request header and JSON when appropriate. FormData is sent unchanged without setting Content-Type. Normal timeout15seconds; cards/applications retain10seconds, image POSTs retain60seconds. Only the configured API origin is accepted. Responses remain available for each editor's own validation and media error-code handling.
- `AdminCore.confirm(message,{title,accept,danger})` returns a Promise<boolean>. The shared Arabic native dialog traps focus; Escape and إلغاء cancel. Cancel receives initial focus, and closing restores the previous control when still present. Destructive actions use a red button. The old theme-only confirmation dialog and all14 native confirm call sites were replaced.
- `AdminCore.feedback(element,text,error)` keeps loading/context/validation messages beside the relevant form and uses short corner notifications for save results and failures. Success disappears after4.5seconds; errors remain until closed.401,403,400,404,409,413,429, network failures and timeouts have shared Arabic explanations. It never displays raw exception stacks or HTML from responses.
- `AdminCore.watch(section,element,isDirty,isBusy)` connects an existing editor's comparison logic to a badge and sidebar dot. `trackForm` provides a baseline comparison for independent forms. File selections, checkboxes, quick-duration buttons and programmatic editor changes are included. Reverting fields clears the warning. Saving one form resets only that form's baseline.

## Navigation and access

`admin-navigation.js` is the single owner of section switching and browser Back/Forward handling. It waits for the live `/api/access` result, shows only authorized navigation/overview entries, and rejects direct unauthorized section selection. Overview includes links to all authorized existing sections; card statistics are shown/fetched only for card admins. A media-only admin no longer depends on access to the cards API to open administration.

Every admin API request remains protected by the Phase1 AdminSection attribute. The browser is a presentation aid, not authorization.403 rechecks the access result;401 hides the admin workspace. There is no localStorage role or draft store.

Switching sections with edits opens the styled warning. If the user chooses to continue, the in-memory draft remains available and its sidebar dot remains; switching does not silently save or discard it. Explicit editor cancel/reload/record-change confirmations discard the relevant edits. Busy saves prevent leaving until they finish.

Reloading or closing a tab uses the browser's mandatory native beforeunload warning. Browsers do not allow that warning to be replaced with an application-styled dialog. Internal links use the styled warning and avoid a second native prompt after confirmation.

## Editor migration

| Script | Sections | Draft boundaries |
|---|---|---|
| admin-cards.js | cards | Each card, including a new unsaved card |
| admin-applications.js | applications | Each category and application description |
| admin-documents.js | documents, safety | Each document tab/booklet |
| admin-fixed-orders.js | fixed-orders | Current directive; wording replacement confirmation |
| admin-media.js | media | Current video/image/album; existing preview cleanup preserved |
| admin-themes.js | themes | Theme draft, copy/create, colour changes and publication confirmations |
| admin-images.js | images | Group membership/order/settings, uploads and individual theme links |
| admin-header-content.js | header-content | Each number and status-text form |
| admin-decision-notices.js | notices, alerts | Each channel's general settings and individual decision window |

Header-content saves update only the saved row/form, preserving unrelated edits. Notice saves preserve the other channel and the other form in the same channel. Changing the selected decision asks before dropping an edited window. Image-group saves preserve unsaved theme-image links. No preview or confirmation produces business writes.

## Verification

Run:

```powershell
node CompanyPortal/tools/verify-admin-core.mjs
node CompanyPortal/tools/verify-offline-assets.mjs
dotnet build CompanyPortal/Frontend/CompanyPortal.Web/CompanyPortal.Web.csproj --no-restore
```

The shared-core test uses an isolated DOM/transport adapter with no browser, network or database. It verifies restricted and super-admin visibility, request headers/JSON/FormData, unsafe destination rejection, dialog cancellation/Escape/reentry/focus, independent draft baselines, unload guards, timed successes/persistent errors and401/403/timeout feedback.

Desktop browser checks covered all editor dirty indicators, cancellation and field reversion; shared destructive image/theme dialogs; Back cancellation preserving the URL and draft; a successful temporary inactive-number save while another status form remained dirty; and an actual API400 leaving values/editability/dirty state intact. The inactive test number was deleted precisely after the test; existing production/sample records and role grants were unchanged. The normal change-history mechanism retains its audit entries.

Section-role rendering was checked by the isolated shared-core tests; the desktop browser used the existing super-admin account. API authorization remains the separately tested Phase1 implementation.

Deployment: republish the frontend including the new shared JS/CSS and Razor layout. No database migration or new runtime dependency is required.
