-- DEVELOPMENT ONLY. Inferred schemas, never run against real source databases.
USE master;
GO
IF DB_ID(N'IsnadDB') IS NULL BEGIN EXEC(N'CREATE DATABASE IsnadDB'); EXEC IsnadDB.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1; END;
GO
IF DB_ID(N'ReportsDB') IS NULL BEGIN EXEC(N'CREATE DATABASE ReportsDB'); EXEC ReportsDB.sys.sp_addextendedproperty @name=N'CompanyPortalDevelopmentFixture',@value=1; END;
GO
IF NOT EXISTS(SELECT 1 FROM IsnadDB.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1) OR NOT EXISTS(SELECT 1 FROM ReportsDB.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1) BEGIN SET NOEXEC ON; THROW 50040,'Marked technical-service development databases required.',1; END;
GO
USE IsnadDB;
GO
IF OBJECT_ID(N'dbo.Recipients',N'U') IS NULL CREATE TABLE dbo.Recipients(RecipientId int IDENTITY(1,1) NOT NULL PRIMARY KEY,RecipientName nvarchar(500) NOT NULL,Active bit NOT NULL DEFAULT(1));
IF OBJECT_ID(N'dbo.Requests',N'U') IS NULL CREATE TABLE dbo.Requests(RequestId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,UserId int NOT NULL,RecipientId int NOT NULL REFERENCES dbo.Recipients(RecipientId),Details nvarchar(4000) NOT NULL,OfficeNumber nvarchar(100) NULL,DocumentNumber nvarchar(200) NULL,RequestKey uniqueidentifier NOT NULL,Timestamp datetime NOT NULL DEFAULT(GETDATE()),Active bit NOT NULL DEFAULT(1),CONSTRAINT UQ_Isnad_Request UNIQUE(UserId,RequestKey));
IF NOT EXISTS(SELECT 1 FROM dbo.Recipients) INSERT dbo.Recipients(RecipientName) VALUES(N'الدعم التقني'),(N'إدارة المرافق'),(N'الدعم التشغيلي');
GO
USE ReportsDB;
GO
IF OBJECT_ID(N'dbo.Categories',N'U') IS NULL CREATE TABLE dbo.Categories(CategoryId int IDENTITY(1,1) NOT NULL PRIMARY KEY,CategoryName nvarchar(300) NOT NULL,RequiresRecipient bit NOT NULL DEFAULT(0),Active bit NOT NULL DEFAULT(1));
IF OBJECT_ID(N'dbo.Recipients',N'U') IS NULL CREATE TABLE dbo.Recipients(RecipientId int IDENTITY(1,1) NOT NULL PRIMARY KEY,CategoryId int NOT NULL REFERENCES dbo.Categories(CategoryId),RecipientName nvarchar(500) NOT NULL,Active bit NOT NULL DEFAULT(1));
IF OBJECT_ID(N'dbo.ReportTypes',N'U') IS NULL CREATE TABLE dbo.ReportTypes(TypeId int IDENTITY(1,1) NOT NULL PRIMARY KEY,CategoryId int NOT NULL REFERENCES dbo.Categories(CategoryId),TypeName nvarchar(300) NOT NULL,Active bit NOT NULL DEFAULT(1));
IF OBJECT_ID(N'dbo.InitiativeTypes',N'U') IS NULL CREATE TABLE dbo.InitiativeTypes(TypeId int IDENTITY(1,1) NOT NULL PRIMARY KEY,TypeName nvarchar(300) NOT NULL,Active bit NOT NULL DEFAULT(1));
IF OBJECT_ID(N'dbo.Reports',N'U') IS NULL CREATE TABLE dbo.Reports(ReportId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,UserId int NOT NULL,CategoryId int NOT NULL REFERENCES dbo.Categories(CategoryId),RecipientId int NULL REFERENCES dbo.Recipients(RecipientId),TypeId int NOT NULL REFERENCES dbo.ReportTypes(TypeId),Title nvarchar(500) NOT NULL,Details nvarchar(4000) NOT NULL,RequestKey uniqueidentifier NOT NULL,Timestamp datetime NOT NULL DEFAULT(GETDATE()),Active bit NOT NULL DEFAULT(1),CONSTRAINT UQ_Report_Request UNIQUE(UserId,RequestKey));
IF OBJECT_ID(N'dbo.Initiatives',N'U') IS NULL CREATE TABLE dbo.Initiatives(InitiativeId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,UserId int NOT NULL,TypeId int NOT NULL REFERENCES dbo.InitiativeTypes(TypeId),Title nvarchar(500) NOT NULL,Details nvarchar(4000) NOT NULL,RequestKey uniqueidentifier NOT NULL,Timestamp datetime NOT NULL DEFAULT(GETDATE()),Active bit NOT NULL DEFAULT(1),CONSTRAINT UQ_Initiative_Request UNIQUE(UserId,RequestKey));
IF NOT EXISTS(SELECT 1 FROM dbo.Categories) INSERT dbo.Categories(CategoryName,RequiresRecipient) VALUES(N'بلاغ إلى جهة',1),(N'بلاغ عام',0);
IF NOT EXISTS(SELECT 1 FROM dbo.Recipients) INSERT dbo.Recipients(CategoryId,RecipientName) SELECT CategoryId,N'الدعم التقني' FROM dbo.Categories WHERE RequiresRecipient=1 UNION ALL SELECT CategoryId,N'الخدمات الإدارية' FROM dbo.Categories WHERE RequiresRecipient=1;
IF NOT EXISTS(SELECT 1 FROM dbo.ReportTypes) INSERT dbo.ReportTypes(CategoryId,TypeName) SELECT CategoryId,N'عطل تقني' FROM dbo.Categories WHERE RequiresRecipient=1 UNION ALL SELECT CategoryId,N'طلب صيانة' FROM dbo.Categories WHERE RequiresRecipient=1 UNION ALL SELECT CategoryId,N'ملاحظة على خدمة' FROM dbo.Categories WHERE RequiresRecipient=0 UNION ALL SELECT CategoryId,N'ملاحظة على بيئة العمل' FROM dbo.Categories WHERE RequiresRecipient=0;
IF NOT EXISTS(SELECT 1 FROM dbo.InitiativeTypes) INSERT dbo.InitiativeTypes(TypeName) VALUES(N'تحسين الخدمات'),(N'بيئة العمل'),(N'التحول الرقمي');
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Portal.Isnad_Recipients_Get @UserId int AS BEGIN SET NOCOUNT ON; SELECT RecipientId Id,RecipientName Name FROM IsnadDB.dbo.Recipients WHERE Active=1 ORDER BY RecipientId; END;
GO
CREATE OR ALTER PROCEDURE Portal.Reports_Categories_Get @UserId int AS BEGIN SET NOCOUNT ON; SELECT CategoryId Id,CategoryName Name,RequiresRecipient FROM ReportsDB.dbo.Categories WHERE Active=1 ORDER BY CategoryId; END;
GO
CREATE OR ALTER PROCEDURE Portal.Reports_Recipients_Get @UserId int AS BEGIN SET NOCOUNT ON; SELECT r.RecipientId Id,r.RecipientName Name,r.CategoryId FROM ReportsDB.dbo.Recipients r INNER JOIN ReportsDB.dbo.Categories c ON c.CategoryId=r.CategoryId WHERE r.Active=1 AND c.Active=1 ORDER BY r.RecipientId; END;
GO
CREATE OR ALTER PROCEDURE Portal.Reports_Types_Get @UserId int AS BEGIN SET NOCOUNT ON; SELECT t.TypeId Id,t.TypeName Name,t.CategoryId FROM ReportsDB.dbo.ReportTypes t INNER JOIN ReportsDB.dbo.Categories c ON c.CategoryId=t.CategoryId WHERE t.Active=1 AND c.Active=1 ORDER BY t.TypeId; END;
GO
CREATE OR ALTER PROCEDURE Portal.Initiatives_Types_Get @UserId int AS BEGIN SET NOCOUNT ON; SELECT TypeId Id,TypeName Name FROM ReportsDB.dbo.InitiativeTypes WHERE Active=1 ORDER BY TypeId; END;
GO
CREATE OR ALTER PROCEDURE Portal.Isnad_Create @UserId int,@RecipientId int,@Details nvarchar(4000),@OfficeNumber nvarchar(100)=NULL,@DocumentNumber nvarchar(200)=NULL,@RequestKey uniqueidentifier=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @RequestKey IS NULL OR NULLIF(LTRIM(RTRIM(@Details)),N'') IS NULL THROW 50012,'Required request values missing.',1;
 BEGIN TRANSACTION;
 DECLARE @Id bigint;SELECT @Id=RequestId FROM IsnadDB.dbo.Requests WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND RequestKey=@RequestKey;
 IF @Id IS NULL BEGIN
 IF NOT EXISTS(SELECT 1 FROM IsnadDB.dbo.Recipients WHERE RecipientId=@RecipientId AND Active=1) THROW 50012,'Invalid recipient.',1;
 INSERT IsnadDB.dbo.Requests(UserId,RecipientId,Details,OfficeNumber,DocumentNumber,RequestKey) VALUES(@UserId,@RecipientId,@Details,@OfficeNumber,@DocumentNumber,@RequestKey);SET @Id=SCOPE_IDENTITY();
 END;
 COMMIT;SELECT @Id;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Reports_Create @UserId int,@CategoryId int,@RecipientId int=NULL,@TypeId int=NULL,@Title nvarchar(500)=NULL,@Details nvarchar(4000)=NULL,@RequestKey uniqueidentifier=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @RequestKey IS NULL OR NULLIF(LTRIM(RTRIM(@Details)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Title)),N'') IS NULL THROW 50012,'Required request values missing.',1;
 BEGIN TRANSACTION;
 DECLARE @Id bigint;SELECT @Id=ReportId FROM ReportsDB.dbo.Reports WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND RequestKey=@RequestKey;
 IF @Id IS NULL BEGIN
 IF NOT EXISTS(SELECT 1 FROM ReportsDB.dbo.Categories WHERE CategoryId=@CategoryId AND Active=1) OR NOT EXISTS(SELECT 1 FROM ReportsDB.dbo.ReportTypes WHERE TypeId=@TypeId AND CategoryId=@CategoryId AND Active=1) THROW 50012,'Invalid report classification or type.',1; IF EXISTS(SELECT 1 FROM ReportsDB.dbo.Categories WHERE CategoryId=@CategoryId AND RequiresRecipient=1) BEGIN IF NOT EXISTS(SELECT 1 FROM ReportsDB.dbo.Recipients WHERE RecipientId=@RecipientId AND CategoryId=@CategoryId AND Active=1) THROW 50012,'Invalid recipient.',1; END ELSE IF @RecipientId IS NOT NULL THROW 50012,'Recipient not allowed.',1;
 INSERT ReportsDB.dbo.Reports(UserId,CategoryId,RecipientId,TypeId,Title,Details,RequestKey) VALUES(@UserId,@CategoryId,@RecipientId,@TypeId,@Title,@Details,@RequestKey);SET @Id=SCOPE_IDENTITY();
 END;
 COMMIT;SELECT @Id;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Initiatives_Create @UserId int,@TypeId int,@Title nvarchar(500),@Details nvarchar(4000),@RequestKey uniqueidentifier=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @RequestKey IS NULL OR NULLIF(LTRIM(RTRIM(@Details)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Title)),N'') IS NULL THROW 50012,'Required request values missing.',1;
 BEGIN TRANSACTION;
 DECLARE @Id bigint;SELECT @Id=InitiativeId FROM ReportsDB.dbo.Initiatives WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND RequestKey=@RequestKey;
 IF @Id IS NULL BEGIN
 IF NOT EXISTS(SELECT 1 FROM ReportsDB.dbo.InitiativeTypes WHERE TypeId=@TypeId AND Active=1) THROW 50012,'Invalid initiative type.',1;
 INSERT ReportsDB.dbo.Initiatives(UserId,TypeId,Title,Details,RequestKey) VALUES(@UserId,@TypeId,@Title,@Details,@RequestKey);SET @Id=SCOPE_IDENTITY();
 END;
 COMMIT;SELECT @Id;
END;
GO
