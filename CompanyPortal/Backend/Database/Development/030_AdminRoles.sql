-- DEVELOPMENT ONLY: creates role names, never assigns employees or groups.
USE SecurityDB;
GO
IF OBJECT_ID(N'dbo.Roles',N'U') IS NULL THROW 50040,'Local sample Roles table required.',1;
INSERT dbo.Roles(RoleName) SELECT v.RoleName FROM(VALUES(N'CompanyPortal.Content'),(N'CompanyPortal.Library'),(N'CompanyPortal.Appearance'),(N'CompanyPortal.Applications'),(N'CompanyPortal.Notices'),(N'CompanyPortal.Directory'),(N'CompanyPortal.Status'))v(RoleName)
WHERE NOT EXISTS(SELECT 1 FROM dbo.Roles r WHERE r.RoleName=v.RoleName);
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Security.Roles_getForAdministration AS
BEGIN SET NOCOUNT ON;SELECT RoleName FROM SecurityDB.dbo.Roles WHERE Active=1 ORDER BY RoleName;END;
GO
