USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
GO
-- Read-only. There is no catalog of every role in the security source (Security.UserRoles_get only
-- answers per user), so the admin editors suggest the role names the portal already knows: the
-- signed-in admin's own roles plus active card, theme-preview and admin-section role names.
-- A name outside this list may still be valid; the editors only warn.
CREATE OR ALTER PROCEDURE Portal.KnownRoles_get
 @Username nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Users TABLE(UserId int);
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Users EXEC Security.User_getByUsername @Username=@Username;
 DECLARE @UserId int=(SELECT TOP(1) UserId FROM @Users WHERE UserId IS NOT NULL);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT RoleName FROM (
  SELECT LTRIM(RTRIM(RoleName)) COLLATE Latin1_General_100_BIN2 RoleName FROM @Roles
  UNION SELECT RoleName COLLATE Latin1_General_100_BIN2 FROM [Master].CardRoles WHERE Active=1
  UNION SELECT RoleName COLLATE Latin1_General_100_BIN2 FROM [Master].ThemePreviewRoles WHERE Active=1
  UNION SELECT RoleName COLLATE Latin1_General_100_BIN2 FROM Portal.AdminSectionRoles
 ) r WHERE LEN(RoleName)>0 ORDER BY RoleName;
END;
GO
COMMIT;
GO
