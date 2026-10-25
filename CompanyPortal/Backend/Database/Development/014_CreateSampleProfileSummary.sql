-- DEVELOPMENT ONLY. Fictional data for the current registered Windows employee.
-- Not part of the production/fresh-install scripts. Reruns preserve edited values.
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalProfileFixture')
 AND (OBJECT_ID(N'Development.ProfilePeople',N'U') IS NOT NULL OR OBJECT_ID(N'Development.ProfileAttendance',N'U') IS NOT NULL OR OBJECT_ID(N'Development.ProfileLeaveBalances',N'U') IS NOT NULL)
 THROW 50012,'Existing unmarked profile tables: no development fixture changes permitted.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'Portal.UserAttendance_Get')) NOT LIKE N'%WHERE 1=0%'
 AND OBJECT_DEFINITION(OBJECT_ID(N'Portal.UserAttendance_Get')) NOT LIKE N'%Development.ProfilePeople%'
 THROW 50012,'Attendance lookup has a custom mapping; do not replace it with samples.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'Portal.UserLeaveBalance_Get')) NOT LIKE N'%WHERE 1=0%'
 AND OBJECT_DEFINITION(OBJECT_ID(N'Portal.UserLeaveBalance_Get')) NOT LIKE N'%Development.ProfileLeaveBalances%'
 THROW 50012,'Leave lookup has a custom mapping; do not replace it with samples.',1;
GO
BEGIN TRANSACTION;
IF SCHEMA_ID(N'Development') IS NULL EXEC(N'CREATE SCHEMA Development AUTHORIZATION dbo;');
IF OBJECT_ID(N'Development.ProfilePeople',N'U') IS NULL
 CREATE TABLE Development.ProfilePeople(
  ProfilePersonID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  UserId int NOT NULL UNIQUE,DisplayName nvarchar(300) NULL,JobTitle nvarchar(300) NULL,Department nvarchar(300) NULL,
  LastChangeAt datetime NOT NULL DEFAULT GETDATE(),Active bit NOT NULL DEFAULT 1);
IF OBJECT_ID(N'Development.ProfileAttendance',N'U') IS NULL
 CREATE TABLE Development.ProfileAttendance(
  ProfileAttendanceID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  UserId int NOT NULL,AttendanceDate date NOT NULL,ArrivalAt datetime NULL,ExpectedLeaveAt datetime NULL,
  LastChangeAt datetime NOT NULL DEFAULT GETDATE(),Active bit NOT NULL DEFAULT 1,
  UNIQUE(UserId,AttendanceDate));
IF OBJECT_ID(N'Development.ProfileLeaveBalances',N'U') IS NULL
 CREATE TABLE Development.ProfileLeaveBalances(
  ProfileLeaveBalanceID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  UserId int NOT NULL UNIQUE,HolidayDays decimal(10,2) NULL,DaysToBeDeleted decimal(10,2) NULL,
  AsOfDate date NULL,DeletionDate date NULL,LastChangeAt datetime NOT NULL DEFAULT GETDATE(),Active bit NOT NULL DEFAULT 1,
  CHECK(HolidayDays>=0),CHECK(DaysToBeDeleted>=0));
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalProfileFixture')
 EXEC sys.sp_addextendedproperty @name=N'CompanyPortalProfileFixture',@value=N'Development-only fictional profile data';
DECLARE @Ids TABLE(UserId int);
DECLARE @Username nvarchar(512)=ORIGINAL_LOGIN();
INSERT @Ids EXEC Security.User_getByUsername @Username=@Username;
DECLARE @UserId int=(SELECT UserId FROM @Ids),@Today date=CONVERT(date,GETDATE());
IF @UserId IS NULL THROW 50012,'Register the current development Windows account first.',1;
IF NOT EXISTS(SELECT 1 FROM Development.ProfilePeople WHERE UserId=@UserId)
 INSERT Development.ProfilePeople(UserId,DisplayName,JobTitle,Department) VALUES(@UserId,N'أحمد سالم',N'أخصائي نظم معلومات',N'دائرة تقنية المعلومات');
IF NOT EXISTS(SELECT 1 FROM Development.ProfileAttendance WHERE UserId=@UserId AND AttendanceDate=@Today)
 INSERT Development.ProfileAttendance(UserId,AttendanceDate,ArrivalAt,ExpectedLeaveAt)
 VALUES(@UserId,@Today,DATEADD(minute,8*60+7,CAST(@Today AS datetime)),DATEADD(minute,15*60+7,CAST(@Today AS datetime)));
IF NOT EXISTS(SELECT 1 FROM Development.ProfileLeaveBalances WHERE UserId=@UserId)
 INSERT Development.ProfileLeaveBalances(UserId,HolidayDays,DaysToBeDeleted,AsOfDate,DeletionDate)
 VALUES(@UserId,32.5,2.5,@Today,DATEFROMPARTS(YEAR(@Today),12,31));
COMMIT;
GO
CREATE OR ALTER PROCEDURE Portal.UserAttendance_Get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT p.DisplayName,p.JobTitle,p.Department,a.AttendanceDate,a.ArrivalAt,a.ExpectedLeaveAt
 FROM Development.ProfilePeople p
 LEFT JOIN Development.ProfileAttendance a ON a.UserId=p.UserId AND a.AttendanceDate=CONVERT(date,GETDATE()) AND a.Active=1
 WHERE p.UserId=@UserId AND p.Active=1;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserLeaveBalance_Get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT HolidayDays,DaysToBeDeleted,AsOfDate,DeletionDate FROM Development.ProfileLeaveBalances
 WHERE UserId=@UserId AND Active=1;
END;
GO
