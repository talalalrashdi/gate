# Header content: أرقام تهمك and حالة المؤسسة texts

Both were fixed text in the page; they are now database content managed at **/admin/header-content** (sidebar: «أرقام تهمك والحالة»).

## Data (migration `039_HeaderContent.sql`)

| Table | Columns | Used for |
| --- | --- | --- |
| `Mng.ImportantNumbers` | Id, Title (150), Number (50), SortOrder, Active, LastChangeAt | «أرقام تهمك» in the phone-directory dialog (active rows, by SortOrder) |
| `Mng.StatusLevels` | ColorValue 1–4 (PK), Title (100), ColorName (30), Summary (600), GuideText (300), Actions (1500, one step per line), LastChangeAt | Titles, badge text, description, «دليل الحالات» text and «ما الذي يجب فعله؟» steps for حالة المؤسسة |

Seeds reproduce the previous fixed text once; reruns keep edits. The current status itself still comes from `Mng.CurrentStatus` ([ORGANIZATION_STATUS.md](ORGANIZATION_STATUS.md)).

Procedures: `Mng.ImportantNumbers_GetActive/_GetAll/_Save/_Delete`, `Mng.StatusLevels_GetAll/_Save` (blank required fields → error 50039).

## API

- Read (any signed-in employee): `GET /api/header-content/important-numbers`, `GET /api/header-content/status-levels`.
- Admin (`CompanyPortal.Admin` role, header `X-CompanyPortal-Request: header-content`): `GET /api/admin/header-content`, `POST|PUT|DELETE /api/admin/header-content/important-numbers[/{id}]`, `PUT /api/admin/header-content/status-levels/{1-4}`.

## Frontend

- `js/important-numbers.js` fills the list; «تعذر تحميل الأرقام» if it fails. The old «أرقام داخلية تجريبية للمعاينة» subtitle was removed.
- `js/organization-status.js` loads the level texts and updates the dialog and guide; if the request fails the built-in text is kept.
- Admin: `Views/Admin/_HeaderContent.cshtml`, `js/admin-header-content.js`, `css/admin-header-content.css`. Changes appear to users on the next portal reload.

Verified 26 October 2026 (desktop): `.local/header-content-browser.cjs`: portal reads both tables; admin add number + edit yellow texts → portal shows them (incl. steps on the detail page); restored through admin delete/save.
