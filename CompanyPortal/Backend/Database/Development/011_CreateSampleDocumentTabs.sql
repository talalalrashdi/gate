-- LOCAL DEVELOPMENT ONLY. Fictional documents, not official legal content.
USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
 THROW 50041,'Initialize the marked document fixture first. No real folders will be changed.',1;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS(SELECT 1 FROM Mng.Folder WHERE FolderID IN(101,102,103) AND
 ((FolderID=101 AND FolderName<>N'قوانين المؤسسة') OR (FolderID=102 AND FolderName<>N'قوانين التقاعد') OR (FolderID=103 AND FolderName<>N'الدراسات')))
 THROW 50041,'Sample folder IDs are already in use.',1;
SET IDENTITY_INSERT Mng.Folder ON;
INSERT Mng.Folder(FolderID,FolderName)
SELECT s.* FROM(VALUES(101,N'قوانين المؤسسة'),(102,N'قوانين التقاعد'),(103,N'الدراسات')) s(FolderID,FolderName)
WHERE NOT EXISTS(SELECT 1 FROM Mng.Folder f WHERE f.FolderID=s.FolderID);
SET IDENTITY_INSERT Mng.Folder OFF;
INSERT Mng.Document(DocumentID,DocumentName,DocumentPath,FolderID)
SELECT s.* FROM(VALUES
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000101'),N'لائحة تنظيم العمل',N'لائحة تنظيم العمل.pdf',101),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000102'),N'دليل شؤون التقاعد',N'دليل شؤون التقاعد.pdf',102),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000103'),N'دراسة تطوير الخدمات',N'دراسة تطوير الخدمات.pdf',103)
) s(DocumentID,DocumentName,DocumentPath,FolderID)
WHERE NOT EXISTS(SELECT 1 FROM Mng.Document d WHERE d.DocumentID=s.DocumentID);
-- Add each initial tab once; reruns preserve admin selections, ordering and hidden state.
DECLARE @Seed TABLE(FolderID int,TabName nvarchar(200),DisplayOrder int,DocumentID uniqueidentifier);
INSERT @Seed VALUES
 (101,N'قوانين المؤسسة',10,'d0250000-0000-0000-0000-000000000101'),
 (102,N'قوانين التقاعد',20,'d0250000-0000-0000-0000-000000000102'),
 (103,N'الدراسات',30,'d0250000-0000-0000-0000-000000000103');
DECLARE @New TABLE(DocumentTabID int,FolderID int);
INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder)
OUTPUT inserted.DocumentTabID,inserted.FolderID INTO @New
SELECT TabName,FolderID,DisplayOrder FROM @Seed s
WHERE NOT EXISTS(SELECT 1 FROM Portal.DocumentTabs t WHERE t.FolderID=s.FolderID);
INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
SELECT n.DocumentTabID,s.DocumentID FROM @New n JOIN @Seed s ON s.FolderID=n.FolderID;
COMMIT;
GO
