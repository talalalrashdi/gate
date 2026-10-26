-- DEVELOPMENT ONLY: adds PersonalID to the local sample SecurityDB and assigns 1244 to the
-- account running this script. The real security database is not modified by the portal.
USE [SecurityDB];
GO
IF COL_LENGTH(N'dbo.Users', N'PersonalID') IS NULL
    ALTER TABLE dbo.Users ADD PersonalID bigint NULL;
GO
UPDATE dbo.Users SET PersonalID = 1244 WHERE NTName = ORIGINAL_LOGIN() AND PersonalID IS NULL;
GO
