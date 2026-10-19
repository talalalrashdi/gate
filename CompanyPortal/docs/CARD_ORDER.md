# Employee card order

19 October 2026. Scope: synchronize the order of the 22 existing built-in workspace cards with the signed-in employee's account. Existing pinning, content concealment and custom groups remain browser-local. No admin interface or card creation/deletion API is added.

## Data model

Migration `008_UserCardOrder.sql` creates the following tables. Apply pending migrations in order; do not modify historical scripts or migrate automatically at startup.

| Table | Columns in order |
| --- | --- |
| Master.Cards | CardId int identity PK; CardKey nvarchar(100) unique; CardName nvarchar(200); DisplayOrder int; Active bit default 1; LastChangeAt datetime default GETDATE() |
| Portal.UserCardOrder | UserCardOrderId int identity PK; UserId int; CardId int FK; SortOrder int; Active bit default 1; LastChangeAt datetime default GETDATE() |

CardKey is the existing internal frontend identifier, such as library or inbox. CardName is an Arabic display label; changing it does not identify or reorder a card. Catalog labels currently document existing frontend cards; they do not replace their rendered headings or supply dynamic layouts. Adding a new kind of card requires its frontend implementation. Seed order matches the current frontend, including hidden/unpinned built-in cards, so pinning cannot discard positions. Custom group IDs are excluded until their own persistence feature is implemented.

There is one row per employee/card, enforced by a unique UserId/CardId constraint. UserId comes from authenticated NTName through Security.User_getByUsername; no cross-database user FK or duplicate employee table. SortOrder starts at zero. Writes commit a complete unique active catalog order atomically, with per-user indexed range locks. Changed positions/reactivated rows receive GETDATE(); unchanged rows preserve LastChangeAt. The response timestamp is the latest active setting timestamp. Reads write nothing, return saved active cards first, and append new active definitions using catalog order. Runtime must have execution rights on both new Portal procedures and EXECUTE/REFERENCES permissions on the Portal.CardOrderInput table type. Validate deployment permissions using the intended IIS service identity; local development tests do not establish production grants.

## API

Windows-authenticated `GET /api/user-settings/card-order` returns cardKeys (array), isSaved and lastChangeAt. `PUT` accepts only `{"cardKeys":["library","inbox", ...]}` with all active built-in card keys exactly once. The shown array is abbreviated; fetch GET for the complete list. Require JSON and `X-CompanyPortal-Request: card-order`; existing exact CORS/Origin restrictions apply. The body never selects UserId/NTName. Invalid/duplicate/unknown/incomplete lists return 400; unregistered/inactive employees return 403; database errors return generic 503. Limit: 200 keys, each at most 100 characters; SQL table-valued parameter Portal.CardOrderInput with SortOrder int and CardKey nvarchar(100), HTTP request limit 32768 bytes. No JSON is stored in a column.

## Frontend

The existing grip/keyboard controls emit an order-change event. workspace-settings.js loads the account order and queues the latest requested save. It does not overwrite a newer local reorder with a delayed read. An account with no saved order keeps its existing browser order until explicitly rearranging a card; old local records are not silently imported on load.

Account order is applied to built-in card slots, preserving local custom-group slots. The existing full-order localStorage key remains intact. Adding/editing a local group continues using local state. A small live status under the workspace toolbar reports loading/save/errors. API failures preserve the working local order. Different devices share built-in order but still have their own pinned cards/groups; simultaneous devices use last successful save wins. Browser storage is a local fallback, not a separately authenticated account store.

## Deployment and verification

Status: migration 008 completed and rerun successfully locally on 19 October 2026. Its first attempt created the tables/read procedure but failed on an oversized nvarchar parameter; the corrected write procedure uses a table-valued parameter and completed successfully. No historical migration was changed. Direct SQL verified 22 active definitions, 22 saved positions numbered 0–21 for the test account, an enabled/trusted foreign key and no constraint violations. The original order (library, inbox, email first) was restored and theme remained ThemeId 2. From Backend with the deployment account:

```powershell
sqlcmd -S localhost -E -b -f 65001 -i Database/Scripts/008_UserCardOrder.sql
```

Use the destination server and approved connection/permission settings in the internal network; keep local SecurityDB samples out of that deployment. Apply 008 before activating this code.

Completed checks: Release builds (zero warnings/errors), `node tools/verify-workspace-settings.mjs`, JS syntax and offline asset checks. Live checks passed: migration application/rerun, authenticated `powershell -File tools/Test-CardOrder.ps1`, actual browser keyboard reorder/refresh, account ordering on both localhost and 127.0.0.1, and API-unavailable fallback. Browser acceptance exposed stale cached scripts; the affected scripts and layout stylesheet now use MVC content-versioned asset URLs. Migration parity checks also passed for the retained baseline, rendered routes and static resources. The new toolbar was also inspected at desktop and mobile width; its bounds stayed inside the mobile viewport. Full mobile drag/pointer acceptance and production IIS testing remain separate. Both test servers were stopped. The API test changes/restores the caller's order; a previously unsaved account gains rows for its starting order and LastChangeAt advances for changed positions. Live tests do not prove internal IIS or disconnected-network deployment.

Next incremental step after acceptance: account-backed custom card groups and their contents, then pin/hide settings as separately agreed. Do not treat storing an order as implementing those features.
