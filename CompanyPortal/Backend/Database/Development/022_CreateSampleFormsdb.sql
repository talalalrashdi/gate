-- DEVELOPMENT ONLY. Inferred source schema, never run against a real forms database.
USE master;
GO
IF DB_ID(N'Formsdb') IS NULL
BEGIN
 EXEC(N'CREATE DATABASE Formsdb');
 EXEC Formsdb.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1;
END;
GO
USE Formsdb;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 BEGIN SET NOEXEC ON; THROW 50040,'Refusing to modify an unmarked Formsdb.',1; END;
GO
IF OBJECT_ID(N'dbo.FormInbox',N'U') IS NULL
 CREATE TABLE dbo.FormInbox(
 FormId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FormInbox PRIMARY KEY,
 FormNumber nvarchar(100) NULL,
 UserId int NOT NULL,Title nvarchar(1000) NOT NULL,SenderName nvarchar(500) NOT NULL,
 Purpose nvarchar(100) NOT NULL CONSTRAINT DF_FormInbox_Purpose DEFAULT(N'للعلم'),
 SentAt datetime NOT NULL CONSTRAINT DF_FormInbox_SentAt DEFAULT(GETDATE()),
 IsOpened bit NOT NULL CONSTRAINT DF_FormInbox_IsOpened DEFAULT(0),
 Active bit NOT NULL CONSTRAINT DF_FormInbox_Active DEFAULT(1));
GO
IF COL_LENGTH(N'dbo.FormInbox',N'FormNumber') IS NULL
 ALTER TABLE dbo.FormInbox ADD FormNumber nvarchar(100) NULL;
GO
IF COL_LENGTH(N'dbo.FormInbox',N'Purpose') IS NULL
 ALTER TABLE dbo.FormInbox ADD Purpose nvarchar(100) NOT NULL CONSTRAINT DF_FormInbox_Purpose DEFAULT(N'للعلم') WITH VALUES;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.FormInbox') AND name=N'IX_FormInbox_User')
 CREATE INDEX IX_FormInbox_User ON dbo.FormInbox(UserId,Active,SentAt DESC) INCLUDE(IsOpened);
GO
DECLARE @UserId int,@Username nvarchar(512)=ORIGINAL_LOGIN();
DECLARE @User TABLE(UserId int);
INSERT @User EXEC CompanyPortal.Security.User_getByUsername @Username=@Username;
SELECT @UserId=UserId FROM @User;
IF @UserId IS NULL THROW 50041,'Register the current Windows user before seeding forms.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.FormInbox WHERE UserId=@UserId)
 INSERT dbo.FormInbox(UserId,Title,SenderName,Purpose,SentAt,IsOpened) VALUES
 (@UserId,N'طلب شراء جهاز جديد',N'سالم العبري · تقنية المعلومات',N'للإجراء',GETDATE(),0),
 (@UserId,N'طلب المشاركة في برنامج تدريبي',N'مريم الحارثية · الموارد البشرية',N'للعلم',DATEADD(hour,-2,GETDATE()),0),
 (@UserId,N'طلب اعتماد إجازة',N'خالد البلوشي · الشؤون الإدارية',N'للإجراء',DATEADD(day,-1,GETDATE()),1),
 (@UserId,N'طلب صيانة جهاز',N'أحمد العامري · الدعم التقني',N'للإجراء',DATEADD(day,-2,GETDATE()),1),
 (@UserId,N'طلب توفير مستلزمات مكتبية',N'فاطمة الرواحية · الخدمات',N'للعلم',DATEADD(day,-3,GETDATE()),0);
GO
UPDATE dbo.FormInbox SET FormNumber=CONVERT(nvarchar(4),YEAR(SentAt))+N'/'+CONVERT(nvarchar(20),FormId) WHERE FormNumber IS NULL;
GO
USE CompanyPortal;
GO
-- Refuse adapter changes unless the source is explicitly marked as a development fixture.
IF NOT EXISTS(SELECT 1 FROM Formsdb.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 BEGIN SET NOEXEC ON; THROW 50040,'Marked development source required.',1; END;
GO
CREATE OR ALTER PROCEDURE Portal.Forms_Inbox_Get @UserId int,@FormId bigint=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT FormId,FormNumber,Title,SenderName,Purpose,SentAt,IsOpened,CAST(1 AS bit) IsSample
 FROM Formsdb.dbo.FormInbox WHERE UserId=@UserId AND Active=1 AND (@FormId IS NULL OR FormId=@FormId)
 ORDER BY SentAt DESC,FormId DESC;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Forms_UnreadCount_Get @UserId int AS
BEGIN SET NOCOUNT ON;
 SELECT COUNT(*) UnreadCount FROM Formsdb.dbo.FormInbox WHERE UserId=@UserId AND Active=1 AND IsOpened=0;
END;
GO
