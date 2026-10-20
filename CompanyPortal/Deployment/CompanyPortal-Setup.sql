/* CompanyPortal fresh installation, generated from migrations 001-018.
   Open this entire UTF-8 file in SSMS and Execute (normal mode, no SQLCMD mode).
   Or: sqlcmd -S SQLSERVER -E -b -f 65001 -i CompanyPortal-Setup.sql
   FRESH INSTALL ONLY. Never run on an existing CompanyPortal database.
   TestSources=1 creates NEW sample SecurityDB and Pubs_Info_V4 databases.
   TestSources=0 leaves external databases alone; configure the three Security
   adapter procedures and dbo.VNews against the real sources AFTER this script.
   No current employee preferences, uploaded images or custom themes are exported.
*/
USE master;
GO
SET NOCOUNT ON;
CREATE TABLE #PortalDeployment (
 TestSources bit NOT NULL, TestNTName nvarchar(512) NOT NULL,
 ApiIdentity nvarchar(512) NOT NULL, PortalUrl nvarchar(2048) NOT NULL
);
-- EDIT these values. TestNTName is the employee using the browser, NOT the API service account.
INSERT #PortalDeployment VALUES (
 1,                         -- 1 = isolated sample sources; 0 = real external sources
 N'COMPANY\employee1',       -- exact DOMAIN\username: gets an explicit TEST admin grant
 N'',                       -- optional DOMAIN\svcCompanyPortal; empty = DBA grants later
 N'https://portal.company.local/'
);
IF DB_ID(N'CompanyPortal') IS NOT NULL
 OR EXISTS(SELECT 1 FROM #PortalDeployment WHERE TestSources=1
   AND (DB_ID(N'SecurityDB') IS NOT NULL OR DB_ID(N'Pubs_Info_V4') IS NOT NULL
        OR TestNTName=N'COMPANY\employee1' OR TestNTName=N''))
BEGIN
 RAISERROR('STOP: use a fresh CompanyPortal; sample mode also requires NEW external databases and an edited TestNTName. No setup ran. Reconnect before retrying.',16,1);
 SET NOEXEC ON;
END;
GO

-- BEGIN 001_CreateDatabase.sql
-- Run against the selected SQL Server using a database deployment account.
-- Uses that server's default file locations; contains no machine-specific paths.
USE [master];
GO

SET NOCOUNT ON;

IF DB_ID(N'CompanyPortal') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [CompanyPortal];');
    PRINT N'Created CompanyPortal database.';
END
ELSE
BEGIN
    PRINT N'CompanyPortal already exists; no changes made.';
END;
GO

GO


-- BEGIN 002_CreateSchemas.sql
USE [CompanyPortal];
GO
IF SCHEMA_ID(N'Security') IS NULL EXEC(N'CREATE SCHEMA [Security] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'Portal') IS NULL EXEC(N'CREATE SCHEMA [Portal] AUTHORIZATION [dbo];');
GO

GO


-- BEGIN 003_CreateUserSettings.sql
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

GO


-- BEGIN 004_UserSettingsProcedures.sql
USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_getTheme
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Theme FROM Portal.UserSettings WHERE UserId = @UserId AND Active = 1;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_setTheme
    @UserId int,
    @Theme nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Theme IS NULL OR @Theme NOT IN (N'majestic', N'official', N'formal')
        THROW 50001, 'Invalid theme.', 1;

    BEGIN TRANSACTION;
    UPDATE Portal.UserSettings WITH (UPDLOCK, SERIALIZABLE)
    SET Theme = @Theme, Active = 1
    WHERE UserId = @UserId;

    IF @@ROWCOUNT = 0
        INSERT Portal.UserSettings (UserId, Theme) VALUES (@UserId, @Theme);
    COMMIT TRANSACTION;
END;
GO

GO


-- BEGIN 005_RenameThemeColumns.sql
USE [CompanyPortal];
GO
-- Preserve existing rows/values. Previously deployed scripts 003/004 are unchanged.
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'Portal.CK_UserSettings_Theme', N'C') IS NOT NULL
        ALTER TABLE Portal.UserSettings DROP CONSTRAINT CK_UserSettings_Theme;

    IF COL_LENGTH(N'Portal.UserSettings', N'ThemeName') IS NULL
        AND COL_LENGTH(N'Portal.UserSettings', N'Theme') IS NOT NULL
        EXEC sys.sp_rename N'Portal.UserSettings.Theme', N'ThemeName', N'COLUMN';
    IF COL_LENGTH(N'Portal.UserSettings', N'LastChangeAt') IS NULL
        AND COL_LENGTH(N'Portal.UserSettings', N'CreatedAt') IS NOT NULL
        EXEC sys.sp_rename N'Portal.UserSettings.CreatedAt', N'LastChangeAt', N'COLUMN';

    IF OBJECT_ID(N'Portal.DF_UserSettings_Theme', N'D') IS NOT NULL
        EXEC sys.sp_rename N'Portal.DF_UserSettings_Theme', N'DF_UserSettings_ThemeName', N'OBJECT';
    IF OBJECT_ID(N'Portal.DF_UserSettings_CreatedAt', N'D') IS NOT NULL
        EXEC sys.sp_rename N'Portal.DF_UserSettings_CreatedAt', N'DF_UserSettings_LastChangeAt', N'OBJECT';
    IF OBJECT_ID(N'Portal.CK_UserSettings_ThemeName', N'C') IS NULL
        EXEC(N'ALTER TABLE Portal.UserSettings WITH CHECK ADD CONSTRAINT CK_UserSettings_ThemeName
            CHECK (ThemeName IN (N''majestic'', N''formal'', N''official''));');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_getTheme
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ThemeName, LastChangeAt
    FROM Portal.UserSettings WHERE UserId = @UserId AND Active = 1;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_setTheme
    @UserId int,
    @ThemeName nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ThemeName IS NULL OR @ThemeName NOT IN (N'majestic', N'formal', N'official')
        THROW 50001, 'Invalid theme name.', 1;

    BEGIN TRANSACTION;
    UPDATE Portal.UserSettings WITH (UPDLOCK, SERIALIZABLE)
    SET LastChangeAt = CASE WHEN ThemeName <> @ThemeName OR Active = 0
                           THEN GETDATE() ELSE LastChangeAt END,
        ThemeName = @ThemeName, Active = 1
    WHERE UserId = @UserId;

    IF @@ROWCOUNT = 0
        INSERT Portal.UserSettings (UserId, ThemeName) VALUES (@UserId, @ThemeName);
    COMMIT TRANSACTION;
END;
GO

GO


-- BEGIN 006_RenameThemeNames.sql
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    -- Old 'official' meant national day, so migrate once under the old constraint.
    IF EXISTS (SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'Portal.UserSettings')
          AND name = N'CK_UserSettings_ThemeName' AND definition LIKE N'%majestic%')
    BEGIN
        ALTER TABLE Portal.UserSettings DROP CONSTRAINT CK_UserSettings_ThemeName;
        UPDATE Portal.UserSettings SET ThemeName = CASE ThemeName
            WHEN N'majestic' THEN N'official'
            WHEN N'formal' THEN N'work'
            WHEN N'official' THEN N'national-day' END;
        -- This is a naming migration, not a changed employee preference: retain LastChangeAt.
        ALTER TABLE Portal.UserSettings DROP CONSTRAINT DF_UserSettings_ThemeName;
        ALTER TABLE Portal.UserSettings ADD CONSTRAINT DF_UserSettings_ThemeName DEFAULT (N'official') FOR ThemeName;
        ALTER TABLE Portal.UserSettings WITH CHECK ADD CONSTRAINT CK_UserSettings_ThemeName
            CHECK (ThemeName IN (N'official', N'work', N'national-day'));
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_setTheme
    @UserId int,
    @ThemeName nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ThemeName IS NULL OR @ThemeName NOT IN (N'official', N'work', N'national-day')
        THROW 50001, 'Invalid theme name.', 1;

    BEGIN TRANSACTION;
    UPDATE Portal.UserSettings WITH (UPDLOCK, SERIALIZABLE)
    SET LastChangeAt = CASE WHEN ThemeName <> @ThemeName OR Active = 0
                           THEN GETDATE() ELSE LastChangeAt END,
        ThemeName = @ThemeName, Active = 1
    WHERE UserId = @UserId;
    IF @@ROWCOUNT = 0
        INSERT Portal.UserSettings (UserId, ThemeName) VALUES (@UserId, @ThemeName);
    COMMIT TRANSACTION;
END;
GO

GO


-- BEGIN 007_MasterThemes.sql
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

GO


