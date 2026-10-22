-- SAMPLE adapter for the local SecurityDB fixture only.
-- Internally replace this SELECT with the approved active application catalog.
-- This catalog does not grant employee application access.
USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE Security.Apps_getForAdministration AS
BEGIN
 SET NOCOUNT ON;
 SELECT AppId,AppName FROM SecurityDB.dbo.Applications WHERE Active=1 ORDER BY AppId;
END;
GO
