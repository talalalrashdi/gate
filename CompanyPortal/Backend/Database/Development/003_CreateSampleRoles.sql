-- DEVELOPMENT ONLY. Do not deploy these sample grants internally.
USE [SecurityDB];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Roles',N'U') IS NULL
CREATE TABLE dbo.Roles (
 RoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
 RoleName nvarchar(200) NOT NULL CONSTRAINT UQ_Roles_Name UNIQUE,
 Active bit NOT NULL CONSTRAINT DF_Roles_Active DEFAULT(1),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_Roles_LastChangeAt DEFAULT(GETDATE())
);
IF OBJECT_ID(N'dbo.UserRoles',N'U') IS NULL
CREATE TABLE dbo.UserRoles (
 UserRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserRoles PRIMARY KEY,
 UserId int NOT NULL CONSTRAINT FK_UserRoles_Users REFERENCES dbo.Users(UserId),
 RoleId int NOT NULL CONSTRAINT FK_UserRoles_Roles REFERENCES dbo.Roles(RoleId),
 Active bit NOT NULL CONSTRAINT DF_UserRoles_Active DEFAULT(1),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_UserRoles_LastChangeAt DEFAULT(GETDATE()),
 CONSTRAINT UQ_UserRoles_User_Role UNIQUE(UserId,RoleId)
);
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE RoleName=N'CompanyPortal.Admin')
 INSERT dbo.Roles(RoleName) VALUES(N'CompanyPortal.Admin');
-- An explicit development grant to the executing Windows account, never every employee.
INSERT dbo.UserRoles(UserId,RoleId)
SELECT u.UserId,r.RoleId FROM dbo.Users u CROSS JOIN dbo.Roles r
WHERE u.NTName=ORIGINAL_LOGIN() AND u.Active=1 AND r.RoleName=N'CompanyPortal.Admin' AND r.Active=1
AND NOT EXISTS(SELECT 1 FROM dbo.UserRoles x WHERE x.UserId=u.UserId AND x.RoleId=r.RoleId);
COMMIT;
GO
