-- DEVELOPMENT ONLY. Uses the existing marked legal fixture and existing sample PDFs.
USE LegelAffairs;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 THROW 50031,'Refusing to seed an unmarked legal database.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Decisions WHERE Title=N'مواعيد استقبال الطلبات' AND DecisionType=N'تنويه')
 INSERT dbo.Decisions(DecisionType,Title,PublishedAt,PdfFileName,IsPublic) VALUES(N'تنويه',N'مواعيد استقبال الطلبات',GETDATE(),N'decision-1.pdf',1);
IF NOT EXISTS(SELECT 1 FROM dbo.Decisions WHERE Title=N'بدء التسجيل في برامج التدريب' AND DecisionType=N'إعلان')
 INSERT dbo.Decisions(DecisionType,Title,PublishedAt,PdfFileName,IsPublic) VALUES(N'إعلان',N'بدء التسجيل في برامج التدريب',GETDATE(),N'decision-2.pdf',1);
GO
