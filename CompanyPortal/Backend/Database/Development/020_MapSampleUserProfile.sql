-- DEVELOPMENT ONLY. Maps Portal.UserProfile_Get to the fictional Development.ProfilePeople sample
-- (from Development/014). Not part of the production/fresh-install scripts.
USE [CompanyPortal];
GO
IF OBJECT_ID(N'Development.ProfilePeople',N'U') IS NULL
 THROW 50038,'Run Development/014_CreateSampleProfileSummary.sql first.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'Portal.UserProfile_Get')) NOT LIKE N'%WHERE 1=0%'
 AND OBJECT_DEFINITION(OBJECT_ID(N'Portal.UserProfile_Get')) NOT LIKE N'%Development.ProfilePeople%'
 THROW 50038,'Profile lookup has a custom mapping; do not replace it with samples.',1;
GO
CREATE OR ALTER PROCEDURE Portal.UserProfile_Get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT DisplayName,JobTitle,Department
 FROM Development.ProfilePeople
 WHERE UserId=@UserId AND Active=1;
END;
GO
