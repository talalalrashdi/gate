USE CompanyPortal;
GO
-- Integration boundary: map this SP to the real security/employee database on deployment.
IF OBJECT_ID(N'Security.UserProfile_getById',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Security.UserProfile_getById @UserId int AS BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS nvarchar(300)) DisplayName,CAST(NULL AS nvarchar(300)) JobTitle,CAST(NULL AS nvarchar(300)) Department WHERE 1=0; END;');
GO
CREATE OR ALTER PROCEDURE Portal.UserProfile_Get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 EXEC Security.UserProfile_getById @UserId=@UserId;
END;
GO
