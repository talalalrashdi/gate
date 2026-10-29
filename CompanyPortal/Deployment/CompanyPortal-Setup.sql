/* CompanyPortal fresh installation, generated from migrations 001-054.
   Open this entire UTF-8 file in SSMS and Execute (normal mode, no SQLCMD mode).
   Or: sqlcmd -S SQLSERVER -E -b -f 65001 -i CompanyPortal-Setup.sql
   FRESH INSTALL ONLY. Never run on an existing CompanyPortal database.
   TestSources=1 creates NEW sample SecurityDB and Pubs_Info_V4 databases.
   TestSources=0 leaves external databases alone; configure the four Security
   adapter procedures and dbo.VNews against the real sources AFTER this script.
   No current employee preferences, uploaded images or custom themes are exported.
*/
USE master;
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
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


-- BEGIN 019_MasterApplicationCards.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF COL_LENGTH(N'Master.Cards',N'CardType') IS NULL
 ALTER TABLE [Master].Cards ADD CardType nvarchar(30) NOT NULL CONSTRAINT DF_Cards_Type DEFAULT(N'connected'),
 Audience nvarchar(20) NOT NULL CONSTRAINT DF_Cards_Audience DEFAULT(N'everyone');
GO
IF OBJECT_ID(N'Master.CardApplications',N'U') IS NULL
 CREATE TABLE [Master].CardApplications(
  CardApplicationId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_MasterCardApplications PRIMARY KEY,
  CardId int NOT NULL CONSTRAINT FK_MasterCardApplications_Card REFERENCES [Master].Cards(CardId),
  AppId int NOT NULL,
  Active bit NOT NULL CONSTRAINT DF_MasterCardApplications_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_MasterCardApplications_Changed DEFAULT(GETDATE()),
  CONSTRAINT UQ_MasterCardApplications UNIQUE(CardId,AppId));
IF OBJECT_ID(N'Master.CardRoles',N'U') IS NULL
 CREATE TABLE [Master].CardRoles(
  CardRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_MasterCardRoles PRIMARY KEY,
  CardId int NOT NULL CONSTRAINT FK_MasterCardRoles_Card REFERENCES [Master].Cards(CardId),
  RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 NOT NULL,
  Active bit NOT NULL CONSTRAINT DF_MasterCardRoles_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_MasterCardRoles_Changed DEFAULT(GETDATE()),
  CONSTRAINT UQ_MasterCardRoles UNIQUE(CardId,RoleName));
IF OBJECT_ID(N'Master.CK_Cards_Type',N'C') IS NULL
 ALTER TABLE [Master].Cards ADD CONSTRAINT CK_Cards_Type CHECK(CardType IN(N'connected',N'applications')),
 CONSTRAINT CK_Cards_Audience CHECK(Audience IN(N'everyone',N'roles'));
GO
-- Administrators configure only these connected cards and newly created app cards.
-- Retired baseline definitions remain untouched and unavailable in this editor.
CREATE OR ALTER PROCEDURE [Master].Cards_get AS
BEGIN
 SET NOCOUNT ON;
 SELECT CardId,CardKey,CardName,DisplayOrder,IsFixed,LastChangeAt,CardType,Active,Audience
 FROM [Master].Cards WHERE CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services')
 ORDER BY DisplayOrder,CardId;
 SELECT a.CardId,a.AppId FROM [Master].CardApplications a JOIN [Master].Cards c ON c.CardId=a.CardId WHERE a.Active=1 ORDER BY a.CardId,a.AppId;
 SELECT CardId,RoleName FROM [Master].CardRoles WHERE Active=1 ORDER BY CardId,RoleName;
END;
GO
-- The real-source adapter is installed separately, never guessed here.
IF OBJECT_ID(N'Security.Apps_getForAdministration',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Security.Apps_getForAdministration AS
 BEGIN SET NOCOUNT ON; THROW 50010,''Configure the approved administration application catalog adapter.'',1; END');
GO
CREATE OR ALTER PROCEDURE [Master].Cards_save
 @CardName nvarchar(200),@IsFixed bit,@DisplayOrder int,@Active bit,@Audience nvarchar(20),
 @AppsJson nvarchar(max),@RolesJson nvarchar(max),@CardId int=NULL
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
 IF @CardName IS NULL OR LEN(@CardName)=0 OR @IsFixed IS NULL OR @Active IS NULL
 OR @DisplayOrder IS NULL OR @DisplayOrder<1 OR @Audience NOT IN(N'everyone',N'roles') OR @Audience IS NULL
 OR ISJSON(@AppsJson)<>1 OR ISJSON(@RolesJson)<>1
  THROW 50006,'Check card details.',1;
 DECLARE @Apps TABLE(AppId int PRIMARY KEY);
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@AppsJson) WHERE type<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value)<1)
 OR EXISTS(SELECT 1 FROM OPENJSON(@RolesJson) WHERE type<>1 OR LEN(value)>200 OR LEN(LTRIM(RTRIM(value)))=0)
  THROW 50006,'Invalid applications or roles.',1;
 INSERT @Apps SELECT DISTINCT CONVERT(int,value) FROM OPENJSON(@AppsJson);
 INSERT @Roles SELECT DISTINCT CONVERT(nvarchar(200),value) COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@RolesJson);
 IF (SELECT COUNT(*) FROM @Apps)>100 OR (SELECT COUNT(*) FROM @Roles)>50
 OR (@Audience=N'roles' AND NOT EXISTS(SELECT 1 FROM @Roles))
 OR (@Audience=N'everyone' AND EXISTS(SELECT 1 FROM @Roles)) THROW 50006,'Check audience roles.',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MasterCards',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50006,'Card settings are busy. Retry.',1;
 DECLARE @Type nvarchar(30)=N'applications';
 IF @CardId IS NOT NULL
 BEGIN
  SELECT @Type=CardType FROM [Master].Cards WITH(UPDLOCK,HOLDLOCK) WHERE CardId=@CardId;
  IF NOT EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId=@CardId AND (CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services')))
   THROW 50006,'Select an available card.',1;
 END;
 IF (@Type=N'applications' AND NOT EXISTS(SELECT 1 FROM @Apps)) OR (@Type=N'connected' AND EXISTS(SELECT 1 FROM @Apps))
  THROW 50006,'Application cards require apps; connected cards do not accept app membership.',1;
 -- Validate membership against the current approved catalog, not employee grants.
 IF @Type=N'applications'
 BEGIN
  DECLARE @Catalog TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
  INSERT @Catalog EXEC Security.Apps_getForAdministration;
  IF EXISTS(SELECT 1 FROM @Apps a LEFT JOIN @Catalog c ON c.AppId=a.AppId WHERE c.AppId IS NULL)
   THROW 50006,'Select applications from the current catalog.',1;
 END;
 IF @CardId IS NULL
 BEGIN
  IF (SELECT COUNT(*) FROM [Master].Cards WHERE CardType=N'applications')>=100 THROW 50006,'Application card limit reached.',1;
  INSERT [Master].Cards(CardKey,CardName,DisplayOrder,IsFixed,Active,CardType,Audience)
  VALUES(N'master-'+LOWER(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')),@CardName,@DisplayOrder,0,0,N'applications',@Audience);
  SET @CardId=CONVERT(int,SCOPE_IDENTITY());
 END;
 DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1 AND CardId<>@CardId)+CONVERT(int,@Active);
 IF (@Active=1 AND @DisplayOrder>CASE WHEN @Count=0 THEN 1 ELSE @Count END)
 OR @DisplayOrder>200
 OR (@Active=1 AND @IsFixed=1 AND EXISTS(SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND CardId<>@CardId AND DisplayOrder=@DisplayOrder))
 OR EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId<>@CardId AND Active=1 AND IsFixed=1 AND DisplayOrder>@Count)
  THROW 50006,'Check position and other fixed slots before hiding or moving cards.',1;
 DECLARE @Changed bit=0;
 IF EXISTS(SELECT @CardName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@IsFixed,@Active,@Audience
  EXCEPT SELECT CardName COLLATE Latin1_General_100_BIN2,DisplayOrder,IsFixed,Active,Audience FROM [Master].Cards WHERE CardId=@CardId)
 OR EXISTS(SELECT AppId FROM @Apps EXCEPT SELECT AppId FROM [Master].CardApplications WHERE CardId=@CardId AND Active=1)
 OR EXISTS(SELECT AppId FROM [Master].CardApplications WHERE CardId=@CardId AND Active=1 EXCEPT SELECT AppId FROM @Apps)
 OR EXISTS(SELECT RoleName FROM @Roles EXCEPT SELECT RoleName FROM [Master].CardRoles WHERE CardId=@CardId AND Active=1)
 OR EXISTS(SELECT RoleName FROM [Master].CardRoles WHERE CardId=@CardId AND Active=1 EXCEPT SELECT RoleName FROM @Roles)
  SET @Changed=1;
 IF @Changed=1
 UPDATE [Master].Cards SET CardName=@CardName,DisplayOrder=@DisplayOrder,IsFixed=@IsFixed,Active=@Active,Audience=@Audience,LastChangeAt=GETDATE() WHERE CardId=@CardId;
 UPDATE a SET Active=CASE WHEN s.AppId IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM [Master].CardApplications a LEFT JOIN @Apps s ON s.AppId=a.AppId
 WHERE a.CardId=@CardId AND a.Active<>CASE WHEN s.AppId IS NULL THEN 0 ELSE 1 END;
 INSERT [Master].CardApplications(CardId,AppId) SELECT @CardId,a.AppId FROM @Apps a WHERE NOT EXISTS(SELECT 1 FROM [Master].CardApplications x WHERE x.CardId=@CardId AND x.AppId=a.AppId);
 UPDATE r SET Active=CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM [Master].CardRoles r LEFT JOIN @Roles s ON s.RoleName=r.RoleName
 WHERE r.CardId=@CardId AND r.Active<>CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END;
 INSERT [Master].CardRoles(CardId,RoleName) SELECT @CardId,r.RoleName FROM @Roles r WHERE NOT EXISTS(SELECT 1 FROM [Master].CardRoles x WHERE x.CardId=@CardId AND x.RoleName=r.RoleName);
 COMMIT;
 SELECT @CardId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
-- Normalize global fixed slots first, then compact only the employee-visible
-- master list. A role-restricted card never leaves empty slots for other users.
CREATE OR ALTER FUNCTION [Master].Cards_visible(@RolesJson nvarchar(max))
RETURNS TABLE AS RETURN
(
 WITH Base AS(SELECT CardId,CardKey,CardName,IsFixed,DisplayOrder,CardType,Audience FROM [Master].Cards WHERE Active=1),
 Slots AS(SELECT ROW_NUMBER() OVER(ORDER BY CardId) Position FROM Base),
 FreeSlots AS(SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) RowNumber FROM Slots s WHERE NOT EXISTS(SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=s.Position)),
 Movable AS(SELECT *,ROW_NUMBER() OVER(ORDER BY DisplayOrder,CardId) RowNumber FROM Base WHERE IsFixed=0),
 GlobalOrder AS(
 SELECT CardId,CardKey,CardName,IsFixed,DisplayOrder Position,CardType,Audience FROM Base WHERE IsFixed=1
 UNION ALL SELECT m.CardId,m.CardKey,m.CardName,m.IsFixed,f.Position,m.CardType,m.Audience FROM Movable m JOIN FreeSlots f ON f.RowNumber=m.RowNumber),
 Eligible AS(SELECT g.* FROM GlobalOrder g WHERE Audience=N'everyone' OR EXISTS(
 SELECT 1 FROM [Master].CardRoles r JOIN OPENJSON(@RolesJson) j ON r.RoleName=j.value COLLATE Latin1_General_100_BIN2
 WHERE r.CardId=g.CardId AND r.Active=1))
 SELECT CardId,CardKey,CardName,IsFixed,CONVERT(int,ROW_NUMBER() OVER(ORDER BY Position)) DisplayOrder,CardType FROM Eligible
);
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 DECLARE @RolesJson nvarchar(max)=(SELECT N'['+ISNULL(STRING_AGG(CONVERT(nvarchar(max),N'"'+STRING_ESCAPE(RoleName,'json')+N'"'),N','),N'')+N']' FROM @Roles);
 DECLARE @Definitions TABLE(CardKey nvarchar(100) PRIMARY KEY,CardName nvarchar(200),IsFixed bit,DisplayOrder int,IsCustom bit,UserCardId int NULL,CardType nvarchar(30));
 INSERT @Definitions SELECT CardKey,CardName,IsFixed,DisplayOrder,0,NULL,CardType FROM [Master].Cards_visible(@RolesJson);
 DECLARE @MasterCount int=(SELECT COUNT(*) FROM @Definitions);
 INSERT @Definitions SELECT N'custom-'+CONVERT(nvarchar(20),UserCardId),CardName,0,
 @MasterCount+CONVERT(int,ROW_NUMBER() OVER(ORDER BY UserCardId)),1,UserCardId,N'custom' FROM Portal.UserCards WHERE UserId=@UserId AND Active=1;
 ;WITH Base AS(
 SELECT d.*,s.SortOrder,CAST(CASE WHEN s.UserWorkspaceOrderId IS NULL THEN 0 ELSE 1 END AS bit) IsSaved,s.LastChangeAt
 FROM @Definitions d LEFT JOIN Portal.UserWorkspaceOrder s ON s.UserId=@UserId AND s.CardKey=d.CardKey AND s.Active=1),
 Slots AS(SELECT ROW_NUMBER() OVER(ORDER BY CardKey)-1 Position FROM Base),
 FreeSlots AS(SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) RowNumber FROM Slots s WHERE NOT EXISTS(SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=s.Position+1)),
 Movable AS(SELECT *,ROW_NUMBER() OVER(ORDER BY IsSaved DESC,SortOrder,DisplayOrder,CardKey) RowNumber FROM Base WHERE IsFixed=0),
 Resolved AS(
 SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt,CardType,DisplayOrder-1 Position FROM Base WHERE IsFixed=1
 UNION ALL SELECT m.CardKey,m.CardName,m.IsFixed,m.DisplayOrder,m.IsCustom,m.UserCardId,m.IsSaved,m.LastChangeAt,m.CardType,f.Position FROM Movable m JOIN FreeSlots f ON f.RowNumber=m.RowNumber)
 SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt,CardType FROM Resolved ORDER BY Position;
 DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
 INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
 SELECT d.CardKey,a.AppId,a.AppName FROM @Definitions d JOIN [Master].Cards c ON c.CardKey=d.CardKey AND c.CardType=N'applications'
 JOIN [Master].CardApplications m ON m.CardId=c.CardId AND m.Active=1 JOIN @Allowed a ON a.AppId=m.AppId ORDER BY d.CardKey,a.AppId;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_set @UserId int,@Cards Portal.CardOrderInput READONLY AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF (SELECT COUNT(*) FROM @Cards)>200 OR EXISTS(SELECT 1 FROM @Cards WHERE SortOrder<0)
 OR ((SELECT COUNT(*) FROM @Cards)>0 AND ((SELECT MIN(SortOrder) FROM @Cards)<>0 OR (SELECT MAX(SortOrder) FROM @Cards)<>(SELECT COUNT(*)-1 FROM @Cards)))
 THROW 50004,'Supply unique consecutive positions.',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MasterCards',@LockMode=N'Shared',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50004,'Catalog is busy. Reload.',1;
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 DECLARE @RolesJson nvarchar(max)=(SELECT N'['+ISNULL(STRING_AGG(CONVERT(nvarchar(max),N'"'+STRING_ESCAPE(RoleName,'json')+N'"'),N','),N'')+N']' FROM @Roles);
 DECLARE @Valid TABLE(CardKey nvarchar(100) PRIMARY KEY,IsFixed bit,DisplayOrder int);
 INSERT @Valid SELECT CardKey,IsFixed,DisplayOrder FROM [Master].Cards_visible(@RolesJson);
 INSERT @Valid SELECT N'custom-'+CONVERT(nvarchar(20),UserCardId),0,0 FROM Portal.UserCards WITH(HOLDLOCK) WHERE UserId=@UserId AND Active=1;
 IF EXISTS(SELECT CardKey FROM @Cards EXCEPT SELECT CardKey FROM @Valid)
 OR EXISTS(SELECT CardKey FROM @Valid EXCEPT SELECT CardKey FROM @Cards)
 OR EXISTS(SELECT 1 FROM @Cards i JOIN @Valid v ON v.CardKey=i.CardKey WHERE v.IsFixed=1 AND i.SortOrder<>v.DisplayOrder-1)
 THROW 50004,'Supply current visible cards and preserve fixed positions.',1;
 DECLARE @Count int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId);
 UPDATE s SET SortOrder=i.SortOrder,Active=1,LastChangeAt=GETDATE() FROM Portal.UserWorkspaceOrder s JOIN @Cards i ON i.CardKey=s.CardKey
 WHERE s.UserId=@UserId AND (s.SortOrder<>i.SortOrder OR s.Active=0);
 INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder) SELECT @UserId,i.CardKey,i.SortOrder FROM @Cards i
 WHERE NOT EXISTS(SELECT 1 FROM Portal.UserWorkspaceOrder s WHERE s.UserId=@UserId AND s.CardKey=i.CardKey);
 -- Hidden or no-longer-authorized card preferences are deliberately retained.
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO

GO


-- BEGIN 020_ApplicationDirectory.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'Master.ApplicationCategories',N'U') IS NULL
 CREATE TABLE [Master].ApplicationCategories(
  ApplicationCategoryId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ApplicationCategories PRIMARY KEY,
  CategoryName nvarchar(200) NOT NULL,
  DisplayOrder int NOT NULL CONSTRAINT DF_ApplicationCategories_Order DEFAULT(0),
  Active bit NOT NULL CONSTRAINT DF_ApplicationCategories_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_ApplicationCategories_Changed DEFAULT(GETDATE()),
  CONSTRAINT CK_ApplicationCategories_Name CHECK(LEN(LTRIM(RTRIM(CategoryName)))>0),
  CONSTRAINT CK_ApplicationCategories_Order CHECK(DisplayOrder>=0));
IF OBJECT_ID(N'Master.ApplicationDetails',N'U') IS NULL
 CREATE TABLE [Master].ApplicationDetails(
  ApplicationDetailId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ApplicationDetails PRIMARY KEY,
  AppId int NOT NULL CONSTRAINT UQ_ApplicationDetails_App UNIQUE,
  ApplicationCategoryId int NULL CONSTRAINT FK_ApplicationDetails_Category REFERENCES [Master].ApplicationCategories(ApplicationCategoryId),
  AppDescription nvarchar(2000) NOT NULL CONSTRAINT DF_ApplicationDetails_Description DEFAULT(N''),
  Active bit NOT NULL CONSTRAINT DF_ApplicationDetails_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_ApplicationDetails_Changed DEFAULT(GETDATE()));
