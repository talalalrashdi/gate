-- Header content managed from /admin/header-content:
--   Mng.ImportantNumbers  → «أرقام تهمك» in the phone-directory dialog
--   Mng.StatusLevels      → titles/texts/steps for حالة المؤسسة (ColorValue 1 green … 4 red, as Mng.CurrentStatus)
-- Seeds reproduce the previous fixed text once; reruns keep edited rows.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'Mng') IS NULL EXEC(N'CREATE SCHEMA Mng');
GO
IF OBJECT_ID(N'Mng.ImportantNumbers',N'U') IS NULL
BEGIN
 CREATE TABLE Mng.ImportantNumbers
 (
  Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImportantNumbers PRIMARY KEY,
  Title nvarchar(150) NOT NULL,
  Number nvarchar(50) NOT NULL,
  SortOrder int NOT NULL CONSTRAINT DF_ImportantNumbers_SortOrder DEFAULT (0),
  Active bit NOT NULL CONSTRAINT DF_ImportantNumbers_Active DEFAULT (1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_ImportantNumbers_LastChangeAt DEFAULT (GETDATE())
 );
 INSERT Mng.ImportantNumbers(Title,Number,SortOrder) VALUES
  (N'طوارئ المؤسسة',N'1000',1),(N'فريق السلامة',N'1001',2),(N'الإسعافات الأولية',N'1002',3),
  (N'الأمن والاستقبال',N'1003',4),(N'الدعم التقني',N'1044',5);
END;
GO
IF OBJECT_ID(N'Mng.StatusLevels',N'U') IS NULL
BEGIN
 CREATE TABLE Mng.StatusLevels
 (
  ColorValue tinyint NOT NULL CONSTRAINT PK_StatusLevels PRIMARY KEY CONSTRAINT CK_StatusLevels_ColorValue CHECK (ColorValue BETWEEN 1 AND 4),
  Title nvarchar(100) NOT NULL,
  ColorName nvarchar(30) NOT NULL,
  Summary nvarchar(600) NOT NULL,
  GuideText nvarchar(300) NULL,
  Actions nvarchar(1500) NULL, -- one step per line
  LastChangeAt datetime NOT NULL CONSTRAINT DF_StatusLevels_LastChangeAt DEFAULT (GETDATE())
 );
 INSERT Mng.StatusLevels(ColorValue,Title,ColorName,Summary,GuideText,Actions) VALUES
  (1,N'الحالة الطبيعية',N'أخضر',N'العمل مستمر بصورة طبيعية. اتبع إجراءات العمل المعتادة وراقب القنوات الرسمية للتحديثات.',NULL,NULL),
  (2,N'تنبيه احترازي',N'أصفر',N'توجد حالة تستدعي الانتباه والاستعداد، مع استمرار العمل وفق الإجراءات المعتادة ما لم يصدر تحديث رسمي.',
     N'تابع التنبيهات، تأكد من وسائل التواصل، واستعد لأي تحديث في الإجراءات.',
     N'تابع قنوات المؤسسة الرسمية باستمرار.'+NCHAR(10)+N'تأكد من جاهزية وسائل التواصل وبيانات الاتصال.'+NCHAR(10)+N'راجع تعليمات السلامة الخاصة بموقعك.'),
  (3,N'حالة مرتفعة',N'برتقالي',N'ارتفع مستوى الحالة ويتطلب الأمر تقليل الحركة غير الضرورية ورفع الجاهزية حتى وصول تعليمات جديدة.',
     N'قلّل الحركة غير الضرورية والتزم بتوجيهات المسؤولين وخطة الاستجابة.',
     N'التزم بتوجيهات المسؤول المباشر وفريق السلامة.'+NCHAR(10)+N'أجّل التنقل والاجتماعات غير الضرورية.'+NCHAR(10)+N'جهّز المتطلبات الأساسية لخطة الاستجابة أو الإخلاء.'),
  (4,N'حالة طوارئ',N'أحمر',N'حالة طارئة تتطلب إيقاف الإجراءات الاعتيادية وتنفيذ التعليمات الرسمية بصورة فورية.',
     N'توقف عن العمل المعتاد ونفّذ تعليمات الطوارئ أو الإخلاء الصادرة فورًا.',
     N'توقف عن العمل المعتاد وحافظ على الهدوء.'+NCHAR(10)+N'نفّذ تعليمات الطوارئ أو الإخلاء فور صدورها.'+NCHAR(10)+N'توجه إلى نقطة التجمع ولا تعد إلى الموقع قبل التصريح.');
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_GetActive AS
BEGIN
 SET NOCOUNT ON;
 SELECT Id,Title,Number FROM Mng.ImportantNumbers WHERE Active=1 ORDER BY SortOrder,Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_GetAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT Id,Title,Number,SortOrder,Active,LastChangeAt FROM Mng.ImportantNumbers ORDER BY SortOrder,Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Save
 @Id int=NULL,@Title nvarchar(150),@Number nvarchar(50),@SortOrder int,@Active bit
AS
BEGIN
 SET NOCOUNT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @Number=LTRIM(RTRIM(@Number));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@Number,N'')=N'' THROW 50039,'Title and number are required.',1;
 IF @Id IS NULL
 BEGIN
  INSERT Mng.ImportantNumbers(Title,Number,SortOrder,Active) VALUES(@Title,@Number,@SortOrder,@Active);
  SELECT CAST(SCOPE_IDENTITY() AS int) AS Id;RETURN;
 END;
 UPDATE Mng.ImportantNumbers SET Title=@Title,Number=@Number,SortOrder=@SortOrder,Active=@Active,LastChangeAt=GETDATE() WHERE Id=@Id;
 IF @@ROWCOUNT=0 THROW 50011,'Important number not found.',1;
 SELECT @Id AS Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Delete @Id int AS
BEGIN
 SET NOCOUNT ON;
 DELETE Mng.ImportantNumbers WHERE Id=@Id;
 IF @@ROWCOUNT=0 THROW 50011,'Important number not found.',1;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_GetAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ColorValue,Title,ColorName,Summary,GuideText,Actions,LastChangeAt FROM Mng.StatusLevels ORDER BY ColorValue;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_Save
 @ColorValue tinyint,@Title nvarchar(100),@ColorName nvarchar(30),@Summary nvarchar(600),@GuideText nvarchar(300)=NULL,@Actions nvarchar(1500)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @ColorName=LTRIM(RTRIM(@ColorName));SET @Summary=LTRIM(RTRIM(@Summary));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@ColorName,N'')=N'' OR ISNULL(@Summary,N'')=N'' THROW 50039,'Title, colour name and description are required.',1;
 UPDATE Mng.StatusLevels SET Title=@Title,ColorName=@ColorName,Summary=@Summary,
  GuideText=NULLIF(LTRIM(RTRIM(@GuideText)),N''),Actions=NULLIF(LTRIM(RTRIM(@Actions)),N''),LastChangeAt=GETDATE()
 WHERE ColorValue=@ColorValue;
 IF @@ROWCOUNT=0 THROW 50011,'Status level not found.',1;
END;
GO
