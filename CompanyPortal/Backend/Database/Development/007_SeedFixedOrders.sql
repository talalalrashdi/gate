-- DEVELOPMENT SAMPLE DATA ONLY: fictional directives, not official records.
-- TimestampType=1 is a sample value only; its business meaning remains unconfirmed.
USE [CompanyPortal];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @Samples TABLE([Timestamp] date,Timestamp2 date,ContentBefor nvarchar(500),ContentAfter nvarchar(1000),ContentText nvarchar(1000));
INSERT @Samples VALUES
 ('20261020',NULL,N'قسم الخدمات',N'تطوير الخدمات الإلكترونية',N'بتغيير ds{0}de إلى ss{1}se وتوسيع نطاق الخدمات المقدمة للموظفين.'),
 ('20260915','20260916',N'الإجراءات الورقية',N'تحديث إجراءات العمل',N'بمراجعة ds{0}de والعمل على ss{1}se لتبسيط إنجاز المعاملات.'),
 ('20260503',NULL,N'خطة التدريب السنوية',N'اعتماد خطة التدريب',N'باعتماد ds{0}de وتوفير البرامج المناسبة لتنمية مهارات الموظفين.'),
 ('20251112',NULL,N'آلية متابعة الطلبات',N'تحسين متابعة الطلبات',N'بمراجعة ds{0}de وتطويرها بما يسهم في ss{1}se وسرعة إنجازها.'),
 ('20250308',NULL,N'دليل تنظيم الاجتماعات',N'تنظيم الاجتماعات',N'بالعمل وفق ds{0}de وتعميمه على الوحدات المعنية.'),
 ('20000214',NULL,N'السجلات الورقية',N'تطوير نظام الأرشفة',N'بتنظيم ds{0}de والبدء في ss{1}se لتسهيل حفظ الوثائق واسترجاعها.'),
 ('20010623',NULL,N'خطة تأهيل الموظفين',N'تنمية الموارد البشرية',N'باعتماد ds{0}de وإعطاء الأولوية لبرامج التدريب والتأهيل الوظيفي.'),
 ('20020910',NULL,N'إجراءات استقبال المراجعين',N'تحسين خدمات المراجعين',N'بمراجعة ds{0}de وتبسيطها بما يحقق ss{1}se.'),
 ('20030419',NULL,N'برامج الصيانة الدورية',N'المحافظة على المرافق',N'بتنفيذ ds{0}de ومتابعة جاهزية المرافق والمعدات في جميع الوحدات.'),
 ('20041107',NULL,N'نماذج المراسلات المتعددة',N'توحيد نماذج المراسلات',N'بمراجعة ds{0}de والعمل على ss{1}se وتعميم النماذج المعتمدة.');

-- Update only the five previously labelled sample records; preserve their IDs.
UPDATE f SET ContentBefor=s.ContentBefor,ContentAfter=s.ContentAfter,ContentText=s.ContentText
FROM Portal.FixedOrders f JOIN @Samples s ON f.[Timestamp]=s.[Timestamp]
 AND f.ContentAfter=N'[بيانات تجريبية] '+s.ContentAfter
WHERE f.TimestampType=1;

INSERT Portal.FixedOrders([Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType)
SELECT s.[Timestamp],s.Timestamp2,s.ContentBefor,s.ContentAfter,s.ContentText,1 FROM @Samples s
WHERE NOT EXISTS(SELECT 1 FROM Portal.FixedOrders f WITH(UPDLOCK,HOLDLOCK) WHERE f.[Timestamp]=s.[Timestamp] AND f.ContentAfter=s.ContentAfter);
COMMIT TRANSACTION;
SELECT f.FixedOrderID,f.[Timestamp],f.ContentAfter,f.TimestampType
FROM Portal.FixedOrders f JOIN @Samples s ON f.[Timestamp]=s.[Timestamp] AND f.ContentAfter=s.ContentAfter
ORDER BY f.[Timestamp] DESC,f.FixedOrderID DESC;
GO