GO
-- Keep Security.Apps_getForUser's three-column contract unchanged: existing
-- personal/master card procedures also INSERT EXEC that permission adapter.
CREATE OR ALTER PROCEDURE [Master].Applications_getForUser @UserId int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
 INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
 SELECT a.AppId,a.AppName,ISNULL(d.AppDescription,N'') AS Description,
 c.ApplicationCategoryId AS CategoryId,ISNULL(c.CategoryName,N'غير مصنف') AS CategoryName,
 ISNULL(c.DisplayOrder,2147483647) AS CategoryOrder
 FROM @Allowed a LEFT JOIN [Master].ApplicationDetails d ON d.AppId=a.AppId AND d.Active=1
 LEFT JOIN [Master].ApplicationCategories c ON c.ApplicationCategoryId=d.ApplicationCategoryId AND c.Active=1
 ORDER BY ISNULL(c.DisplayOrder,2147483647),c.CategoryName,a.AppName,a.AppId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_adminGet AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 SELECT a.AppId,a.AppName,ISNULL(d.AppDescription,N'') AS Description,
 d.ApplicationCategoryId AS CategoryId,d.LastChangeAt
 FROM @Apps a LEFT JOIN [Master].ApplicationDetails d ON d.AppId=a.AppId AND d.Active=1 ORDER BY a.AppName,a.AppId;
 SELECT ApplicationCategoryId AS CategoryId,CategoryName,DisplayOrder,Active,LastChangeAt
 FROM [Master].ApplicationCategories ORDER BY DisplayOrder,CategoryName,ApplicationCategoryId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_save
 @AppId int,@Description nvarchar(2000),@CategoryId int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @Description IS NULL THROW 50012,'Supply a description, optionally empty.',1;
 SET @Description=LTRIM(RTRIM(@Description));
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 IF NOT EXISTS(SELECT 1 FROM @Apps WHERE AppId=@AppId) THROW 50011,'Application not found in current catalog.',1;
 BEGIN TRY
 BEGIN TRAN;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WITH(HOLDLOCK) WHERE ApplicationCategoryId=@CategoryId)
  THROW 50012,'Category not found.',1;
 DECLARE @Existing int=(SELECT ApplicationDetailId FROM [Master].ApplicationDetails WITH(UPDLOCK,HOLDLOCK) WHERE AppId=@AppId);
 IF @Existing IS NULL
  INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription) VALUES(@AppId,@CategoryId,@Description);
 ELSE
  UPDATE [Master].ApplicationDetails SET ApplicationCategoryId=@CategoryId,AppDescription=@Description,Active=1,LastChangeAt=GETDATE()
  WHERE ApplicationDetailId=@Existing AND (Active=0 OR EXISTS(
   SELECT @CategoryId,@Description COLLATE Latin1_General_100_BIN2 EXCEPT SELECT ApplicationCategoryId,AppDescription COLLATE Latin1_General_100_BIN2 FROM [Master].ApplicationDetails WHERE ApplicationDetailId=@Existing));
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].ApplicationCategories_save
 @CategoryName nvarchar(200),@DisplayOrder int,@Active bit,@CategoryId int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET @CategoryName=LTRIM(RTRIM(@CategoryName));
 IF @CategoryName IS NULL OR LEN(@CategoryName)=0 OR @DisplayOrder IS NULL OR @DisplayOrder<0 OR @Active IS NULL
  THROW 50012,'Check category name, order and availability.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ApplicationCategories',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50012,'Category settings busy. Retry.',1;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId)
  THROW 50011,'Category not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].ApplicationCategories WHERE CategoryName=@CategoryName AND (@CategoryId IS NULL OR ApplicationCategoryId<>@CategoryId))
  THROW 50012,'Category name already exists.',1;
 IF @CategoryId IS NULL
 BEGIN
  INSERT [Master].ApplicationCategories(CategoryName,DisplayOrder,Active) VALUES(@CategoryName,@DisplayOrder,@Active);
  SET @CategoryId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE UPDATE [Master].ApplicationCategories SET CategoryName=@CategoryName,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE ApplicationCategoryId=@CategoryId AND EXISTS(
  SELECT @CategoryName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@Active EXCEPT SELECT CategoryName COLLATE Latin1_General_100_BIN2,DisplayOrder,Active FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId);
 COMMIT;
 SELECT @CategoryId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO

GO


-- BEGIN 021_FixedOrders.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Portal.FixedOrders',N'U') IS NULL
 CREATE TABLE Portal.FixedOrders
 (
  FixedOrderID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FixedOrders PRIMARY KEY,
  [Timestamp] date NULL,
  Timestamp2 date NULL,
  ContentBefor nvarchar(500) NULL,
  ContentAfter nvarchar(1000) NULL,
  ContentText nvarchar(1000) NULL,
  TimestampType int NOT NULL
 );
GO
CREATE OR ALTER PROCEDURE Portal.FixedOrders_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT FixedOrderID,[Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType
 FROM Portal.FixedOrders ORDER BY [Timestamp] DESC,FixedOrderID DESC;
END;
GO

GO


-- BEGIN 022_LegalDecisions.sql
USE CompanyPortal;
GO
IF SCHEMA_ID(N'Legal') IS NULL EXEC(N'CREATE SCHEMA Legal');
GO
-- Integration adapter: replace with the real permission-filtered lookup.
-- Rerunning a migration must never overwrite an installed adapter.
IF OBJECT_ID(N'Legal.Decisions_getForUser',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Legal.Decisions_getForUser @UserId int,@DecisionId bigint=NULL AS
 BEGIN SET NOCOUNT ON; THROW 50030,''Legal decisions source is not configured.'',1; END');
GO

GO


-- BEGIN 023_Documents.sql
USE CompanyPortal;
GO
IF SCHEMA_ID(N'Mng') IS NULL EXEC(N'CREATE SCHEMA Mng');
IF SCHEMA_ID(N'App') IS NULL EXEC(N'CREATE SCHEMA App');
GO
IF OBJECT_ID(N'Mng.Document',N'U') IS NULL
CREATE TABLE Mng.Document(
 DocumentID uniqueidentifier NOT NULL CONSTRAINT DF_Document_DocumentID DEFAULT(NEWID()) CONSTRAINT PK_Document PRIMARY KEY,
 DocumentName nvarchar(100) NOT NULL,
 DocumentPath nvarchar(150) NOT NULL,
 FolderID int NOT NULL,
 [Timestamp] datetime NOT NULL CONSTRAINT EForm_EFormUploadedDate DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_Document_Active DEFAULT(1)
);
GO
-- Install the real lookup only after its views exist; never replace an installed adapter here.
IF OBJECT_ID(N'Portal.Document_GetAll',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Document_GetAll @UserId int AS
 BEGIN SET NOCOUNT ON; THROW 50040,''Document source views/access list are not configured.'',1; END');
GO

GO


-- BEGIN 024_FolderAndDocsRoot.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @LegacyId int=OBJECT_ID(N'Mng.DocumentSampleFolders',N'U'),@Seed bigint;
 IF @LegacyId IS NOT NULL AND OBJECT_ID(N'Mng.Folder',N'U') IS NOT NULL
  THROW 50042,'Both folder tables exist. Resolve the collision before applying this migration.',1;
 IF @LegacyId IS NOT NULL
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
   THROW 50043,'The legacy folder table is not a marked development source.',1;
  IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=@LegacyId)<>5
   OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@LegacyId OR referenced_object_id=@LegacyId)
   OR EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@LegacyId)
   OR EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@LegacyId AND is_primary_key=0 AND index_id>0)
   OR EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=@LegacyId)
   OR EXISTS(SELECT 1 FROM sys.sql_expression_dependencies WHERE referenced_id=@LegacyId AND referencing_id<>OBJECT_ID(N'dbo.VFolder'))
   OR OBJECTPROPERTY(OBJECT_ID(N'dbo.VFolder'),N'IsSchemaBound')=1
   THROW 50044,'Legacy folder customizations need review before rebuilding its column order.',1;
  SELECT @Seed=CONVERT(bigint,last_value) FROM sys.identity_columns WHERE object_id=@LegacyId;
 END;
 IF OBJECT_ID(N'Mng.Folder',N'U') IS NULL
 CREATE TABLE Mng.Folder(
  FolderID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Folder PRIMARY KEY,
  ParentID int NULL,
  FolderName nvarchar(200) NOT NULL,
  UnitMstID int NULL,
  IsForDisplay bit NOT NULL CONSTRAINT DF_Folder_IsForDisplay DEFAULT(1),
  [Timestamp] datetime NOT NULL CONSTRAINT DF_Folder_Timestamp DEFAULT(GETDATE()),
  Active bit NOT NULL CONSTRAINT DF_Folder_Active DEFAULT(1)
 );
 IF @LegacyId IS NOT NULL
 BEGIN
  SET IDENTITY_INSERT Mng.Folder ON;
  EXEC(N'INSERT Mng.Folder(FolderID,ParentID,FolderName,IsForDisplay,Active)
   SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.DocumentSampleFolders;
   IF EXISTS(SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.DocumentSampleFolders
    EXCEPT SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.Folder)
   OR EXISTS(SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.Folder
    EXCEPT SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.DocumentSampleFolders)
    THROW 50045,''Folder data comparison failed.'',1;');
  SET IDENTITY_INSERT Mng.Folder OFF;
  IF @Seed IS NOT NULL EXEC(N'DBCC CHECKIDENT (''Mng.Folder'',RESEED,'+@Seed+N') WITH NO_INFOMSGS;');
  EXEC(N'DROP TABLE Mng.DocumentSampleFolders;');
 END;
 -- Change only the marked sample view; preserve a real external view on other installations.
 IF EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
  EXEC(N'CREATE OR ALTER VIEW dbo.VFolder AS
   SELECT FolderID,ParentID,FolderName,UnitMstID,IsForDisplay,[Timestamp],Active FROM Mng.Folder;');
 IF EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'Documents')
  AND EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'docs')
  THROW 50046,'Both Documents and docs folder keys exist. Review the intended roots before renaming.',1;
 UPDATE Mstr.Utls SET [Key]=N'docs',LastChangeAt=GETDATE() WHERE [Key]=N'Documents';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO

GO


-- BEGIN 025_DocumentTabs.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Portal.DocumentTabs',N'U') IS NULL
CREATE TABLE Portal.DocumentTabs(
 DocumentTabID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentTabs PRIMARY KEY,
 TabName nvarchar(200) NOT NULL,
 FolderID int NOT NULL,
 DisplayOrder int NOT NULL CONSTRAINT DF_DocumentTabs_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_DocumentTabs_LastChange DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_DocumentTabs_Active DEFAULT(1),
 CONSTRAINT CK_DocumentTabs_Order CHECK(DisplayOrder>=0)
);
IF OBJECT_ID(N'Portal.DocumentTabItems',N'U') IS NULL
CREATE TABLE Portal.DocumentTabItems(
 DocumentTabItemID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentTabItems PRIMARY KEY,
 DocumentTabID int NOT NULL CONSTRAINT FK_DocumentTabItems_Tab REFERENCES Portal.DocumentTabs(DocumentTabID),
 DocumentID uniqueidentifier NOT NULL CONSTRAINT FK_DocumentTabItems_Document REFERENCES Mng.Document(DocumentID),
 CONSTRAINT UQ_DocumentTabItems UNIQUE(DocumentTabID,DocumentID)
);
COMMIT;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Get @IncludeHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT DocumentTabID,TabName,FolderID,DisplayOrder,LastChangeAt,Active
 FROM Portal.DocumentTabs WHERE Active=1 OR @IncludeHidden=1 ORDER BY DisplayOrder,DocumentTabID;
 SELECT i.DocumentTabID,i.DocumentID FROM Portal.DocumentTabItems i
 JOIN Portal.DocumentTabs t ON t.DocumentTabID=i.DocumentTabID WHERE t.Active=1 OR @IncludeHidden=1;
END;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Save
 @DocumentTabID int=NULL,@TabName nvarchar(200),@FolderID int,@DisplayOrder int,@Active bit,@DocumentIds nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@TabName)),N'') IS NULL OR @DisplayOrder<0 OR ISJSON(@DocumentIds)<>1
  THROW 50012,'Invalid document tab.',1;
 DECLARE @Items TABLE(DocumentID uniqueidentifier NOT NULL PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@DocumentIds) WHERE TRY_CONVERT(uniqueidentifier,value) IS NULL)
  THROW 50012,'Invalid document selection.',1;
 INSERT @Items SELECT DISTINCT CONVERT(uniqueidentifier,value) FROM OPENJSON(@DocumentIds);
 IF NOT EXISTS(SELECT 1 FROM @Items) OR (SELECT COUNT(*) FROM @Items)>500
  THROW 50012,'Select between one and 500 PDF documents.',1;
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN Mng.Document d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentID=i.DocumentID
  WHERE d.DocumentID IS NULL OR d.FolderID<>@FolderID OR d.Active<>1 OR LOWER(RIGHT(d.DocumentPath,4))<>N'.pdf')
  THROW 50012,'Selection must contain active PDFs from the selected folder.',1;
 IF @DocumentTabID IS NULL
 BEGIN
  INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder,Active) VALUES(@TabName,@FolderID,@DisplayOrder,@Active);
  SET @DocumentTabID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.DocumentTabs WITH(UPDLOCK,HOLDLOCK) WHERE DocumentTabID=@DocumentTabID)
   THROW 50011,'Document tab not found.',1;
  UPDATE Portal.DocumentTabs SET TabName=@TabName,FolderID=@FolderID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE DocumentTabID=@DocumentTabID AND (TabName COLLATE Latin1_General_100_BIN2<>@TabName COLLATE Latin1_General_100_BIN2
   OR FolderID<>@FolderID OR DisplayOrder<>@DisplayOrder OR Active<>@Active
   OR EXISTS(SELECT DocumentID FROM @Items EXCEPT SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID)
   OR EXISTS(SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID EXCEPT SELECT DocumentID FROM @Items));
 END;
 DELETE Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID AND DocumentID NOT IN(SELECT DocumentID FROM @Items);
 INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
 SELECT @DocumentTabID,DocumentID FROM @Items i WHERE NOT EXISTS(
  SELECT 1 FROM Portal.DocumentTabItems t WHERE t.DocumentTabID=@DocumentTabID AND t.DocumentID=i.DocumentID);
 COMMIT;
 SELECT @DocumentTabID;
END;
GO

GO


-- BEGIN 026_SafetyBooklets.sql
USE CompanyPortal;
GO
IF COL_LENGTH(N'Portal.DocumentTabs',N'SectionKey') IS NULL
 ALTER TABLE Portal.DocumentTabs ADD SectionKey nvarchar(30) NOT NULL
  CONSTRAINT DF_DocumentTabs_Section DEFAULT(N'documents') WITH VALUES;
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_DocumentTabs_Section' AND parent_object_id=OBJECT_ID(N'Portal.DocumentTabs'))
 ALTER TABLE Portal.DocumentTabs ADD CONSTRAINT CK_DocumentTabs_Section CHECK(SectionKey IN(N'documents',N'safety'));
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Get @IncludeHidden bit=0,@SectionKey nvarchar(30)=N'documents' AS
BEGIN
 SET NOCOUNT ON;
 SELECT DocumentTabID,TabName,FolderID,DisplayOrder,LastChangeAt,Active
 FROM Portal.DocumentTabs WHERE SectionKey=@SectionKey AND (Active=1 OR @IncludeHidden=1) ORDER BY DisplayOrder,DocumentTabID;
 SELECT i.DocumentTabID,i.DocumentID FROM Portal.DocumentTabItems i
 JOIN Portal.DocumentTabs t ON t.DocumentTabID=i.DocumentTabID WHERE t.SectionKey=@SectionKey AND (t.Active=1 OR @IncludeHidden=1);
END;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Save
 @DocumentTabID int=NULL,@TabName nvarchar(200),@FolderID int,@DisplayOrder int,@Active bit,@DocumentIds nvarchar(max),@SectionKey nvarchar(30)=N'documents'
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @SectionKey NOT IN(N'documents',N'safety') THROW 50012,'Invalid section.',1;
 IF NULLIF(LTRIM(RTRIM(@TabName)),N'') IS NULL OR @DisplayOrder<0 OR ISJSON(@DocumentIds)<>1
  THROW 50012,'Invalid document tab.',1;
 DECLARE @Items TABLE(DocumentID uniqueidentifier NOT NULL PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@DocumentIds) WHERE TRY_CONVERT(uniqueidentifier,value) IS NULL)
  THROW 50012,'Invalid document selection.',1;
 INSERT @Items SELECT DISTINCT CONVERT(uniqueidentifier,value) FROM OPENJSON(@DocumentIds);
 IF NOT EXISTS(SELECT 1 FROM @Items) OR (SELECT COUNT(*) FROM @Items)>500
  THROW 50012,'Select between one and 500 PDF documents.',1;
 IF @SectionKey=N'safety' AND (SELECT COUNT(*) FROM @Items)<>1 THROW 50012,'Select one PDF per safety booklet.',1;
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN Mng.Document d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentID=i.DocumentID
  WHERE d.DocumentID IS NULL OR d.FolderID<>@FolderID OR d.Active<>1 OR LOWER(RIGHT(d.DocumentPath,4))<>N'.pdf')
  THROW 50012,'Selection must contain active PDFs from the selected folder.',1;
 IF @DocumentTabID IS NULL
 BEGIN
  INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder,Active,SectionKey) VALUES(@TabName,@FolderID,@DisplayOrder,@Active,@SectionKey);
  SET @DocumentTabID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.DocumentTabs WITH(UPDLOCK,HOLDLOCK) WHERE DocumentTabID=@DocumentTabID AND SectionKey=@SectionKey)
   THROW 50011,'Document tab not found.',1;
  UPDATE Portal.DocumentTabs SET TabName=@TabName,FolderID=@FolderID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE DocumentTabID=@DocumentTabID AND SectionKey=@SectionKey AND (TabName COLLATE Latin1_General_100_BIN2<>@TabName COLLATE Latin1_General_100_BIN2
   OR FolderID<>@FolderID OR DisplayOrder<>@DisplayOrder OR Active<>@Active
   OR EXISTS(SELECT DocumentID FROM @Items EXCEPT SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID)
   OR EXISTS(SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID EXCEPT SELECT DocumentID FROM @Items));
 END;
 DELETE Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID AND DocumentID NOT IN(SELECT DocumentID FROM @Items);
 INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
 SELECT @DocumentTabID,DocumentID FROM @Items i WHERE NOT EXISTS(
  SELECT 1 FROM Portal.DocumentTabItems t WHERE t.DocumentTabID=@DocumentTabID AND t.DocumentID=i.DocumentID);
 COMMIT;
 SELECT @DocumentTabID;