-- BEGIN 008_UserCardOrder.sql
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Master.Cards', N'U') IS NULL
BEGIN
    CREATE TABLE [Master].Cards
    (
        CardId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cards PRIMARY KEY,
        CardKey nvarchar(100) NOT NULL CONSTRAINT UQ_Cards_CardKey UNIQUE,
        CardName nvarchar(200) NOT NULL,
        DisplayOrder int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_Cards_Active DEFAULT (1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_Cards_LastChangeAt DEFAULT (GETDATE()),
        CONSTRAINT CK_Cards_DisplayOrder CHECK (DisplayOrder >= 0)
    );
    INSERT [Master].Cards(CardKey, CardName, DisplayOrder) VALUES
(N'library', N'القرارات', 1),
(N'inbox', N'مراسلات', 2),
(N'email', N'البريد الإلكتروني', 3),
(N'requests', N'نظام الاستمارات', 4),
(N'services', N'مركز الخدمات', 5),
(N'electronic-services', N'الخدمات الإلكترونية', 6),
(N'meetings', N'الاجتماعات', 7),
(N'tasks', N'المهام', 8),
(N'employees', N'شؤون الموظفين', 9),
(N'attendance', N'الحضور والانصراف', 10),
(N'leave', N'الإجازات', 11),
(N'learning', N'التعلّم والتدريب', 12),
(N'projects', N'إدارة المشاريع', 13),
(N'assets', N'الأصول والعُهد', 14),
(N'purchases', N'المشتريات', 15),
(N'finance', N'الشؤون المالية', 16),
(N'contracts', N'العقود', 17),
(N'warehouse', N'المخازن', 18),
(N'reports', N'التقارير والمؤشرات', 19),
(N'archive', N'الأرشيف الإلكتروني', 20),
(N'ideas', N'الأفكار والمقترحات', 21),
(N'support', N'الدعم التقني', 22);
END;
IF OBJECT_ID(N'Portal.UserCardOrder', N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserCardOrder
    (
        UserCardOrderId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserCardOrder PRIMARY KEY,
        UserId int NOT NULL,
        CardId int NOT NULL CONSTRAINT FK_UserCardOrder_Cards REFERENCES [Master].Cards(CardId),
        SortOrder int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserCardOrder_Active DEFAULT (1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserCardOrder_LastChangeAt DEFAULT (GETDATE()),
        CONSTRAINT UQ_UserCardOrder_UserCard UNIQUE (UserId, CardId),
        CONSTRAINT CK_UserCardOrder_SortOrder CHECK (SortOrder >= 0)
    );
END;
IF TYPE_ID(N'Portal.CardOrderInput') IS NULL
    EXEC(N'CREATE TYPE Portal.CardOrderInput AS TABLE
        (SortOrder int NOT NULL PRIMARY KEY, CardKey nvarchar(100) NOT NULL UNIQUE);');
COMMIT TRANSACTION;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CardKey,
        CAST(CASE WHEN s.UserCardOrderId IS NULL THEN 0 ELSE 1 END AS bit) AS IsSaved,
        s.LastChangeAt
    FROM [Master].Cards c
    LEFT JOIN Portal.UserCardOrder s ON s.CardId = c.CardId AND s.UserId = @UserId AND s.Active = 1
    WHERE c.Active = 1
    ORDER BY CASE WHEN s.UserCardOrderId IS NULL THEN 1 ELSE 0 END, s.SortOrder, c.DisplayOrder, c.CardId;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_set
    @UserId int,
    @Cards Portal.CardOrderInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF (SELECT COUNT(*) FROM @Cards) NOT BETWEEN 1 AND 200
       OR EXISTS (SELECT 1 FROM @Cards WHERE SortOrder < 0)
       OR (SELECT MIN(SortOrder) FROM @Cards) <> 0
       OR (SELECT MAX(SortOrder) FROM @Cards) <> (SELECT COUNT(*) - 1 FROM @Cards)
        THROW 50004, 'Supply unique card keys with consecutive positions.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Keep catalog validation stable until the complete order is committed.
        DECLARE @Available int = (SELECT COUNT(*) FROM [Master].Cards WITH (HOLDLOCK) WHERE Active = 1);
        IF @Available <> (SELECT COUNT(*) FROM @Cards)
           OR EXISTS (SELECT 1 FROM @Cards i LEFT JOIN [Master].Cards c ON c.CardKey = i.CardKey AND c.Active = 1 WHERE c.CardId IS NULL)
            THROW 50004, 'The available cards changed. Reload before saving.', 1;
        -- Lock this user's indexed range, including an initially empty range.
        DECLARE @Existing int = (SELECT COUNT(*) FROM Portal.UserCardOrder WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId);
        UPDATE s SET SortOrder = i.SortOrder, Active = 1, LastChangeAt = GETDATE()
        FROM Portal.UserCardOrder s
        JOIN [Master].Cards c ON c.CardId = s.CardId
        JOIN @Cards i ON i.CardKey = c.CardKey
        WHERE s.UserId = @UserId AND (s.SortOrder <> i.SortOrder OR s.Active = 0);
        INSERT Portal.UserCardOrder(UserId,CardId,SortOrder)
        SELECT @UserId,c.CardId,i.SortOrder FROM @Cards i JOIN [Master].Cards c ON c.CardKey=i.CardKey
        WHERE NOT EXISTS (SELECT 1 FROM Portal.UserCardOrder s WHERE s.UserId=@UserId AND s.CardId=c.CardId);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

GO


-- BEGIN 009_MasterCardPolicy.sql
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
-- Initialize this policy once; reruns must preserve later administrator choices.
IF COL_LENGTH(N'Master.Cards',N'IsFixed') IS NULL
BEGIN
    ALTER TABLE [Master].Cards ADD IsFixed bit NOT NULL CONSTRAINT DF_Cards_IsFixed DEFAULT (0);
    UPDATE [Master].Cards SET Active=0, LastChangeAt=GETDATE()
    WHERE CardKey NOT IN (N'library',N'inbox',N'email',N'requests',N'electronic-services') AND Active=1;
    UPDATE c SET CardName=v.CardName,DisplayOrder=v.DisplayOrder,Active=1,LastChangeAt=GETDATE()
    FROM [Master].Cards c JOIN (VALUES
      (N'library',N'القرارات',1),
      (N'inbox',N'مرسالات',2),
      (N'email',N'البريد الالكتروني',3),
      (N'requests',N'نظام الاستمارات',4),
      (N'electronic-services',N'الخدمات الالكترونية',5)
    ) v(CardKey,CardName,DisplayOrder) ON v.CardKey=c.CardKey;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'Master.Cards') AND name=N'UQ_Cards_FixedPosition')
    EXEC(N'CREATE UNIQUE INDEX UQ_Cards_FixedPosition ON [Master].Cards(DisplayOrder) WHERE Active=1 AND IsFixed=1;');
IF OBJECT_ID(N'Master.CK_Cards_FixedPosition',N'C') IS NULL
    EXEC(N'ALTER TABLE [Master].Cards ADD CONSTRAINT CK_Cards_FixedPosition CHECK(IsFixed=0 OR DisplayOrder>=1);');
COMMIT TRANSACTION;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1);
    IF EXISTS (SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND DisplayOrder>@Count)
        THROW 50005, 'Configure fixed positions within the active card count.', 1;
    ;WITH Base AS
    (
        SELECT c.CardId,c.CardKey,c.CardName,c.IsFixed,c.DisplayOrder,s.SortOrder,
          CAST(CASE WHEN s.UserCardOrderId IS NULL THEN 0 ELSE 1 END AS bit) AS IsSaved,s.LastChangeAt
        FROM [Master].Cards c
        LEFT JOIN Portal.UserCardOrder s ON s.CardId=c.CardId AND s.UserId=@UserId AND s.Active=1
        WHERE c.Active=1
    ), Slots AS
    (
        SELECT ROW_NUMBER() OVER(ORDER BY CardId)-1 AS Position FROM Base
    ), FreeSlots AS
    (
        SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) AS RowNumber FROM Slots p
        WHERE NOT EXISTS (SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=p.Position+1)
    ), Movable AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY IsSaved DESC,SortOrder,DisplayOrder,CardId) AS RowNumber
        FROM Base WHERE IsFixed=0
    ), Resolved AS
    (
        SELECT CardKey,CardName,IsFixed,DisplayOrder,IsSaved,LastChangeAt,DisplayOrder-1 AS Position FROM Base WHERE IsFixed=1
        UNION ALL
        SELECT m.CardKey,m.CardName,m.IsFixed,m.DisplayOrder,m.IsSaved,m.LastChangeAt,p.Position
        FROM Movable m JOIN FreeSlots p ON p.RowNumber=m.RowNumber
    )
    SELECT CardKey,CardName,IsFixed,DisplayOrder,IsSaved,LastChangeAt FROM Resolved ORDER BY Position;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_set
    @UserId int,
    @Cards Portal.CardOrderInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF (SELECT COUNT(*) FROM @Cards) NOT BETWEEN 1 AND 200
       OR EXISTS (SELECT 1 FROM @Cards WHERE SortOrder < 0)
       OR (SELECT MIN(SortOrder) FROM @Cards) <> 0
       OR (SELECT MAX(SortOrder) FROM @Cards) <> (SELECT COUNT(*) - 1 FROM @Cards)
        THROW 50004, 'Supply unique card keys with consecutive positions.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Keep catalog validation stable until the complete order is committed.
        DECLARE @Available int = (SELECT COUNT(*) FROM [Master].Cards WITH (HOLDLOCK) WHERE Active = 1);
        IF @Available <> (SELECT COUNT(*) FROM @Cards)
           OR EXISTS (SELECT 1 FROM @Cards i LEFT JOIN [Master].Cards c ON c.CardKey = i.CardKey AND c.Active = 1 WHERE c.CardId IS NULL)
            THROW 50004, 'The available cards changed. Reload before saving.', 1;
        IF EXISTS (SELECT 1 FROM @Cards i JOIN [Master].Cards c ON c.CardKey=i.CardKey
                   WHERE c.Active=1 AND c.IsFixed=1 AND i.SortOrder<>c.DisplayOrder-1)
            THROW 50004, 'A fixed card cannot change position.', 1;
        -- Lock this user's indexed range, including an initially empty range.
        DECLARE @Existing int = (SELECT COUNT(*) FROM Portal.UserCardOrder WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId);
        UPDATE s SET SortOrder = i.SortOrder, Active = 1, LastChangeAt = GETDATE()
        FROM Portal.UserCardOrder s
        JOIN [Master].Cards c ON c.CardId = s.CardId
        JOIN @Cards i ON i.CardKey = c.CardKey
        WHERE s.UserId = @UserId AND (s.SortOrder <> i.SortOrder OR s.Active = 0);
        INSERT Portal.UserCardOrder(UserId,CardId,SortOrder)
        SELECT @UserId,c.CardId,i.SortOrder FROM @Cards i JOIN [Master].Cards c ON c.CardKey=i.CardKey
        WHERE NOT EXISTS (SELECT 1 FROM Portal.UserCardOrder s WHERE s.UserId=@UserId AND s.CardId=c.CardId);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_setPosition
    @CardId int,
    @IsFixed bit,
    @DisplayOrder int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WITH (UPDLOCK,HOLDLOCK) WHERE Active=1);
        IF @IsFixed IS NULL OR @DisplayOrder IS NULL OR @DisplayOrder<1 OR @DisplayOrder>@Count
           OR NOT EXISTS (SELECT 1 FROM [Master].Cards WHERE CardId=@CardId AND Active=1)
            THROW 50006, 'Select an active card and a position within the active card count.', 1;
        IF @IsFixed=1 AND EXISTS (SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND DisplayOrder=@DisplayOrder AND CardId<>@CardId)
            THROW 50006, 'Another fixed card already occupies that position.', 1;
        UPDATE [Master].Cards SET IsFixed=@IsFixed,DisplayOrder=@DisplayOrder,LastChangeAt=GETDATE()
        WHERE CardId=@CardId AND (IsFixed<>@IsFixed OR DisplayOrder<>@DisplayOrder);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

