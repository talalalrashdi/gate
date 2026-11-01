-- DEVELOPMENT ONLY. Replace these two adapters with the approved security database operations internally.
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Security.Role_Create @RoleName nvarchar(200) AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM SecurityDB.dbo.Roles WITH(UPDLOCK,HOLDLOCK) WHERE RoleName=@RoleName) THROW 50006,'Role name already exists (including inactive roles).',1;
 INSERT SecurityDB.dbo.Roles(RoleName) VALUES(@RoleName);
END;
GO
CREATE OR ALTER PROCEDURE Security.Role_Deactivate @RoleName nvarchar(200) AS
BEGIN
 SET NOCOUNT ON;
 IF @RoleName COLLATE Latin1_General_100_CI_AS=N'CompanyPortal.Admin' THROW 50006,'Protected role.',1;
 UPDATE SecurityDB.dbo.Roles SET Active=0,LastChangeAt=GETDATE() WHERE RoleName=@RoleName AND Active=1;
 IF @@ROWCOUNT<>1 THROW 50006,'Active role not found.',1;
END;
GO