END;
GO

GO


-- BEGIN 027_FixedOrdersAdministration.sql
USE CompanyPortal;
GO
-- Preserve the explicitly agreed table shape and existing records.
CREATE OR ALTER PROCEDURE Portal.FixedOrders_Save
 @FixedOrderID bigint=NULL,@Timestamp date=NULL,@Timestamp2 date=NULL,
 @ContentBefor nvarchar(500)=NULL,@ContentAfter nvarchar(1000),@ContentText nvarchar(1000),@TimestampType int
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ContentAfter)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@ContentText)),N'') IS NULL
  OR (CHARINDEX(N'ds{0}de',@ContentText)>0 AND NULLIF(LTRIM(RTRIM(@ContentBefor)),N'') IS NULL)
  THROW 50012,'Provide title, wording and any referenced previous text.',1;
 BEGIN TRANSACTION;
 IF @FixedOrderID IS NULL
 BEGIN
  INSERT Portal.FixedOrders([Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType)
  VALUES(@Timestamp,@Timestamp2,@ContentBefor,@ContentAfter,@ContentText,@TimestampType);
  SET @FixedOrderID=CONVERT(bigint,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.FixedOrders WITH(UPDLOCK,HOLDLOCK) WHERE FixedOrderID=@FixedOrderID)
   THROW 50011,'Fixed order not found.',1;
  UPDATE Portal.FixedOrders SET [Timestamp]=@Timestamp,Timestamp2=@Timestamp2,ContentBefor=@ContentBefor,
   ContentAfter=@ContentAfter,ContentText=@ContentText,TimestampType=@TimestampType
  WHERE FixedOrderID=@FixedOrderID AND (EXISTS(
   SELECT [Timestamp],Timestamp2,ContentBefor COLLATE Latin1_General_100_BIN2,ContentAfter COLLATE Latin1_General_100_BIN2,ContentText COLLATE Latin1_General_100_BIN2,TimestampType
   EXCEPT SELECT @Timestamp,@Timestamp2,@ContentBefor COLLATE Latin1_General_100_BIN2,@ContentAfter COLLATE Latin1_General_100_BIN2,@ContentText COLLATE Latin1_General_100_BIN2,@TimestampType)
   OR ISNULL(DATALENGTH(ContentBefor),-1)<>ISNULL(DATALENGTH(@ContentBefor),-1)
   OR ISNULL(DATALENGTH(ContentAfter),-1)<>ISNULL(DATALENGTH(@ContentAfter),-1)
   OR ISNULL(DATALENGTH(ContentText),-1)<>ISNULL(DATALENGTH(@ContentText),-1));
 END;
 COMMIT;
 SELECT @FixedOrderID;
END;
GO

GO


-- BEGIN 028_PortalMedia.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Portal.MediaGroups',N'U') IS NULL
CREATE TABLE Portal.MediaGroups(
 MediaGroupID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_MediaGroups PRIMARY KEY,
 GroupName nvarchar(200) NOT NULL,
 CoverMediaID int NULL,
 DisplayOrder int NOT NULL CONSTRAINT DF_MediaGroups_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_MediaGroups_Change DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_MediaGroups_Active DEFAULT(1),
 CONSTRAINT CK_MediaGroups_Order CHECK(DisplayOrder>=0)
);
IF OBJECT_ID(N'Portal.Media',N'U') IS NULL
CREATE TABLE Portal.Media(
 MediaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Media PRIMARY KEY,
 MediaName nvarchar(300) NOT NULL,
 MediaPath nvarchar(2000) NOT NULL,
 MediaType nvarchar(20) NOT NULL,
 MediaGroupID int NULL CONSTRAINT FK_Media_Group REFERENCES Portal.MediaGroups(MediaGroupID),
 DisplayOrder int NOT NULL CONSTRAINT DF_Media_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_Media_Change DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_Media_Active DEFAULT(1),
 CONSTRAINT CK_Media_Type CHECK(MediaType IN(N'image',N'video') AND (MediaType=N'image' OR MediaGroupID IS NULL)),
 CONSTRAINT CK_Media_Order CHECK(DisplayOrder>=0)
);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_MediaGroups_Cover' AND parent_object_id=OBJECT_ID(N'Portal.MediaGroups'))
 ALTER TABLE Portal.MediaGroups ADD CONSTRAINT FK_MediaGroups_Cover FOREIGN KEY(CoverMediaID) REFERENCES Portal.Media(MediaID);
COMMIT;
GO
-- Fixed source contract: groups first, media second. Adapt these SELECTs internally.
CREATE OR ALTER PROCEDURE Portal.Media_GetAll @IncludeHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT MediaGroupID,GroupName,CoverMediaID,DisplayOrder,LastChangeAt,Active
 FROM Portal.MediaGroups WHERE @IncludeHidden=1 OR Active=1 ORDER BY DisplayOrder,MediaGroupID;
 SELECT m.MediaID,m.MediaName,m.MediaPath,m.MediaType,m.MediaGroupID,m.DisplayOrder,m.LastChangeAt,m.Active
 FROM Portal.Media m LEFT JOIN Portal.MediaGroups g ON g.MediaGroupID=m.MediaGroupID
 WHERE @IncludeHidden=1 OR (m.Active=1 AND (m.MediaGroupID IS NULL OR g.Active=1))
 ORDER BY m.DisplayOrder,m.MediaID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Media_GetById @MediaID int,@IncludeHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT m.MediaID,m.MediaName,m.MediaPath,m.MediaType,m.MediaGroupID,m.DisplayOrder,m.LastChangeAt,m.Active
 FROM Portal.Media m LEFT JOIN Portal.MediaGroups g ON g.MediaGroupID=m.MediaGroupID
 WHERE m.MediaID=@MediaID AND (@IncludeHidden=1 OR (m.Active=1 AND (m.MediaGroupID IS NULL OR g.Active=1)));
END;
GO
CREATE OR ALTER PROCEDURE Portal.Media_Save
 @MediaID int=NULL,@MediaName nvarchar(300),@MediaPath nvarchar(2000),@MediaType nvarchar(20),@MediaGroupID int=NULL,@DisplayOrder int,@Active bit
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@MediaName)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@MediaPath)),N'') IS NULL OR @MediaType NOT IN(N'image',N'video')
  OR @DisplayOrder<0 OR (@MediaType=N'video' AND @MediaGroupID IS NOT NULL)
  THROW 50012,'Invalid media fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
 -- Lock groups before media consistently with group saves/cover selection.
 IF @MediaGroupID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.MediaGroups WITH(UPDLOCK,HOLDLOCK) WHERE MediaGroupID=@MediaGroupID)
  THROW 50012,'Unknown photo group.',1;
 IF @MediaID IS NULL
 BEGIN
  INSERT Portal.Media(MediaName,MediaPath,MediaType,MediaGroupID,DisplayOrder,Active)
  VALUES(@MediaName,@MediaPath,@MediaType,@MediaGroupID,@DisplayOrder,@Active);
  SET @MediaID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  -- Clear any saved cover before moving its photo or changing it to video.
  UPDATE Portal.MediaGroups SET CoverMediaID=NULL,LastChangeAt=GETDATE()
   WHERE CoverMediaID=@MediaID AND (@MediaType<>N'image' OR @MediaGroupID IS NULL OR MediaGroupID<>@MediaGroupID);
  IF NOT EXISTS(SELECT 1 FROM Portal.Media WITH(UPDLOCK,HOLDLOCK) WHERE MediaID=@MediaID) THROW 50011,'Media not found.',1;
  UPDATE Portal.Media SET MediaName=@MediaName,MediaPath=@MediaPath,MediaType=@MediaType,MediaGroupID=@MediaGroupID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE MediaID=@MediaID AND EXISTS(
   SELECT MediaName COLLATE Latin1_General_100_BIN2,MediaPath COLLATE Latin1_General_100_BIN2,MediaType,MediaGroupID,DisplayOrder,Active
   EXCEPT SELECT @MediaName COLLATE Latin1_General_100_BIN2,@MediaPath COLLATE Latin1_General_100_BIN2,@MediaType,@MediaGroupID,@DisplayOrder,@Active);
 END;
 COMMIT;SELECT @MediaID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.MediaGroups_Save
 @MediaGroupID int=NULL,@GroupName nvarchar(200),@CoverMediaID int=NULL,@DisplayOrder int,@Active bit
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@GroupName)),N'') IS NULL OR @DisplayOrder<0 THROW 50012,'Invalid group fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
 IF @MediaGroupID IS NULL
 BEGIN
  IF @CoverMediaID IS NOT NULL THROW 50012,'Create the group before selecting its cover.',1;
  INSERT Portal.MediaGroups(GroupName,DisplayOrder,Active) VALUES(@GroupName,@DisplayOrder,@Active);
  SET @MediaGroupID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE IF NOT EXISTS(SELECT 1 FROM Portal.MediaGroups WITH(UPDLOCK,HOLDLOCK) WHERE MediaGroupID=@MediaGroupID) THROW 50011,'Group not found.',1;
 IF @CoverMediaID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.Media WITH(UPDLOCK,HOLDLOCK)
  WHERE MediaID=@CoverMediaID AND MediaGroupID=@MediaGroupID AND MediaType=N'image') THROW 50012,'Cover must be a photo in this album.',1;
 UPDATE Portal.MediaGroups SET GroupName=@GroupName,CoverMediaID=@CoverMediaID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE MediaGroupID=@MediaGroupID AND EXISTS(
  SELECT GroupName COLLATE Latin1_General_100_BIN2,CoverMediaID,DisplayOrder,Active
  EXCEPT SELECT @GroupName COLLATE Latin1_General_100_BIN2,@CoverMediaID,@DisplayOrder,@Active);
 COMMIT;SELECT @MediaGroupID;
END;
GO

GO


-- BEGIN 029_ProfileSummary.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Read-only integration contracts. Replace the SELECTs internally; never return another user.
-- Keep existing mapped SPs unchanged when this migration is reapplied.
IF OBJECT_ID(N'Portal.UserAttendance_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.UserAttendance_Get @UserId int AS BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS nvarchar(300)) AS DisplayName, CAST(NULL AS nvarchar(300)) AS JobTitle,
 CAST(NULL AS nvarchar(300)) AS Department, CAST(NULL AS date) AS AttendanceDate,
 CAST(NULL AS datetime) AS ArrivalAt, CAST(NULL AS datetime) AS ExpectedLeaveAt WHERE 1=0; END;');
GO
IF OBJECT_ID(N'Portal.UserLeaveBalance_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.UserLeaveBalance_Get @UserId int AS BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS decimal(10,2)) AS HolidayDays, CAST(NULL AS decimal(10,2)) AS DaysToBeDeleted,
 CAST(NULL AS date) AS AsOfDate, CAST(NULL AS date) AS DeletionDate WHERE 1=0; END;');
GO

GO


-- BEGIN 030_Magazines.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Portal.Magazines',N'U') IS NULL
 CREATE TABLE Portal.Magazines(
  MagazineID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Magazines PRIMARY KEY,
  MagazineName nvarchar(300) NOT NULL,
  IssueNumber nvarchar(100) NOT NULL,
  IssueDate date NOT NULL,
  FileName nvarchar(1000) NOT NULL,
  DisplayOrder int NOT NULL CONSTRAINT DF_Magazines_DisplayOrder DEFAULT 0,
  LastChangeAt datetime NOT NULL CONSTRAINT DF_Magazines_LastChangeAt DEFAULT GETDATE(),
  Active bit NOT NULL CONSTRAINT DF_Magazines_Active DEFAULT 1,
  CONSTRAINT CK_Magazines_DisplayOrder CHECK(DisplayOrder>=0));
GO
-- Preserve a customized source adapter when reapplying this migration.
IF OBJECT_ID(N'Portal.Magazines_GetAll',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Magazines_GetAll @MagazineID int=NULL AS BEGIN
 SET NOCOUNT ON;
 SELECT MagazineID,MagazineName,IssueNumber,IssueDate,FileName,DisplayOrder,LastChangeAt,Active
 FROM Portal.Magazines WHERE Active=1 AND (@MagazineID IS NULL OR MagazineID=@MagazineID)
 ORDER BY IssueDate DESC,DisplayOrder,MagazineID DESC;
 END;');
GO

GO


-- BEGIN 031_UserMagazineReads.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Portal.UserMagazineReads',N'U') IS NULL
 CREATE TABLE Portal.UserMagazineReads(
  UserMagazineReadID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserMagazineReads PRIMARY KEY,
  UserId int NOT NULL,MagazineID int NOT NULL,
  ReadAt datetime NOT NULL CONSTRAINT DF_UserMagazineReads_ReadAt DEFAULT GETDATE(),
  Active bit NOT NULL CONSTRAINT DF_UserMagazineReads_Active DEFAULT 1,
  CONSTRAINT UQ_UserMagazineReads_User_Issue UNIQUE(UserId,MagazineID),
  CONSTRAINT CK_UserMagazineReads_IDs CHECK(UserId>0 AND MagazineID>0));
GO
-- User and magazine identities can be supplied by external mapped sources; no cross-source FK.
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_Get @UserId int AS
BEGIN SET NOCOUNT ON;SELECT MagazineID FROM Portal.UserMagazineReads WHERE UserId=@UserId AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_MarkRead @UserId int,@MagazineID int AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @MagazineID<=0 THROW 50012,'Invalid read identity.',1;
 BEGIN TRANSACTION;
 DECLARE @Active bit;
 SELECT @Active=Active FROM Portal.UserMagazineReads WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND MagazineID=@MagazineID;
 IF @Active IS NULL INSERT Portal.UserMagazineReads(UserId,MagazineID) VALUES(@UserId,@MagazineID);
 ELSE IF @Active=0 UPDATE Portal.UserMagazineReads SET Active=1,ReadAt=GETDATE() WHERE UserId=@UserId AND MagazineID=@MagazineID;
 -- Already read: preserve the original timestamp; no UPDATE.
 COMMIT;
END;
GO

GO


-- BEGIN 032_SharedUserReads.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Mstr.ContentType',N'U') IS NULL
 CREATE TABLE Mstr.ContentType(
 ContentTypeID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ContentType PRIMARY KEY,
 ContentTypeName nvarchar(200) NOT NULL,
 Active bit NOT NULL CONSTRAINT DF_ContentType_Active DEFAULT(1));
IF EXISTS(SELECT 1 FROM Mstr.ContentType WHERE (ContentTypeID=1 AND ContentTypeName<>N'المجلات') OR (ContentTypeID=2 AND ContentTypeName<>N'القرارات'))
 THROW 50012,'Reserved content type identity conflicts with an existing type.',1;
SET IDENTITY_INSERT Mstr.ContentType ON;
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=1) INSERT Mstr.ContentType(ContentTypeID,ContentTypeName) VALUES(1,N'المجلات');
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=2) INSERT Mstr.ContentType(ContentTypeID,ContentTypeName) VALUES(2,N'القرارات');
SET IDENTITY_INSERT Mstr.ContentType OFF;
IF OBJECT_ID(N'Portal.UserReads',N'U') IS NULL
 CREATE TABLE Portal.UserReads(
 UserReadID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserReads PRIMARY KEY,
 UserId int NOT NULL,ContentTypeID int NOT NULL,ContentId nvarchar(200) NOT NULL,
 ReadAt datetime NOT NULL CONSTRAINT DF_UserReads_ReadAt DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_UserReads_Active DEFAULT(1),
 CONSTRAINT FK_UserReads_ContentType FOREIGN KEY(ContentTypeID) REFERENCES Mstr.ContentType(ContentTypeID),
 CONSTRAINT UQ_UserReads_User_Type_Content UNIQUE(UserId,ContentTypeID,ContentId),
 CONSTRAINT CK_UserReads_Identity CHECK(UserId>0 AND LEN(ContentId)>0));
-- One-time migration: legacy table is retained as an archive, never written by the application again.
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE major_id=OBJECT_ID(N'Portal.UserReads') AND name=N'MagazineReadsMigrated')
BEGIN
 INSERT Portal.UserReads(UserId,ContentTypeID,ContentId,ReadAt,Active)
 SELECT r.UserId,1,CONVERT(nvarchar(200),r.MagazineID),r.ReadAt,r.Active FROM Portal.UserMagazineReads r
 WHERE NOT EXISTS(SELECT 1 FROM Portal.UserReads u WHERE u.UserId=r.UserId AND u.ContentTypeID=1 AND u.ContentId=CONVERT(nvarchar(200),r.MagazineID));
 EXEC sys.sp_addextendedproperty @name=N'MagazineReadsMigrated',@value=1,@level0type=N'SCHEMA',@level0name=N'Portal',@level1type=N'TABLE',@level1name=N'UserReads';
END;
COMMIT;
GO
CREATE OR ALTER PROCEDURE Portal.UserReads_Get @UserId int,@ContentTypeID int AS
BEGIN SET NOCOUNT ON;SELECT ContentId FROM Portal.UserReads WHERE UserId=@UserId AND ContentTypeID=@ContentTypeID AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserReads_MarkRead @UserId int,@ContentTypeID int,@ContentId nvarchar(200) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR NULLIF(LTRIM(RTRIM(@ContentId)),N'') IS NULL OR NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=@ContentTypeID AND Active=1) THROW 50012,'Invalid read identity.',1;
 BEGIN TRANSACTION;
 DECLARE @Active bit;
 SELECT @Active=Active FROM Portal.UserReads WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND ContentTypeID=@ContentTypeID AND ContentId=@ContentId;
 IF @Active IS NULL INSERT Portal.UserReads(UserId,ContentTypeID,ContentId) VALUES(@UserId,@ContentTypeID,@ContentId);
 ELSE IF @Active=0 UPDATE Portal.UserReads SET Active=1,ReadAt=GETDATE() WHERE UserId=@UserId AND ContentTypeID=@ContentTypeID AND ContentId=@ContentId;
 COMMIT;
END;
GO
-- Compatibility for callers of the old contracts; no duplicate storage.
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_Get @UserId int AS
BEGIN SET NOCOUNT ON;SELECT CONVERT(int,ContentId) MagazineID FROM Portal.UserReads WHERE UserId=@UserId AND ContentTypeID=1 AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_MarkRead @UserId int,@MagazineID int AS
BEGIN SET NOCOUNT ON;DECLARE @Id nvarchar(200)=CONVERT(nvarchar(200),@MagazineID);EXEC Portal.UserReads_MarkRead @UserId,1,@Id;END;
GO

