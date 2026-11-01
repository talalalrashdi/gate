# SecurityDB names and library badges

Implemented 1 November 2026.

## Profile identity

Windows NTName resolves to an active UserId through Security.User_getByUsername. Portal.UserProfile_Get delegates to Security.UserProfile_getById, which returns DisplayName, JobTitle and Department for that UserId. The API adds the resolved UserId to /api/profile/person; clients cannot select another employee by submitting a UserId. Header name, avatar description and admin author/last-change labels use this common source. NTName remains the authentication/audit identity.

Migration058 installs the Security adapter contract and the Portal wrapper. Development/028 adds nullable nvarchar(300) DisplayName/JobTitle/Department to local SecurityDB.dbo.Users, copies existing local profile samples only into empty fields, and maps the adapter to active SecurityDB users. It does not overwrite existing names. On the internal network, replace only Security.UserProfile_getById's SELECT with the actual SecurityDB employee source. Its output stays exactly three columns so existing admin author procedures continue to work. UserId is supplied by the server. Arrival/departure and leave-balance sources remain separate.

## New content

- Header links for وثائق تهمك and تعليمات السلامة show جديد when there are unseen, unread PDFs the current user may access.
- Clicking a section link acknowledges its currently loaded unseen entries. That header badge disappears and remains gone after refresh. A PDF's own badge remains until opened.
- Each unread PDF shows جديد above its title; safety badges sit above the booklet cover. Opening a PDF saves its read state and removes its badge. Multiple PDFs per tab and dynamic tabs remain supported. Safety remains one PDF per booklet.
- A PDF appearing in both sections shares its read state. Reading it once clears its item badge in both, without duplicate read records. Section visits are independent.
- New document GUIDs appear new. Renaming/reordering an existing document does not reset reads. Existing unread files initially show جديد too. No date-based expiry or browser storage is used.
- Failed acknowledgements are not claimed saved and can retry on the next click. Repeated opens/refresh do not create duplicate rows or change the first read timestamp. Catalog loading includes flags, with no extra read-status request or polling.

Migration059 extends existing Mstr.ContentType/Portal.UserReads:

| Type | ContentId | Meaning |
|---|---|---|
|4 ملفات الوثائق|document GUID|PDF opened, shared between both libraries|
|5 مشاهدة المكتبات|documents:GUID or safety:GUID|That section entry acknowledged|

Portal.LibraryReads_Get reads both states in one query. Portal.LibraryReads_Mark is an idempotent batch SP, serialized per employee. The API rechecks current registration, published tabs, PDF membership and document permissions before every write. PDF reads also validate that the configured file exists and is a valid PDF. Unauthorized/hidden/missing sources cannot be acknowledged. No paths or client UserId are trusted.

POST /api/document-library/seen and /api/safety-library/seen accept documentIds (max500 per batch). POST /api/{document-library|safety-library}/{id}/read records one opened PDF. All require Windows authentication, an allowed Origin and X-CompanyPortal-Request: library-read. Existing GET catalogs include hasRead/hasSeen; file endpoints retain inline PDF behavior.

## Deployment and verification

Existing database: apply058 then059; local sample source additionally needs Development/028. Fresh CompanyPortal-Setup.sql includes001–059 and sample SecurityDB name mapping in sample mode. Never rerun fresh Setup on an existing database. Historical CompanyPortal-CurrentData.sql and published ZIPs are not refreshed by this change.

Both apps build with no warnings/errors. Test-LibraryReads.ps1 verifies SecurityDB name/UserId, ignores supplied UserId, flags, auth/header/origin/invalid/unauthorized IDs and Swagger. Test-LibraryReadsPersistence.ps1 uses only marked local fixtures, tests successful seen/read/reload/repeated-open behavior and cleans only its newly created acknowledgements. SQL transaction tests verify separation/idempotency/no-op timestamps. verify-library-reads.mjs checks header versus item state, early clicks, cross-section reads, retries, batching and no duplicate calls. verify-document-library.mjs retains50 tabs/500 PDFs coverage. Browser visual acceptance was unavailable because the browser automation tool failed to initialize; no browser pass is claimed.

## Follow-up: tab badges, admin sources and decision popups

Document category buttons also show جديد while any PDF in that tab remains unread. Opening a PDF updates its row and every affected tab badge without a catalog refetch; selecting the tab alone does not mark PDFs read.

The documents and safety admin catalogs include a source summary (Mng.Document / Portal.Document_GetAll, Mstr.Utls_GetFolderPaths key docs), configured absolute roots, logical folder paths and candidate full file paths. The admin shows the summary and each file's path in the lazy selection list. Paths use the reader's same safe relative-path construction; file reading still checks root containment, reparse points, permissions and PDF signature. Multiple roots are candidates; the reader uses the first accessible matching file. Missing root configuration shows guidance without preventing metadata editing. Employee catalogs still contain no physical paths.

Shared admin context and the authorization-success status bar are removed from the layout. A separate hidden error/retry area is shown only for access denial/failure; useful error handling remains. The standalone health page retains its own controls.

Decision read handling now removes only the read row from its eligible channels, retains other unread entries, preserves the current entry for unrelated reads, and closes each floating channel only when empty. The all-notices dialog closes when both channels are empty. This supersedes the earlier close-displayed-channel-on-read behavior.

Follow-up verification: builds, floating notice regression, document tabs/500-PDF reader and tab badges, read helper, admin core and lazy501-choice source-path tests pass. Test-LibraryAdminSources.ps1 verifies authorized admin-only paths, employee path isolation, unchanged protected PDF reads, anonymous denial and six MVC admin routes. No database changes for this follow-up. Browser automation remains unavailable (kernel assets initialization failure); visual review remains pending.
