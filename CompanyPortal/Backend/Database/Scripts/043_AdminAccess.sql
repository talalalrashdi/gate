USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON;SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;SET ARITHABORT ON;SET NUMERIC_ROUNDABORT OFF;
GO
-- Optional per-section admin roles. CompanyPortal.Admin always manages every section;
-- rows here let other roles manage individual sections (e.g. 'media' → CompanyPortal.Content).
-- Intentionally empty until roles are agreed. SectionKey values: see docs/PORTAL_ADMINISTRATION.md.
IF OBJECT_ID(N'Portal.AdminSectionRoles',N'U') IS NULL
CREATE TABLE Portal.AdminSectionRoles(
 SectionKey varchar(40) NOT NULL,
 RoleName nvarchar(200) NOT NULL,
 LastChangeAt datetime NOT NULL CONSTRAINT DF_AdminSectionRoles_LastChangeAt DEFAULT GETDATE(),
 CONSTRAINT PK_AdminSectionRoles PRIMARY KEY(SectionKey,RoleName),
 CONSTRAINT CK_AdminSectionRoles_Key CHECK(SectionKey IN('cards','applications','documents','safety','fixed-orders','header-content','notices','alerts','media','images','themes')));
GO
-- One round trip for every admin request. Reuses the configured identity contracts
-- (Security.User_getByUsername / Security.UserRoles_get) so internal mapping stays in one place.
-- Result 1: IsSuperAdmin (exact, case-sensitive CompanyPortal.Admin). Result 2: extra SectionKey grants.
CREATE OR ALTER PROCEDURE Portal.AdminAccess_get
 @Username nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Users TABLE(UserId int);
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Users EXEC Security.User_getByUsername @Username=@Username;
 DECLARE @UserId int=(SELECT TOP(1) UserId FROM @Users WHERE UserId IS NOT NULL);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM @Roles WHERE RoleName COLLATE Latin1_General_BIN2=N'CompanyPortal.Admin') THEN 1 ELSE 0 END) IsSuperAdmin;
 SELECT DISTINCT s.SectionKey
 FROM Portal.AdminSectionRoles s
 JOIN @Roles r ON r.RoleName COLLATE Latin1_General_BIN2=s.RoleName COLLATE Latin1_General_BIN2;
END;
GO