GO


-- BEGIN 033_DecisionNotices.sql
USE CompanyPortal;
GO
IF OBJECT_ID(N'Portal.DecisionNoticeSettings',N'U') IS NULL
 CREATE TABLE Portal.DecisionNoticeSettings(
 SettingID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DecisionNoticeSettings PRIMARY KEY,
 ChannelID int NOT NULL CONSTRAINT UQ_DecisionNoticeSettings_Channel UNIQUE,
 DurationDays int NOT NULL,DecisionTypes nvarchar(4000) NOT NULL,
 LastChangeAt datetime NOT NULL CONSTRAINT DF_DecisionNoticeSettings_Changed DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_DecisionNoticeSettings_Active DEFAULT(1),
 CONSTRAINT CK_DecisionNoticeSettings_Channel CHECK(ChannelID IN(1,2)),
 CONSTRAINT CK_DecisionNoticeSettings_Days CHECK(DurationDays BETWEEN 1 AND 365),
 CONSTRAINT CK_DecisionNoticeSettings_Types CHECK(ISJSON(DecisionTypes)=1));
IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeSettings WHERE ChannelID=1) INSERT Portal.DecisionNoticeSettings(ChannelID,DurationDays,DecisionTypes) VALUES(1,7,N'["تنويه"]');
IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeSettings WHERE ChannelID=2) INSERT Portal.DecisionNoticeSettings(ChannelID,DurationDays,DecisionTypes) VALUES(2,7,N'["إعلان"]');
IF OBJECT_ID(N'Portal.DecisionNoticeWindows',N'U') IS NULL
 CREATE TABLE Portal.DecisionNoticeWindows(
 WindowID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DecisionNoticeWindows PRIMARY KEY,
 ChannelID int NOT NULL,DecisionId bigint NOT NULL,FromAt datetime NULL,ToAt datetime NULL,IsHidden bit NOT NULL DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_DecisionNoticeWindows_Changed DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_DecisionNoticeWindows_Active DEFAULT(1),
 CONSTRAINT UQ_DecisionNoticeWindows_Channel_Decision UNIQUE(ChannelID,DecisionId),
 CONSTRAINT FK_DecisionNoticeWindows_Channel FOREIGN KEY(ChannelID) REFERENCES Portal.DecisionNoticeSettings(ChannelID),
 CONSTRAINT CK_DecisionNoticeWindows_Dates CHECK((FromAt IS NULL AND ToAt IS NULL) OR (FromAt IS NOT NULL AND ToAt>FromAt)),
 CONSTRAINT CK_DecisionNoticeWindows_Id CHECK(DecisionId>0));
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNotices_Get AS
BEGIN SET NOCOUNT ON;SELECT ChannelID,DurationDays,DecisionTypes,LastChangeAt,Active FROM Portal.DecisionNoticeSettings ORDER BY ChannelID;
 SELECT ChannelID,DecisionId,FromAt,ToAt,IsHidden FROM Portal.DecisionNoticeWindows WHERE Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNotices_Save @ChannelID int,@DurationDays int,@DecisionTypes nvarchar(4000),@Active bit AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DurationDays NOT BETWEEN 1 AND 365 OR ISJSON(@DecisionTypes)<>1 OR LEFT(@DecisionTypes,1)<>'[' THROW 50012,'Invalid notice settings.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@DecisionTypes))>16 OR EXISTS(SELECT 1 FROM OPENJSON(@DecisionTypes) WHERE type<>1 OR LEN(value) NOT BETWEEN 1 AND 200) THROW 50012,'Invalid decision types.',1;
 UPDATE Portal.DecisionNoticeSettings SET DurationDays=@DurationDays,DecisionTypes=@DecisionTypes,Active=@Active,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND (DurationDays<>@DurationDays OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes)) OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes)) OR Active<>@Active);
END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNoticeWindows_Save @ChannelID int,@DecisionId bigint,@FromAt datetime=NULL,@ToAt datetime=NULL,@IsHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DecisionId<=0 OR (@FromAt IS NULL AND @ToAt IS NOT NULL) OR (@FromAt IS NOT NULL AND (@ToAt IS NULL OR @ToAt<=@FromAt)) THROW 50012,'Invalid notice window.',1;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WITH(UPDLOCK,HOLDLOCK) WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId)
 BEGIN
  IF @FromAt IS NOT NULL OR @IsHidden=1 INSERT Portal.DecisionNoticeWindows(ChannelID,DecisionId,FromAt,ToAt,IsHidden) VALUES(@ChannelID,@DecisionId,@FromAt,@ToAt,@IsHidden);
 END
 ELSE UPDATE Portal.DecisionNoticeWindows SET FromAt=@FromAt,ToAt=@ToAt,IsHidden=@IsHidden,Active=1,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId AND (ISNULL(FromAt,'17530101')<>ISNULL(@FromAt,'17530101') OR ISNULL(ToAt,'17530101')<>ISNULL(@ToAt,'17530101') OR IsHidden<>@IsHidden OR Active<>1);
 COMMIT;
END;
GO

GO


-- BEGIN 034_AddCircularNoticeType.sql
USE CompanyPortal;
GO
-- Add the requested type once, preserving the administrator's other settings.
-- The migration marker prevents a later rerun from undoing an intentional admin removal.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=1 AND major_id=OBJECT_ID(N'Portal.DecisionNoticeSettings') AND name=N'CircularNoticeTypeAdded')
BEGIN
 UPDATE Portal.DecisionNoticeSettings SET DecisionTypes=JSON_MODIFY(DecisionTypes,'append $',N'تعميم'),LastChangeAt=GETDATE()
 WHERE ChannelID=1 AND NOT EXISTS(SELECT 1 FROM OPENJSON(DecisionTypes) WHERE value=N'تعميم');
 EXEC sys.sp_addextendedproperty @name=N'CircularNoticeTypeAdded',@value=1,@level0type=N'SCHEMA',@level0name=N'Portal',@level1type=N'TABLE',@level1name=N'DecisionNoticeSettings';
END;
COMMIT;
GO

GO


-- BEGIN 035_UserDecisionDismissals.sql
USE CompanyPortal;
GO
IF OBJECT_ID(N'Portal.UserDecisionDismissals',N'U') IS NULL
 CREATE TABLE Portal.UserDecisionDismissals(
  UserDecisionDismissalID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserDecisionDismissals PRIMARY KEY,
  UserId int NOT NULL,DecisionId bigint NOT NULL,ChannelId int NOT NULL,
  DismissedAt datetime NOT NULL CONSTRAINT DF_UserDecisionDismissals_At DEFAULT(GETDATE()),
  Active bit NOT NULL CONSTRAINT DF_UserDecisionDismissals_Active DEFAULT(1),
  CONSTRAINT UQ_UserDecisionDismissals_User_Decision_Channel UNIQUE(UserId,DecisionId,ChannelId),
  CONSTRAINT CK_UserDecisionDismissals_IDs CHECK(UserId>0 AND DecisionId>0 AND ChannelId IN(1,2)));
GO
CREATE OR ALTER PROCEDURE Portal.UserDecisionDismissals_Get @UserId int,@ChannelId int AS
BEGIN SET NOCOUNT ON;SELECT DecisionId FROM Portal.UserDecisionDismissals WHERE UserId=@UserId AND ChannelId=@ChannelId AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserDecisionDismissals_Dismiss @UserId int,@DecisionId bigint,@ChannelId int AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @DecisionId<=0 OR @ChannelId NOT IN(1,2) THROW 50012,'Invalid dismissal identity.',1;
 BEGIN TRANSACTION;
 DECLARE @Active bit;
 SELECT @Active=Active FROM Portal.UserDecisionDismissals WITH(UPDLOCK,HOLDLOCK)
 WHERE UserId=@UserId AND DecisionId=@DecisionId AND ChannelId=@ChannelId;
 IF @Active IS NULL INSERT Portal.UserDecisionDismissals(UserId,DecisionId,ChannelId) VALUES(@UserId,@DecisionId,@ChannelId);
 ELSE IF @Active=0 UPDATE Portal.UserDecisionDismissals SET Active=1,DismissedAt=GETDATE() WHERE UserId=@UserId AND DecisionId=@DecisionId AND ChannelId=@ChannelId;
 -- Repeated closes are no-ops, preserving the original dismissal time.
 COMMIT;
END;
GO

GO


-- BEGIN 036_CurrentStatus.sql
-- Organization status (حالة المؤسسة) shown in the portal header.
-- ColorValue: 1 green, 2 yellow, 3 orange, 4 red. The current status is the most recently updated row.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'Mng') IS NULL EXEC(N'CREATE SCHEMA Mng');
GO
IF OBJECT_ID(N'Mng.CurrentStatus',N'U') IS NULL
 CREATE TABLE Mng.CurrentStatus
 (
  Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CurrentStatus PRIMARY KEY,
  ColorValue tinyint NOT NULL CONSTRAINT CK_CurrentStatus_ColorValue CHECK (ColorValue BETWEEN 1 AND 4),
  LastUpdated datetime NOT NULL CONSTRAINT DF_CurrentStatus_LastUpdated DEFAULT (GETDATE()),
  [No] int NULL
 );
GO
CREATE OR ALTER PROCEDURE Mng.CurrentStatus_get AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP (1) Id,ColorValue,LastUpdated,[No]
 FROM Mng.CurrentStatus
 ORDER BY LastUpdated DESC,Id DESC;
END;
GO

GO


-- BEGIN 037_UserPersonalId.sql
-- Employee PersonalID lookup (NTName → PersonalID) for the header profile photo.
-- This creates a safe default that returns no row (the portal then shows a placeholder).
-- Point it at the real security source with Integration/ConfigureUserPersonalId.sample.sql.
-- Rerunning this script never replaces an already configured procedure.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Security.User_getPersonalId',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Security.User_getPersonalId
    @Username nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(NULL AS bigint) AS PersonalID WHERE 1 = 0;
END;');
GO

GO


-- BEGIN 038_UserProfile.sql
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Employee name and title for the header profile panel (read-only integration contract).
-- Replace the SELECT internally with the real employee source; never return another user.
-- Keeps an existing mapped procedure unchanged when this migration is reapplied.
IF OBJECT_ID(N'Portal.UserProfile_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.UserProfile_Get @UserId int AS BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS nvarchar(300)) AS DisplayName, CAST(NULL AS nvarchar(300)) AS JobTitle,
 CAST(NULL AS nvarchar(300)) AS Department WHERE 1=0; END;');
GO

GO


-- BEGIN 039_HeaderContent.sql
-- Header content managed from /admin/header-content:
--   Mng.ImportantNumbers  → «أرقام تهمك» in the phone-directory dialog
--   Mng.StatusLevels      → titles/texts/steps for حالة المؤسسة (ColorValue 1 green … 4 red, as Mng.CurrentStatus)
-- Seeds reproduce the previous fixed text once; reruns keep edited rows.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'Mng') IS NULL EXEC(N'CREATE SCHEMA Mng');
GO
IF OBJECT_ID(N'Mng.ImportantNumbers',N'U') IS NULL
BEGIN
 CREATE TABLE Mng.ImportantNumbers
 (
  Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImportantNumbers PRIMARY KEY,
  Title nvarchar(150) NOT NULL,
  Number nvarchar(50) NOT NULL,
  SortOrder int NOT NULL CONSTRAINT DF_ImportantNumbers_SortOrder DEFAULT (0),
  Active bit NOT NULL CONSTRAINT DF_ImportantNumbers_Active DEFAULT (1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_ImportantNumbers_LastChangeAt DEFAULT (GETDATE())
 );
 INSERT Mng.ImportantNumbers(Title,Number,SortOrder) VALUES
  (N'طوارئ المؤسسة',N'1000',1),(N'فريق السلامة',N'1001',2),(N'الإسعافات الأولية',N'1002',3),
  (N'الأمن والاستقبال',N'1003',4),(N'الدعم التقني',N'1044',5);
END;
GO
IF OBJECT_ID(N'Mng.StatusLevels',N'U') IS NULL
BEGIN
 CREATE TABLE Mng.StatusLevels
 (
  ColorValue tinyint NOT NULL CONSTRAINT PK_StatusLevels PRIMARY KEY CONSTRAINT CK_StatusLevels_ColorValue CHECK (ColorValue BETWEEN 1 AND 4),
  Title nvarchar(100) NOT NULL,
  ColorName nvarchar(30) NOT NULL,
  Summary nvarchar(600) NOT NULL,
  GuideText nvarchar(300) NULL,
  Actions nvarchar(1500) NULL, -- one step per line
  LastChangeAt datetime NOT NULL CONSTRAINT DF_StatusLevels_LastChangeAt DEFAULT (GETDATE())
 );
 INSERT Mng.StatusLevels(ColorValue,Title,ColorName,Summary,GuideText,Actions) VALUES
  (1,N'الحالة الطبيعية',N'أخضر',N'العمل مستمر بصورة طبيعية. اتبع إجراءات العمل المعتادة وراقب القنوات الرسمية للتحديثات.',NULL,NULL),
  (2,N'تنبيه احترازي',N'أصفر',N'توجد حالة تستدعي الانتباه والاستعداد، مع استمرار العمل وفق الإجراءات المعتادة ما لم يصدر تحديث رسمي.',
     N'تابع التنبيهات، تأكد من وسائل التواصل، واستعد لأي تحديث في الإجراءات.',
     N'تابع قنوات المؤسسة الرسمية باستمرار.'+NCHAR(10)+N'تأكد من جاهزية وسائل التواصل وبيانات الاتصال.'+NCHAR(10)+N'راجع تعليمات السلامة الخاصة بموقعك.'),
  (3,N'حالة مرتفعة',N'برتقالي',N'ارتفع مستوى الحالة ويتطلب الأمر تقليل الحركة غير الضرورية ورفع الجاهزية حتى وصول تعليمات جديدة.',
     N'قلّل الحركة غير الضرورية والتزم بتوجيهات المسؤولين وخطة الاستجابة.',
     N'التزم بتوجيهات المسؤول المباشر وفريق السلامة.'+NCHAR(10)+N'أجّل التنقل والاجتماعات غير الضرورية.'+NCHAR(10)+N'جهّز المتطلبات الأساسية لخطة الاستجابة أو الإخلاء.'),
  (4,N'حالة طوارئ',N'أحمر',N'حالة طارئة تتطلب إيقاف الإجراءات الاعتيادية وتنفيذ التعليمات الرسمية بصورة فورية.',
     N'توقف عن العمل المعتاد ونفّذ تعليمات الطوارئ أو الإخلاء الصادرة فورًا.',
     N'توقف عن العمل المعتاد وحافظ على الهدوء.'+NCHAR(10)+N'نفّذ تعليمات الطوارئ أو الإخلاء فور صدورها.'+NCHAR(10)+N'توجه إلى نقطة التجمع ولا تعد إلى الموقع قبل التصريح.');
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_GetActive AS
BEGIN
 SET NOCOUNT ON;
 SELECT Id,Title,Number FROM Mng.ImportantNumbers WHERE Active=1 ORDER BY SortOrder,Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_GetAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT Id,Title,Number,SortOrder,Active,LastChangeAt FROM Mng.ImportantNumbers ORDER BY SortOrder,Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Save
 @Id int=NULL,@Title nvarchar(150),@Number nvarchar(50),@SortOrder int,@Active bit
AS
BEGIN
 SET NOCOUNT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @Number=LTRIM(RTRIM(@Number));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@Number,N'')=N'' THROW 50039,'Title and number are required.',1;
 IF @Id IS NULL
 BEGIN
  INSERT Mng.ImportantNumbers(Title,Number,SortOrder,Active) VALUES(@Title,@Number,@SortOrder,@Active);
  SELECT CAST(SCOPE_IDENTITY() AS int) AS Id;RETURN;
 END;
 UPDATE Mng.ImportantNumbers SET Title=@Title,Number=@Number,SortOrder=@SortOrder,Active=@Active,LastChangeAt=GETDATE() WHERE Id=@Id;
 IF @@ROWCOUNT=0 THROW 50011,'Important number not found.',1;
 SELECT @Id AS Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Delete @Id int AS
BEGIN
 SET NOCOUNT ON;
 DELETE Mng.ImportantNumbers WHERE Id=@Id;
 IF @@ROWCOUNT=0 THROW 50011,'Important number not found.',1;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_GetAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ColorValue,Title,ColorName,Summary,GuideText,Actions,LastChangeAt FROM Mng.StatusLevels ORDER BY ColorValue;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_Save
 @ColorValue tinyint,@Title nvarchar(100),@ColorName nvarchar(30),@Summary nvarchar(600),@GuideText nvarchar(300)=NULL,@Actions nvarchar(1500)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @ColorName=LTRIM(RTRIM(@ColorName));SET @Summary=LTRIM(RTRIM(@Summary));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@ColorName,N'')=N'' OR ISNULL(@Summary,N'')=N'' THROW 50039,'Title, colour name and description are required.',1;
 UPDATE Mng.StatusLevels SET Title=@Title,ColorName=@ColorName,Summary=@Summary,
  GuideText=NULLIF(LTRIM(RTRIM(@GuideText)),N''),Actions=NULLIF(LTRIM(RTRIM(@Actions)),N''),LastChangeAt=GETDATE()
 WHERE ColorValue=@ColorValue;
 IF @@ROWCOUNT=0 THROW 50011,'Status level not found.',1;
END;
GO

GO


-- BEGIN 040_FormsInbox.sql
USE CompanyPortal;
GO
-- Integration contracts only. Configure these SELECTs against the real Formsdb.
-- Rerunning setup must never overwrite an installed source adapter.
IF OBJECT_ID(N'Portal.Forms_Inbox_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Forms_Inbox_Get @UserId int,@FormId bigint=NULL AS
 BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS bigint) FormId,CAST(NULL AS nvarchar(100)) FormNumber,CAST(NULL AS nvarchar(1000)) Title,
 CAST(NULL AS nvarchar(500)) SenderName,CAST(NULL AS nvarchar(100)) Purpose,CAST(NULL AS datetime) SentAt,
 CAST(NULL AS bit) IsOpened,CAST(0 AS bit) IsSample WHERE 1=0; END');
