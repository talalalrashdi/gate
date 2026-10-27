-- DEVELOPMENT ONLY. Inferred source schema; never run against the real office system.
USE master;
GO
IF DB_ID(N'OfficeFormsdb') IS NULL
BEGIN
 EXEC(N'CREATE DATABASE OfficeFormsdb');
 EXEC OfficeFormsdb.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1;
END;
GO
IF NOT EXISTS(SELECT 1 FROM OfficeFormsdb.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
BEGIN SET NOEXEC ON;THROW 50040,'Refusing to modify an unmarked OfficeFormsdb.',1;END;
GO
USE OfficeFormsdb;
GO
IF OBJECT_ID(N'dbo.CorrespondenceInbox',N'U') IS NULL
 CREATE TABLE dbo.CorrespondenceInbox(
 CorrespondenceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CorrespondenceInbox PRIMARY KEY,
 UserId int NOT NULL,DocNo nvarchar(200) NOT NULL,Title nvarchar(1000) NOT NULL,
 SenderName nvarchar(500) NULL,Purpose nvarchar(100) NOT NULL,ReceivedAt datetime NOT NULL CONSTRAINT DF_Correspondence_ReceivedAt DEFAULT(GETDATE()),
 IsOpened bit NOT NULL CONSTRAINT DF_Correspondence_IsOpened DEFAULT(0),
 Active bit NOT NULL CONSTRAINT DF_Correspondence_Active DEFAULT(1));
GO
IF COL_LENGTH(N'dbo.CorrespondenceInbox',N'SenderName') IS NULL
 ALTER TABLE dbo.CorrespondenceInbox ADD SenderName nvarchar(500) NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.CorrespondenceInbox') AND name=N'IX_CorrespondenceInbox_User')
 CREATE INDEX IX_CorrespondenceInbox_User ON dbo.CorrespondenceInbox(UserId,Active,ReceivedAt DESC) INCLUDE(IsOpened);
GO
DECLARE @UserId int,@Username nvarchar(512)=ORIGINAL_LOGIN();
DECLARE @User TABLE(UserId int);
INSERT @User EXEC CompanyPortal.Security.User_getByUsername @Username=@Username;
SELECT @UserId=UserId FROM @User;
IF @UserId IS NULL BEGIN SET NOEXEC ON;THROW 50041,'Register the current employee before seeding correspondence.',1;END;
IF NOT EXISTS(SELECT 1 FROM dbo.CorrespondenceInbox WHERE UserId=@UserId)
 INSERT dbo.CorrespondenceInbox(UserId,DocNo,Title,Purpose,ReceivedAt,IsOpened) VALUES
 (@UserId,N'2026/101',N'دعوة للمشاركة في لقاء الفريق',N'للعلم',GETDATE(),0),
 (@UserId,N'2026/102',N'مراجعة خطة العمل للأسبوع القادم',N'للإجراء',DATEADD(hour,-1,GETDATE()),0),
 (@UserId,N'2026/103',N'تحديث صلاحيات الوصول للأنظمة',N'للعلم',DATEADD(day,-1,GETDATE()),1),
 (@UserId,N'2026/104',N'اعتماد جدول الزيارات الميدانية',N'للإجراء',DATEADD(day,-2,GETDATE()),0),
 (@UserId,N'2026/105',N'تقرير متابعة تحسين الخدمات الإلكترونية',N'للعلم',DATEADD(day,-7,GETDATE()),1);
GO
-- Fill only original sample senders; preserve custom values and source state.
UPDATE dbo.CorrespondenceInbox SET SenderName=CASE DocNo
 WHEN N'2026/101' THEN N'سالم العبري'
 WHEN N'2026/102' THEN N'خالد الرواحي'
 WHEN N'2026/103' THEN N'مازن الحارثي'
 WHEN N'2026/104' THEN N'مريم البلوشية'
 WHEN N'2026/105' THEN N'أحمد العامري' END
WHERE SenderName IS NULL AND DocNo IN(N'2026/101',N'2026/102',N'2026/103',N'2026/104',N'2026/105');
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Portal.Correspondence_Inbox_Get @UserId int,@CorrespondenceId bigint=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT CorrespondenceId,DocNo,Title,Purpose,SenderName,ReceivedAt,IsOpened,CAST(1 AS bit) IsSample
 FROM OfficeFormsdb.dbo.CorrespondenceInbox
 WHERE UserId=@UserId AND Active=1 AND ReceivedAt<=GETDATE() AND (@CorrespondenceId IS NULL OR CorrespondenceId=@CorrespondenceId)
 ORDER BY ReceivedAt DESC,CorrespondenceId DESC;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Correspondence_UnreadCount_Get @UserId int AS
BEGIN SET NOCOUNT ON;
 SELECT COUNT(*) UnreadCount FROM OfficeFormsdb.dbo.CorrespondenceInbox
 WHERE UserId=@UserId AND Active=1 AND ReceivedAt<=GETDATE() AND IsOpened=0;
END;
GO
