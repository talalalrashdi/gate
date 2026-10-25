USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Read-only integration contracts. Replace the SELECTs internally; never return another user.
-- Keep existing mapped SPs unchanged when this migration is reapplied.
IF OBJECT_ID(N'Portal.UserAttendance_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.UserAttendance_Get @UserId int AS BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS nvarchar(300)) AS DisplayName, CAST(NULL AS nvarchar(300)) AS JobTitle,
 CAST(NULL AS nvarchar(300)) AS Department, CAST(NULL AS date) AS AttendanceDate,
 CAST(NULL AS datetime) AS ArrivalAt, CAST(NULL AS datetime) AS ExpectedLeaveAt WHERE 1=0; END;');
GO
IF OBJECT_ID(N'Portal.UserLeaveBalance_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.UserLeaveBalance_Get @UserId int AS BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS decimal(10,2)) AS HolidayDays, CAST(NULL AS decimal(10,2)) AS DaysToBeDeleted,
 CAST(NULL AS date) AS AsOfDate, CAST(NULL AS date) AS DeletionDate WHERE 1=0; END;');
GO