GO
IF OBJECT_ID(N'Portal.Forms_UnreadCount_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Forms_UnreadCount_Get @UserId int AS
 BEGIN SET NOCOUNT ON;SELECT CAST(0 AS int) UnreadCount; END');
GO

GO


-- BEGIN 041_TechnicalServices.sql
USE CompanyPortal;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
-- Rename only the original system label; preserve a custom admin-supplied name.
UPDATE Master.Cards SET CardName=N'الخدمات الفنية',LastChangeAt=GETDATE()
WHERE CardKey=N'electronic-services' AND CardName IN(N'الخدمات الالكترونية',N'الخدمات الإلكترونية');
GO
-- Integration contracts: install once, preserve configured real-system adapters.
IF OBJECT_ID(N'Portal.Isnad_Recipients_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Isnad_Recipients_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Categories_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Categories_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Recipients_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Recipients_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Types_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Types_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Initiatives_Types_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Initiatives_Types_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Isnad_Create',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Isnad_Create @UserId int,@RecipientId int,@Details nvarchar(4000),@OfficeNumber nvarchar(100)=NULL,@DocumentNumber nvarchar(200)=NULL,@RequestKey uniqueidentifier=NULL AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Reports_Create',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Reports_Create @UserId int,@CategoryId int,@RecipientId int=NULL,@TypeId int=NULL,@Title nvarchar(500)=NULL,@Details nvarchar(4000)=NULL,@RequestKey uniqueidentifier=NULL AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Initiatives_Create',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Initiatives_Create @UserId int,@TypeId int,@Title nvarchar(500),@Details nvarchar(4000),@RequestKey uniqueidentifier=NULL AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical services source is not configured.'',1; END');
GO

GO


-- BEGIN 042_CorrespondenceInbox.sql
USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON;SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;SET ARITHABORT ON;SET NUMERIC_ROUNDABORT OFF;
GO
UPDATE Master.Cards SET CardName=N'مراسلات',LastChangeAt=GETDATE() WHERE CardKey=N'inbox' AND CardName=N'مرسالات';
GO
-- Contracts only: preserve configured real-system adapters on rerun.
IF OBJECT_ID(N'Portal.Correspondence_Inbox_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Correspondence_Inbox_Get @UserId int,@CorrespondenceId bigint=NULL AS
 BEGIN SET NOCOUNT ON;THROW 50030,''Correspondence source is not configured.'',1;END');
GO
IF OBJECT_ID(N'Portal.Correspondence_UnreadCount_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Correspondence_UnreadCount_Get @UserId int AS
 BEGIN SET NOCOUNT ON;THROW 50030,''Correspondence source is not configured.'',1;END');
GO

GO


-- BEGIN 043_AdminAccess.sql
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

GO


-- BEGIN 044_AdminChanges.sql
USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON;SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;SET ARITHABORT ON;SET NUMERIC_ROUNDABORT OFF;
GO
/* Admin change history. Every admin save procedure takes @ChangedBy (the employee's Windows name, passed by
   the API; falls back to ORIGINAL_LOGIN() for direct SQL calls), snapshots the item before (after its locks)
   and after (before COMMIT), and calls Portal.AdminChanges_Add inside the same transaction. No-op saves are
   not recorded. Snapshots exclude LastChangeAt and binary image data.
   Later migrations that ALTER these procedures must keep the history lines. */
IF OBJECT_ID(N'Portal.AdminChanges',N'U') IS NULL
CREATE TABLE Portal.AdminChanges(
 AdminChangeId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AdminChanges PRIMARY KEY,
 ChangedAt datetime NOT NULL CONSTRAINT DF_AdminChanges_ChangedAt DEFAULT GETDATE(),
 ChangedBy nvarchar(512) NOT NULL,
 Section varchar(40) NOT NULL,
 Action varchar(20) NOT NULL CONSTRAINT CK_AdminChanges_Action CHECK(Action IN('create','update','delete','apply-to-all')),
 ItemType varchar(40) NOT NULL,
 ItemId nvarchar(100) NOT NULL,
 ItemTitle nvarchar(300) NULL,
 OldJson nvarchar(max) NULL,
 NewJson nvarchar(max) NULL);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_AdminChanges_Section' AND object_id=OBJECT_ID(N'Portal.AdminChanges'))
 CREATE INDEX IX_AdminChanges_Section ON Portal.AdminChanges(Section,AdminChangeId DESC);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_AdminChanges_Item' AND object_id=OBJECT_ID(N'Portal.AdminChanges'))
 CREATE INDEX IX_AdminChanges_Item ON Portal.AdminChanges(Section,ItemType,ItemId,AdminChangeId DESC);
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_Add
 @ChangedBy nvarchar(512)=NULL,@Section varchar(40),@ItemType varchar(40),@ItemId nvarchar(100),@ItemTitle nvarchar(300)=NULL,
 @OldJson nvarchar(max)=NULL,@NewJson nvarchar(max)=NULL,@Action varchar(20)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @OldJson IS NULL AND @NewJson IS NULL RETURN;
 IF @Action IS NULL AND @OldJson COLLATE Latin1_General_100_BIN2=@NewJson COLLATE Latin1_General_100_BIN2 RETURN; -- no-op save
 INSERT Portal.AdminChanges(ChangedBy,Section,Action,ItemType,ItemId,ItemTitle,OldJson,NewJson)
 VALUES(COALESCE(NULLIF(LTRIM(RTRIM(@ChangedBy)),N''),ORIGINAL_LOGIN()),@Section,
  COALESCE(@Action,CASE WHEN @OldJson IS NULL THEN 'create' WHEN @NewJson IS NULL THEN 'delete' ELSE 'update' END),
  @ItemType,@ItemId,LEFT(@ItemTitle,300),@OldJson,@NewJson);
END;
GO
-- Item snapshots (JSON). NULL when the item does not exist.
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Card(@CardId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT c.CardName,c.CardType,c.DisplayOrder,c.IsFixed,c.Active,c.Audience,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(CONVERT(nvarchar(20),a.AppId),N',') WITHIN GROUP(ORDER BY a.AppId) FROM [Master].CardApplications a WHERE a.CardId=c.CardId AND a.Active=1),N'')+N']') Apps,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(N'"'+STRING_ESCAPE(r.RoleName,'json')+N'"',N',') WITHIN GROUP(ORDER BY r.RoleName) FROM [Master].CardRoles r WHERE r.CardId=c.CardId AND r.Active=1),N'')+N']') Roles
  FROM [Master].Cards c WHERE c.CardId=@CardId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_ApplicationCategory(@CategoryId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT CategoryName,DisplayOrder,Active FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Application(@AppId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT d.AppDescription [Description],d.ApplicationCategoryId CategoryId,c.CategoryName Category,d.Active
  FROM [Master].ApplicationDetails d LEFT JOIN [Master].ApplicationCategories c ON c.ApplicationCategoryId=d.ApplicationCategoryId
  WHERE d.AppId=@AppId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_DocumentTab(@DocumentTabID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT t.TabName,t.SectionKey,t.FolderID,t.DisplayOrder,t.Active,
  JSON_QUERY((SELECT i.DocumentID,d.DocumentName FROM Portal.DocumentTabItems i LEFT JOIN Mng.Document d ON d.DocumentID=i.DocumentID
   WHERE i.DocumentTabID=t.DocumentTabID ORDER BY i.DocumentID FOR JSON PATH,INCLUDE_NULL_VALUES)) Documents
  FROM Portal.DocumentTabs t WHERE t.DocumentTabID=@DocumentTabID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_FixedOrder(@FixedOrderID bigint) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT [Timestamp],Timestamp2,TimestampType,ContentBefor,ContentAfter,ContentText FROM Portal.FixedOrders WHERE FixedOrderID=@FixedOrderID
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_NoticeSettings(@ChannelID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT DurationDays,JSON_QUERY(CASE WHEN ISJSON(DecisionTypes)=1 THEN DecisionTypes END) DecisionTypes,Active
  FROM Portal.DecisionNoticeSettings WHERE ChannelID=@ChannelID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_NoticeWindow(@ChannelID int,@DecisionId bigint) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT DecisionId,FromAt,ToAt,IsHidden,Active FROM Portal.DecisionNoticeWindows WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Media(@MediaID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT MediaName,MediaType,MediaPath,MediaGroupID,DisplayOrder,Active FROM Portal.Media WHERE MediaID=@MediaID
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_MediaGroup(@MediaGroupID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT GroupName,CoverMediaID,DisplayOrder,Active FROM Portal.MediaGroups WHERE MediaGroupID=@MediaGroupID
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Image(@ImageId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT ImageName,ContentType,PixelWidth,PixelHeight,Active FROM [Master].Images WHERE ImageId=@ImageId
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_ImageGroup(@ImageGroupId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT g.GroupName,g.RotateImages,g.RotationSeconds,g.DefaultImageId,g.Active,
  JSON_QUERY((SELECT i.ImageId,i.DisplayOrder,i.Active FROM [Master].ImageGroupItems i WHERE i.ImageGroupId=g.ImageGroupId
   ORDER BY i.DisplayOrder,i.ImageId FOR JSON PATH)) Items
  FROM [Master].ImageGroups g WHERE g.ImageGroupId=@ImageGroupId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Theme(@ThemeId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT t.ThemeName,t.LayoutKey,t.DisplayOrder,t.IsDefault,t.Active,t.Visibility,t.Deleted,t.PrimaryColor,t.AccentColor,t.BackgroundColor,
  t.OverlayOpacity,t.ForegroundPreset,t.ImagePresentation,t.ImageGroupId,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(N'"'+STRING_ESCAPE(r.RoleName,'json')+N'"',N',') WITHIN GROUP(ORDER BY r.RoleName) FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=t.ThemeId AND r.Active=1),N'')+N']') PreviewRoles
  FROM [Master].Themes t WHERE t.ThemeId=@ThemeId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_ImportantNumber(@Id int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT Title,Number,SortOrder,Active FROM Mng.ImportantNumbers WHERE Id=@Id FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_StatusLevel(@ColorValue tinyint) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT Title,ColorName,Summary,GuideText,Actions FROM Mng.StatusLevels WHERE ColorValue=@ColorValue FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO

/* ===== Admin save procedures (bodies unchanged except the lines marked -- history) ===== */

CREATE OR ALTER PROCEDURE [Master].ApplicationCategories_save
 @CategoryName nvarchar(200),@DisplayOrder int,@Active bit,@CategoryId int=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET @CategoryName=LTRIM(RTRIM(@CategoryName));
 IF @CategoryName IS NULL OR LEN(@CategoryName)=0 OR @DisplayOrder IS NULL OR @DisplayOrder<0 OR @Active IS NULL
  THROW 50012,'Check category name, order and availability.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ApplicationCategories',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50012,'Category settings busy. Retry.',1;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId)
  THROW 50011,'Category not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].ApplicationCategories WHERE CategoryName=@CategoryName AND (@CategoryId IS NULL OR ApplicationCategoryId<>@CategoryId))
  THROW 50012,'Category name already exists.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_ApplicationCategory(@CategoryId); -- history
 IF @CategoryId IS NULL
 BEGIN
  INSERT [Master].ApplicationCategories(CategoryName,DisplayOrder,Active) VALUES(@CategoryName,@DisplayOrder,@Active);
  SET @CategoryId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE UPDATE [Master].ApplicationCategories SET CategoryName=@CategoryName,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE ApplicationCategoryId=@CategoryId AND EXISTS(
  SELECT @CategoryName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@Active EXCEPT SELECT CategoryName COLLATE Latin1_General_100_BIN2,DisplayOrder,Active FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_ApplicationCategory(@CategoryId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='applications',@ItemType='category',@ItemId=@CategoryId,@ItemTitle=@CategoryName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @CategoryId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_save
 @AppId int,@Description nvarchar(2000),@CategoryId int=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @Description IS NULL THROW 50012,'Supply a description, optionally empty.',1;
 SET @Description=LTRIM(RTRIM(@Description));
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 IF NOT EXISTS(SELECT 1 FROM @Apps WHERE AppId=@AppId) THROW 50011,'Application not found in current catalog.',1;
 DECLARE @AppName nvarchar(200)=(SELECT AppName FROM @Apps WHERE AppId=@AppId); -- history
 BEGIN TRY
 BEGIN TRAN;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WITH(HOLDLOCK) WHERE ApplicationCategoryId=@CategoryId)
  THROW 50012,'Category not found.',1;
 DECLARE @Existing int=(SELECT ApplicationDetailId FROM [Master].ApplicationDetails WITH(UPDLOCK,HOLDLOCK) WHERE AppId=@AppId);
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Application(@AppId); -- history
 IF @Existing IS NULL
  INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription) VALUES(@AppId,@CategoryId,@Description);
 ELSE
  UPDATE [Master].ApplicationDetails SET ApplicationCategoryId=@CategoryId,AppDescription=@Description,Active=1,LastChangeAt=GETDATE()
  WHERE ApplicationDetailId=@Existing AND (Active=0 OR EXISTS(
   SELECT @CategoryId,@Description COLLATE Latin1_General_100_BIN2 EXCEPT SELECT ApplicationCategoryId,AppDescription COLLATE Latin1_General_100_BIN2 FROM [Master].ApplicationDetails WHERE ApplicationDetailId=@Existing));
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Application(@AppId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='applications',@ItemType='application',@ItemId=@AppId,@ItemTitle=@AppName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_save
 @CardName nvarchar(200),@IsFixed bit,@DisplayOrder int,@Active bit,@Audience nvarchar(20),
 @AppsJson nvarchar(max),@RolesJson nvarchar(max),@CardId int=NULL,@ChangedBy nvarchar(512)=NULL
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
 IF @CardName IS NULL OR LEN(@CardName)=0 OR @IsFixed IS NULL OR @Active IS NULL
 OR @DisplayOrder IS NULL OR @DisplayOrder<1 OR @Audience NOT IN(N'everyone',N'roles') OR @Audience IS NULL
 OR ISJSON(@AppsJson)<>1 OR ISJSON(@RolesJson)<>1
  THROW 50006,'Check card details.',1;
 DECLARE @Apps TABLE(AppId int PRIMARY KEY);
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@AppsJson) WHERE type<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value)<1)
 OR EXISTS(SELECT 1 FROM OPENJSON(@RolesJson) WHERE type<>1 OR LEN(value)>200 OR LEN(LTRIM(RTRIM(value)))=0)
  THROW 50006,'Invalid applications or roles.',1;
 INSERT @Apps SELECT DISTINCT CONVERT(int,value) FROM OPENJSON(@AppsJson);
 INSERT @Roles SELECT DISTINCT CONVERT(nvarchar(200),value) COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@RolesJson);
 IF (SELECT COUNT(*) FROM @Apps)>100 OR (SELECT COUNT(*) FROM @Roles)>50
 OR (@Audience=N'roles' AND NOT EXISTS(SELECT 1 FROM @Roles))
 OR (@Audience=N'everyone' AND EXISTS(SELECT 1 FROM @Roles)) THROW 50006,'Check audience roles.',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MasterCards',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50006,'Card settings are busy. Retry.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Card(@CardId); -- history
 DECLARE @Type nvarchar(30)=N'applications';
 IF @CardId IS NOT NULL
 BEGIN
  SELECT @Type=CardType FROM [Master].Cards WITH(UPDLOCK,HOLDLOCK) WHERE CardId=@CardId;
  IF NOT EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId=@CardId AND (CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services')))
   THROW 50006,'Select an available card.',1;
 END;
 IF (@Type=N'applications' AND NOT EXISTS(SELECT 1 FROM @Apps)) OR (@Type=N'connected' AND EXISTS(SELECT 1 FROM @Apps))
  THROW 50006,'Application cards require apps; connected cards do not accept app membership.',1;
 -- Validate membership against the current approved catalog, not employee grants.
 IF @Type=N'applications'
 BEGIN
  DECLARE @Catalog TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
  INSERT @Catalog EXEC Security.Apps_getForAdministration;
  IF EXISTS(SELECT 1 FROM @Apps a LEFT JOIN @Catalog c ON c.AppId=a.AppId WHERE c.AppId IS NULL)
   THROW 50006,'Select applications from the current catalog.',1;
 END;
 IF @CardId IS NULL
 BEGIN
  IF (SELECT COUNT(*) FROM [Master].Cards WHERE CardType=N'applications')>=100 THROW 50006,'Application card limit reached.',1;
  INSERT [Master].Cards(CardKey,CardName,DisplayOrder,IsFixed,Active,CardType,Audience)
  VALUES(N'master-'+LOWER(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')),@CardName,@DisplayOrder,0,0,N'applications',@Audience);
  SET @CardId=CONVERT(int,SCOPE_IDENTITY());
 END;
 DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1 AND CardId<>@CardId)+CONVERT(int,@Active);
 IF (@Active=1 AND @DisplayOrder>CASE WHEN @Count=0 THEN 1 ELSE @Count END)
 OR @DisplayOrder>200
 OR (@Active=1 AND @IsFixed=1 AND EXISTS(SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND CardId<>@CardId AND DisplayOrder=@DisplayOrder))
 OR EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId<>@CardId AND Active=1 AND IsFixed=1 AND DisplayOrder>@Count)
  THROW 50006,'Check position and other fixed slots before hiding or moving cards.',1;
 DECLARE @Changed bit=0;
 IF EXISTS(SELECT @CardName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@IsFixed,@Active,@Audience
  EXCEPT SELECT CardName COLLATE Latin1_General_100_BIN2,DisplayOrder,IsFixed,Active,Audience FROM [Master].Cards WHERE CardId=@CardId)
 OR EXISTS(SELECT AppId FROM @Apps EXCEPT SELECT AppId FROM [Master].CardApplications WHERE CardId=@CardId AND Active=1)
 OR EXISTS(SELECT AppId FROM [Master].CardApplications WHERE CardId=@CardId AND Active=1 EXCEPT SELECT AppId FROM @Apps)
 OR EXISTS(SELECT RoleName FROM @Roles EXCEPT SELECT RoleName FROM [Master].CardRoles WHERE CardId=@CardId AND Active=1)
 OR EXISTS(SELECT RoleName FROM [Master].CardRoles WHERE CardId=@CardId AND Active=1 EXCEPT SELECT RoleName FROM @Roles)
  SET @Changed=1;
 IF @Changed=1
 UPDATE [Master].Cards SET CardName=@CardName,DisplayOrder=@DisplayOrder,IsFixed=@IsFixed,Active=@Active,Audience=@Audience,LastChangeAt=GETDATE() WHERE CardId=@CardId;
 UPDATE a SET Active=CASE WHEN s.AppId IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM [Master].CardApplications a LEFT JOIN @Apps s ON s.AppId=a.AppId
 WHERE a.CardId=@CardId AND a.Active<>CASE WHEN s.AppId IS NULL THEN 0 ELSE 1 END;
 INSERT [Master].CardApplications(CardId,AppId) SELECT @CardId,a.AppId FROM @Apps a WHERE NOT EXISTS(SELECT 1 FROM [Master].CardApplications x WHERE x.CardId=@CardId AND x.AppId=a.AppId);
 UPDATE r SET Active=CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM [Master].CardRoles r LEFT JOIN @Roles s ON s.RoleName=r.RoleName
 WHERE r.CardId=@CardId AND r.Active<>CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END;
 INSERT [Master].CardRoles(CardId,RoleName) SELECT @CardId,r.RoleName FROM @Roles r WHERE NOT EXISTS(SELECT 1 FROM [Master].CardRoles x WHERE x.CardId=@CardId AND x.RoleName=r.RoleName);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Card(@CardId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='cards',@ItemType='card',@ItemId=@CardId,@ItemTitle=@CardName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @CardId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].ImageGroups_save
 @ImageGroupId int=NULL, @GroupName nvarchar(200), @RotateImages bit, @RotationSeconds int,
 @DefaultImageId int=NULL, @Active bit, @Items [Master].ImageSelection READONLY, @ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
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
   SET @Before=Portal.AdminSnapshot_ImageGroup(@ImageGroupId); -- history
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
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_ImageGroup(@ImageGroupId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image-group',@ItemId=@ImageGroupId,@ItemTitle=@GroupName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @ImageGroupId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_add
 @ImageName nvarchar(200), @ContentType nvarchar(100), @ImageData varbinary(max), @PixelWidth int, @PixelHeight int, @ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: insert and history row commit together
 IF LEN(LTRIM(RTRIM(@ImageName)))=0 THROW 50007,'Image name is required.',1;
 BEGIN TRANSACTION; -- history
 INSERT [Master].Images(ImageName,ContentType,ImageData,PixelWidth,PixelHeight)
 VALUES(@ImageName,@ContentType,@ImageData,@PixelWidth,@PixelHeight);
 DECLARE @ImageId int=CAST(SCOPE_IDENTITY() AS int); -- history
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image',@ItemId=@ImageId,@ItemTitle=@ImageName,@NewJson=@After; -- history
 COMMIT; -- history
 SELECT @ImageId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_delete @ImageId int,@ChangedBy nvarchar(512)=NULL
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
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId); -- history
 UPDATE [Master].Images SET Active=0,LastChangeAt=GETDATE() WHERE ImageId=@ImageId;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId),@ImageName nvarchar(200)=JSON_VALUE(@Before,'$.ImageName'); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image',@ItemId=@ImageId,@ItemTitle=@ImageName,@OldJson=@Before,@NewJson=@After,@Action='delete'; -- history
 COMMIT;
 SELECT CAST(1 AS bit);
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_applyToAll @ThemeId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND Active=1 AND Deleted=0 AND Visibility=N'public')
 THROW 50008,'Only live public themes can be applied to everyone.',1;
 DECLARE @OldDefault int=(SELECT TOP(1) ThemeId FROM [Master].Themes WHERE IsDefault=1 AND ThemeId<>@ThemeId ORDER BY ThemeId); -- history
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId),@OldBefore nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault); -- history
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND ThemeId<>@ThemeId;
 UPDATE [Master].Themes SET IsDefault=1,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND IsDefault=0;
 UPDATE Portal.UserSettings SET ThemeId=@ThemeId,LastChangeAt=GETDATE() WHERE Active=1 AND ThemeId<>@ThemeId;
 DECLARE @UsersUpdated int=@@ROWCOUNT; -- history
 DECLARE @After nvarchar(max)=JSON_MODIFY(Portal.AdminSnapshot_Theme(@ThemeId),'$.UsersUpdated',@UsersUpdated),@Title nvarchar(200)=JSON_VALUE(@Before,'$.ThemeName'); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After,@Action='apply-to-all'; -- history
 IF @OldDefault IS NOT NULL -- history: the previous default loses IsDefault
 BEGIN
  DECLARE @OldAfter nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault),@OldTitle nvarchar(200)=JSON_VALUE(@OldBefore,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@OldDefault,@ItemTitle=@OldTitle,@OldJson=@OldBefore,@NewJson=@OldAfter;
 END;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_delete @ThemeId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) THROW 50008,'Choose another default first.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 UPDATE [Master].Themes SET Deleted=1,Active=0,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND Deleted=0;
 DECLARE @Found bit=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
 IF @Found=1 -- history
 BEGIN
  DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId),@Title nvarchar(200)=JSON_VALUE(@Before,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After,@Action='delete';
 END;
 COMMIT; SELECT @Found;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL,@Visibility nvarchar(20)=NULL,@PreviewRolesJson nvarchar(max)=N'[]',
 @ChangedBy nvarchar(512)=NULL
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
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 DECLARE @OldDefault int=(SELECT TOP(1) ThemeId FROM [Master].Themes WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId) ORDER BY ThemeId); -- history
 DECLARE @OldBefore nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault); -- history
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
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@ThemeName,@OldJson=@Before,@NewJson=@After; -- history
 IF @OldDefault IS NOT NULL -- history: a new default clears the previous one (no-op otherwise)
 BEGIN
  DECLARE @OldAfter nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault),@OldTitle nvarchar(200)=JSON_VALUE(@OldBefore,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@OldDefault,@ItemTitle=@OldTitle,@OldJson=@OldBefore,@NewJson=@OldAfter;
 END;
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_setImageGroup @ThemeId int,@ImageGroupId int=NULL,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Select an active image group.',1; END;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Theme was not found.',1; END;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 UPDATE [Master].Themes SET ImageGroupId=@ImageGroupId,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND Active=1 AND ISNULL(ImageGroupId,0)<>ISNULL(@ImageGroupId,0);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId),@Title nvarchar(200)=JSON_VALUE(@Before,'$.ThemeName'); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Delete @Id int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: delete and history row commit together
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_ImportantNumber(Id) FROM Mng.ImportantNumbers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
 DELETE Mng.ImportantNumbers WHERE Id=@Id;
 IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Important number not found.',1; END;
 DECLARE @Title nvarchar(150)=JSON_VALUE(@Before,'$.Title');
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='important-number',@ItemId=@Id,@ItemTitle=@Title,@OldJson=@Before;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Save
 @Id int=NULL,@Title nvarchar(150),@Number nvarchar(50),@SortOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: save and history row commit together
 SET @Title=LTRIM(RTRIM(@Title));SET @Number=LTRIM(RTRIM(@Number));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@Number,N'')=N'' THROW 50039,'Title and number are required.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max),@After nvarchar(max);
 IF @Id IS NULL
 BEGIN
  INSERT Mng.ImportantNumbers(Title,Number,SortOrder,Active) VALUES(@Title,@Number,@SortOrder,@Active);
  SET @Id=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 BEGIN
  SET @Before=(SELECT Portal.AdminSnapshot_ImportantNumber(Id) FROM Mng.ImportantNumbers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
  UPDATE Mng.ImportantNumbers SET Title=@Title,Number=@Number,SortOrder=@SortOrder,Active=@Active,LastChangeAt=GETDATE() WHERE Id=@Id;
  IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Important number not found.',1; END;
 END;
 SET @After=Portal.AdminSnapshot_ImportantNumber(@Id);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='important-number',@ItemId=@Id,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After;
 COMMIT;
 SELECT @Id AS Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_Save
 @ColorValue tinyint,@Title nvarchar(100),@ColorName nvarchar(30),@Summary nvarchar(600),@GuideText nvarchar(300)=NULL,@Actions nvarchar(1500)=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: save and history row commit together
 SET @Title=LTRIM(RTRIM(@Title));SET @ColorName=LTRIM(RTRIM(@ColorName));SET @Summary=LTRIM(RTRIM(@Summary));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@ColorName,N'')=N'' OR ISNULL(@Summary,N'')=N'' THROW 50039,'Title, colour name and description are required.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_StatusLevel(ColorValue) FROM Mng.StatusLevels WITH(UPDLOCK,HOLDLOCK) WHERE ColorValue=@ColorValue);
 UPDATE Mng.StatusLevels SET Title=@Title,ColorName=@ColorName,Summary=@Summary,
  GuideText=NULLIF(LTRIM(RTRIM(@GuideText)),N''),Actions=NULLIF(LTRIM(RTRIM(@Actions)),N''),LastChangeAt=GETDATE()
 WHERE ColorValue=@ColorValue;
 IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Status level not found.',1; END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_StatusLevel(@ColorValue);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='status-level',@ItemId=@ColorValue,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNotices_Save @ChannelID int,@DurationDays int,@DecisionTypes nvarchar(4000),@Active bit,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DurationDays NOT BETWEEN 1 AND 365 OR ISJSON(@DecisionTypes)<>1 OR LEFT(@DecisionTypes,1)<>'[' THROW 50012,'Invalid notice settings.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@DecisionTypes))>16 OR EXISTS(SELECT 1 FROM OPENJSON(@DecisionTypes) WHERE type<>1 OR LEN(value) NOT BETWEEN 1 AND 200) THROW 50012,'Invalid decision types.',1;
 BEGIN TRANSACTION; -- history
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_NoticeSettings(ChannelID) FROM Portal.DecisionNoticeSettings WITH(UPDLOCK,HOLDLOCK) WHERE ChannelID=@ChannelID); -- history
 UPDATE Portal.DecisionNoticeSettings SET DurationDays=@DurationDays,DecisionTypes=@DecisionTypes,Active=@Active,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND (DurationDays<>@DurationDays OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes)) OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes)) OR Active<>@Active);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_NoticeSettings(@ChannelID), -- history
  @Section varchar(40)=CASE WHEN @ChannelID=1 THEN 'notices' ELSE 'alerts' END,@Title nvarchar(50)=CASE WHEN @ChannelID=1 THEN N'التنويهات' ELSE N'التنبيهات' END;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section=@Section,@ItemType='notice-settings',@ItemId=@ChannelID,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT; -- history
