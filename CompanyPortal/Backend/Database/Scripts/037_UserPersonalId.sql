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
