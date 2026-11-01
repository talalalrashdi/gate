-- DEVELOPMENT ONLY: inferred inbox; real permissions and read status belong to Isnad.
USE master;
GO
IF DB_ID(N'IsnadDB') IS NULL BEGIN EXEC(N'CREATE DATABASE IsnadDB');EXEC IsnadDB.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1;END;
GO
IF NOT EXISTS(SELECT 1 FROM IsnadDB.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
BEGIN SET NOEXEC ON;THROW 50040,'Refusing to modify unmarked IsnadDB.',1;END;
GO
USE IsnadDB;
GO
IF OBJECT_ID(N'dbo.TechnicalInbox',N'U') IS NULL
CREATE TABLE dbo.TechnicalInbox(
 TechnicalInboxId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TechnicalInbox PRIMARY KEY,
 UserId int NOT NULL,RequestType nvarchar(200) NOT NULL,DocumentNumber nvarchar(200) NULL,
 OfficeNumber nvarchar(100) NULL,Details nvarchar(4000) NOT NULL,
 HasAttachment bit NOT NULL CONSTRAINT DF_TechnicalInbox_Attachment DEFAULT(0),
 ReceivedAt datetime NOT NULL CONSTRAINT DF_TechnicalInbox_Received DEFAULT(GETDATE()),
 IsOpened bit NOT NULL CONSTRAINT DF_TechnicalInbox_Opened DEFAULT(0),
 Active bit NOT NULL CONSTRAINT DF_TechnicalInbox_Active DEFAULT(1));
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TechnicalInbox') AND name=N'IX_TechnicalInbox_User')
 CREATE INDEX IX_TechnicalInbox_User ON dbo.TechnicalInbox(UserId,Active,ReceivedAt DESC,TechnicalInboxId DESC) INCLUDE(IsOpened);
GO
DECLARE @Users TABLE(UserId int);DECLARE @Username nvarchar(512)=ORIGINAL_LOGIN(),@UserId int;
INSERT @Users EXEC CompanyPortal.Security.User_getByUsername @Username=@Username;
SELECT @UserId=UserId FROM @Users;
IF @UserId IS NULL BEGIN SET NOEXEC ON;THROW 50041,'Register current employee before seeding technical inbox.',1;END;
IF NOT EXISTS(SELECT 1 FROM dbo.TechnicalInbox WHERE UserId=@UserId)
 INSERT dbo.TechnicalInbox(UserId,RequestType,DocumentNumber,OfficeNumber,Details,HasAttachment,ReceivedAt,IsOpened) VALUES
 (@UserId,N'دعم تقني',N'2026/501',N'1312',N'فحص جهاز الحاسب وتحديث البرامج المطلوبة',1,GETDATE(),0),
 (@UserId,N'صيانة',NULL,N'1420',N'متابعة صيانة الطابعة في قسم الموارد البشرية',0,DATEADD(minute,-30,GETDATE()),0),
 (@UserId,N'صلاحيات',N'2026/503',NULL,N'مراجعة صلاحيات الدخول إلى نظام المراسلات',1,DATEADD(hour,-2,GETDATE()),1),
 (@UserId,N'شبكات',NULL,NULL,N'التحقق من اتصال الشبكة في قاعة الاجتماعات',0,DATEADD(day,-1,GETDATE()),0),
 (@UserId,N'دعم تقني',N'2026/505',N'1502',N'تجهيز الحاسب للمستخدم الجديد وتثبيت التطبيقات المعتمدة',1,DATEADD(day,-2,GETDATE()),1),
 (@UserId,N'صيانة',N'2026/506',NULL,N'متابعة استبدال شاشة المكتب',0,DATEADD(day,-3,GETDATE()),1),
 (@UserId,N'شبكات',NULL,N'1210',N'إعداد نقطة اتصال إضافية',0,DATEADD(day,-4,GETDATE()),1);
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Portal.Isnad_Inbox_Get @UserId int AS
BEGIN SET NOCOUNT ON;
 SELECT TechnicalInboxId,RequestType,DocumentNumber,OfficeNumber,Details,HasAttachment,ReceivedAt,IsOpened
 FROM IsnadDB.dbo.TechnicalInbox
 WHERE UserId=@UserId AND Active=1 AND ReceivedAt<=GETDATE()
 ORDER BY ReceivedAt DESC,TechnicalInboxId DESC;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Isnad_UnreadCount_Get @UserId int AS
BEGIN SET NOCOUNT ON;
 SELECT COUNT(*) FROM IsnadDB.dbo.TechnicalInbox WHERE UserId=@UserId AND Active=1 AND IsOpened=0 AND ReceivedAt<=GETDATE();
END;
GO
