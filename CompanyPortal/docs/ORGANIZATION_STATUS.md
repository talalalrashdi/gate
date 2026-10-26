# حالة المؤسسة (Organization status)

The header **حالة المؤسسة** reads the current status from the database instead of fixed demo text.

## Data

Migration `Backend/Database/Scripts/036_CurrentStatus.sql` creates:

| Column | Type | Meaning |
| --- | --- | --- |
| `Id` | `int IDENTITY` PK | Row id |
| `ColorValue` | `tinyint`, CHECK 1–4 | 1 green (الحالة الطبيعية), 2 yellow (تنبيه احترازي), 3 orange (حالة مرتفعة), 4 red (حالة طوارئ) |
| `LastUpdated` | `datetime`, default `GETDATE()` | Shown as **آخر تحديث للحالة** |
| `No` | `int NULL` | Stored and returned by the API; not displayed |

`Mng.CurrentStatus_get` returns the **most recent row** (`ORDER BY LastUpdated DESC, Id DESC`). To change the status, insert a new row (history is kept) or update the existing one, setting `LastUpdated`.

`Development/018_SeedCurrentStatus.sql` inserts one green sample row for local testing only. Do not deploy it internally.

## API

`GET /api/organization-status` (Windows authentication, `no-store`):

```json
{"colorValue":1,"color":"green","lastUpdated":"2026-10-01T08:00:00","no":1}
```

- `204 No Content` when the table is empty, `503` on a SQL error or an unknown `ColorValue`. A `404` means the API is outdated (no endpoint) and the header shows «الحالة غير متاحة».
- `lastUpdated` is the SQL `datetime` as a local value with no timezone conversion.

## Frontend

`wwwroot/js/organization-status.js` fills the header button, the current-status panel (badge, title, description) and آخر تحديث للحالة, e.g. «26 أكتوبر 2026 / 02:34 مساءً». The page starts in a grey «جارٍ التحميل…» state. It refreshes every 2 minutes and when the tab becomes visible again. A failed refresh keeps the last good status. If nothing has loaded, it shows «الحالة غير متاحة», or «لم تُسجَّل حالة» when the table is empty. The yellow/orange/red guide list and its detail pages are unchanged.

## Verified (26 October 2026, local)

Migration applied twice (rerun-safe); CHECK rejects `ColorValue` 5. End to end through the browser with Windows authentication (`.local/org-status-browser.cjs`): green seed, then yellow/orange/red rows, removal back to green, and the empty table. The table was restored to the single seed row. The offline `Deployment/CompanyPortal-Setup.sql` was regenerated with migration 036.
