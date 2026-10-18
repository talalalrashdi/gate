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
