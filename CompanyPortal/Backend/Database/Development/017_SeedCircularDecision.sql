-- DEVELOPMENT ONLY: the real legal source has not supplied a type-table contract.
USE LegelAffairs;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 THROW 50031,'Refusing to seed an unmarked legal database.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Decisions WHERE Title=N'إجراءات تنظيم المراسلات الداخلية' AND DecisionType=N'تعميم')
 INSERT dbo.Decisions(DecisionType,Title,PublishedAt,PdfFileName,IsPublic) VALUES(N'تعميم',N'إجراءات تنظيم المراسلات الداخلية',GETDATE(),N'decision-1.pdf',1);
GO
