-- SAMPLE mapping only. Replace the SELECT with the approved internal permission source.
USE [CompanyPortal];
GO
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
GO