GO


-- BEGIN 010_UserCustomCards.sql
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Portal.UserCards',N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserCards
    (
        UserCardId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserCards PRIMARY KEY,
        UserId int NOT NULL,
        CardName nvarchar(200) NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserCards_Active DEFAULT(1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserCards_LastChangeAt DEFAULT(GETDATE()),
        CONSTRAINT CK_UserCards_Name CHECK(LEN(LTRIM(RTRIM(CardName)))>0)
    );
    CREATE INDEX IX_UserCards_Owner ON Portal.UserCards(UserId,Active,UserCardId);
END;
IF OBJECT_ID(N'Portal.UserCardApplications',N'U') IS NULL
    CREATE TABLE Portal.UserCardApplications
    (
        UserCardApplicationId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserCardApplications PRIMARY KEY,
        UserCardId int NOT NULL CONSTRAINT FK_UserCardApplications_UserCards REFERENCES Portal.UserCards(UserCardId),
        AppId int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserCardApplications_Active DEFAULT(1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserCardApplications_LastChangeAt DEFAULT(GETDATE()),
        CONSTRAINT UQ_UserCardApplications_CardApp UNIQUE(UserCardId,AppId)
    );
IF OBJECT_ID(N'Portal.UserWorkspaceOrder',N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserWorkspaceOrder
    (
        UserWorkspaceOrderId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserWorkspaceOrder PRIMARY KEY,
        UserId int NOT NULL,
        CardKey nvarchar(100) NOT NULL,
        SortOrder int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserWorkspaceOrder_Active DEFAULT(1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserWorkspaceOrder_LastChangeAt DEFAULT(GETDATE()),
        CONSTRAINT UQ_UserWorkspaceOrder_UserKey UNIQUE(UserId,CardKey),
        CONSTRAINT CK_UserWorkspaceOrder_SortOrder CHECK(SortOrder>=0)
    );
    -- Preserve existing master ordering and timestamps once; retain historical rows/table.
    INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder,Active,LastChangeAt)
    SELECT s.UserId,c.CardKey,s.SortOrder,s.Active,s.LastChangeAt
    FROM Portal.UserCardOrder s JOIN [Master].Cards c ON c.CardId=s.CardId WHERE c.Active=1;
END;
IF TYPE_ID(N'Portal.AppIdInput') IS NULL
    EXEC(N'CREATE TYPE Portal.AppIdInput AS TABLE(AppId int NOT NULL PRIMARY KEY);');
COMMIT TRANSACTION;
GO
CREATE OR ALTER PROCEDURE Portal.UserCards_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
    INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
    SELECT UserCardId,CardName,LastChangeAt FROM Portal.UserCards
    WHERE UserId=@UserId AND Active=1 ORDER BY UserCardId;
    SELECT c.UserCardId,a.AppId,a.AppName FROM Portal.UserCards c
    JOIN Portal.UserCardApplications m ON m.UserCardId=c.UserCardId AND m.Active=1
    JOIN @Allowed a ON a.AppId=m.AppId
    WHERE c.UserId=@UserId AND c.Active=1 ORDER BY c.UserCardId,a.AppId;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCards_save
    @UserId int,
    @CardName nvarchar(200),
    @Apps Portal.AppIdInput READONLY,
    @UserCardId int=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CardName IS NULL OR LEN(LTRIM(RTRIM(@CardName)))=0
       OR (SELECT COUNT(*) FROM @Apps) NOT BETWEEN 1 AND 100
        THROW 50007,'Supply a name and at least one authorized application.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Count int=(SELECT COUNT(*) FROM Portal.UserCards WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND Active=1);
        IF @UserCardId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND UserId=@UserId AND Active=1)
            THROW 50008,'Card not found.',1;
        IF @UserCardId IS NULL AND @Count>=50 THROW 50009,'The custom card limit is 50.',1;
        DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
        INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
        IF EXISTS(SELECT 1 FROM @Apps i LEFT JOIN @Allowed a ON a.AppId=i.AppId WHERE a.AppId IS NULL)
            THROW 50007,'One or more applications are not authorized.',1;
        DECLARE @Changed bit=0;
        IF @UserCardId IS NULL
        BEGIN
            INSERT Portal.UserCards(UserId,CardName) VALUES(@UserId,LTRIM(RTRIM(@CardName)));
            SET @UserCardId=CONVERT(int,SCOPE_IDENTITY());
            DECLARE @Existing int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND Active=1);
            IF @Existing=0
                INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
                SELECT @UserId,CardKey,ROW_NUMBER() OVER(ORDER BY DisplayOrder,CardId)-1 FROM [Master].Cards WHERE Active=1;
            DECLARE @Position int=(SELECT ISNULL(MAX(SortOrder),-1)+1 FROM Portal.UserWorkspaceOrder WHERE UserId=@UserId AND Active=1);
            INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
            VALUES(@UserId,N'custom-'+CONVERT(nvarchar(20),@UserCardId),@Position);
        END;
        IF EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND CardName<>LTRIM(RTRIM(@CardName)))
           OR EXISTS(SELECT AppId FROM @Apps EXCEPT SELECT AppId FROM Portal.UserCardApplications WHERE UserCardId=@UserCardId AND Active=1)
           OR EXISTS(SELECT AppId FROM Portal.UserCardApplications WHERE UserCardId=@UserCardId AND Active=1 EXCEPT SELECT AppId FROM @Apps)
            SET @Changed=1;
        UPDATE Portal.UserCardApplications SET Active=0,LastChangeAt=GETDATE()
        WHERE UserCardId=@UserCardId AND Active=1 AND AppId NOT IN(SELECT AppId FROM @Apps);
        UPDATE m SET Active=1,LastChangeAt=GETDATE() FROM Portal.UserCardApplications m JOIN @Apps i ON i.AppId=m.AppId
        WHERE m.UserCardId=@UserCardId AND m.Active=0;
        INSERT Portal.UserCardApplications(UserCardId,AppId)
        SELECT @UserCardId,i.AppId FROM @Apps i WHERE NOT EXISTS(SELECT 1 FROM Portal.UserCardApplications m WHERE m.UserCardId=@UserCardId AND m.AppId=i.AppId);
        IF @Changed=1 UPDATE Portal.UserCards SET CardName=LTRIM(RTRIM(@CardName)),LastChangeAt=GETDATE() WHERE UserCardId=@UserCardId;
        COMMIT TRANSACTION;
        SELECT @UserCardId AS UserCardId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCards_delete
    @UserId int,
    @UserCardId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM Portal.UserCards WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND UserCardId=@UserCardId AND Active=1)
            THROW 50008,'Card not found.',1;
        UPDATE Portal.UserCards SET Active=0,LastChangeAt=GETDATE() WHERE UserId=@UserId AND UserCardId=@UserCardId;
        UPDATE Portal.UserCardApplications SET Active=0,LastChangeAt=GETDATE() WHERE UserCardId=@UserCardId AND Active=1;
        UPDATE Portal.UserWorkspaceOrder SET Active=0,LastChangeAt=GETDATE()
        WHERE UserId=@UserId AND CardKey=N'custom-'+CONVERT(nvarchar(20),@UserCardId) AND Active=1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MasterCount int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1);
    IF EXISTS(SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND DisplayOrder>@MasterCount)
        THROW 50005,'Configure fixed positions within the master card count.',1;
    ;WITH Definitions AS
    (
        SELECT c.CardKey,c.CardName,c.IsFixed,c.DisplayOrder,CAST(0 AS bit) AS IsCustom,CAST(NULL AS int) AS UserCardId
        FROM [Master].Cards c WHERE c.Active=1
        UNION ALL
        SELECT N'custom-'+CONVERT(nvarchar(20),c.UserCardId),c.CardName,CAST(0 AS bit),
          CONVERT(int,@MasterCount+ROW_NUMBER() OVER(ORDER BY c.UserCardId)),CAST(1 AS bit),c.UserCardId
        FROM Portal.UserCards c WHERE c.UserId=@UserId AND c.Active=1
    ), Base AS
    (
        SELECT d.*,s.SortOrder,CAST(CASE WHEN s.UserWorkspaceOrderId IS NULL THEN 0 ELSE 1 END AS bit) AS IsSaved,s.LastChangeAt
        FROM Definitions d LEFT JOIN Portal.UserWorkspaceOrder s ON s.CardKey=d.CardKey AND s.UserId=@UserId AND s.Active=1
    ), Slots AS
    (
        SELECT ROW_NUMBER() OVER(ORDER BY CardKey)-1 AS Position FROM Base
    ), FreeSlots AS
    (
        SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) AS RowNumber FROM Slots p
        WHERE NOT EXISTS(SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=p.Position+1)
    ), Movable AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY IsSaved DESC,SortOrder,DisplayOrder,CardKey) AS RowNumber FROM Base WHERE IsFixed=0
    ), Resolved AS
    (
        SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt,DisplayOrder-1 AS Position FROM Base WHERE IsFixed=1
        UNION ALL
        SELECT m.CardKey,m.CardName,m.IsFixed,m.DisplayOrder,m.IsCustom,m.UserCardId,m.IsSaved,m.LastChangeAt,p.Position
        FROM Movable m JOIN FreeSlots p ON p.RowNumber=m.RowNumber
    )
    SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt FROM Resolved ORDER BY Position;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_set
    @UserId int,
    @Cards Portal.CardOrderInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF (SELECT COUNT(*) FROM @Cards) NOT BETWEEN 1 AND 200
       OR EXISTS(SELECT 1 FROM @Cards WHERE SortOrder<0)
       OR (SELECT MIN(SortOrder) FROM @Cards)<>0
       OR (SELECT MAX(SortOrder) FROM @Cards)<>(SELECT COUNT(*)-1 FROM @Cards)
        THROW 50004,'Supply unique card keys with consecutive positions.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Valid TABLE(CardKey nvarchar(100) PRIMARY KEY,IsFixed bit,DisplayOrder int);
        INSERT @Valid SELECT CardKey,IsFixed,DisplayOrder FROM [Master].Cards WITH(HOLDLOCK) WHERE Active=1;
        INSERT @Valid SELECT N'custom-'+CONVERT(nvarchar(20),UserCardId),0,0
        FROM Portal.UserCards WITH(HOLDLOCK) WHERE UserId=@UserId AND Active=1;
        IF (SELECT COUNT(*) FROM @Valid)<>(SELECT COUNT(*) FROM @Cards)
           OR EXISTS(SELECT 1 FROM @Cards i LEFT JOIN @Valid v ON v.CardKey=i.CardKey WHERE v.CardKey IS NULL)
            THROW 50004,'Supply only the current master cards and your own active custom cards.',1;
        IF EXISTS(SELECT 1 FROM @Cards i JOIN @Valid v ON v.CardKey=i.CardKey WHERE v.IsFixed=1 AND i.SortOrder<>v.DisplayOrder-1)
            THROW 50004,'A fixed card cannot change position.',1;
        DECLARE @Existing int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId);
        UPDATE s SET SortOrder=i.SortOrder,Active=1,LastChangeAt=GETDATE()
        FROM Portal.UserWorkspaceOrder s JOIN @Cards i ON i.CardKey=s.CardKey
        WHERE s.UserId=@UserId AND (s.SortOrder<>i.SortOrder OR s.Active=0);
        INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
        SELECT @UserId,i.CardKey,i.SortOrder FROM @Cards i
        WHERE NOT EXISTS(SELECT 1 FROM Portal.UserWorkspaceOrder s WHERE s.UserId=@UserId AND s.CardKey=i.CardKey);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

