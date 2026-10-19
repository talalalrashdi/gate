USE [CompanyPortal];
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF SCHEMA_ID(N'Master') IS NULL EXEC(N'CREATE SCHEMA [Master] AUTHORIZATION dbo;');
    IF OBJECT_ID(N'Master.Themes', N'U') IS NULL
    BEGIN
        CREATE TABLE [Master].Themes
        (
            ThemeId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Themes PRIMARY KEY,
            ThemeName nvarchar(200) NOT NULL,
            LayoutKey nvarchar(50) NOT NULL,
            DisplayOrder int NOT NULL CONSTRAINT DF_Themes_DisplayOrder DEFAULT (0),
            IsDefault bit NOT NULL CONSTRAINT DF_Themes_IsDefault DEFAULT (0),
            Active bit NOT NULL CONSTRAINT DF_Themes_Active DEFAULT (1),
            LastChangeAt datetime NOT NULL CONSTRAINT DF_Themes_LastChangeAt DEFAULT (GETDATE()),
            CONSTRAINT CK_Themes_Name CHECK (LEN(LTRIM(RTRIM(ThemeName))) > 0),
            CONSTRAINT CK_Themes_LayoutKey CHECK (LayoutKey IN (N'official', N'work', N'national-day')),
            CONSTRAINT CK_Themes_DisplayOrder CHECK (DisplayOrder >= 0),
            CONSTRAINT CK_Themes_DefaultActive CHECK (IsDefault = 0 OR Active = 1)
        );
        CREATE UNIQUE INDEX UQ_Themes_ActiveDefault ON [Master].Themes(IsDefault) WHERE IsDefault = 1 AND Active = 1;
        INSERT [Master].Themes (ThemeName, LayoutKey, DisplayOrder, IsDefault)
        VALUES (N'الرسمي', N'official', 1, 1),
               (N'العملي', N'work', 2, 0),
               (N'اليوم الوطني', N'national-day', 3, 0);
    END;

    IF COL_LENGTH(N'Portal.UserSettings', N'ThemeId') IS NULL
        EXEC(N'ALTER TABLE Portal.UserSettings ADD ThemeId int NULL;');
    IF COL_LENGTH(N'Portal.UserSettings', N'ThemeName') IS NOT NULL
        EXEC(N'UPDATE s SET ThemeId = t.ThemeId
            FROM Portal.UserSettings s JOIN [Master].Themes t ON t.LayoutKey = s.ThemeName
            WHERE s.ThemeId IS NULL;
            IF EXISTS (SELECT 1 FROM Portal.UserSettings WHERE ThemeId IS NULL)
                THROW 50003, ''An existing theme has no catalog mapping.'', 1;');

    EXEC(N'ALTER TABLE Portal.UserSettings ALTER COLUMN ThemeId int NOT NULL;');
    IF OBJECT_ID(N'Portal.FK_UserSettings_Themes', N'F') IS NULL
        EXEC(N'ALTER TABLE Portal.UserSettings WITH CHECK ADD CONSTRAINT FK_UserSettings_Themes
            FOREIGN KEY (ThemeId) REFERENCES [Master].Themes(ThemeId);');
    IF OBJECT_ID(N'Portal.CK_UserSettings_ThemeName', N'C') IS NOT NULL
        ALTER TABLE Portal.UserSettings DROP CONSTRAINT CK_UserSettings_ThemeName;
    IF OBJECT_ID(N'Portal.DF_UserSettings_ThemeName', N'D') IS NOT NULL
        ALTER TABLE Portal.UserSettings DROP CONSTRAINT DF_UserSettings_ThemeName;
    IF COL_LENGTH(N'Portal.UserSettings', N'ThemeName') IS NOT NULL
        EXEC(N'ALTER TABLE Portal.UserSettings DROP COLUMN ThemeName;');
    -- Selecting by ID preserves the chosen design; do not change LastChangeAt here.
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ThemeId, ThemeName, LayoutKey, DisplayOrder, IsDefault
    FROM [Master].Themes WHERE Active = 1 ORDER BY DisplayOrder, ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_getTheme
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1) t.ThemeId, t.ThemeName, t.LayoutKey,
        CAST(CASE WHEN s.UserSettingId IS NOT NULL THEN 1 ELSE 0 END AS bit) AS IsSaved,
        s.LastChangeAt
    FROM [Master].Themes t
    LEFT JOIN Portal.UserSettings s ON s.ThemeId = t.ThemeId AND s.UserId = @UserId AND s.Active = 1
    WHERE t.Active = 1 AND (s.UserSettingId IS NOT NULL OR t.IsDefault = 1)
    ORDER BY CASE WHEN s.UserSettingId IS NOT NULL THEN 0 ELSE 1 END;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_setTheme
    @UserId int,
    @ThemeId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM [Master].Themes WITH (HOLDLOCK) WHERE ThemeId = @ThemeId AND Active = 1)
        THROW 50002, 'Select an available theme.', 1;

    UPDATE Portal.UserSettings WITH (UPDLOCK, SERIALIZABLE)
    SET LastChangeAt = CASE WHEN ThemeId <> @ThemeId OR Active = 0 THEN GETDATE() ELSE LastChangeAt END,
        ThemeId = @ThemeId, Active = 1
    WHERE UserId = @UserId;
    IF @@ROWCOUNT = 0
        INSERT Portal.UserSettings (UserId, ThemeId) VALUES (@UserId, @ThemeId);
    COMMIT TRANSACTION;
END;
GO
