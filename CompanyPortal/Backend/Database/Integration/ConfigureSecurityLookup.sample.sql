-- SAMPLE mapping for the local development SecurityDB only.
-- Adapt this procedure's SELECT to the real security database before internal deployment.
USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE Security.User_getByUsername
    @Username nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId
    FROM [SecurityDB].[dbo].[Users]
    WHERE NTName = @Username AND Active = 1;
END;
GO
