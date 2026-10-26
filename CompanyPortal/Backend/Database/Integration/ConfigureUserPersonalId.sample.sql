-- SAMPLE mapping for the local development SecurityDB only.
-- Adapt this procedure's SELECT to the real security database (the column holding the
-- employee's PersonalID used by Dalil GetEmplyeeThumb) before internal deployment.
USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE Security.User_getPersonalId
    @Username nvarchar(512)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PersonalID
    FROM [SecurityDB].[dbo].[Users]
    WHERE NTName = @Username AND Active = 1 AND PersonalID IS NOT NULL;
END;
GO
