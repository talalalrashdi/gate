-- LOCAL DEVELOPMENT ONLY. Fictional PDF fixtures, not approved safety guidance.
USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
 THROW 50041,'Requires the marked local document fixture.',1;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS(SELECT 1 FROM Mng.Folder WHERE FolderID=110 AND (FolderName<>N'تعليمات السلامة' OR ParentID IS NOT NULL))
 THROW 50041,'Sample safety folder ID is already in use.',1;
IF NOT EXISTS(SELECT 1 FROM Mng.Folder WHERE FolderID=110)
BEGIN
 SET IDENTITY_INSERT Mng.Folder ON;
 INSERT Mng.Folder(FolderID,FolderName) VALUES(110,N'تعليمات السلامة');
 SET IDENTITY_INSERT Mng.Folder OFF;
END;
DECLARE @Seed TABLE(DocumentID uniqueidentifier,DocumentName nvarchar(100),DocumentPath nvarchar(150),DisplayOrder int);
INSERT @Seed VALUES
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000201'),N'السلامة في بيئة العمل',N'السلامة في بيئة العمل.pdf',10),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000202'),N'سلامة الأجهزة والكهرباء',N'سلامة الأجهزة والكهرباء.pdf',20),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000203'),N'الاستعداد للطوارئ',N'الاستعداد للطوارئ.pdf',30),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000204'),N'الإخلاء الآمن',N'الإخلاء الآمن.pdf',40),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000205'),N'الإبلاغ عن المخاطر',N'الإبلاغ عن المخاطر.pdf',50),
 (CONVERT(uniqueidentifier,'d0250000-0000-0000-0000-000000000206'),N'الراحة أثناء العمل',N'الراحة أثناء العمل.pdf',60);
INSERT Mng.Document(DocumentID,DocumentName,DocumentPath,FolderID)
SELECT DocumentID,DocumentName,DocumentPath,110 FROM @Seed s WHERE NOT EXISTS(SELECT 1 FROM Mng.Document d WHERE d.DocumentID=s.DocumentID);
-- Seed booklets once; later reruns never undo an administrator's PDF changes.
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalSafetyFixture')
BEGIN
DECLARE @New TABLE(DocumentTabID int,TabName nvarchar(200));
INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder,SectionKey)
OUTPUT inserted.DocumentTabID,inserted.TabName INTO @New
SELECT DocumentName,110,DisplayOrder,N'safety' FROM @Seed s
WHERE NOT EXISTS(SELECT 1 FROM Portal.DocumentTabItems i JOIN Portal.DocumentTabs t ON t.DocumentTabID=i.DocumentTabID
 WHERE t.SectionKey=N'safety' AND i.DocumentID=s.DocumentID);
INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
SELECT n.DocumentTabID,s.DocumentID FROM @New n JOIN @Seed s ON s.DocumentName=n.TabName;
EXEC sys.sp_addextendedproperty @name=N'CompanyPortalSafetyFixture',@value=1;
END;
COMMIT;
GO
