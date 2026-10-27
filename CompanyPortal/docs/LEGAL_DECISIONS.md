# القرارات

The workspace card now reads legal decisions through the API instead of the illustrative document dialog. Each item shows its type, title and publication time; clicking anywhere on it opens its PDF in a new tab. Search, type filters and existing five-item pagination operate on the authorized list only.

## Source contract and permissions

`GET /api/decisions` resolves Windows NTName through `Security.User_getByUsername`, then calls `CompanyPortal.Legal.Decisions_getForUser`. Unregistered or inactive employees receive 403. The browser cannot supply a UserId or filename.

The adapter accepts `@UserId int` and optional `@DecisionId bigint=NULL`, returning:

| Column | SQL type | Purpose |
|---|---|---|
| DecisionId | bigint | Stable positive ID, serialized as a JSON string |
| DecisionType | nvarchar(200) | Type label |
| Title | nvarchar(1000) | Display title |
| PublishedAt | datetime | Publication time, newest first |
| PdfFileName | nvarchar(4000) | Filename, relative path or absolute path; server-only |

Return one row per permitted decision, ordered by PublishedAt descending then DecisionId descending. Apply current publication, activity and permission rules to both list and single-ID calls. Unknown or unauthorized IDs return no rows. Public means any active portal employee; admin status does not bypass source permissions.

Migration `022_LegalDecisions.sql` creates the Legal schema and a fail-closed adapter only if absent. Rerunning it preserves an installed integration. Without a configured adapter, the API returns a sanitized 503 and logs the cause.

The actual source schema is unavailable. Local development uses the requested name **LegelAffairs** with an explicitly marked, inferred schema:

- `dbo.Decisions`: identity first, type/title/publication time/PDF filename, IsPublic, Active default 1.
- `dbo.DecisionUsers`: identity first, DecisionId, portal UserId, Active default 1; unique decision/user grant.
- Five public samples and one restricted sample explicitly granted to the current local test employee.
- Only active, already-published decisions are returned; restricted records require an active user grant.

These are fictional records, not a copy of the real legal system. Later replace the adapter query to map the actual columns and effective user/group/role permissions. Map employee IDs there if the external source uses different IDs. The frontend/API contract stays the same.

## Folder paths and PDFs

`Mstr.Utls_GetFolderPaths` returns `[Key]` and `strVal AS [Path]`. Configure active rows with key **LegalAffairs**. Multiple roots are supported and read afresh on every PDF request.

Use a fully qualified path such as `D:\Documents\Legelaffairs` or `\\fileserver\documents\Legelaffairs`. A lone `\folder\Legelaffairs` is drive-relative and rejected. The API process identity needs file read permission and, for UNC paths, share permission. Do not place restricted PDFs in a public static website folder that bypasses the API.

`GET /api/decisions/{id}/pdf` resolves the employee and reruns the permission-filtered adapter before opening the file. Relative filenames are resolved against LegalAffairs roots; absolute paths must also fall inside these roots. Other folder keys, traversal outside roots, device paths, alternate streams and reparse points are rejected. Files require a `.pdf` extension and PDF signature.

Responses use inline display, range support, nosniff and private/no-store. JSON exposes no physical paths. The frontend clears results when the page is hidden and rereads on return or explicit refresh. No decision data, grants or invented read/unread state is saved in browser storage. Previously downloaded/opened PDFs cannot be recalled after revocation.

## Local setup

After earlier migrations and sample SecurityDB, run from the repository root:

```powershell
sqlcmd -S localhost -E -b -f 65001 -i CompanyPortal/Backend/Database/Scripts/022_LegalDecisions.sql
powershell -NoProfile -File CompanyPortal/Backend/tools/Initialize-LegalFixture.ps1
```

The initializer refuses an unmarked existing LegelAffairs database. It creates six standalone sample PDFs under `Backend/artifacts/legal-fixture`, installs the development adapter and adds a local LegalAffairs folder setting only if the key is absent. Existing folder settings and records are preserved on rerun. The fixture PDFs contain English labels; decision titles/types are Arabic. PDFs are generated only by this development tool, never by the running API.

## Internal deployment

Apply pending migrations through 022 and republish both apps. Fresh `Deployment/CompanyPortal-Setup.sql` includes the fail-closed adapter; its sample mode does not install LegelAffairs. Older CurrentData exports and Airgap publish folders were not refreshed for this feature. Do not replay the fresh-install script on an existing database.

Configure the real adapter, LegalAffairs folders and API account SQL/file read rights. For cross-database reads grant the API identity only the necessary read access in the external database and execute access on the adapter. Do not enable TRUSTWORTHY or broad cross-database ownership chaining. Never run development initialization against the internal source.

| Error | Check |
|---|---|
| 401 | Windows authentication |
| 403 | Active employee lookup |
| 404 opening PDF | Current access/publication/activity, filename, file existence, allowed folder, PDF format |
| 503 | API logs, adapter, SQL rights, absolute roots and API account file/share permissions |

## Verification

### Decision number and date display

`Legal.Decisions_getForUser` can additionally return `DecisionNumber nvarchar(100)` containing the full source reference, e.g. `2026/66`. The API returns it as nullable `decisionNumber` and the card displays `[2026/66]` in left-to-right order. This is a business number, not DecisionId; production must return the actual source number/year. Missing numbers remain hidden, and older adapters without this optional column continue to work. `Development/023_SampleDecisionNumbers.sql` adds and seeds sample numbers once in the marked local LegelAffairs only, and updates its adapter. Run it after Development008 if rebuilding local fixtures; it never overwrites existing numbers. No CompanyPortal migration or historical export changed.

The card shows اليوم, قبل يوم, قبل 2 أيام through قبل 6 أيام using Oman calendar dates; from seven days onward it shows only the actual decision date. Times are omitted from both the text and date tooltip. Source timestamps remain intact for permissions/publication/notice windows. Successful unchanged catalog refreshes update date labels after midnight without replacing the list. Decision numbers sit beneath the type label and titles are centered. Workspace cards use fixed680px frames with list scrolling when needed; decision rows are capped at88px; filtering to a single result never stretches its row, while the containing card retains pagination stability.

Both Release builds passed without warnings. `Backend/tools/Test-LegalDecisions.ps1` checks anonymous rejection, public/restricted list, grant revocation, inactive user/item, unknown IDs, path redaction, relative/absolute files, forbidden paths, invalid PDF signature, missing roots, headers/ranges and Swagger. It runs only against marked local fixtures and restores changed flags, grants, paths and user status. Existing news regression checks passed with the shared file reader using separate folder keys.

`tools/verify-decisions.mjs` executes the real renderer for Arabic search, type filtering, literal HTML, large IDs, PDF links, empty/error/retry and clear-on-hide behaviour. Local browser checks cover connected rendering, search, filtering and pagination. Real source mapping, internal UNC access and destination IIS remain internal acceptance checks.

Development/024_SeedLongDecision.sql retains long-title sample [2026/80] in the marked local source using an existing sample PDF. Its insert is idempotent. Five88px records fit without list scrolling in the680px workspace frame. Titles are vertically centered, with dates separately anchored below and full title tooltips.