GO


-- BEGIN 011_UserCardNameComparison.sql
-- Preserve case-only display-name edits while retaining no-op timestamp behavior.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE Portal.UserCards_save
    @UserId int,
    @CardName nvarchar(200),
    @Apps Portal.AppIdInput READONLY,
    @UserCardId int=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CardName IS NULL OR LEN(LTRIM(RTRIM(@CardName)))=0
       OR (SELECT COUNT(*) FROM @Apps) NOT BETWEEN 1 AND 100
        THROW 50007,'Supply a name and at least one authorized application.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Count int=(SELECT COUNT(*) FROM Portal.UserCards WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND Active=1);
        IF @UserCardId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND UserId=@UserId AND Active=1)
            THROW 50008,'Card not found.',1;
        IF @UserCardId IS NULL AND @Count>=50 THROW 50009,'The custom card limit is 50.',1;
        DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
        INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
        IF EXISTS(SELECT 1 FROM @Apps i LEFT JOIN @Allowed a ON a.AppId=i.AppId WHERE a.AppId IS NULL)
            THROW 50007,'One or more applications are not authorized.',1;
        DECLARE @Changed bit=0;
        IF @UserCardId IS NULL
        BEGIN
            INSERT Portal.UserCards(UserId,CardName) VALUES(@UserId,LTRIM(RTRIM(@CardName)));
            SET @UserCardId=CONVERT(int,SCOPE_IDENTITY());
            DECLARE @Existing int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND Active=1);
            IF @Existing=0
                INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
                SELECT @UserId,CardKey,ROW_NUMBER() OVER(ORDER BY DisplayOrder,CardId)-1 FROM [Master].Cards WHERE Active=1;
            DECLARE @Position int=(SELECT ISNULL(MAX(SortOrder),-1)+1 FROM Portal.UserWorkspaceOrder WHERE UserId=@UserId AND Active=1);
            INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
            VALUES(@UserId,N'custom-'+CONVERT(nvarchar(20),@UserCardId),@Position);
        END;
        IF EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND CardName COLLATE Latin1_General_100_BIN2<>LTRIM(RTRIM(@CardName)) COLLATE Latin1_General_100_BIN2)
           OR EXISTS(SELECT AppId FROM @Apps EXCEPT SELECT AppId FROM Portal.UserCardApplications WHERE UserCardId=@UserCardId AND Active=1)
           OR EXISTS(SELECT AppId FROM Portal.UserCardApplications WHERE UserCardId=@UserCardId AND Active=1 EXCEPT SELECT AppId FROM @Apps)
            SET @Changed=1;
        UPDATE Portal.UserCardApplications SET Active=0,LastChangeAt=GETDATE()
        WHERE UserCardId=@UserCardId AND Active=1 AND AppId NOT IN(SELECT AppId FROM @Apps);
        UPDATE m SET Active=1,LastChangeAt=GETDATE() FROM Portal.UserCardApplications m JOIN @Apps i ON i.AppId=m.AppId
        WHERE m.UserCardId=@UserCardId AND m.Active=0;
        INSERT Portal.UserCardApplications(UserCardId,AppId)
        SELECT @UserCardId,i.AppId FROM @Apps i WHERE NOT EXISTS(SELECT 1 FROM Portal.UserCardApplications m WHERE m.UserCardId=@UserCardId AND m.AppId=i.AppId);
        IF @Changed=1 UPDATE Portal.UserCards SET CardName=LTRIM(RTRIM(@CardName)),LastChangeAt=GETDATE() WHERE UserCardId=@UserCardId;
        COMMIT TRANSACTION;
        SELECT @UserCardId AS UserCardId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

GO


-- BEGIN 012_MasterCardAdministration.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_get
AS
BEGIN
 SET NOCOUNT ON;
 SELECT CardId,CardKey,CardName,DisplayOrder,IsFixed,LastChangeAt
 FROM [Master].Cards WHERE Active=1 ORDER BY DisplayOrder,CardId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_save
 @CardId int,
 @CardName nvarchar(200),
 @IsFixed bit,
 @DisplayOrder int
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET ARITHABORT ON;
 SET NUMERIC_ROUNDABORT OFF;
 SET @CardName=LTRIM(RTRIM(@CardName));
 IF @CardName IS NULL OR LEN(@CardName)=0
  THROW 50006,'Supply a card name.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Reuse the existing locked policy validation, including fixed-slot conflicts.
  EXEC [Master].Cards_setPosition @CardId,@IsFixed,@DisplayOrder;
  UPDATE [Master].Cards SET CardName=@CardName,LastChangeAt=GETDATE()
  WHERE CardId=@CardId AND CardName COLLATE Latin1_General_100_BIN2<>@CardName COLLATE Latin1_General_100_BIN2;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

GO


