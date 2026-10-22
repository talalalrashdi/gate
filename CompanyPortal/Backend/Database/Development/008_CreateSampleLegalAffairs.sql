-- DEVELOPMENT ONLY. Inferred schema, not the real legal system.
USE master;
GO
IF DB_ID(N'LegelAffairs') IS NULL
BEGIN
 EXEC(N'CREATE DATABASE LegelAffairs');
 EXEC LegelAffairs.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1;
END;
GO
USE LegelAffairs;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 THROW 50031,'Refusing to modify an unmarked existing legal database.',1;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.Decisions',N'U') IS NULL
CREATE TABLE dbo.Decisions(
 DecisionId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 DecisionType nvarchar(200) NOT NULL,
 Title nvarchar(1000) NOT NULL,
 PublishedAt datetime NOT NULL DEFAULT(GETDATE()),
 PdfFileName nvarchar(4000) NOT NULL,
 IsPublic bit NOT NULL DEFAULT(1),
 Active bit NOT NULL DEFAULT(1)
);
IF OBJECT_ID(N'dbo.DecisionUsers',N'U') IS NULL
CREATE TABLE dbo.DecisionUsers(
 DecisionUserId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
 DecisionId bigint NOT NULL REFERENCES dbo.Decisions(DecisionId),
 UserId int NOT NULL,
 Active bit NOT NULL DEFAULT(1),
 CONSTRAINT UQ_LegalDecisionUsers UNIQUE(DecisionId,UserId)
);
IF NOT EXISTS(SELECT 1 FROM dbo.Decisions)
BEGIN
 INSERT dbo.Decisions(DecisionType,Title,PublishedAt,PdfFileName,IsPublic) VALUES
 (N'قرارات إدارية',N'تنظيم إجراءات العمل','20261021 09:00',N'decision-1.pdf',1),
 (N'تعاميم',N'مواعيد تقديم الطلبات','20261020 10:30',N'decision-2.pdf',1),
 (N'سياسات',N'سياسة حفظ الوثائق','20261018 08:15',N'decision-3.pdf',1),
 (N'قرارات إدارية',N'اعتماد خطة التدريب','20261015 11:00',N'decision-4.pdf',1),
 (N'تعاميم',N'تنظيم استخدام المرافق','20261010 09:45',N'decision-5.pdf',1),
 (N'قرارات إدارية',N'قرار مخصص للموظف المخول','20261022 08:00',N'decision-6.pdf',0);
END;
-- Only the explicitly identified local test employee receives the restricted sample.
INSERT dbo.DecisionUsers(DecisionId,UserId)
SELECT d.DecisionId,u.UserId FROM dbo.Decisions d CROSS JOIN SecurityDB.dbo.Users u
WHERE d.Title=N'قرار مخصص للموظف المخول' AND d.IsPublic=0 AND u.NTName=ORIGINAL_LOGIN() AND u.Active=1
 AND NOT EXISTS(SELECT 1 FROM dbo.DecisionUsers g WHERE g.DecisionId=d.DecisionId AND g.UserId=u.UserId);
COMMIT;
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Legal.Decisions_getForUser @UserId int,@DecisionId bigint=NULL AS
BEGIN
 SET NOCOUNT ON;
 SELECT d.DecisionId,d.DecisionType,d.Title,d.PublishedAt,d.PdfFileName
 FROM LegelAffairs.dbo.Decisions d
 WHERE d.Active=1 AND d.PublishedAt<=GETDATE() AND (@DecisionId IS NULL OR d.DecisionId=@DecisionId)
 AND (d.IsPublic=1 OR EXISTS(SELECT 1 FROM LegelAffairs.dbo.DecisionUsers g
  WHERE g.DecisionId=d.DecisionId AND g.UserId=@UserId AND g.Active=1))
 ORDER BY d.PublishedAt DESC,d.DecisionId DESC;
END;
GO
