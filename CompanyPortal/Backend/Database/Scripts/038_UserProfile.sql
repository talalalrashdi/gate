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
