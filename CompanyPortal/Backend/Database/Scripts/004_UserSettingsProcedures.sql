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
