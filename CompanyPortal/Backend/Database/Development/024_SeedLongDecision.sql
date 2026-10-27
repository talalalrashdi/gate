-- DEVELOPMENT ONLY: retained long-title sample requested for visual acceptance.
USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM LegelAffairs.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
BEGIN SET NOEXEC ON; THROW 50040,'Marked legal fixture required.',1; END;
GO
USE LegelAffairs;
GO
IF NOT EXISTS(SELECT 1 FROM dbo.Decisions WHERE DecisionNumber=N'2026/80')
 INSERT dbo.Decisions(DecisionType,Title,PublishedAt,PdfFileName,IsPublic,DecisionNumber)
 VALUES(N'قرارات إدارية',N'اعتماد الإجراءات التنظيمية المحدثة لتطوير الخدمات الإلكترونية وتحسين آليات التنسيق بين الوحدات الإدارية ومتابعة تنفيذ خطط العمل وتقييم جودة الخدمات المقدمة للموظفين',GETDATE(),N'decision-1.pdf',1,N'2026/80');
GO