END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNoticeWindows_Save @ChannelID int,@DecisionId bigint,@FromAt datetime=NULL,@ToAt datetime=NULL,@IsHidden bit=0,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DecisionId<=0 OR (@FromAt IS NULL AND @ToAt IS NOT NULL) OR (@FromAt IS NOT NULL AND (@ToAt IS NULL OR @ToAt<=@FromAt)) THROW 50012,'Invalid notice window.',1;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WITH(UPDLOCK,HOLDLOCK) WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId)
 BEGIN
  IF @FromAt IS NOT NULL OR @IsHidden=1 INSERT Portal.DecisionNoticeWindows(ChannelID,DecisionId,FromAt,ToAt,IsHidden) VALUES(@ChannelID,@DecisionId,@FromAt,@ToAt,@IsHidden);
 END
 ELSE
 BEGIN
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_NoticeWindow(@ChannelID,@DecisionId); -- history
 UPDATE Portal.DecisionNoticeWindows SET FromAt=@FromAt,ToAt=@ToAt,IsHidden=@IsHidden,Active=1,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId AND (ISNULL(FromAt,'17530101')<>ISNULL(@FromAt,'17530101') OR ISNULL(ToAt,'17530101')<>ISNULL(@ToAt,'17530101') OR IsHidden<>@IsHidden OR Active<>1);
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_NoticeWindow(@ChannelID,@DecisionId), -- history
  @Section varchar(40)=CASE WHEN @ChannelID=1 THEN 'notices' ELSE 'alerts' END,@ItemId nvarchar(100)=CONCAT(@ChannelID,N':',@DecisionId);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section=@Section,@ItemType='notice-window',@ItemId=@ItemId,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Save
 @DocumentTabID int=NULL,@TabName nvarchar(200),@FolderID int,@DisplayOrder int,@Active bit,@DocumentIds nvarchar(max),@SectionKey nvarchar(30)=N'documents',@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @SectionKey NOT IN(N'documents',N'safety') THROW 50012,'Invalid section.',1;
 IF NULLIF(LTRIM(RTRIM(@TabName)),N'') IS NULL OR @DisplayOrder<0 OR ISJSON(@DocumentIds)<>1
  THROW 50012,'Invalid document tab.',1;
 DECLARE @Items TABLE(DocumentID uniqueidentifier NOT NULL PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@DocumentIds) WHERE TRY_CONVERT(uniqueidentifier,value) IS NULL)
  THROW 50012,'Invalid document selection.',1;
 INSERT @Items SELECT DISTINCT CONVERT(uniqueidentifier,value) FROM OPENJSON(@DocumentIds);
 IF NOT EXISTS(SELECT 1 FROM @Items) OR (SELECT COUNT(*) FROM @Items)>500
  THROW 50012,'Select between one and 500 PDF documents.',1;
 IF @SectionKey=N'safety' AND (SELECT COUNT(*) FROM @Items)<>1 THROW 50012,'Select one PDF per safety booklet.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN Mng.Document d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentID=i.DocumentID
  WHERE d.DocumentID IS NULL OR d.FolderID<>@FolderID OR d.Active<>1 OR LOWER(RIGHT(d.DocumentPath,4))<>N'.pdf')
  THROW 50012,'Selection must contain active PDFs from the selected folder.',1;
 IF @DocumentTabID IS NULL
 BEGIN
  INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder,Active,SectionKey) VALUES(@TabName,@FolderID,@DisplayOrder,@Active,@SectionKey);
  SET @DocumentTabID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.DocumentTabs WITH(UPDLOCK,HOLDLOCK) WHERE DocumentTabID=@DocumentTabID AND SectionKey=@SectionKey)
   THROW 50011,'Document tab not found.',1;
  SET @Before=Portal.AdminSnapshot_DocumentTab(@DocumentTabID); -- history
  UPDATE Portal.DocumentTabs SET TabName=@TabName,FolderID=@FolderID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE DocumentTabID=@DocumentTabID AND SectionKey=@SectionKey AND (TabName COLLATE Latin1_General_100_BIN2<>@TabName COLLATE Latin1_General_100_BIN2
   OR FolderID<>@FolderID OR DisplayOrder<>@DisplayOrder OR Active<>@Active
   OR EXISTS(SELECT DocumentID FROM @Items EXCEPT SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID)
   OR EXISTS(SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID EXCEPT SELECT DocumentID FROM @Items));
 END;
 DELETE Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID AND DocumentID NOT IN(SELECT DocumentID FROM @Items);
 INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
 SELECT @DocumentTabID,DocumentID FROM @Items i WHERE NOT EXISTS(
  SELECT 1 FROM Portal.DocumentTabItems t WHERE t.DocumentTabID=@DocumentTabID AND t.DocumentID=i.DocumentID);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_DocumentTab(@DocumentTabID),@Section varchar(40)=@SectionKey; -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section=@Section,@ItemType='tab',@ItemId=@DocumentTabID,@ItemTitle=@TabName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @DocumentTabID;
END;
GO
-- Preserve the explicitly agreed table shape and existing records.
CREATE OR ALTER PROCEDURE Portal.FixedOrders_Save
 @FixedOrderID bigint=NULL,@Timestamp date=NULL,@Timestamp2 date=NULL,
 @ContentBefor nvarchar(500)=NULL,@ContentAfter nvarchar(1000),@ContentText nvarchar(1000),@TimestampType int,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ContentAfter)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@ContentText)),N'') IS NULL
  OR (CHARINDEX(N'ds{0}de',@ContentText)>0 AND NULLIF(LTRIM(RTRIM(@ContentBefor)),N'') IS NULL)
  THROW 50012,'Provide title, wording and any referenced previous text.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
 IF @FixedOrderID IS NULL
 BEGIN
  INSERT Portal.FixedOrders([Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType)
  VALUES(@Timestamp,@Timestamp2,@ContentBefor,@ContentAfter,@ContentText,@TimestampType);
  SET @FixedOrderID=CONVERT(bigint,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.FixedOrders WITH(UPDLOCK,HOLDLOCK) WHERE FixedOrderID=@FixedOrderID)
   THROW 50011,'Fixed order not found.',1;
  SET @Before=Portal.AdminSnapshot_FixedOrder(@FixedOrderID); -- history
  UPDATE Portal.FixedOrders SET [Timestamp]=@Timestamp,Timestamp2=@Timestamp2,ContentBefor=@ContentBefor,
   ContentAfter=@ContentAfter,ContentText=@ContentText,TimestampType=@TimestampType
  WHERE FixedOrderID=@FixedOrderID AND (EXISTS(
   SELECT [Timestamp],Timestamp2,ContentBefor COLLATE Latin1_General_100_BIN2,ContentAfter COLLATE Latin1_General_100_BIN2,ContentText COLLATE Latin1_General_100_BIN2,TimestampType
   EXCEPT SELECT @Timestamp,@Timestamp2,@ContentBefor COLLATE Latin1_General_100_BIN2,@ContentAfter COLLATE Latin1_General_100_BIN2,@ContentText COLLATE Latin1_General_100_BIN2,@TimestampType)
   OR ISNULL(DATALENGTH(ContentBefor),-1)<>ISNULL(DATALENGTH(@ContentBefor),-1)
   OR ISNULL(DATALENGTH(ContentAfter),-1)<>ISNULL(DATALENGTH(@ContentAfter),-1)
   OR ISNULL(DATALENGTH(ContentText),-1)<>ISNULL(DATALENGTH(@ContentText),-1));
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_FixedOrder(@FixedOrderID),@Title nvarchar(300)=LEFT(@ContentAfter,300); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='fixed-orders',@ItemType='directive',@ItemId=@FixedOrderID,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @FixedOrderID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Media_Save
 @MediaID int=NULL,@MediaName nvarchar(300),@MediaPath nvarchar(2000),@MediaType nvarchar(20),@MediaGroupID int=NULL,@DisplayOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@MediaName)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@MediaPath)),N'') IS NULL OR @MediaType NOT IN(N'image',N'video')
  OR @DisplayOrder<0 OR (@MediaType=N'video' AND @MediaGroupID IS NOT NULL)
  THROW 50012,'Invalid media fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Media(@MediaID), -- history
  @CoverGroup int=(SELECT TOP(1) MediaGroupID FROM Portal.MediaGroups WHERE CoverMediaID=@MediaID);
 DECLARE @CoverBefore nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@CoverGroup); -- history
 -- Lock groups before media consistently with group saves/cover selection.
 IF @MediaGroupID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.MediaGroups WITH(UPDLOCK,HOLDLOCK) WHERE MediaGroupID=@MediaGroupID)
  THROW 50012,'Unknown photo group.',1;
 IF @MediaID IS NULL
 BEGIN
  INSERT Portal.Media(MediaName,MediaPath,MediaType,MediaGroupID,DisplayOrder,Active)
  VALUES(@MediaName,@MediaPath,@MediaType,@MediaGroupID,@DisplayOrder,@Active);
  SET @MediaID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  -- Clear any saved cover before moving its photo or changing it to video.
  UPDATE Portal.MediaGroups SET CoverMediaID=NULL,LastChangeAt=GETDATE()
   WHERE CoverMediaID=@MediaID AND (@MediaType<>N'image' OR @MediaGroupID IS NULL OR MediaGroupID<>@MediaGroupID);
  IF NOT EXISTS(SELECT 1 FROM Portal.Media WITH(UPDLOCK,HOLDLOCK) WHERE MediaID=@MediaID) THROW 50011,'Media not found.',1;
  UPDATE Portal.Media SET MediaName=@MediaName,MediaPath=@MediaPath,MediaType=@MediaType,MediaGroupID=@MediaGroupID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE MediaID=@MediaID AND EXISTS(
   SELECT MediaName COLLATE Latin1_General_100_BIN2,MediaPath COLLATE Latin1_General_100_BIN2,MediaType,MediaGroupID,DisplayOrder,Active
   EXCEPT SELECT @MediaName COLLATE Latin1_General_100_BIN2,@MediaPath COLLATE Latin1_General_100_BIN2,@MediaType,@MediaGroupID,@DisplayOrder,@Active);
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Media(@MediaID); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='media',@ItemType='media',@ItemId=@MediaID,@ItemTitle=@MediaName,@OldJson=@Before,@NewJson=@After; -- history
 IF @CoverGroup IS NOT NULL -- history: moving the cover photo clears the album cover (no-op otherwise)
 BEGIN
  DECLARE @CoverAfter nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@CoverGroup),@CoverTitle nvarchar(200)=JSON_VALUE(@CoverBefore,'$.GroupName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='media',@ItemType='album',@ItemId=@CoverGroup,@ItemTitle=@CoverTitle,@OldJson=@CoverBefore,@NewJson=@CoverAfter;
 END;
 COMMIT;SELECT @MediaID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.MediaGroups_Save
 @MediaGroupID int=NULL,@GroupName nvarchar(200),@CoverMediaID int=NULL,@DisplayOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@GroupName)),N'') IS NULL OR @DisplayOrder<0 THROW 50012,'Invalid group fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@MediaGroupID); -- history
 IF @MediaGroupID IS NULL
 BEGIN
  IF @CoverMediaID IS NOT NULL THROW 50012,'Create the group before selecting its cover.',1;
  INSERT Portal.MediaGroups(GroupName,DisplayOrder,Active) VALUES(@GroupName,@DisplayOrder,@Active);
  SET @MediaGroupID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE IF NOT EXISTS(SELECT 1 FROM Portal.MediaGroups WITH(UPDLOCK,HOLDLOCK) WHERE MediaGroupID=@MediaGroupID) THROW 50011,'Group not found.',1;
 IF @CoverMediaID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.Media WITH(UPDLOCK,HOLDLOCK)
  WHERE MediaID=@CoverMediaID AND MediaGroupID=@MediaGroupID AND MediaType=N'image') THROW 50012,'Cover must be a photo in this album.',1;
 UPDATE Portal.MediaGroups SET GroupName=@GroupName,CoverMediaID=@CoverMediaID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE MediaGroupID=@MediaGroupID AND EXISTS(
  SELECT GroupName COLLATE Latin1_General_100_BIN2,CoverMediaID,DisplayOrder,Active
  EXCEPT SELECT @GroupName COLLATE Latin1_General_100_BIN2,@CoverMediaID,@DisplayOrder,@Active);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@MediaGroupID); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='media',@ItemType='album',@ItemId=@MediaGroupID,@ItemTitle=@GroupName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;SELECT @MediaGroupID;
