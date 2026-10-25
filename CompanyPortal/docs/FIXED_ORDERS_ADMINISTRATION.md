# إدارة التوجيهات السامية

Open **إدارة البوابة → التوجيهات السامية** (`/admin/fixed-orders`). This adds creation and editing to the existing `Portal.FixedOrders` timeline; existing records and its seven-column table shape remain unchanged.

## Entering a directive

1. Choose **إضافة توجيه**, or select an existing record from the searchable list.
2. Enter **العنوان / النص الجديد**. This is `ContentAfter`: both the card title and the green replacement phrase when inserted into the wording.
3. Enter **النص السابق** (`ContentBefor`, original database spelling), when the wording refers to the previous phrase.
4. Choose a wording preset, or type surrounding text and use **إدراج النص السابق / إدراج النص الجديد** at the cursor. These buttons insert the exact `ds{0}de` / `ss{1}se` tokens that the existing portal renderer understands. Repeated tokens and before-only wording are supported; plain wording without tokens is also allowed.
5. Enter the optional primary/secondary dates and the required numeric **نوع التاريخ** (`TimestampType`). Its business meaning is still unconfirmed, so no calendar labels or default value have been invented.
6. Review the live preview, then **حفظ ونشر التوجيه**. Existing edits use **حفظ التغييرات**.

The primary date alone supplies the displayed year. Undated directives retain the existing fallback. Timestamp2 is saved for future use and does not replace a missing primary date. Dates are date-only, without timezone or calendar conversion.

Saving publishes directly to all registered active portal employees through the existing employee list. Changes appear when the timeline is reopened. There is no separate draft, Active flag, hiding, deletion or approval workflow in this feature. Unsaved edits are indicated and can be cancelled; switching entries or leaving the page warns before discarding them. Previewing performs no business/preference writes.

## Validation and rendering

- Required nonblank title and wording, each at most 1,000 characters.
- Previous text at most 500 characters; required when its exact marker appears.
- Numeric TimestampType is required and preserves the full SQL int range; zero and existing values are not reinterpreted.
- Optional dates preserve SQL date's 0001–9999 range. Typed SQL Date parameters avoid datetime narrowing.
- Recognizable malformed token forms, unknown JSON properties and invalid IDs are rejected. Admins should use the insertion buttons rather than type formatting syntax.
- Replacement values and surrounding content are plain text, never HTML. Tokens inside the replacement values are not recursively interpreted.
- The new shared `fixed-order-text.js` renderer drives both admin preview and employee wording. Amber previous and green replacement colours match the existing portal. ContentAfter remains the title, including for before-only wording.

Legacy nullable rows remain readable without rewriting them. Editing a legacy blank title/body requires supplying the newly required administrator inputs before saving. Whitespace-only previous text is stored as NULL; nonblank content is otherwise preserved.

## Database and API

Apply pending migration **027_FixedOrdersAdministration.sql**. It creates `Portal.FixedOrders_Save`, using the existing table and employee `Portal.FixedOrders_getAll` procedure. It does not seed data, change current records, add timestamps/Active, or change sort order. Updates are transactional, last-save-wins, and skip an unchanged row.

- `GET /api/admin/fixed-orders` returns existing records, date-only strings and string bigint IDs.
- `POST /api/admin/fixed-orders` creates a record and returns a string ID with HTTP 201.
- `PUT /api/admin/fixed-orders/{id}` updates it and returns HTTP 204; missing IDs return 404.

All admin operations require Windows authentication plus the **current** external `CompanyPortal.Admin` role and active employee lookup, checked on each request. Writes require JSON, `X-CompanyPortal-Request: fixed-orders`, and an allowed Origin. Input limits mirror the actual nvarchar columns. Queries use parameters and responses use no-store. Employee access remains unchanged; no admin flag or database identity is accepted from the browser. Connection/SQL failures return sanitized problems and are logged server-side.

## Deployment and verification

Rebuild/republish both apps after applying migration 027. The generated fresh-install `CompanyPortal-Setup.sql` includes 027; never replay it over an existing database. Historical CurrentData exports and previously published Airgap folders were not regenerated and require the pending migration and updated applications. No new package, internet dependency, security-source change or Exchange setting is required.

Release builds, shared renderer tests, authenticated API create/edit/read and no-op checks passed. Validation covers lengths, blank values, marker dependencies, malformed tokens, required TimestampType, unknown fields, date range/null/year mapping and bigint IDs. Tests verify anonymous rejection, origin/header checks, admin-role revocation, Swagger and preservation of existing directives. The existing employee-read suite and offline/frontend preservation checks passed.

Browser checks verify marker buttons, nonrecursive literal text, coloured preview, creation/edit, save/reload, and the saved entry appearing in the employee timeline with matching wording. Existing loaded records have Save disabled until changed. Temporary entries were removed and local role flags restored.

`Backend/tools/Test-FixedOrdersAdministration.ps1` uses temporary rows and restores local fixtures in finally. Run only against the local development database, not production. SQL migration reruns leave existing data unchanged.
