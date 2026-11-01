-- DEVELOPMENT ONLY: security identity/name source. Replace the adapter SELECT internally.
USE SecurityDB;
GO
IF COL_LENGTH(N'dbo.Users',N'DisplayName') IS NULL ALTER TABLE dbo.Users ADD DisplayName nvarchar(300) NULL;
IF COL_LENGTH(N'dbo.Users',N'JobTitle') IS NULL ALTER TABLE dbo.Users ADD JobTitle nvarchar(300) NULL;
IF COL_LENGTH(N'dbo.Users',N'Department') IS NULL ALTER TABLE dbo.Users ADD Department nvarchar(300) NULL;
GO
-- Preserve existing populated security names; carry the local profile samples into SecurityDB once.
IF OBJECT_ID(N'CompanyPortal.Development.ProfilePeople',N'U') IS NOT NULL
 UPDATE u SET DisplayName=COALESCE(u.DisplayName,p.DisplayName),JobTitle=COALESCE(u.JobTitle,p.JobTitle),Department=COALESCE(u.Department,p.Department)
 FROM dbo.Users u JOIN CompanyPortal.Development.ProfilePeople p ON p.UserId=u.UserId AND p.Active=1;
UPDATE dbo.Users SET DisplayName=N'أحمد سالم' WHERE DisplayName IS NULL AND NTName=ORIGINAL_LOGIN();
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Security.UserProfile_getById @UserId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT DisplayName,JobTitle,Department FROM SecurityDB.dbo.Users WHERE UserId=@UserId AND Active=1;
END;
GO
