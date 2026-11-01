-- SAMPLE ONLY. Replace with the authoritative active role catalog internally.
-- Return one RoleName nvarchar(200) column; do not use employee memberships as the role catalog.
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Security.Roles_getForAdministration AS
BEGIN SET NOCOUNT ON;SELECT RoleName FROM SecurityDB.dbo.Roles WHERE Active=1 ORDER BY RoleName;END;
GO
