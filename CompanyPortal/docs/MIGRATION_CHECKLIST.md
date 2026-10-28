# Internal deployment checklist

One page for moving CompanyPortal from the test machine to the internal network. Checked against the code and database on 28 October 2026 (migrations 001–050).

How to install IIS, publish and run the setup script is in [AIRGAP_IIS_GUIDE.md](AIRGAP_IIS_GUIDE.md) and [Deployment/START_HERE.md](../Deployment/START_HERE.md). This page lists what must change for real data.

> **Note:** START_HERE.md still mentions a «فحص الاتصال (مؤقت)» button and TEMPORARY_DIAGNOSTICS.md. That check only runs in Development. In production use **/admin/health** (super admin, English, numbered fix steps) instead.

## 1. Choose how to create the database

- [ ] **Fresh install:** run `Deployment/CompanyPortal-Setup.sql` once, on a new server, with `TestSources=0`.
- [ ] **Keep this machine's data** (themes, images, admin settings): use `CompanyPortal-CurrentData.sql`, following [CURRENT_DATA_README.md](../Deployment/CURRENT_DATA_README.md). Use it instead of the setup script, never both.
- [ ] Never run anything in `Backend/Database/Development/`. Those scripts create sample databases and sample mappings.

## 2. Point the adapters at the real sources

The API reads only through stored procedures. The objects below reach outside CompanyPortal, or read sample tables. Edit only the `SELECT` inside each one, and **keep the returned column names and types**. The database names are hard-coded, so if the internal names differ, edit every object that uses them.

| Source today | Objects to edit | Template |
|---|---|---|
| `SecurityDB` (users, roles, apps) | `Security.User_getByUsername`, `Security.UserRoles_get`, `Security.Apps_getForUser`, `Security.Apps_getForAdministration`, `Security.User_getPersonalId` | `Integration/ConfigureSecurityLookup`, `ConfigureRoleLookup`, `ConfigureAppAccess`, `ConfigureAdminAppCatalog`, `ConfigureUserPersonalId` (`.sample.sql`) |
| `Pubs_Info_V4` (news) | view `dbo.VNews` | in the setup script |
| `LegelAffairs` (decisions) | `Legal.Decisions_getForUser` | none; edit the procedure |
| `Formsdb` / `OfficeFormsdb` | `Portal.Forms_Inbox_Get`, `Portal.Forms_UnreadCount_Get`, `Portal.Correspondence_Inbox_Get`, `Portal.Correspondence_UnreadCount_Get` | none |
| `ReportsDB` / `IsnadDB` | `Portal.Reports_*` (4), `Portal.Initiatives_*` (2), `Portal.Isnad_*` (2) | none |
| Sample tables in `Development.*` | `Portal.UserProfile_Get`, `Portal.UserAttendance_Get`, `Portal.UserLeaveBalance_Get` | none |
| Local views `dbo.VFolder`, `dbo.VJobMainPeriod` | used by `Portal.Document_GetAll` (وثائق تهمك، تعليمات السلامة) | `Integration/ConfigureDocumentLookup.sql` |

- [ ] The setup script includes only four templates (security, app access, roles, admin app catalogue), and only in sample mode. Run `ConfigureUserPersonalId` and `ConfigureDocumentLookup` by hand, and edit the rest directly.
- [ ] **Unmapped procedures fail silently.** A feature just shows empty, not an error, so open each feature after mapping it.
- [ ] Cross-database reads run with the API account's rights in the other database. Grant it read access there, unless your DBA uses ownership chaining or signing.

## 3. Database settings rows

- [ ] **`Mstr.Utls`:** all five folder keys point at local test folders. Change them to the internal shares, and give the API account read access.

  | Key | Current value |
  |---|---|
  | `PubsInfo` | `…\Backend\artifacts\news-fixture` |
  | `LegalAffairs` | `…\Backend\artifacts\legal-fixture` |
  | `docs` | `…\Backend\artifacts\document-fixture` |
  | `PortalMedia` | `…\Backend\artifacts\media-fixture` |
  | `Magazines` | `…\Backend\artifacts\magazine-fixture` |

- [ ] **`Mng.CurrentStatus`:** set the real organization status.
- [ ] **`Portal.AdminSectionRoles`:** empty means only `CompanyPortal.Admin` manages the admin area. Add rows only when section admins are agreed.

## 4. Settings files (`appsettings.Production.json`)

Start from `Deployment/appsettings.*.Production.example.json`.

- [ ] **API:**
  - `ConnectionStrings:CompanyPortal`, `Cors:AllowedOrigins`, `AllowedHosts`, `EmployeeImageUrl`
  - `Exchange` (keep `Enabled`/`ScheduleEnabled` false until access is approved)
  - `Diagnostics:BootstrapAccounts` (empty after first setup)
- [ ] **API sections missing from the example** (add them yourself):
  - `PhoneDirectory`: `Enabled`, `BaseUrl`. `EmailDomain` is still the placeholder `email.com`.
  - `Forms`: `AppUrl`, `ItemUrlTemplate`. Keep `AllowSamplePreview` false.
  - `TechnicalServices`: `IsnadUrl`, `ReportsUrl`.
  - `InterfaceImages:MaximumUploadMb` (default 10).
- [ ] **Frontend:** `Api:BaseUrl` (`https://PORTAL/backend/`), `AllowedHosts`. Keep `Diagnostics:SimulationEnabled` false.

## 5. Permissions

- [ ] The API account needs EXECUTE on the 87 CompanyPortal procedures listed in `Backend/CompanyPortal.Api/HealthProcedures.json`. Recent ones easy to miss: `Portal.AdminAccess_get`, the `Portal.AdminChanges_*` readers, `Portal.KnownRoles_get` (049), `Master.Images_getThumbnail` and `Master.Images_setThumbnail` (050).
- [ ] The API account needs read access to the five folders above, plus SQL and Exchange rights as described in the IIS guide.

## 6. Content still written in the code

These need a code edit and a republish. They are not in the database:

- [ ] `wwwroot/js/editorial.js`: sample articles (some marked «خبر تجريبي»).
- [ ] `wwwroot/js/site.js`: two demo notifications marked «تجريبي».
- [ ] `wwwroot/js/personal-workspace.js`: the national-day sample event in the calendar.
- [ ] `Views/Home/_Overlays.cshtml`: the advert dialog text «محتوى توضيحي لتجربة الإعلانات».

Already moved to the database (no code change): أرقام تهمك and the organization-status texts, both under `/admin/header-content`.

## 7. After deployment

- [ ] **`/admin/health`:** all checks OK. Warnings are acceptable only for integrations deliberately left off (Exchange, photo service).
- [ ] From a domain employee PC:
  - the portal loads with the default theme
  - news, decisions, وثائق تهمك, تعليمات السلامة and مجلة الشهر open (the magazine turns pages right-to-left)
  - inbox counts show for a mapped user
- [ ] **In `/admin` as a super admin:**
  - save one item per section, then check that it appears in سجل التعديلات
  - on صور الواجهة, click «إنشاء نسخ معاينة صغيرة» once, so the existing images get small previews