-- BEGIN 013_NewsRead.sql
USE [CompanyPortal];
GO
IF SCHEMA_ID(N'News') IS NULL EXEC(N'CREATE SCHEMA News');
GO
-- dbo.VNews is an integration prerequisite, owned by the existing news system.
-- This script never creates/replaces that view or writes to Pubs_Info_V4.
CREATE OR ALTER PROCEDURE News.Items_get
 @Page int=1,
 @PageSize int=8,
 @NewsId bigint=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @Page<1 OR @Page>1000000 OR @PageSize<1 OR @PageSize>50
  THROW 50011,'Invalid news page.',1;
 -- Filter news independently of attachment activity: a missing attachment must not
 -- remove an otherwise published item from this left-joined source.
 ;WITH Source AS (
  SELECT TRY_CONVERT(bigint,PIN_ID) AS NewsId,
   TRY_CONVERT(datetime,PIN_Date) AS PublishedAt,
   CONVERT(nvarchar(4000),PIN_Subject) AS Subject,
   NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(4000),PIN_PicturePath))),N'') AS PicturePath,
   COALESCE(TRY_CONVERT(int,PIN_IsImportant),0) AS IsImportant,
   CASE WHEN TRY_CONVERT(bit,ATT_Active)=1
     AND LOWER(RIGHT(RTRIM(CONVERT(nvarchar(4000),ATT_File_Path)),4))=N'.pdf'
    THEN NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(4000),ATT_File_Path))),N'') END AS PdfPath
  FROM dbo.VNews
  WHERE TRY_CONVERT(bit,PIN_Publish)=1 AND TRY_CONVERT(bit,PIN_Active)=1 AND TRY_CONVERT(bit,PIN_Portal)=1
   AND (@NewsId IS NULL OR TRY_CONVERT(bigint,PIN_ID)=@NewsId)
 )
 SELECT NewsId,MAX(PublishedAt) AS PublishedAt,MAX(Subject) AS Subject,
  CAST(MAX(CASE WHEN IsImportant<>0 THEN 1 ELSE 0 END) AS bit) AS IsImportant,
  CASE WHEN COUNT(DISTINCT PicturePath)=1 THEN MAX(PicturePath) END AS PicturePath,
  CASE WHEN COUNT(DISTINCT PdfPath)=1 THEN MAX(PdfPath) END AS PdfPath,
  CAST(CASE WHEN COUNT(DISTINCT PdfPath)>1 THEN 1 ELSE 0 END AS bit) AS AttachmentConflict
 INTO #Items FROM Source WHERE NewsId>0 GROUP BY NewsId;
 SELECT NewsId,PublishedAt,Subject,IsImportant,PicturePath,PdfPath,AttachmentConflict FROM #Items
 ORDER BY PublishedAt DESC,NewsId DESC
 OFFSET (CONVERT(bigint,@Page)-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
 SELECT COUNT(*) AS TotalCount FROM #Items;
END;
GO

GO


-- BEGIN 014_UtilityFolderPaths.sql
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF SCHEMA_ID(N'Mstr') IS NULL EXEC(N'CREATE SCHEMA Mstr');
IF OBJECT_ID(N'Mstr.Utls',N'U') IS NULL
BEGIN
 CREATE TABLE Mstr.Utls (
  UtlsId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Utls PRIMARY KEY,
  [Key] nvarchar(200) NOT NULL,
  strVal nvarchar(4000) NOT NULL,
  Active bit NOT NULL CONSTRAINT DF_Utls_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_Utls_LastChangeAt DEFAULT(GETDATE())
 );
END;
COMMIT;
GO
CREATE OR ALTER PROCEDURE Mstr.Utls_GetFolderPaths
AS
BEGIN
 SET NOCOUNT ON;
 SELECT [Key],strVal AS [Path]
 FROM Mstr.Utls
 WHERE Active=1
 ORDER BY UtlsId;
END;
GO

GO


-- BEGIN 015_InterfaceImages.sql
USE [CompanyPortal];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Master.Images', N'U') IS NULL
CREATE TABLE [Master].Images (
    ImageId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Images PRIMARY KEY,
    ImageName nvarchar(200) NOT NULL,
    ContentType nvarchar(100) NOT NULL,
    ImageData varbinary(max) NOT NULL,
    PixelWidth int NOT NULL,
    PixelHeight int NOT NULL,
    Active bit NOT NULL CONSTRAINT DF_Images_Active DEFAULT (1),
    LastChangeAt datetime NOT NULL CONSTRAINT DF_Images_LastChangeAt DEFAULT (GETDATE()),
    CONSTRAINT CK_Images_Size CHECK (DATALENGTH(ImageData) BETWEEN 1 AND 10485760),
    CONSTRAINT CK_Images_Dimensions CHECK (PixelWidth BETWEEN 1 AND 12000 AND PixelHeight BETWEEN 1 AND 12000),
    CONSTRAINT CK_Images_Type CHECK (ContentType IN (N'image/jpeg',N'image/png',N'image/webp',N'image/svg+xml'))
);
IF OBJECT_ID(N'Master.ImageGroups', N'U') IS NULL
CREATE TABLE [Master].ImageGroups (
    ImageGroupId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImageGroups PRIMARY KEY,
    GroupName nvarchar(200) NOT NULL,
    RotateImages bit NOT NULL CONSTRAINT DF_ImageGroups_Rotate DEFAULT (1),
    RotationSeconds int NOT NULL CONSTRAINT DF_ImageGroups_Seconds DEFAULT (8),
    DefaultImageId int NULL CONSTRAINT FK_ImageGroups_Default REFERENCES [Master].Images(ImageId),
    Active bit NOT NULL CONSTRAINT DF_ImageGroups_Active DEFAULT (1),
    LastChangeAt datetime NOT NULL CONSTRAINT DF_ImageGroups_LastChangeAt DEFAULT (GETDATE()),
    CONSTRAINT CK_ImageGroups_Seconds CHECK (RotationSeconds BETWEEN 3 AND 3600)
);
IF OBJECT_ID(N'Master.ImageGroupItems', N'U') IS NULL
CREATE TABLE [Master].ImageGroupItems (
    ImageGroupItemId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImageGroupItems PRIMARY KEY,
    ImageGroupId int NOT NULL CONSTRAINT FK_ImageGroupItems_Group REFERENCES [Master].ImageGroups(ImageGroupId),
    ImageId int NOT NULL CONSTRAINT FK_ImageGroupItems_Image REFERENCES [Master].Images(ImageId),
    DisplayOrder int NOT NULL,
    Active bit NOT NULL CONSTRAINT DF_ImageGroupItems_Active DEFAULT (1),
    LastChangeAt datetime NOT NULL CONSTRAINT DF_ImageGroupItems_LastChangeAt DEFAULT (GETDATE()),
    CONSTRAINT UQ_ImageGroupItems UNIQUE(ImageGroupId,ImageId),
    CONSTRAINT CK_ImageGroupItems_Order CHECK (DisplayOrder > 0)
);
IF COL_LENGTH(N'Master.Themes', N'ImageGroupId') IS NULL
    ALTER TABLE [Master].Themes ADD ImageGroupId int NULL CONSTRAINT FK_Themes_ImageGroups REFERENCES [Master].ImageGroups(ImageGroupId);
IF TYPE_ID(N'Master.ImageSelection') IS NULL
    EXEC(N'CREATE TYPE [Master].ImageSelection AS TABLE(ImageId int NOT NULL PRIMARY KEY, DisplayOrder int NOT NULL UNIQUE, Active bit NOT NULL);');
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Images_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageId,ImageName,ContentType,PixelWidth,PixelHeight,DATALENGTH(ImageData) ByteLength,LastChangeAt
 FROM [Master].Images WHERE Active=1 ORDER BY ImageId DESC;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_add
 @ImageName nvarchar(200), @ContentType nvarchar(100), @ImageData varbinary(max), @PixelWidth int, @PixelHeight int
AS
BEGIN
 SET NOCOUNT ON;
 IF LEN(LTRIM(RTRIM(@ImageName)))=0 THROW 50007,'Image name is required.',1;
 INSERT [Master].Images(ImageName,ContentType,ImageData,PixelWidth,PixelHeight)
 VALUES(@ImageName,@ContentType,@ImageData,@PixelWidth,@PixelHeight);
 SELECT CAST(SCOPE_IDENTITY() AS int);
END;
GO
CREATE OR ALTER PROCEDURE [Master].ImageGroups_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageGroupId,GroupName,RotateImages,RotationSeconds,DefaultImageId,Active,LastChangeAt FROM [Master].ImageGroups ORDER BY ImageGroupId;
 SELECT ImageGroupId,ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems ORDER BY ImageGroupId,DisplayOrder,ImageId;
 SELECT ThemeId,ThemeName,LayoutKey,ImageGroupId FROM [Master].Themes WHERE Active=1 ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].ImageGroups_save
 @ImageGroupId int=NULL, @GroupName nvarchar(200), @RotateImages bit, @RotationSeconds int,
 @DefaultImageId int=NULL, @Active bit, @Items [Master].ImageSelection READONLY
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 IF LEN(LTRIM(RTRIM(@GroupName)))=0 OR @RotationSeconds NOT BETWEEN 3 AND 3600 OR (SELECT COUNT(*) FROM @Items)>100
    THROW 50007,'Invalid image group.',1;
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN [Master].Images m WITH(HOLDLOCK) ON i.ImageId=m.ImageId AND m.Active=1 WHERE m.ImageId IS NULL OR i.DisplayOrder<1)
    THROW 50007,'Select active images and valid positions.',1;
 IF @DefaultImageId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Items WHERE ImageId=@DefaultImageId AND Active=1)
    THROW 50007,'Default image must be an active member.',1;
 IF @ImageGroupId IS NULL
 BEGIN
   INSERT [Master].ImageGroups(GroupName,RotateImages,RotationSeconds,DefaultImageId,Active)
   VALUES(@GroupName,@RotateImages,@RotationSeconds,@DefaultImageId,@Active);
   SET @ImageGroupId=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 BEGIN
   IF NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(UPDLOCK,HOLDLOCK) WHERE ImageGroupId=@ImageGroupId)
      THROW 50007,'Image group was not found.',1;
   DECLARE @Changed bit=0;
   IF EXISTS(SELECT @GroupName COLLATE Latin1_General_100_BIN2,@RotateImages,@RotationSeconds,@DefaultImageId,@Active
      EXCEPT SELECT GroupName COLLATE Latin1_General_100_BIN2,RotateImages,RotationSeconds,DefaultImageId,Active FROM [Master].ImageGroups WHERE ImageGroupId=@ImageGroupId)
      OR EXISTS(SELECT ImageId,DisplayOrder,Active FROM @Items EXCEPT SELECT ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems WHERE ImageGroupId=@ImageGroupId)
      OR EXISTS(SELECT ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems WHERE ImageGroupId=@ImageGroupId EXCEPT SELECT ImageId,DisplayOrder,Active FROM @Items)
      SET @Changed=1;
   UPDATE [Master].ImageGroups WITH(UPDLOCK) SET GroupName=@GroupName,RotateImages=@RotateImages,RotationSeconds=@RotationSeconds,
     DefaultImageId=@DefaultImageId,Active=@Active,LastChangeAt=CASE WHEN @Changed=1 THEN GETDATE() ELSE LastChangeAt END WHERE ImageGroupId=@ImageGroupId;
 END;
 -- Removing a membership does not remove its reusable image.
 DELETE m FROM [Master].ImageGroupItems m
 WHERE m.ImageGroupId=@ImageGroupId AND NOT EXISTS(SELECT 1 FROM @Items i WHERE i.ImageId=m.ImageId);
 UPDATE m SET DisplayOrder=i.DisplayOrder,Active=i.Active,LastChangeAt=GETDATE()
 FROM [Master].ImageGroupItems m JOIN @Items i ON i.ImageId=m.ImageId WHERE m.ImageGroupId=@ImageGroupId AND (m.DisplayOrder<>i.DisplayOrder OR m.Active<>i.Active);
 INSERT [Master].ImageGroupItems(ImageGroupId,ImageId,DisplayOrder,Active)
 SELECT @ImageGroupId,i.ImageId,i.DisplayOrder,i.Active FROM @Items i
 WHERE NOT EXISTS(SELECT 1 FROM [Master].ImageGroupItems m WHERE m.ImageGroupId=@ImageGroupId AND m.ImageId=i.ImageId);
 COMMIT;
 SELECT @ImageGroupId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_setImageGroup @ThemeId int,@ImageGroupId int=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Select an active image group.',1; END;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Theme was not found.',1; END;
 UPDATE [Master].Themes SET ImageGroupId=@ImageGroupId,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND Active=1 AND ISNULL(ImageGroupId,0)<>ISNULL(@ImageGroupId,0);
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getImages @ThemeId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT g.ImageGroupId,g.RotateImages,g.RotationSeconds,g.DefaultImageId
 FROM [Master].Themes t JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1 WHERE t.ThemeId=@ThemeId AND t.Active=1;
 SELECT i.ImageId,i.ImageName,m.DisplayOrder FROM [Master].Themes t
 JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].ImageGroupItems m ON g.ImageGroupId=m.ImageGroupId AND m.Active=1
 JOIN [Master].Images i ON m.ImageId=i.ImageId AND i.Active=1
 WHERE t.ThemeId=@ThemeId AND t.Active=1 ORDER BY m.DisplayOrder,i.ImageId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_getContent @ImageId int,@IsAdmin bit AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageData,ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1));
