-- DEVELOPMENT ONLY: annotate only the explicit local sample applications.
-- No application URLs, users, grants, or existing metadata are changed.
USE [CompanyPortal];
GO
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @Seed TABLE(AppKey nvarchar(100),CategoryName nvarchar(200),DisplayOrder int,Description nvarchar(2000));
INSERT @Seed VALUES
 (N'people-demo',N'شؤون الموظفين',1,N'متابعة الإجازات وبيانات الموظف وخدمات الموارد البشرية.'),
 (N'support-demo',N'التقنية والدعم',2,N'تسجيل البلاغات التقنية ومتابعة طلبات الدعم الفني.'),
 (N'projects-demo',N'إدارة الأعمال',3,N'متابعة المشاريع ومراحل التنفيذ ومهام فرق العمل.'),
 (N'reports-demo',N'المالية والتقارير',4,N'استعراض التقارير والمؤشرات المالية — تطبيق غير مصرح به في العينة.');
INSERT [Master].ApplicationCategories(CategoryName,DisplayOrder)
SELECT DISTINCT s.CategoryName,s.DisplayOrder FROM @Seed s WHERE NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories c WHERE c.CategoryName=s.CategoryName);
INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription)
SELECT a.AppId,c.ApplicationCategoryId,s.Description FROM @Seed s
JOIN SecurityDB.dbo.Applications a ON a.AppKey=s.AppKey
JOIN [Master].ApplicationCategories c ON c.CategoryName=s.CategoryName
WHERE NOT EXISTS(SELECT 1 FROM [Master].ApplicationDetails d WHERE d.AppId=a.AppId);
COMMIT;
GO
