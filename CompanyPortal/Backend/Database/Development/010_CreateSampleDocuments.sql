-- DEVELOPMENT ONLY. The source view schemas are inferred, not the real internal views.
USE CompanyPortal;
GO
IF (OBJECT_ID(N'dbo.VFolder') IS NOT NULL OR OBJECT_ID(N'dbo.VJobMainPeriod') IS NOT NULL)
 AND NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
 THROW 50041,'Refusing to replace existing non-fixture document views.',1;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture')
 EXEC sys.sp_addextendedproperty @name=N'CompanyPortalDocumentFixture',@value=1;
GO
IF OBJECT_ID(N'Mng.Folder',N'U') IS NULL
 THROW 50047,'Apply migration 024_FolderAndDocsRoot.sql before seeding document folders.',1;
IF OBJECT_ID(N'Mng.DocumentSampleJobs',N'U') IS NULL
CREATE TABLE Mng.DocumentSampleJobs(
 ID int IDENTITY(10001,1) NOT NULL PRIMARY KEY,UserID int NOT NULL UNIQUE,Active bit NOT NULL DEFAULT(1)
);
GO
CREATE OR ALTER VIEW dbo.VFolder AS
 SELECT FolderID,ParentID,FolderName,UnitMstID,IsForDisplay,[Timestamp],Active FROM Mng.Folder;
GO
CREATE OR ALTER VIEW dbo.VJobMainPeriod AS
 SELECT ID,UserID FROM Mng.DocumentSampleJobs WHERE Active=1;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
SET IDENTITY_INSERT Mng.Folder ON;
INSERT Mng.Folder(FolderID,ParentID,FolderName,Active,IsForDisplay)
SELECT s.* FROM(VALUES(10,NULL,N'الموارد البشرية',1,1),(11,10,N'الاستمارات',1,1),
 (20,NULL,N'تقنية المعلومات',1,1),(74,NULL,N'الوثائق المخصصة',1,1),(75,74,N'الاستمارات المخصصة',1,1),
 (90,NULL,N'مجلد مخفي',1,0)) s(FolderID,ParentID,FolderName,Active,IsForDisplay)
WHERE NOT EXISTS(SELECT 1 FROM Mng.Folder f WHERE f.FolderID=s.FolderID);
SET IDENTITY_INSERT Mng.Folder OFF;
INSERT Mng.DocumentSampleJobs(UserID)
SELECT UserID FROM SecurityDB.dbo.Users u WHERE u.NTName=ORIGINAL_LOGIN() AND u.Active=1
 AND NOT EXISTS(SELECT 1 FROM Mng.DocumentSampleJobs j WHERE j.UserID=u.UserID);
INSERT Mng.Document(DocumentID,DocumentName,DocumentPath,FolderID)
SELECT s.* FROM(VALUES
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000001'),N'طلب إجازة',N'طلب إجازة.docx',11),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000002'),N'دليل شؤون الموظفين',N'دليل شؤون الموظفين.pdf',10),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000003'),N'طلب صلاحيات نظام',N'طلب صلاحيات نظام.docx',20),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000004'),N'دليل أمن المعلومات',N'دليل أمن المعلومات.pdf',20),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000005'),N'وثيقة مخصصة',N'وثيقة مخصصة.pdf',74),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000006'),N'استمارة مخصصة',N'استمارة مخصصة.docx',75),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000007'),N'وثيقة مخفية',N'وثيقة مخفية.pdf',90)
) s(DocumentID,DocumentName,DocumentPath,FolderID)
WHERE NOT EXISTS(SELECT 1 FROM Mng.Document d WHERE d.DocumentID=s.DocumentID);
COMMIT;
GO