END;
GO

GO


-- BEGIN 016_ThemeAdministration.sql
USE [CompanyPortal];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'Master.Themes',N'PrimaryColor') IS NULL
BEGIN
 ALTER TABLE [Master].Themes ADD
 PrimaryColor nvarchar(7) NULL, AccentColor nvarchar(7) NULL, BackgroundColor nvarchar(7) NULL,
 OverlayOpacity int NULL, ForegroundPreset nvarchar(10) NULL,
 ImagePresentation nvarchar(20) NOT NULL CONSTRAINT DF_Themes_ImagePresentation DEFAULT(N'background');
 EXEC(N'ALTER TABLE [Master].Themes ADD
 CONSTRAINT CK_Themes_Overlay CHECK(OverlayOpacity IS NULL OR OverlayOpacity BETWEEN 0 AND 85),
 CONSTRAINT CK_Themes_Foreground CHECK(ForegroundPreset IS NULL OR ForegroundPreset IN(N''light'',N''dark'')),
 CONSTRAINT CK_Themes_Presentation CHECK(ImagePresentation IN(N''background'',N''artwork'')),
 CONSTRAINT CK_Themes_Colors CHECK(
 (PrimaryColor IS NULL OR (LEN(PrimaryColor)=7 AND PrimaryColor COLLATE Latin1_General_100_BIN2 LIKE N''#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'')) AND
 (AccentColor IS NULL OR (LEN(AccentColor)=7 AND AccentColor COLLATE Latin1_General_100_BIN2 LIKE N''#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'')) AND
 (BackgroundColor IS NULL OR (LEN(BackgroundColor)=7 AND BackgroundColor COLLATE Latin1_General_100_BIN2 LIKE N''#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'')));');
END;
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId
 FROM [Master].Themes WHERE Active=1 ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getForAdministration AS
BEGIN
 SET NOCOUNT ON;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,Active,LastChangeAt,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId
 FROM [Master].Themes ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 -- Serialize catalog writes, including changes to the single default.
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF LEN(LTRIM(RTRIM(@ThemeName)))=0 OR @DisplayOrder<0 OR @LayoutKey NOT IN(N'official',N'work',N'national-day') OR (@IsDefault=1 AND @Active=0)
 THROW 50008,'Check the theme details.',1;
 IF @ThemeId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId)
 THROW 50008,'Theme not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) AND (@IsDefault=0 OR @Active=0)
 THROW 50008,'Choose another default before disabling this default.',1;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 THROW 50008,'Choose an active image group.',1;
 IF @IsDefault=1
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId);
 IF @ThemeId IS NULL
 BEGIN
 INSERT [Master].Themes(ThemeName,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId)
 VALUES(@ThemeName,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId);
 SET @ThemeId=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 UPDATE [Master].Themes SET ThemeName=@ThemeName,LayoutKey=@LayoutKey,DisplayOrder=@DisplayOrder,Active=@Active,IsDefault=@IsDefault,
 PrimaryColor=@PrimaryColor,AccentColor=@AccentColor,BackgroundColor=@BackgroundColor,OverlayOpacity=@OverlayOpacity,ForegroundPreset=@ForegroundPreset,ImagePresentation=@ImagePresentation,ImageGroupId=@ImageGroupId,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND EXISTS(
 SELECT @ThemeName COLLATE Latin1_General_100_BIN2,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId
 EXCEPT SELECT ThemeName COLLATE Latin1_General_100_BIN2,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId FROM [Master].Themes WHERE ThemeId=@ThemeId);
 IF (SELECT COUNT(*) FROM [Master].Themes WHERE Active=1 AND IsDefault=1)<>1 THROW 50008,'Exactly one active default is required.',1;
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO

GO


-- BEGIN 017_ImageDeletion.sql
USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE [Master].Images_delete @ImageId int
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM [Master].Images WITH(UPDLOCK,HOLDLOCK) WHERE ImageId=@ImageId AND Active=1)
 BEGIN COMMIT; SELECT CAST(0 AS bit); RETURN; END;
 IF EXISTS(SELECT 1 FROM [Master].ImageGroupItems WHERE ImageId=@ImageId)
 OR EXISTS(SELECT 1 FROM [Master].ImageGroups WHERE DefaultImageId=@ImageId)
 BEGIN ROLLBACK; THROW 50009,'Remove the image from saved groups before deleting it.',1; END;
 UPDATE [Master].Images SET Active=0,LastChangeAt=GETDATE() WHERE ImageId=@ImageId;
 COMMIT;
 SELECT CAST(1 AS bit);
END;
GO

GO


-- BEGIN 018_ThemePublication.sql
USE [CompanyPortal];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'Master.Themes',N'Visibility') IS NULL
BEGIN
 ALTER TABLE [Master].Themes ADD Visibility nvarchar(20) NOT NULL CONSTRAINT DF_Themes_Visibility DEFAULT(N'public'),
 Deleted bit NOT NULL CONSTRAINT DF_Themes_Deleted DEFAULT(0);
 EXEC(N'UPDATE [Master].Themes SET Visibility=N''hidden'' WHERE Active=0;
 ALTER TABLE [Master].Themes ADD CONSTRAINT CK_Themes_Visibility CHECK(Visibility IN(N''hidden'',N''preview'',N''public'')),
 CONSTRAINT CK_Themes_PublicDefault CHECK(IsDefault=0 OR (Active=1 AND Deleted=0 AND Visibility=N''public''));');
END;
IF OBJECT_ID(N'Master.ThemePreviewRoles',N'U') IS NULL
CREATE TABLE [Master].ThemePreviewRoles(
 ThemePreviewRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ThemePreviewRoles PRIMARY KEY,
 ThemeId int NOT NULL CONSTRAINT FK_ThemePreviewRoles_Theme REFERENCES [Master].Themes(ThemeId),
 RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Active bit NOT NULL CONSTRAINT DF_ThemePreviewRoles_Active DEFAULT(1),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_ThemePreviewRoles_LastChangeAt DEFAULT(GETDATE()),
 CONSTRAINT UQ_ThemePreviewRoles UNIQUE(ThemeId,RoleName)
);
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getAll @UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId
 FROM [Master].Themes t WHERE t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))) ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getForAdministration AS
BEGIN
 SET NOCOUNT ON;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,Active,LastChangeAt,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId,Visibility,
 COALESCE((SELECT RoleName FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=t.ThemeId AND r.Active=1 ORDER BY RoleName FOR JSON PATH),N'[]') PreviewRolesJson
 FROM [Master].Themes t WHERE Deleted=0 ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL,@Visibility nvarchar(20)=NULL,@PreviewRolesJson nvarchar(max)=N'[]'
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 SET @Visibility=CASE WHEN @Active=0 THEN N'hidden' ELSE COALESCE(@Visibility,N'public') END;
 IF @Visibility NOT IN(N'hidden',N'preview',N'public') OR (@Active=1 AND @Visibility=N'hidden') OR (@IsDefault=1 AND @Visibility<>N'public')
 THROW 50008,'Default must be live for everyone.',1;
 IF ISJSON(@PreviewRolesJson)<>1 OR LEFT(LTRIM(@PreviewRolesJson),1)<>N'[' THROW 50008,'Invalid roles.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@PreviewRolesJson))>50 OR EXISTS(SELECT 1 FROM OPENJSON(@PreviewRolesJson) WHERE [type]<>1 OR LEN(LTRIM(RTRIM(value))) NOT BETWEEN 1 AND 200)
 THROW 50008,'Enter up to 50 role names.',1;
 DECLARE @SelectedRoles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 INSERT @SelectedRoles SELECT DISTINCT LTRIM(RTRIM(value)) COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@PreviewRolesJson);
 IF @Visibility=N'preview' AND NOT EXISTS(SELECT 1 FROM @SelectedRoles) THROW 50008,'Choose preview roles.',1;
 BEGIN TRANSACTION;
 -- Serialize catalog writes, including changes to the single default.
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF LEN(LTRIM(RTRIM(@ThemeName)))=0 OR @DisplayOrder<0 OR @LayoutKey NOT IN(N'official',N'work',N'national-day') OR (@IsDefault=1 AND @Active=0)
 THROW 50008,'Check the theme details.',1;
 IF @ThemeId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId AND Deleted=0)
 THROW 50008,'Theme not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) AND (@IsDefault=0 OR @Active=0 OR @Visibility<>N'public')
 THROW 50008,'Choose another default before disabling this default.',1;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 THROW 50008,'Choose an active image group.',1;
 DECLARE @ApplyToAll bit=CASE WHEN @IsDefault=1 AND NOT EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) THEN 1 ELSE 0 END;
 IF @IsDefault=1
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId);
 IF @ThemeId IS NULL
 BEGIN
 INSERT [Master].Themes(ThemeName,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId,Visibility)
 VALUES(@ThemeName,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId,@Visibility);
 SET @ThemeId=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 UPDATE [Master].Themes SET ThemeName=@ThemeName,LayoutKey=@LayoutKey,DisplayOrder=@DisplayOrder,Active=@Active,IsDefault=@IsDefault,
 PrimaryColor=@PrimaryColor,AccentColor=@AccentColor,BackgroundColor=@BackgroundColor,OverlayOpacity=@OverlayOpacity,ForegroundPreset=@ForegroundPreset,ImagePresentation=@ImagePresentation,ImageGroupId=@ImageGroupId,Visibility=@Visibility,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND EXISTS(
 SELECT @ThemeName COLLATE Latin1_General_100_BIN2,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId,@Visibility
 EXCEPT SELECT ThemeName COLLATE Latin1_General_100_BIN2,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId,Visibility FROM [Master].Themes WHERE ThemeId=@ThemeId);
 IF EXISTS(SELECT RoleName FROM @SelectedRoles EXCEPT SELECT RoleName FROM [Master].ThemePreviewRoles WHERE ThemeId=@ThemeId AND Active=1)
 OR EXISTS(SELECT RoleName FROM [Master].ThemePreviewRoles WHERE ThemeId=@ThemeId AND Active=1 EXCEPT SELECT RoleName FROM @SelectedRoles)
 BEGIN
  UPDATE [Master].Themes SET LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId;
  UPDATE r SET Active=CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
  FROM [Master].ThemePreviewRoles r LEFT JOIN @SelectedRoles s ON r.RoleName=s.RoleName
  WHERE r.ThemeId=@ThemeId AND r.Active<>CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END;
  INSERT [Master].ThemePreviewRoles(ThemeId,RoleName) SELECT @ThemeId,s.RoleName FROM @SelectedRoles s
  WHERE NOT EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=@ThemeId AND r.RoleName=s.RoleName);
 END;
 IF @ApplyToAll=1 UPDATE Portal.UserSettings SET ThemeId=@ThemeId,LastChangeAt=GETDATE() WHERE Active=1 AND ThemeId<>@ThemeId;
 IF (SELECT COUNT(*) FROM [Master].Themes WHERE Active=1 AND IsDefault=1)<>1 THROW 50008,'Exactly one active default is required.',1;
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_delete @ThemeId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) THROW 50008,'Choose another default first.',1;
 UPDATE [Master].Themes SET Deleted=1,Active=0,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND Deleted=0;
 DECLARE @Found bit=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
 COMMIT; SELECT @Found;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_applyToAll @ThemeId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND Active=1 AND Deleted=0 AND Visibility=N'public')
 THROW 50008,'Only live public themes can be applied to everyone.',1;
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND ThemeId<>@ThemeId;
 UPDATE [Master].Themes SET IsDefault=1,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND IsDefault=0;
 UPDATE Portal.UserSettings SET ThemeId=@ThemeId,LastChangeAt=GETDATE() WHERE Active=1 AND ThemeId<>@ThemeId;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_getTheme @UserId int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT TOP(1) t.ThemeId,t.ThemeName,t.LayoutKey,CAST(CASE WHEN s.UserSettingId IS NOT NULL THEN 1 ELSE 0 END AS bit) IsSaved,s.LastChangeAt
 FROM [Master].Themes t
 LEFT JOIN Portal.UserSettings s ON s.ThemeId=t.ThemeId AND s.UserId=@UserId AND s.Active=1
 WHERE t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))) AND (s.UserSettingId IS NOT NULL OR t.IsDefault=1)
 ORDER BY CASE WHEN s.UserSettingId IS NOT NULL THEN 0 ELSE 1 END;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_setTheme @UserId int,@ThemeId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes t WITH(HOLDLOCK) WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))))
 THROW 50002,'Select an available theme.',1;
 UPDATE Portal.UserSettings WITH(UPDLOCK,SERIALIZABLE)
 SET LastChangeAt=CASE WHEN ThemeId<>@ThemeId OR Active=0 THEN GETDATE() ELSE LastChangeAt END,ThemeId=@ThemeId,Active=1 WHERE UserId=@UserId;
 IF @@ROWCOUNT=0 INSERT Portal.UserSettings(UserId,ThemeId) VALUES(@UserId,@ThemeId);
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getImages @ThemeId int,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT g.ImageGroupId,g.RotateImages,g.RotationSeconds,g.DefaultImageId
 FROM [Master].Themes t JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1 WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)));
 SELECT i.ImageId,i.ImageName,m.DisplayOrder FROM [Master].Themes t
 JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].ImageGroupItems m ON g.ImageGroupId=m.ImageGroupId AND m.Active=1
 JOIN [Master].Images i ON m.ImageId=i.ImageId AND i.Active=1
 WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))) ORDER BY m.DisplayOrder,i.ImageId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_getContent @ImageId int,@IsAdmin bit,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT ImageData,ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1 AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)))));
