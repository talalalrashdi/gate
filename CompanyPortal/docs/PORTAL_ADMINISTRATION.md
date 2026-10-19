# Portal administration

Implemented 19 October 2026. `/admin/cards` manages existing active master cards: display name, one-based default order and fixed/movable policy. It does not create/delete master cards, manage app grants, edit themes or grant roles.

## Identity and permissions

Windows authentication supplies NTName. `Security.User_getByUsername` resolves the active external UserId. `Security.UserRoles_get(@UserId int)` returns distinct effective `RoleName` strings (`nvarchar(200)`). The API requires the exact stable role key `CompanyPortal.Admin`. Application access alone does not grant administration rights.

Users and roles remain in the external security database. Replace the role procedure's SELECT with the real source internally, combining active direct and group assignments as appropriate. The local sample implements direct user assignments only. AD group evaluation and the internal group/role schema are not supplied or implemented. Browser-supplied roles and user IDs are never trusted.

Every admin read/write resolves the user and checks current roles; there is no role cache. Inactive/unregistered users or missing roles receive 403; lookup failures yield 503 and never grant access. Anonymous API requests receive 401. Revocation takes effect on the next request; an already in-flight request may complete.

MVC serves a public HTML shell containing no protected card data. The browser calls the API with the visitor's Windows credentials; MVC's process identity is not used to authorize the visitor. The portal displays an `إدارة البطاقات` link only when the capability lookup succeeds. The API remains the authorization boundary.

## Endpoints and data

| Method/address | Purpose |
| --- | --- |
| GET `/api/access` | Authenticated current account's `{isAdmin}` capability |
| GET `/api/admin/cards` | Admin-only active definitions including CardId, stable CardKey, name, order, IsFixed and LastChangeAt |
| PUT `/api/admin/cards/{id}` | Admin-only update, returns 204 |

PUT accepts only `{cardName, displayOrder, isFixed}`; all three are required. Names are trimmed, nonblank and at most 200 characters. The request cannot select owner, role, CardKey, Active or timestamps. Writes require JSON and `X-CompanyPortal-Request: admin-cards`; existing exact-origin checks and credentialed CORS apply. Responses use no-store.

Migration 012 adds `Master.Cards_get` and `Master.Cards_save`. Save uses a transaction and existing locked `Master.Cards_setPosition` validation. Fixed slots must be within the active master count and cannot collide. Movable default ranks may tie; CardId breaks ties. Saved employee ordering remains for movable cards. Personal cards remain per-user, and fixed masters reserve global positions even alongside personal cards.

True no-op saves preserve LastChangeAt; actual name/policy changes update it, including case-only names. IDs/keys stay stable. Reload the employee portal to receive the updated catalog. Concurrent administrator edits use last-save-wins; editing locks and audit history are outside this first page.

## Local setup

After existing scripts through 011, run in order with your development Windows SQL login:

1. `Backend/Database/Development/003_CreateSampleRoles.sql`.
2. `Backend/Database/Integration/ConfigureRoleLookup.sample.sql`.
3. `Backend/Database/Scripts/012_MasterCardAdministration.sql`.

Development/003 creates SecurityDB Roles/UserRoles with identity keys, explicit nvarchar lengths, Active default 1 and LastChangeAt default GETDATE(). It explicitly assigns CompanyPortal.Admin to the existing sample user matching ORIGINAL_LOGIN(), not every employee. Reruns do not reactivate inactive existing grants. No role-management HTTP endpoint is included.

Start both solutions and visit `http://localhost:5080/admin/cards`, or follow the portal's admin link. Swagger lists the API endpoints, subject to the same permissions.

## Internal / air-gapped deployment

Do not deploy Development/003 or sample grants internally. Configure `Security.UserRoles_get` against the approved real external database on the same server, returning effective roles for the resolved UserId. Confirm whether groups mean database or AD groups before adding group-specific integration. Provision the intended real administrator explicitly in that source.

Apply numbered migration 012 after 011 using a deployment identity. The API runtime SQL identity needs EXECUTE on Security.User_getByUsername, Security.UserRoles_get, Master.Cards_get and Master.Cards_save, plus existing employee-feature permissions. Do not grant employees direct SQL execution of administration procedures, broad Master-schema execution, or db_owner. Runtime SQL identity and employee Windows identity are separate: the API checks the employee role before calling admin procedures. Provision cross-database access to approved security views/tables deliberately; do not enable TRUSTWORTHY or broad cross-database ownership chaining as a shortcut.

Use existing Windows authentication, HTTPS, exact frontend CORS origins and environment-specific connection strings. No packages, remote assets, passwords or tokens were added.

## Verification

- Both Release builds: zero warnings/errors.
- `Backend/tools/Test-Administration.ps1 -TestSampleRevocation`: passed anonymous denial, current capability, strict fields, blank names, invalid IDs/positions, origin/header checks, change/no-op timestamps, case-only names, fixed-slot conflicts and changed names reaching the employee catalog.
- Temporary sample role revocation immediately produced admin GET/PUT 403 and capability false; ordinary app access remained available. Grant and original card names/order/fixed policy were restored in finally. This does not simulate a second interactive Windows account or actual AD group inheritance.
- Actual browser: name/fixed save, reload persistence, restoration of original name/movable policy. Five original active masters remain movable; user themes and personal data were not reset.
- Frontend parity: 328 original files unchanged, six existing routes and 313 original static resources verified; portal scripts now include the admin-capability check. Workspace synchronization checks passed.

The test temporarily changes shared master-card settings. Run only against an isolated development API/database with no concurrent editing. `-TestSampleRevocation` additionally changes the current local sample role grant; omit it to skip grant changes.
