-- DEVELOPMENT ONLY. Do not run against the real internal security database.
USE [SecurityDB];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Applications',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Applications
    (
        AppId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Applications PRIMARY KEY,
        AppKey nvarchar(100) NOT NULL CONSTRAINT UQ_Applications_AppKey UNIQUE,
        AppName nvarchar(200) NOT NULL,
        LaunchUrl nvarchar(2048) NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_Applications_Active DEFAULT (1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_Applications_LastChangeAt DEFAULT (GETDATE())
    );
    INSERT dbo.Applications(AppKey,AppName,LaunchUrl) VALUES
      (N'people-demo',N'الموارد البشرية — تجريبي',N'http://localhost:5080/#workspace'),
      (N'support-demo',N'الدعم الفني — تجريبي',N'http://localhost:5080/#workspace'),
      (N'projects-demo',N'المشاريع — تجريبي',N'http://localhost:5080/#workspace'),
      (N'reports-demo',N'التقارير — غير مصرح في العينة',N'http://localhost:5080/#workspace');
END;
IF OBJECT_ID(N'dbo.UserApplicationAccess',N'U') IS NULL
    CREATE TABLE dbo.UserApplicationAccess
    (
        UserApplicationAccessId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserApplicationAccess PRIMARY KEY,
        UserId int NOT NULL CONSTRAINT FK_UserApplicationAccess_Users REFERENCES dbo.Users(UserId),
        AppId int NOT NULL CONSTRAINT FK_UserApplicationAccess_Applications REFERENCES dbo.Applications(AppId),
        Active bit NOT NULL CONSTRAINT DF_UserApplicationAccess_Active DEFAULT (1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserApplicationAccess_LastChangeAt DEFAULT (GETDATE()),
        CONSTRAINT UQ_UserApplicationAccess_UserApp UNIQUE(UserId,AppId)
    );
-- Explicit grants for the current registered developer only; no blanket app access.
-- Reruns retain existing inactive grants instead of reactivating them.
INSERT dbo.UserApplicationAccess(UserId,AppId)
SELECT u.UserId,a.AppId FROM dbo.Users u CROSS JOIN dbo.Applications a
WHERE u.NTName=ORIGINAL_LOGIN() AND u.Active=1
  AND a.AppKey IN(N'people-demo',N'support-demo',N'projects-demo')
  AND NOT EXISTS(SELECT 1 FROM dbo.UserApplicationAccess x WHERE x.UserId=u.UserId AND x.AppId=a.AppId);
COMMIT TRANSACTION;
GO
