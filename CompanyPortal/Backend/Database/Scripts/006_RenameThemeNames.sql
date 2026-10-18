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
