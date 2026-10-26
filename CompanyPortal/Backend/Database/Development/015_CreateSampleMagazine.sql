-- DEVELOPMENT ONLY: register the existing magazine once; preserve all admin/source edits on rerun.
USE [CompanyPortal];
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalMagazineFixture')
BEGIN
 IF EXISTS(SELECT 1 FROM Portal.Magazines) THROW 50012,'Existing magazine catalog: do not seed fictional development metadata.',1;
 BEGIN TRANSACTION;
 INSERT Portal.Magazines(MagazineName,IssueNumber,IssueDate,FileName,DisplayOrder)
 VALUES(N'مجلة الفلق',N'50/2026','20261001',N'39.pdf',0);
 EXEC sys.sp_addextendedproperty @name=N'CompanyPortalMagazineFixture',@value=N'Existing local magazine sample';
 COMMIT;
END;
GO