END;
GO

/* ===== Reading the history (used by the overview, history page and "last changed by") ===== */

-- @SectionsJson: JSON array of section keys the caller may see; NULL = all.
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetRecent @Top int=10,@SectionsJson nvarchar(max)=NULL AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(CASE WHEN @Top BETWEEN 1 AND 100 THEN @Top ELSE 10 END)
  AdminChangeId,ChangedAt,ChangedBy,Section,Action,ItemType,ItemId,ItemTitle
 FROM Portal.AdminChanges
 WHERE @SectionsJson IS NULL OR Section IN(SELECT value FROM OPENJSON(@SectionsJson))
 ORDER BY AdminChangeId DESC;
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_Search
 @SectionsJson nvarchar(max)=NULL,@Section varchar(40)=NULL,@ChangedBy nvarchar(512)=NULL,@FromAt datetime=NULL,@ToAt datetime=NULL,
 @Page int=1,@PageSize int=50
AS
BEGIN
 SET NOCOUNT ON;
 SET @Page=CASE WHEN @Page>=1 THEN @Page ELSE 1 END;SET @PageSize=CASE WHEN @PageSize BETWEEN 1 AND 200 THEN @PageSize ELSE 50 END;
 DECLARE @Rows TABLE(AdminChangeId bigint PRIMARY KEY);
 INSERT @Rows SELECT AdminChangeId FROM Portal.AdminChanges
 WHERE (@SectionsJson IS NULL OR Section IN(SELECT value FROM OPENJSON(@SectionsJson)))
  AND (@Section IS NULL OR Section=@Section)
  AND (NULLIF(@ChangedBy,N'') IS NULL OR ChangedBy LIKE N'%'+REPLACE(REPLACE(REPLACE(@ChangedBy,N'[',N'[[]'),N'%',N'[%]'),N'_',N'[_]')+N'%')
  AND (@FromAt IS NULL OR ChangedAt>=@FromAt) AND (@ToAt IS NULL OR ChangedAt<@ToAt);
 DECLARE @Total int=(SELECT COUNT(*) FROM @Rows);
 -- One result set; Total repeats on every row (no rows = nothing matched on this page).
 SELECT @Total Total,c.AdminChangeId,c.ChangedAt,c.ChangedBy,c.Section,c.Action,c.ItemType,c.ItemId,c.ItemTitle,c.OldJson,c.NewJson
 FROM @Rows r JOIN Portal.AdminChanges c ON c.AdminChangeId=r.AdminChangeId
 ORDER BY c.AdminChangeId DESC OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
-- Latest change per item in one section ("آخر تعديل: الاسم · التاريخ").
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetLatestByItem @Section varchar(40) AS
BEGIN
 SET NOCOUNT ON;
 SELECT ItemType,ItemId,ChangedAt,ChangedBy,Action FROM(
  SELECT ItemType,ItemId,ChangedAt,ChangedBy,Action,ROW_NUMBER() OVER(PARTITION BY ItemType,ItemId ORDER BY AdminChangeId DESC) n
  FROM Portal.AdminChanges WHERE Section=@Section) x
 WHERE n=1;
END;
GO

GO


-- BEGIN 045_AdminOverview.sql
USE CompanyPortal;
GO
-- Read-only presentation adapters. Identity and profile mappings stay in their existing SPs.
CREATE OR ALTER PROCEDURE Portal.AdminAuthors_Get @NamesJson nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Name nvarchar(512),@UserId int;
 DECLARE @Users TABLE(UserId int);
 DECLARE @Person TABLE(DisplayName nvarchar(1000),JobTitle nvarchar(1000),Department nvarchar(1000));
 DECLARE @Result TABLE(ChangedBy nvarchar(512),DisplayName nvarchar(1000));
 DECLARE authors CURSOR LOCAL FAST_FORWARD FOR
 SELECT DISTINCT CONVERT(nvarchar(512),value) FROM OPENJSON(@NamesJson) WHERE type=1 AND LEN(value)<=512;
 OPEN authors; FETCH NEXT FROM authors INTO @Name;
 WHILE @@FETCH_STATUS=0
 BEGIN
  DELETE @Users; DELETE @Person; SET @UserId=NULL;
  INSERT @Users EXEC Security.User_getByUsername @Username=@Name;
  SELECT TOP(1) @UserId=UserId FROM @Users;
  IF @UserId IS NOT NULL INSERT @Person EXEC Portal.UserProfile_Get @UserId=@UserId;
  INSERT @Result SELECT @Name,COALESCE((SELECT TOP(1) NULLIF(DisplayName,N'') FROM @Person),@Name);
  FETCH NEXT FROM authors INTO @Name;
 END;
 CLOSE authors; DEALLOCATE authors;
 SELECT ChangedBy,DisplayName FROM @Result;
END;
GO

GO


-- BEGIN 046_AdminHistory.sql
USE CompanyPortal;
GO
-- Read-only history readers. Super-admin authorization is enforced by the API.
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetPage
 @Section varchar(40)=NULL,@ChangedBy nvarchar(512)=NULL,@FromAt datetime=NULL,@ToAt datetime=NULL,
 @Page int=1,@PageSize int=25
AS
BEGIN
 SET NOCOUNT ON;
 SET @Page=CASE WHEN @Page BETWEEN 1 AND 1000000 THEN @Page ELSE 1 END;
 SET @PageSize=CASE WHEN @PageSize BETWEEN 1 AND 100 THEN @PageSize ELSE 25 END;
 DECLARE @Rows TABLE(AdminChangeId bigint PRIMARY KEY);
 INSERT @Rows SELECT AdminChangeId FROM Portal.AdminChanges
 WHERE (@Section IS NULL OR Section=@Section)
 AND (NULLIF(@ChangedBy,N'') IS NULL OR ChangedBy LIKE N'%'+REPLACE(REPLACE(REPLACE(@ChangedBy,N'[',N'[[]'),N'%',N'[%]'),N'_',N'[_]')+N'%')
 AND (@FromAt IS NULL OR ChangedAt>=@FromAt) AND (@ToAt IS NULL OR ChangedAt<@ToAt);
 SELECT COUNT(*) Total FROM @Rows;
 SELECT CONVERT(nvarchar(20),c.AdminChangeId) ChangeId,c.ChangedAt,c.ChangedBy,c.Section,c.Action,c.ItemType,c.ItemId,c.ItemTitle
 FROM @Rows r JOIN Portal.AdminChanges c ON c.AdminChangeId=r.AdminChangeId
 ORDER BY c.AdminChangeId DESC OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetById @AdminChangeId bigint AS
BEGIN
 SET NOCOUNT ON;
 SELECT CONVERT(nvarchar(20),AdminChangeId) ChangeId,ChangedAt,ChangedBy,Section,Action,ItemType,ItemId,ItemTitle,OldJson,NewJson
 FROM Portal.AdminChanges WHERE AdminChangeId=@AdminChangeId;
END;
GO

GO


-- BEGIN 047_ThemeImagePositions.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Master.ThemeImagePositions',N'U') IS NULL
CREATE TABLE [Master].ThemeImagePositions(
 ThemeImagePositionId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ThemeImagePositions PRIMARY KEY,
 ThemeId int NOT NULL CONSTRAINT FK_ThemeImagePositions_Theme REFERENCES [Master].Themes(ThemeId),
 ImageId int NOT NULL CONSTRAINT FK_ThemeImagePositions_Image REFERENCES [Master].Images(ImageId),
 FocalX decimal(5,2) NOT NULL CONSTRAINT DF_ThemeImagePositions_X DEFAULT(50),
 FocalY decimal(5,2) NOT NULL CONSTRAINT DF_ThemeImagePositions_Y DEFAULT(50),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_ThemeImagePositions_Changed DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_ThemeImagePositions_Active DEFAULT(1),
 CONSTRAINT UQ_ThemeImagePositions UNIQUE(ThemeId,ImageId),
 CONSTRAINT CK_ThemeImagePositions_Range CHECK(FocalX BETWEEN 0 AND 100 AND FocalY BETWEEN 0 AND 100)
);
GO
CREATE OR ALTER PROCEDURE [Master].ThemeImagePositions_Get @ThemeId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 SELECT p.ThemeId,p.ImageId,p.FocalX,p.FocalY FROM [Master].ThemeImagePositions p
 WHERE p.Active=1 AND (@ThemeId IS NULL OR p.ThemeId=@ThemeId)
  AND EXISTS(SELECT 1 FROM [Master].Themes t JOIN [Master].ImageGroupItems g ON g.ImageGroupId=t.ImageGroupId
    WHERE t.ThemeId=p.ThemeId AND g.ImageId=p.ImageId)
 ORDER BY p.ThemeId,p.ImageId;
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Theme(@ThemeId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT t.ThemeName,t.LayoutKey,t.DisplayOrder,t.IsDefault,t.Active,t.Visibility,t.Deleted,t.PrimaryColor,t.AccentColor,t.BackgroundColor,
  t.OverlayOpacity,t.ForegroundPreset,t.ImagePresentation,t.ImageGroupId,
  JSON_QUERY((SELECT p.ImageId,p.FocalX,p.FocalY FROM [Master].ThemeImagePositions p
    WHERE p.ThemeId=t.ThemeId AND p.Active=1 ORDER BY p.ImageId FOR JSON PATH)) ImagePositions,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(N'"'+STRING_ESCAPE(r.RoleName,'json')+N'"',N',') WITHIN GROUP(ORDER BY r.RoleName) FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=t.ThemeId AND r.Active=1),N'')+N']') PreviewRoles
  FROM [Master].Themes t WHERE t.ThemeId=@ThemeId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL,@Visibility nvarchar(20)=NULL,@PreviewRolesJson nvarchar(max)=N'[]',
 @ChangedBy nvarchar(512)=NULL,@ImagePositionsJson nvarchar(max)=NULL
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
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 DECLARE @OldDefault int=(SELECT TOP(1) ThemeId FROM [Master].Themes WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId) ORDER BY ThemeId); -- history
 DECLARE @OldBefore nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault); -- history
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

 -- An omitted payload preserves saved positions for older callers. Explicit [] clears them.
 IF @ImagePositionsJson IS NOT NULL
 BEGIN
  IF ISJSON(@ImagePositionsJson)<>1 OR LEFT(LTRIM(@ImagePositionsJson),1)<>N'['
   THROW 50008,'Invalid image positions.',1;
  DECLARE @Positions TABLE(ImageId int NOT NULL PRIMARY KEY,FocalX decimal(5,2) NOT NULL,FocalY decimal(5,2) NOT NULL);
  IF (SELECT COUNT(*) FROM OPENJSON(@ImagePositionsJson))>100
   OR EXISTS(SELECT 1 FROM OPENJSON(@ImagePositionsJson) j WHERE j.[type]<>5
    OR TRY_CONVERT(int,JSON_VALUE(j.value,'$.ImageId')) IS NULL
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalX')) NOT BETWEEN 0 AND 100
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalY')) NOT BETWEEN 0 AND 100
    OR JSON_VALUE(j.value,'$.FocalX') IS NULL OR JSON_VALUE(j.value,'$.FocalY') IS NULL
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalX')) IS NULL
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalY')) IS NULL)
   THROW 50008,'Use up to 100 valid image positions.',1;
  IF EXISTS(SELECT JSON_VALUE(value,'$.ImageId') FROM OPENJSON(@ImagePositionsJson) GROUP BY JSON_VALUE(value,'$.ImageId') HAVING COUNT(*)>1)
   THROW 50008,'Duplicate image position.',1;
  INSERT @Positions SELECT ImageId,FocalX,FocalY FROM OPENJSON(@ImagePositionsJson)
   WITH(ImageId int '$.ImageId',FocalX decimal(5,2) '$.FocalX',FocalY decimal(5,2) '$.FocalY');
  IF EXISTS(SELECT 1 FROM @Positions p LEFT JOIN [Master].Images i ON i.ImageId=p.ImageId
    LEFT JOIN [Master].ImageGroupItems g ON g.ImageId=p.ImageId AND g.ImageGroupId=@ImageGroupId
    WHERE i.ImageId IS NULL OR g.ImageId IS NULL)
   THROW 50008,'Positioned images must belong to the selected group.',1;
  IF EXISTS(SELECT ImageId,FocalX,FocalY FROM @Positions EXCEPT SELECT ImageId,FocalX,FocalY FROM [Master].ThemeImagePositions WHERE ThemeId=@ThemeId AND Active=1)
   OR EXISTS(SELECT ImageId,FocalX,FocalY FROM [Master].ThemeImagePositions WHERE ThemeId=@ThemeId AND Active=1 EXCEPT SELECT ImageId,FocalX,FocalY FROM @Positions)
  BEGIN
   UPDATE [Master].Themes SET LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId;
   UPDATE saved SET FocalX=COALESCE(p.FocalX,saved.FocalX),FocalY=COALESCE(p.FocalY,saved.FocalY),
    Active=CASE WHEN p.ImageId IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
   FROM [Master].ThemeImagePositions saved LEFT JOIN @Positions p ON p.ImageId=saved.ImageId
   WHERE saved.ThemeId=@ThemeId AND (saved.Active<>CASE WHEN p.ImageId IS NULL THEN 0 ELSE 1 END OR p.FocalX<>saved.FocalX OR p.FocalY<>saved.FocalY);
   INSERT [Master].ThemeImagePositions(ThemeId,ImageId,FocalX,FocalY)
    SELECT @ThemeId,p.ImageId,p.FocalX,p.FocalY FROM @Positions p
    WHERE NOT EXISTS(SELECT 1 FROM [Master].ThemeImagePositions saved WHERE saved.ThemeId=@ThemeId AND saved.ImageId=p.ImageId);
  END;
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@ThemeName,@OldJson=@Before,@NewJson=@After; -- history
 IF @OldDefault IS NOT NULL -- history: a new default clears the previous one (no-op otherwise)
 BEGIN
  DECLARE @OldAfter nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault),@OldTitle nvarchar(200)=JSON_VALUE(@OldBefore,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@OldDefault,@ItemTitle=@OldTitle,@OldJson=@OldBefore,@NewJson=@OldAfter;
 END;
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
COMMIT;
GO

GO


-- BEGIN 048_ImageGroupThemeGuard.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
GO
-- Themes choose their image group only in the theme editor (Themes_save).
-- The images page lists every non-deleted theme so it can show which themes use a group.
CREATE OR ALTER PROCEDURE [Master].ImageGroups_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageGroupId,GroupName,RotateImages,RotationSeconds,DefaultImageId,Active,LastChangeAt FROM [Master].ImageGroups ORDER BY ImageGroupId;
 SELECT ImageGroupId,ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems ORDER BY ImageGroupId,DisplayOrder,ImageId;
 SELECT ThemeId,ThemeName,LayoutKey,ImageGroupId FROM [Master].Themes WHERE Deleted=0 ORDER BY DisplayOrder,ThemeId;
END;
GO
-- 50013: a group used by a non-deleted theme cannot be deactivated (Themes_save only accepts active groups).
CREATE OR ALTER PROCEDURE [Master].ImageGroups_save
 @ImageGroupId int=NULL, @GroupName nvarchar(200), @RotateImages bit, @RotationSeconds int,
 @DefaultImageId int=NULL, @Active bit, @Items [Master].ImageSelection READONLY, @ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
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
   IF @Active=0 AND EXISTS(SELECT 1 FROM [Master].Themes WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Deleted=0)
      THROW 50013,'Choose other images for the themes that use this group before deactivating it.',1;
   SET @Before=Portal.AdminSnapshot_ImageGroup(@ImageGroupId); -- history
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
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_ImageGroup(@ImageGroupId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image-group',@ItemId=@ImageGroupId,@ItemTitle=@GroupName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @ImageGroupId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
-- The images page no longer assigns groups to themes; that duplicated the theme editor.
DROP PROCEDURE IF EXISTS [Master].Themes_setImageGroup;
GO
COMMIT;
GO

GO


-- BEGIN 049_KnownRoles.sql
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

GO


-- BEGIN 050_ImageThumbnails.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
GO
-- Small preview copy made by the admin browser (about 480 px, WebP) so the admin library and theme
-- cards do not download full-size originals. The portal itself keeps using ImageData.
IF COL_LENGTH(N'Master.Images',N'ThumbnailData') IS NULL
 ALTER TABLE [Master].Images ADD ThumbnailData varbinary(max) NULL, ThumbnailType nvarchar(100) NULL;
GO
IF OBJECT_ID(N'Master.CK_Images_Thumbnail',N'C') IS NULL
 ALTER TABLE [Master].Images ADD CONSTRAINT CK_Images_Thumbnail CHECK(
  (ThumbnailData IS NULL AND ThumbnailType IS NULL)
  OR (DATALENGTH(ThumbnailData) BETWEEN 1 AND 524288 AND ThumbnailType IN (N'image/jpeg',N'image/png',N'image/webp')));
GO
CREATE OR ALTER PROCEDURE [Master].Images_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageId,ImageName,ContentType,PixelWidth,PixelHeight,DATALENGTH(ImageData) ByteLength,LastChangeAt,
  CAST(CASE WHEN ThumbnailData IS NULL THEN 0 ELSE 1 END AS bit) HasThumbnail
 FROM [Master].Images WHERE Active=1 ORDER BY ImageId DESC;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_add
 @ImageName nvarchar(200), @ContentType nvarchar(100), @ImageData varbinary(max), @PixelWidth int, @PixelHeight int, @ChangedBy nvarchar(512)=NULL,
 @ThumbnailData varbinary(max)=NULL, @ThumbnailType nvarchar(100)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: insert and history row commit together
 IF LEN(LTRIM(RTRIM(@ImageName)))=0 THROW 50007,'Image name is required.',1;
 BEGIN TRANSACTION; -- history
 INSERT [Master].Images(ImageName,ContentType,ImageData,PixelWidth,PixelHeight,ThumbnailData,ThumbnailType)
 VALUES(@ImageName,@ContentType,@ImageData,@PixelWidth,@PixelHeight,@ThumbnailData,@ThumbnailType);
 DECLARE @ImageId int=CAST(SCOPE_IDENTITY() AS int); -- history
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image',@ItemId=@ImageId,@ItemTitle=@ImageName,@NewJson=@After; -- history
 COMMIT; -- history
 SELECT @ImageId;
END;
GO
-- Adds a preview copy to an older image. Set once only, so its URL can be cached for good.
-- Not recorded in the change history: the snapshot (no bytes) does not change.
CREATE OR ALTER PROCEDURE [Master].Images_setThumbnail @ImageId int,@ThumbnailData varbinary(max),@ThumbnailType nvarchar(100) AS
BEGIN
 SET NOCOUNT ON;
 UPDATE [Master].Images SET ThumbnailData=@ThumbnailData,ThumbnailType=@ThumbnailType
 WHERE ImageId=@ImageId AND Active=1 AND ThumbnailData IS NULL;
 SELECT CAST(@@ROWCOUNT AS bit);
END;
GO
-- Same access rule as Images_getContent.
CREATE OR ALTER PROCEDURE [Master].Images_getThumbnail @ImageId int,@IsAdmin bit,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT ThumbnailData ImageData,ThumbnailType ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND i.ThumbnailData IS NOT NULL AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1 AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)))));
END;
GO
COMMIT;
GO

