# Account-owned custom cards

Implemented and locally verified 19 October 2026. Scope: create, edit, soft-delete and order personal app cards alongside the five master cards. Fixed master positions remain authoritative. No admin portal or app-grant editing API is introduced.

## Identity and authorization

Every request uses Windows authentication, resolves NTName through Security.User_getByUsername, and uses that UserId for all ownership predicates. JSON cannot choose an owner. Unknown/inactive employees receive 403. Another employee's card ID behaves like a missing ID (404) on read/update/delete. Order writes accept only active master cards and the caller's active custom keys.

Security.Apps_getForUser(@UserId int) is the replaceable app-access contract. It must return unique AppId int, AppName nvarchar(200), LaunchUrl nvarchar(2048), for active apps authorized for that active user only. The local sample joins SecurityDB users, applications and explicit grants. Before internal deployment replace this lookup with the real source while preserving IDs/types and authorization semantics. Do not import sample grants into the internal database. Existing illustrative frontend app cards and browser storage are never authorization sources.

The card write procedure checks every AppId against that lookup inside its transaction. Reads filter membership against current grants; revoked apps disappear from the card without deleting its stored membership. Launch requests check access again and return 404 for unavailable/unauthorized IDs. URLs come only from the trusted lookup and must be absolute HTTP/HTTPS without embedded credentials. No client-supplied launch URL is accepted. Target applications must continue enforcing their own access policies.

## Database

Migration 010 creates:

| Table | Columns in order |
| --- | --- |
| Portal.UserCards | UserCardId int identity PK; UserId int; CardName nvarchar(200); Active bit default 1; LastChangeAt datetime default GETDATE() |
| Portal.UserCardApplications | UserCardApplicationId int identity PK; UserCardId int FK; AppId int; Active bit default 1; LastChangeAt datetime default GETDATE(); unique UserCardId/AppId |
| Portal.UserWorkspaceOrder | UserWorkspaceOrderId int identity PK; UserId int; CardKey nvarchar(100); SortOrder int; Active bit default 1; LastChangeAt datetime default GETDATE(); unique UserId/CardKey |

No cross-database FK or duplicate employee/app grant table is created in CompanyPortal. AppId references the external permission source. Portal.AppIdInput is a typed int table parameter. First creation of UserWorkspaceOrder copies active master positions and timestamps from the previous UserCardOrder table; the historical table/rows remain retained. Reruns do not overwrite current order.

Custom keys are custom-{UserCardId}. The existing card-order procedures now resolve the combined list and persist to UserWorkspaceOrder, validating ownership and fixed slots. Custom cards cannot be fixed. Admin positions remain within the five master slots so they exist for employees with no custom cards. Movable masters/custom cards fill unreserved positions. New personal cards append; deletion deactivates their membership/order rows. No-op name/membership saves preserve the card timestamp. Limits: 50 active personal cards per employee, 1–100 unique authorized apps per save, name up to 200 characters, 200 cards maximum in an order request. A card can remain visible with zero apps after revocation and can be edited or deleted.

## API and frontend

| Request | Behavior |
| --- | --- |
| GET /api/applications | Current employee's authorized AppId/AppName list; does not publish launch URLs |
| GET /api/applications/{id}/launch | Recheck current access and redirect to the trusted app address |
| GET /api/user-cards | Caller-owned cards with currently authorized app memberships |
| GET /api/user-cards/{id} | One caller-owned active card, otherwise 404 |
| POST /api/user-cards | JSON cardName/appIds; returns 201 and userCardId |
| PUT /api/user-cards/{id} | Same JSON; returns 204 |
| DELETE /api/user-cards/{id} | Soft-delete owned card; returns 204 |
| GET/PUT /api/user-settings/card-order | Combined master/personal list; metadata includes isCustom/userCardId |

Card mutations require X-CompanyPortal-Request: custom-cards and allowed Origin; POST/PUT require JSON. DELETE requires the header but no JSON body. Credentialed CORS permits only configured origins and GET/POST/PUT/DELETE with the existing allowed headers. App ownership/policy fields supplied in JSON are rejected. Card-order writes retain their card-order header value. Database errors return generic 503 responses; invalid/unauthorized app selections return 400.

The personal-card dialog fetches the authorized list again when opened. Create/edit/delete reload the page from account data. New cards are built with textContent, not HTML from stored names. Links go through the API launch check. The order module waits for the account-owned DOM before applying combined policy/order. Only public master policy metadata is cached; private card names/memberships are not written to localStorage. Old local-only group definitions remain untouched and are not silently imported. When API loading fails, custom editing stays unavailable; the master workspace can use its cached policy. Already loaded cards cannot save changes while offline.

## Local setup and internal delivery

Use a deployment account. For the explicitly authorized local sample only:

1. Run Development/002_CreateSampleApplications.sql against localhost with UTF-8 input. It adds four demo apps and explicit grants for three to the currently registered Windows SQL login. The fourth has no grant. All demo launch URLs point back to the local portal; no actual business app integration is implied. Reruns do not reactivate existing inactive grants.
2. Run Integration/ConfigureAppAccess.sample.sql in CompanyPortal.
3. Apply Scripts/010_UserCustomCards.sql after 009, then 011_UserCardNameComparison.sql. Migration 011 preserves case-only name edits on the case-insensitive local database without changing no-op timestamp behavior. Historical scripts remain unchanged.

For internal deployment, omit Development scripts, replace the app-access lookup with the real authorized source, and apply numbered migrations in order. Grant the API service identity narrowly scoped EXECUTE on the app lookup and Portal card procedures, plus EXECUTE/REFERENCES on Portal.AppIdInput and the existing order type. Configure approved cross-database access to the real security source; do not enable TRUSTWORTHY or broad database ownership to bypass permissions. Admin-only Master.Cards_setPosition remains separate. No new NuGet dependency is required.

## Verification status

Both Release builds passed with zero warnings/errors. Synchronization/privacy and offline asset checks passed. Migration 010 application/rerun and 011 application passed. Windows-authenticated API tests passed for CRUD, timestamp/no-op/case-only names, invalid app IDs, owner-field rejection, missing cards, write protection, combined order and launch checks. Temporarily revoking a sample grant removed the app from allowed/card reads, rejected its save, and rejected launch; restoring the grant restored readable membership. SQL rollback-only tests rejected a different UserId updating/deleting/ordering another owner's card. They do not simulate a second interactive Windows login.

Actual browser tests passed for a chooser containing exactly the three granted sample apps, create/edit/delete and refresh persistence, safe text rendering of an HTML-like name, and moving a custom card around a temporarily fixed master without shifting its reserved slot. Temporary grants/master policy/order were restored and test cards soft-deleted. A portal instance was already running on port 5080, so it was reused rather than terminated. Final SQL confirmed zero active test personal cards, the original five master positions 0–4, all masters movable, three restored sample app grants, unchanged ThemeId 2 and no constraints violations in the new tables. The test API process was stopped; the pre-existing frontend instance was left running. Browser reload with API unavailable kept the five master cards available, disabled personal-card editing, and displayed localized connection/fallback messages.

Run `powershell -File tools/Test-UserCards.ps1 -TestSampleRevocation` from Backend for the local sample acceptance (changes/restores one current developer grant). `sqlcmd -S localhost -E -b -I -i tools/Test-UserCardOwnership.sql` runs rollback-only ownership tests. The scripts are local test tools, not internal database deployment steps. Tests use local sample data; they do not prove internal app grants, target-app sign-in, full mobile touch/drag or IIS deployment.
