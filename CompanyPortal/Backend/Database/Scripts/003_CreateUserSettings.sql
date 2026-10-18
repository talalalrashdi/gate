USE [CompanyPortal];
GO
IF OBJECT_ID(N'Portal.UserSettings', N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserSettings
    (
        UserSettingId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserSettings PRIMARY KEY,
        UserId int NOT NULL CONSTRAINT UQ_UserSettings_UserId UNIQUE,
        Theme nvarchar(50) NOT NULL CONSTRAINT DF_UserSettings_Theme DEFAULT (N'majestic'),
        Active bit NOT NULL CONSTRAINT DF_UserSettings_Active DEFAULT (1),
        CreatedAt datetime NOT NULL CONSTRAINT DF_UserSettings_CreatedAt DEFAULT (GETDATE()),
        CONSTRAINT CK_UserSettings_Theme CHECK (Theme IN (N'majestic', N'official', N'formal'))
    );
END;
GO