GO


-- BEGIN 051_HeaderEvents.sql
USE CompanyPortal;
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Mng.HeaderEvents',N'U') IS NULL
 CREATE TABLE Mng.HeaderEvents(
 EventId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_HeaderEvents PRIMARY KEY,
 Title nvarchar(150) NOT NULL, AppUrl nvarchar(2048) NOT NULL,
 StartAt datetime NOT NULL, EndAt datetime NOT NULL,
 DisplayOrder int NOT NULL CONSTRAINT DF_HeaderEvents_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_HeaderEvents_LastChange DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_HeaderEvents_Active DEFAULT(1),
 CONSTRAINT CK_HeaderEvents_Window CHECK(EndAt>StartAt),
 CONSTRAINT CK_HeaderEvents_Order CHECK(DisplayOrder BETWEEN 0 AND 100000));
GO
-- Event windows are UTC; LastChangeAt follows the portal's existing SQL GETDATE convention.
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetActive AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,AppUrl,StartAt,EndAt,DisplayOrder FROM Mng.HeaderEvents
 WHERE Active=1 AND StartAt<=GETUTCDATE() AND EndAt>GETUTCDATE()
 ORDER BY DisplayOrder,EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetAll AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,AppUrl,StartAt,EndAt,DisplayOrder,Active,LastChangeAt FROM Mng.HeaderEvents ORDER BY DisplayOrder,EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Save
 @EventId int=NULL,@Title nvarchar(150),@AppUrl nvarchar(2048),@StartAt datetime,@EndAt datetime,
 @DisplayOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @AppUrl=LTRIM(RTRIM(@AppUrl));
 IF NULLIF(@Title,N'') IS NULL OR NULLIF(@AppUrl,N'') IS NULL OR (@AppUrl NOT LIKE N'https://%' AND @AppUrl NOT LIKE N'http://%')
 OR @StartAt IS NULL OR @EndAt IS NULL OR @EndAt<=@StartAt OR @DisplayOrder IS NULL OR @DisplayOrder NOT BETWEEN 0 AND 100000 OR @Active IS NULL
 THROW 50051,'Check the event title, HTTP(S) address, dates and order.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@New nvarchar(max);
 IF @EventId IS NOT NULL
 BEGIN
  SELECT @Old=(SELECT Title,AppUrl,StartAt,EndAt,DisplayOrder,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
  FROM Mng.HeaderEvents WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
  IF @Old IS NULL THROW 50052,'Event not found.',1;
 END;
 IF @EventId IS NULL
 BEGIN
  INSERT Mng.HeaderEvents(Title,AppUrl,StartAt,EndAt,DisplayOrder,Active) VALUES(@Title,@AppUrl,@StartAt,@EndAt,@DisplayOrder,@Active);
  SET @EventId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
  UPDATE Mng.HeaderEvents SET Title=@Title,AppUrl=@AppUrl,StartAt=@StartAt,EndAt=@EndAt,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE EventId=@EventId AND (Title COLLATE Latin1_General_100_BIN2<>@Title COLLATE Latin1_General_100_BIN2
   OR AppUrl COLLATE Latin1_General_100_BIN2<>@AppUrl COLLATE Latin1_General_100_BIN2
   OR StartAt<>@StartAt OR EndAt<>@EndAt OR DisplayOrder<>@DisplayOrder OR Active<>@Active);
 SELECT @New=(SELECT Title,AppUrl,StartAt,EndAt,DisplayOrder,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) FROM Mng.HeaderEvents WHERE EventId=@EventId;
 DECLARE @ItemId nvarchar(100)=CONVERT(nvarchar(100),@EventId);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@NewJson=@New;
 COMMIT;SELECT @EventId EventId;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Delete @EventId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@Title nvarchar(150),@ItemId nvarchar(100)=CONVERT(nvarchar(100),@EventId);
 SELECT @Title=Title,@Old=(SELECT Title,AppUrl,StartAt,EndAt,DisplayOrder,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
 FROM Mng.HeaderEvents WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
 IF @Old IS NULL THROW 50052,'Event not found.',1;
 DELETE Mng.HeaderEvents WHERE EventId=@EventId;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@Action='delete';
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'Portal.AdminSectionRoles') AND name=N'CK_AdminSectionRoles_Key')
 ALTER TABLE Portal.AdminSectionRoles DROP CONSTRAINT CK_AdminSectionRoles_Key;
ALTER TABLE Portal.AdminSectionRoles WITH CHECK ADD CONSTRAINT CK_AdminSectionRoles_Key CHECK(SectionKey IN('cards','applications','documents','safety','fixed-orders','header-content','notices','alerts','media','images','themes','events'));
GO

GO


-- BEGIN 052_HeaderEventsLast.sql
USE CompanyPortal;
GO
-- Event links are always appended after the fixed secondary navigation. No configurable order.
-- Event windows are UTC; LastChangeAt follows the portal's existing SQL GETDATE convention.
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetActive AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,AppUrl,StartAt,EndAt FROM Mng.HeaderEvents
 WHERE Active=1 AND StartAt<=GETUTCDATE() AND EndAt>GETUTCDATE()
 ORDER BY EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetAll AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,AppUrl,StartAt,EndAt,Active,LastChangeAt FROM Mng.HeaderEvents ORDER BY EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Save
 @EventId int=NULL,@Title nvarchar(150),@AppUrl nvarchar(2048),@StartAt datetime,@EndAt datetime,
 @Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @AppUrl=LTRIM(RTRIM(@AppUrl));
 IF NULLIF(@Title,N'') IS NULL OR NULLIF(@AppUrl,N'') IS NULL OR (@AppUrl NOT LIKE N'https://%' AND @AppUrl NOT LIKE N'http://%')
 OR @StartAt IS NULL OR @EndAt IS NULL OR @EndAt<=@StartAt OR @Active IS NULL
 THROW 50051,'Check the event title, HTTP(S) address, dates.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@New nvarchar(max);
 IF @EventId IS NOT NULL
 BEGIN
  SELECT @Old=(SELECT Title,AppUrl,StartAt,EndAt,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
  FROM Mng.HeaderEvents WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
  IF @Old IS NULL THROW 50052,'Event not found.',1;
 END;
 IF @EventId IS NULL
 BEGIN
  INSERT Mng.HeaderEvents(Title,AppUrl,StartAt,EndAt,Active) VALUES(@Title,@AppUrl,@StartAt,@EndAt,@Active);
  SET @EventId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
  UPDATE Mng.HeaderEvents SET Title=@Title,AppUrl=@AppUrl,StartAt=@StartAt,EndAt=@EndAt,Active=@Active,LastChangeAt=GETDATE()
  WHERE EventId=@EventId AND (Title COLLATE Latin1_General_100_BIN2<>@Title COLLATE Latin1_General_100_BIN2
   OR AppUrl COLLATE Latin1_General_100_BIN2<>@AppUrl COLLATE Latin1_General_100_BIN2
   OR StartAt<>@StartAt OR EndAt<>@EndAt OR Active<>@Active);
 SELECT @New=(SELECT Title,AppUrl,StartAt,EndAt,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) FROM Mng.HeaderEvents WHERE EventId=@EventId;
 DECLARE @ItemId nvarchar(100)=CONVERT(nvarchar(100),@EventId);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@NewJson=@New;
 COMMIT;SELECT @EventId EventId;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Delete @EventId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@Title nvarchar(150),@ItemId nvarchar(100)=CONVERT(nvarchar(100),@EventId);
 SELECT @Title=Title,@Old=(SELECT Title,AppUrl,StartAt,EndAt,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
 FROM Mng.HeaderEvents WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
 IF @Old IS NULL THROW 50052,'Event not found.',1;
 DELETE Mng.HeaderEvents WHERE EventId=@EventId;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@Action='delete';
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO

IF COL_LENGTH(N'Mng.HeaderEvents',N'DisplayOrder') IS NOT NULL
BEGIN
 IF OBJECT_ID(N'Mng.CK_HeaderEvents_Order',N'C') IS NOT NULL ALTER TABLE Mng.HeaderEvents DROP CONSTRAINT CK_HeaderEvents_Order;
 IF OBJECT_ID(N'Mng.DF_HeaderEvents_Order',N'D') IS NOT NULL ALTER TABLE Mng.HeaderEvents DROP CONSTRAINT DF_HeaderEvents_Order;
 ALTER TABLE Mng.HeaderEvents DROP COLUMN DisplayOrder;
END;
GO

GO


-- BEGIN 053_MediaReads.sql
USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRAN;
IF EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=3 AND ContentTypeName<>N'أخبارنا')
 THROW 50012,'ContentTypeID 3 is already reserved for a different type.',1;
SET IDENTITY_INSERT Mstr.ContentType ON;
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=3)
 INSERT Mstr.ContentType(ContentTypeID,ContentTypeName,Active) VALUES(3,N'أخبارنا',1);
SET IDENTITY_INSERT Mstr.ContentType OFF;
COMMIT;
GO
-- The API revalidates these IDs against its configured visible media source before this batch.
CREATE OR ALTER PROCEDURE Portal.Media_MarkSeen @UserId int,@MediaIdsJson nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR ISJSON(@MediaIdsJson)<>1 OR NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=3 AND Active=1)
  THROW 50012,'Invalid media acknowledgement.',1;
 DECLARE @Ids TABLE(ContentId nvarchar(200) PRIMARY KEY);
 INSERT @Ids SELECT DISTINCT CONVERT(nvarchar(200),TRY_CONVERT(int,value)) FROM OPENJSON(@MediaIdsJson) WHERE TRY_CONVERT(int,value)>0;
 BEGIN TRAN;
 -- Serialize per user/batch so repeat clicks/tabs cannot create duplicate read records.
 DECLARE @Lock int,@Resource nvarchar(255)=N'Portal.Media.Reads.'+CONVERT(nvarchar(20),@UserId);
 EXEC @Lock=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50012,'Media acknowledgement is busy.',1;
 UPDATE r SET Active=1,ReadAt=GETDATE() FROM Portal.UserReads r JOIN @Ids i ON i.ContentId=r.ContentId
 WHERE r.UserId=@UserId AND r.ContentTypeID=3 AND r.Active=0;
 INSERT Portal.UserReads(UserId,ContentTypeID,ContentId)
 SELECT @UserId,3,i.ContentId FROM @Ids i WHERE NOT EXISTS(SELECT 1 FROM Portal.UserReads r WHERE r.UserId=@UserId AND r.ContentTypeID=3 AND r.ContentId=i.ContentId);
 COMMIT;
END;
GO

GO


-- BEGIN 054_TodayHeadlines.sql
USE CompanyPortal;
GO
-- Optional day filter after deduplication, before paging; unfiltered archive/file calls retain their contract.
CREATE OR ALTER PROCEDURE News.Items_get
 @Page int=1,
 @PageSize int=8,
 @NewsId bigint=NULL,
 @PublishedOn date=NULL
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
 WHERE @PublishedOn IS NULL OR (PublishedAt>=@PublishedOn AND PublishedAt<DATEADD(day,1,@PublishedOn))
 ORDER BY PublishedAt DESC,NewsId DESC
 OFFSET (CONVERT(bigint,@Page)-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
 SELECT COUNT(*) AS TotalCount FROM #Items
 WHERE @PublishedOn IS NULL OR (PublishedAt>=@PublishedOn AND PublishedAt<DATEADD(day,1,@PublishedOn));
END;
GO

GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [master];
-- DEVELOPMENT ONLY. Never run this against the real internal security database.
USE [master];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [master];

IF DB_ID(N''SecurityDB'') IS NULL
    EXEC(N''CREATE DATABASE [SecurityDB];'');
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];

USE [SecurityDB];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];

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

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];

-- This script must be run with the same development Windows account used in the browser.
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE NTName = (SELECT TestNTName FROM #PortalDeployment))
    INSERT dbo.Users (NTName) VALUES ((SELECT TestNTName FROM #PortalDeployment));
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];
-- DEVELOPMENT ONLY. Do not run against the real internal security database.
USE [SecurityDB];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];

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

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];
-- DEVELOPMENT ONLY. Do not deploy these sample grants internally.
USE [SecurityDB];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [SecurityDB];

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

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [CompanyPortal];
-- DEVELOPMENT ONLY: annotate only the explicit local sample applications.
-- No application URLs, users, grants, or existing metadata are changed.
USE [CompanyPortal];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'USE [CompanyPortal];

SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @Seed TABLE(AppKey nvarchar(100),CategoryName nvarchar(200),DisplayOrder int,Description nvarchar(2000));
INSERT @Seed VALUES
 (N''people-demo'',N''شؤون الموظفين'',1,N''متابعة الإجازات وبيانات الموظف وخدمات الموارد البشرية.''),
 (N''support-demo'',N''التقنية والدعم'',2,N''تسجيل البلاغات التقنية ومتابعة طلبات الدعم الفني.''),
 (N''projects-demo'',N''إدارة الأعمال'',3,N''متابعة المشاريع ومراحل التنفيذ ومهام فرق العمل.''),
 (N''reports-demo'',N''المالية والتقارير'',4,N''استعراض التقارير والمؤشرات المالية — تطبيق غير مصرح به في العينة.'');
INSERT [Master].ApplicationCategories(CategoryName,DisplayOrder)
SELECT DISTINCT s.CategoryName,s.DisplayOrder FROM @Seed s WHERE NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories c WHERE c.CategoryName=s.CategoryName);
INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription)
SELECT a.AppId,c.ApplicationCategoryId,s.Description FROM @Seed s
JOIN SecurityDB.dbo.Applications a ON a.AppKey=s.AppKey
JOIN [Master].ApplicationCategories c ON c.CategoryName=s.CategoryName
WHERE NOT EXISTS(SELECT 1 FROM [Master].ApplicationDetails d WHERE d.AppId=a.AppId);
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
 INSERT dbo.Public_info_News(PIN_Subject) VALUES(N''خبر تجريبي لاختبار البوابة'');
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

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'-- SAMPLE adapter for the local SecurityDB fixture only.
-- Internally replace this SELECT with the approved active application catalog.
-- This catalog does not grant employee application access.
USE [CompanyPortal];
');
GO

IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'
CREATE OR ALTER PROCEDURE Security.Apps_getForAdministration AS
BEGIN
 SET NOCOUNT ON;
 SELECT AppId,AppName FROM SecurityDB.dbo.Applications WHERE Active=1 ORDER BY AppId;
END;
');
GO

-- Grant only the API service identity, never every employee.
USE master;
GO
DECLARE @account nvarchar(512)=(SELECT ApiIdentity FROM #PortalDeployment);
IF @account<>N''
BEGIN
 DECLARE @sql nvarchar(max);
 IF SUSER_ID(@account) IS NULL
 BEGIN
  SET @sql=N'CREATE LOGIN '+QUOTENAME(@account)+N' FROM WINDOWS';
  EXEC(@sql);
 END;
 SET @sql=N'USE CompanyPortal; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
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