END;
GO

GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- DEVELOPMENT ONLY. Never run this against the real internal security database.
USE [master];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
IF DB_ID(N''SecurityDB'') IS NULL
    EXEC(N''CREATE DATABASE [SecurityDB];'');
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
USE [SecurityDB];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
IF OBJECT_ID(N''dbo.Users'', N''U'') IS NULL
BEGIN
    CREATE TABLE dbo.Users
    (
        UserId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        NTName nvarchar(512) NOT NULL CONSTRAINT UQ_Users_NTName UNIQUE,
        Active bit NOT NULL CONSTRAINT DF_Users_Active DEFAULT (1),
        CreatedAt datetime NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (GETDATE())
    );
END;
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
-- This script must be run with the same development Windows account used in the browser.
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE NTName = (SELECT TestNTName FROM #PortalDeployment))
    INSERT dbo.Users (NTName) VALUES ((SELECT TestNTName FROM #PortalDeployment));
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- DEVELOPMENT ONLY. Do not run against the real internal security database.
USE [SecurityDB];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N''dbo.Applications'',N''U'') IS NULL
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
      (N''people-demo'',N''الموارد البشرية — تجريبي'',(SELECT PortalUrl+N''#workspace'' FROM #PortalDeployment)),
      (N''support-demo'',N''الدعم الفني — تجريبي'',(SELECT PortalUrl+N''#workspace'' FROM #PortalDeployment)),
      (N''projects-demo'',N''المشاريع — تجريبي'',(SELECT PortalUrl+N''#workspace'' FROM #PortalDeployment)),
      (N''reports-demo'',N''التقارير — غير مصرح في العينة'',(SELECT PortalUrl+N''#workspace'' FROM #PortalDeployment));
END;
IF OBJECT_ID(N''dbo.UserApplicationAccess'',N''U'') IS NULL
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
WHERE u.NTName=(SELECT TestNTName FROM #PortalDeployment) AND u.Active=1
  AND a.AppKey IN(N''people-demo'',N''support-demo'',N''projects-demo'')
  AND NOT EXISTS(SELECT 1 FROM dbo.UserApplicationAccess x WHERE x.UserId=u.UserId AND x.AppId=a.AppId);
COMMIT TRANSACTION;
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- DEVELOPMENT ONLY. Do not deploy these sample grants internally.
USE [SecurityDB];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N''dbo.Roles'',N''U'') IS NULL
CREATE TABLE dbo.Roles (
 RoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
 RoleName nvarchar(200) NOT NULL CONSTRAINT UQ_Roles_Name UNIQUE,
 Active bit NOT NULL CONSTRAINT DF_Roles_Active DEFAULT(1),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_Roles_LastChangeAt DEFAULT(GETDATE())
);
IF OBJECT_ID(N''dbo.UserRoles'',N''U'') IS NULL
CREATE TABLE dbo.UserRoles (
 UserRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserRoles PRIMARY KEY,
 UserId int NOT NULL CONSTRAINT FK_UserRoles_Users REFERENCES dbo.Users(UserId),
 RoleId int NOT NULL CONSTRAINT FK_UserRoles_Roles REFERENCES dbo.Roles(RoleId),
 Active bit NOT NULL CONSTRAINT DF_UserRoles_Active DEFAULT(1),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_UserRoles_LastChangeAt DEFAULT(GETDATE()),
 CONSTRAINT UQ_UserRoles_User_Role UNIQUE(UserId,RoleId)
);
IF NOT EXISTS(SELECT 1 FROM dbo.Roles WHERE RoleName=N''CompanyPortal.Admin'')
 INSERT dbo.Roles(RoleName) VALUES(N''CompanyPortal.Admin'');
-- An explicit development grant to the executing Windows account, never every employee.
INSERT dbo.UserRoles(UserId,RoleId)
SELECT u.UserId,r.RoleId FROM dbo.Users u CROSS JOIN dbo.Roles r
WHERE u.NTName=(SELECT TestNTName FROM #PortalDeployment) AND u.Active=1 AND r.RoleName=N''CompanyPortal.Admin'' AND r.Active=1
AND NOT EXISTS(SELECT 1 FROM dbo.UserRoles x WHERE x.UserId=u.UserId AND x.RoleId=r.RoleId);
COMMIT;
');
GO

USE master;
GO
IF (SELECT TestSources FROM #PortalDeployment)=1
 EXEC(N'CREATE DATABASE Pubs_Info_V4');
GO
IF (SELECT TestSources FROM #PortalDeployment)=1
 EXEC(N'USE Pubs_Info_V4;
 CREATE TABLE dbo.Public_info_News (
  PIN_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  PIN_Date datetime NOT NULL DEFAULT(GETDATE()), PIN_Subject nvarchar(1000) NOT NULL,
  PIN_PicturePath nvarchar(4000) NULL, PIN_Publish bit NOT NULL DEFAULT(1),
  PIN_IsImportant bit NOT NULL DEFAULT(0), PIN_Detailes nvarchar(4000) NULL,
  PIN_Active bit NOT NULL DEFAULT(1), PIN_Portal bit NOT NULL DEFAULT(1));
 CREATE TABLE dbo.Attachment (
  ATT_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  PIN_ID int NOT NULL REFERENCES dbo.Public_info_News(PIN_ID),
  ATT_File_Path nvarchar(4000) NOT NULL, ATT_FileType nvarchar(100) NOT NULL,
  ATT_Active bit NOT NULL DEFAULT(1), ATT_Note nvarchar(1000) NULL);
 CREATE TABLE dbo.Public_info_News_Prodc (
  PIP_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  News_ID int NOT NULL REFERENCES dbo.Public_info_News(PIN_ID), Active bit NOT NULL DEFAULT(1));
 INSERT dbo.Public_info_News(PIN_Subject) VALUES(N''Ø®Ø¨Ø± ØªØ¬Ø±ÙŠØ¨ÙŠ Ù„Ø§Ø®ØªØ¨Ø§Ø± Ø§Ù„Ø¨ÙˆØ§Ø¨Ø©'');
 INSERT dbo.Public_info_News_Prodc(News_ID) VALUES(1);');
GO
USE CompanyPortal;
GO
-- Empty integration view in real-source mode, until the DBA installs the real view.
CREATE OR ALTER VIEW dbo.VNews AS
 SELECT CAST(NULL AS int) PIN_ID, CAST(NULL AS datetime) PIN_Date,
 CAST(NULL AS nvarchar(1000)) PIN_Subject, CAST(NULL AS nvarchar(4000)) PIN_PicturePath,
 CAST(NULL AS bit) PIN_Publish, CAST(NULL AS nvarchar(4000)) ATT_File_Path,
 CAST(NULL AS nvarchar(100)) ATT_FileType, CAST(NULL AS bit) PIN_IsImportant,
 CAST(NULL AS nvarchar(4000)) PIN_Detailes, CAST(NULL AS bit) PIN_Active,
 CAST(NULL AS bit) PIN_Portal, CAST(NULL AS bit) ATT_Active,
 CAST(NULL AS nvarchar(200)) Expr1, CAST(NULL AS int) ATT_ID,
 CAST(NULL AS nvarchar(1000)) ATT_Note, CAST(NULL AS int) PIP_ID WHERE 1=0;
GO
IF (SELECT TestSources FROM #PortalDeployment)=1
 EXEC(N'CREATE OR ALTER VIEW dbo.VNews AS
 SELECT n.*,a.ATT_File_Path,a.ATT_FileType,a.ATT_Active,
 CAST(NULL AS nvarchar(200)) Expr1,a.ATT_ID,a.ATT_Note,p.PIP_ID
 FROM Pubs_Info_V4.dbo.Public_info_News n
 LEFT JOIN Pubs_Info_V4.dbo.Attachment a ON a.PIN_ID=n.PIN_ID
 JOIN Pubs_Info_V4.dbo.Public_info_News_Prodc p ON p.News_ID=n.PIN_ID;');
GO
IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- SAMPLE mapping for the local development SecurityDB only.
-- Adapt this procedure''s SELECT to the real security database before internal deployment.
USE [CompanyPortal];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
CREATE OR ALTER PROCEDURE Security.User_getByUsername
    @Username nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId
    FROM [SecurityDB].[dbo].[Users]
    WHERE NTName = @Username AND Active = 1;
END;
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- SAMPLE mapping only. Replace the SELECT with the approved internal permission source.
USE [CompanyPortal];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
CREATE OR ALTER PROCEDURE Security.Apps_getForUser
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.AppId,a.AppName,a.LaunchUrl
    FROM SecurityDB.dbo.Applications a
    JOIN SecurityDB.dbo.UserApplicationAccess g ON g.AppId=a.AppId AND g.Active=1
    JOIN SecurityDB.dbo.Users u ON u.UserId=g.UserId AND u.Active=1
    WHERE g.UserId=@UserId AND a.Active=1
    ORDER BY a.AppId;
END;
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- SAMPLE ONLY. Replace this SELECT with the real effective-role source internally.
-- Return distinct active RoleName values for @UserId, combining direct and group grants
-- as appropriate. AD group evaluation is not implemented by this sample.
USE [CompanyPortal];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
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
');
GO

-- Grant only the API service identity, never every employee.
USE master;
GO
DECLARE @account nvarchar(512)=(SELECT ApiIdentity FROM #PortalDeployment);
IF @account<>N''
BEGIN
 IF SUSER_ID(@account) IS NULL EXEC(N'CREATE LOGIN '+QUOTENAME(@account)+N' FROM WINDOWS');
 DECLARE @sql nvarchar(max)=N'USE CompanyPortal; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
 EXEC(@sql);
END;
GO
USE CompanyPortal;
GO
DECLARE @account nvarchar(512)=(SELECT ApiIdentity FROM #PortalDeployment), @sql nvarchar(max)=N'';
IF @account<>N''
BEGIN
 SELECT @sql+=N'GRANT EXECUTE ON OBJECT::'+QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N' TO '+QUOTENAME(@account)+N';'
 FROM sys.procedures WHERE SCHEMA_NAME(schema_id) IN(N'Security',N'Portal',N'Master',N'News',N'Mstr');
 SELECT @sql+=N'GRANT EXECUTE, REFERENCES ON TYPE::'+QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N' TO '+QUOTENAME(@account)+N';'
 FROM sys.table_types;
 EXEC(@sql);
 IF (SELECT TestSources FROM #PortalDeployment)=1
 BEGIN
  SET @sql=N'USE SecurityDB; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
  SELECT @sql+=N'GRANT SELECT ON OBJECT::dbo.'+QUOTENAME(n)+N' TO '+QUOTENAME(@account)+N';'
  FROM (VALUES(N'Users'),(N'Applications'),(N'UserApplicationAccess'),(N'Roles'),(N'UserRoles')) t(n);
  EXEC(@sql);
  SET @sql=N'USE Pubs_Info_V4; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
  SELECT @sql+=N'GRANT SELECT ON OBJECT::dbo.'+QUOTENAME(n)+N' TO '+QUOTENAME(@account)+N';'
  FROM (VALUES(N'Public_info_News'),(N'Attachment'),(N'Public_info_News_Prodc')) t(n);
  EXEC(@sql);
 END;
END;
PRINT N'Fresh setup completed. Real-source mode requires Security adapters and dbo.VNews mapping. Empty ApiIdentity requires DBA runtime grants.';
SELECT ThemeId,ThemeName,LayoutKey,IsDefault FROM Master.Themes;
DROP TABLE #PortalDeployment;
GO