-- SAMPLE ONLY. Replace this SELECT with the real effective-role source internally.
-- Return distinct active RoleName values for @UserId, combining direct and group grants
-- as appropriate. AD group evaluation is not implemented by this sample.
USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE Security.UserRoles_get
 @UserId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT DISTINCT r.RoleName
 FROM SecurityDB.dbo.Roles r
 JOIN SecurityDB.dbo.UserRoles ur ON ur.RoleId=r.RoleId AND ur.Active=1
 JOIN SecurityDB.dbo.Users u ON u.UserId=ur.UserId AND u.Active=1
 WHERE ur.UserId=@UserId AND r.Active=1;
END;
GO
