# Admin roles and section permissions

Implemented 1 November 2026. `/admin/permissions` (الأدوار والصلاحيات) is available only to `CompanyPortal.Admin`. It maps existing security roles to portal administration sections. Employee and group memberships stay in the authoritative security database; this page does not assign people to roles.

Migration065 adds role creation and soft deletion for portal-managed roles. See [ROLES_POPUPS_AND_HERO.md](ROLES_POPUPS_AND_HERO.md) for source writers, deployment and workstation/popup changes.

## Initial roles

| Security role | Administration sections |
|---|---|
| CompanyPortal.Admin | All sections, permissions, history and health; fixed and not editable |
| CompanyPortal.Content | أخبارنا، الفعاليات، التوجيهات السامية |
| CompanyPortal.Library | وثائق تهمك، تعليمات السلامة |
| CompanyPortal.Appearance | صور الواجهة، الثيمات والمظهر |
| CompanyPortal.Applications | البطاقات الأساسية، الأنظمة الإلكترونية |
| CompanyPortal.Notices | التنويهات، التنبيهات |
| CompanyPortal.Directory | أرقام تهمك |
| CompanyPortal.Status | حالة المؤسسة |

The seven scoped role names are created in the local development SecurityDB without assigning any employees. Multiple roles combine their sections. No role membership is changed during installation. Super-admin membership must be managed carefully in the external security system.

## Database and deployment

Existing installations apply `Backend/Database/Scripts/063_AdminRoles.sql` after migration062. Fresh `Deployment/CompanyPortal-Setup.sql` includes migrations001–063. Development sample sources also include `Development/030_AdminRoles.sql`; do not deploy that fixture over internal identity sources. Historical CurrentData exports and ZIP packages were not rebuilt.

`Portal.AdminSectionRoles` stores role/section mappings with identity, Active and LastChangeAt. Removing a section deactivates its mapping. No-op saves preserve timestamps. Migration reruns preserve subsequent permission edits. Legacy header-content mappings migrate to both important-numbers and institution-status.

Configure `Security.Roles_getForAdministration` to return the authoritative active role catalog as one `RoleName nvarchar(200)` column. See `Backend/Database/Integration/ConfigureRoleCatalog.sample.sql`. The integration placeholder reports a clear configuration error until mapped. `Security.UserRoles_get` remains the effective-membership adapter: internally, it must return the employee's direct and group-derived roles. The local fixture provides direct memberships only; automatic AD-group lookup is not introduced here.

Runtime SQL access needs EXECUTE on these readers and `Portal.AdminSectionRoles_Get`/`Portal.AdminSectionRoles_Save`, using the existing deployment grant approach. No new appsettings are required.

## Enforcement and tracking

GET/PUT `/api/admin/permissions` require Windows authentication and super-admin access; writes also require the existing administration header and origin validation. Unknown roles, unsupported sections and attempts to modify CompanyPortal.Admin are rejected. Permissions, full history and health cannot be granted through the checklist.

Each request resolves current effective access. Revocation applies on the next request. Number and institution-status reads, writes, previews and author labels use independent section permissions. Combined header-content reads omit data the caller cannot administer.

Permission saves use a serialized transaction and last-save-wins behavior. **Permission changes are not recorded in admin history**, as requested. LastChangeAt is mapping metadata, not an audit trail. Existing business-content change history remains enabled.

## Verification

Both application builds pass with zero warnings/errors. Editor, shared core, asset-loader and history-label tests pass. The disposable-database API test (`Backend/tools/Test-AdminPermissions.ps1`) covers save/reload, invalid roles/sections, immutable super-admin access, header/origin checks, no permission audit entries, Directory/Status read-write isolation, multiple roles, immediate revocation, 401/403 and Swagger. It removes its database and stops its own process afterward.

SQL rollback checks verify no-op timestamps and deactivation without changing working permissions. Migration reruns pass. Desktop browser checks verify the source role list, thirteen section choices, immutable super role, unsaved-change warning and discard behavior. No live permission changes were saved during browser checks.
