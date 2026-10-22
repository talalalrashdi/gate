-- TEMPORARY LOCAL TEST DATA ONLY. TimestampType below is a fixture marker,
-- not a real enum meaning/default. The test runner removes these exact IDs.
SET NOCOUNT ON;
DECLARE @Ids TABLE(FixedOrderID bigint);
INSERT Portal.FixedOrders([Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType)
OUTPUT inserted.FixedOrderID INTO @Ids
VALUES
 ('2026-10-20','2030-01-01',N'المسمى السابق',N'[اختبار مؤقت] المسمى الجديد',N'بتغيير ds{0}de إلى ss{1}se. ويُستبدل ds{0}de.',-2147483000),
 ('2026-03-15',NULL,N'العبارة المعتمدة',N'[اختبار مؤقت] توجيه بعبارة واحدة',N'اعتماد ds{0}de في المخاطبات.',-2147483000),
 ('2025-01-02',NULL,N'<b>نص قديم</b>',N'[اختبار مؤقت] <b>عنوان نصي</b>',N'يُستبدل ds{0}de بـ ss{1}se، دون تفسير HTML.',-2147483000),
 (NULL,'2024-02-03',NULL,NULL,NULL,-2147483000);
SELECT CONVERT(nvarchar(20),FixedOrderID) AS Id FROM @Ids FOR JSON PATH;
