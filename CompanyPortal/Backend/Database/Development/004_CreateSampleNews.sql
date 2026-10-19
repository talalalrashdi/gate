-- DEVELOPMENT ONLY. Inferred minimal schema, not a copy of the internal news schema.
-- Run using tools/Initialize-NewsFixture.ps1 (supplies the local fixture path).
USE [master];
GO
IF DB_ID(N'Pubs_Info_V4') IS NULL
BEGIN
 EXEC(N'CREATE DATABASE Pubs_Info_V4');
 EXEC Pubs_Info_V4.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1;
END;
GO
USE Pubs_Info_V4;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 THROW 50012,'Refusing to seed an unmarked existing news database.',1;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Public_info_News',N'U') IS NULL
CREATE TABLE dbo.Public_info_News (
 PIN_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
 PIN_Date datetime NOT NULL DEFAULT(GETDATE()),
 PIN_Subject nvarchar(1000) NOT NULL,
 PIN_PicturePath nvarchar(4000) NULL,
 PIN_Publish bit NOT NULL DEFAULT(1),
 PIN_IsImportant bit NOT NULL DEFAULT(0),
 PIN_Detailes nvarchar(4000) NULL,
 PIN_Active bit NOT NULL DEFAULT(1),
 PIN_Portal bit NOT NULL DEFAULT(1)
);
IF OBJECT_ID(N'dbo.Attachment',N'U') IS NULL
CREATE TABLE dbo.Attachment (
 ATT_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
 PIN_ID int NOT NULL REFERENCES dbo.Public_info_News(PIN_ID),
 ATT_File_Path nvarchar(4000) NOT NULL,
 ATT_FileType nvarchar(100) NOT NULL,
 ATT_Active bit NOT NULL DEFAULT(1),
 ATT_Note nvarchar(1000) NULL
);
IF OBJECT_ID(N'dbo.Public_info_News_Prodc',N'U') IS NULL
CREATE TABLE dbo.Public_info_News_Prodc (
 PIP_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
 News_ID int NOT NULL REFERENCES dbo.Public_info_News(PIN_ID),
 Active bit NOT NULL DEFAULT(1)
);
IF NOT EXISTS(SELECT 1 FROM dbo.Public_info_News)
BEGIN
 INSERT dbo.Public_info_News(PIN_Subject,PIN_Date,PIN_IsImportant,PIN_PicturePath,PIN_Publish,PIN_Active,PIN_Portal)
 VALUES
 (N'خبر تجريبي: إطلاق بوابة الموظفين', '20261019',1,N'$(NewsRoot)\sample.png',1,1,1),
 (N'خبر تجريبي دون مرفق','20261018',0,NULL,1,1,1),
 (N'خبر تجريبي بمرفق غير نشط','20261017',0,NULL,1,1,1),
 (N'غير منشور: يجب ألا يظهر','20261016',0,NULL,0,1,1),
 (N'غير نشط: يجب ألا يظهر','20261015',0,NULL,1,0,1),
 (N'خارج البوابة: يجب ألا يظهر','20261014',0,NULL,1,1,0),
 (N'اختبار تعارض مرفقين','20261013',0,NULL,1,1,1),
 (N'اختبار ملف مفقود','20261012',0,NULL,1,1,1),
 (N'اختبار مسار خارج المجلد المسموح','20261011',0,NULL,1,1,1),
 (N'خبر تجريبي <b>بعنوان نصي</b>','20261010',0,NULL,1,1,1),
 (N'اختبار محتوى غير صالح','20261009',0,NULL,1,1,1),
 (N'اختبار خبر قديم','20261008',0,NULL,1,1,1);
 INSERT dbo.Public_info_News_Prodc(News_ID) SELECT PIN_ID FROM dbo.Public_info_News;
 -- Duplicate production rows must not duplicate the news item.
 INSERT dbo.Public_info_News_Prodc(News_ID) VALUES(1);
 INSERT dbo.Attachment(PIN_ID,ATT_File_Path,ATT_FileType,ATT_Active) VALUES
 (1,N'$(NewsRoot)\sample.pdf',N'pdf',1),
 (3,N'$(NewsRoot)\sample.pdf',N'pdf',0),
 (7,N'$(NewsRoot)\sample.pdf',N'pdf',1),
 (7,N'$(NewsRoot)\other.pdf',N'pdf',1),
 (8,N'$(NewsRoot)\missing.pdf',N'pdf',1),
 (9,N'$(NewsRoot)\..\outside.pdf',N'pdf',1),
 (11,N'$(NewsRoot)\invalid.pdf',N'pdf',1);
END;
COMMIT;
GO
USE CompanyPortal;
GO
IF OBJECT_ID(N'dbo.VNews') IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM sys.extended_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.VNews') AND name=N'CompanyPortalDevelopmentFixture')
 THROW 50012,'Refusing to replace an existing real news view.',1;
GO
IF OBJECT_ID(N'dbo.VNews') IS NULL
BEGIN
 EXEC(N'CREATE VIEW dbo.VNews AS
 SELECT pin.PIN_ID,pin.PIN_Date,pin.PIN_Subject,pin.PIN_PicturePath,pin.PIN_Publish,
 a.ATT_File_Path,a.ATT_FileType,pin.PIN_IsImportant,pin.PIN_Detailes,pin.PIN_Active,pin.PIN_Portal,
 a.ATT_Active,CAST(NULL AS nvarchar(200)) AS Expr1,a.ATT_ID,a.ATT_Note,p.PIP_ID
 FROM Pubs_Info_V4.dbo.Public_info_News pin
 LEFT JOIN Pubs_Info_V4.dbo.Attachment a ON a.PIN_ID=pin.PIN_ID
 JOIN Pubs_Info_V4.dbo.Public_info_News_Prodc p ON p.News_ID=pin.PIN_ID;');
 EXEC sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1,@level0type=N'SCHEMA',@level0name=N'dbo',@level1type=N'VIEW',@level1name=N'VNews';
END;
GO
