USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO
IF OBJECT_ID(N'Master.ApplicationCategories',N'U') IS NULL
 CREATE TABLE [Master].ApplicationCategories(
  ApplicationCategoryId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ApplicationCategories PRIMARY KEY,
  CategoryName nvarchar(200) NOT NULL,
  DisplayOrder int NOT NULL CONSTRAINT DF_ApplicationCategories_Order DEFAULT(0),
  Active bit NOT NULL CONSTRAINT DF_ApplicationCategories_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_ApplicationCategories_Changed DEFAULT(GETDATE()),
  CONSTRAINT CK_ApplicationCategories_Name CHECK(LEN(LTRIM(RTRIM(CategoryName)))>0),
  CONSTRAINT CK_ApplicationCategories_Order CHECK(DisplayOrder>=0));
IF OBJECT_ID(N'Master.ApplicationDetails',N'U') IS NULL
 CREATE TABLE [Master].ApplicationDetails(
  ApplicationDetailId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ApplicationDetails PRIMARY KEY,
  AppId int NOT NULL CONSTRAINT UQ_ApplicationDetails_App UNIQUE,
  ApplicationCategoryId int NULL CONSTRAINT FK_ApplicationDetails_Category REFERENCES [Master].ApplicationCategories(ApplicationCategoryId),
  AppDescription nvarchar(2000) NOT NULL CONSTRAINT DF_ApplicationDetails_Description DEFAULT(N''),
  Active bit NOT NULL CONSTRAINT DF_ApplicationDetails_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_ApplicationDetails_Changed DEFAULT(GETDATE()));
GO
-- Keep Security.Apps_getForUser's three-column contract unchanged: existing
-- personal/master card procedures also INSERT EXEC that permission adapter.
CREATE OR ALTER PROCEDURE [Master].Applications_getForUser @UserId int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
 INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
 SELECT a.AppId,a.AppName,ISNULL(d.AppDescription,N'') AS Description,
 c.ApplicationCategoryId AS CategoryId,ISNULL(c.CategoryName,N'غير مصنف') AS CategoryName,
 ISNULL(c.DisplayOrder,2147483647) AS CategoryOrder
 FROM @Allowed a LEFT JOIN [Master].ApplicationDetails d ON d.AppId=a.AppId AND d.Active=1
 LEFT JOIN [Master].ApplicationCategories c ON c.ApplicationCategoryId=d.ApplicationCategoryId AND c.Active=1
 ORDER BY ISNULL(c.DisplayOrder,2147483647),c.CategoryName,a.AppName,a.AppId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_adminGet AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 SELECT a.AppId,a.AppName,ISNULL(d.AppDescription,N'') AS Description,
 d.ApplicationCategoryId AS CategoryId,d.LastChangeAt
 FROM @Apps a LEFT JOIN [Master].ApplicationDetails d ON d.AppId=a.AppId AND d.Active=1 ORDER BY a.AppName,a.AppId;
 SELECT ApplicationCategoryId AS CategoryId,CategoryName,DisplayOrder,Active,LastChangeAt
 FROM [Master].ApplicationCategories ORDER BY DisplayOrder,CategoryName,ApplicationCategoryId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_save
 @AppId int,@Description nvarchar(2000),@CategoryId int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @Description IS NULL THROW 50012,'Supply a description, optionally empty.',1;
 SET @Description=LTRIM(RTRIM(@Description));
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 IF NOT EXISTS(SELECT 1 FROM @Apps WHERE AppId=@AppId) THROW 50011,'Application not found in current catalog.',1;
 BEGIN TRY
 BEGIN TRAN;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WITH(HOLDLOCK) WHERE ApplicationCategoryId=@CategoryId)
  THROW 50012,'Category not found.',1;
 DECLARE @Existing int=(SELECT ApplicationDetailId FROM [Master].ApplicationDetails WITH(UPDLOCK,HOLDLOCK) WHERE AppId=@AppId);
 IF @Existing IS NULL
  INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription) VALUES(@AppId,@CategoryId,@Description);
 ELSE
  UPDATE [Master].ApplicationDetails SET ApplicationCategoryId=@CategoryId,AppDescription=@Description,Active=1,LastChangeAt=GETDATE()
  WHERE ApplicationDetailId=@Existing AND (Active=0 OR EXISTS(
   SELECT @CategoryId,@Description COLLATE Latin1_General_100_BIN2 EXCEPT SELECT ApplicationCategoryId,AppDescription COLLATE Latin1_General_100_BIN2 FROM [Master].ApplicationDetails WHERE ApplicationDetailId=@Existing));
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].ApplicationCategories_save
 @CategoryName nvarchar(200),@DisplayOrder int,@Active bit,@CategoryId int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET @CategoryName=LTRIM(RTRIM(@CategoryName));
 IF @CategoryName IS NULL OR LEN(@CategoryName)=0 OR @DisplayOrder IS NULL OR @DisplayOrder<0 OR @Active IS NULL
  THROW 50012,'Check category name, order and availability.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ApplicationCategories',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50012,'Category settings busy. Retry.',1;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId)
  THROW 50011,'Category not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].ApplicationCategories WHERE CategoryName=@CategoryName AND (@CategoryId IS NULL OR ApplicationCategoryId<>@CategoryId))
  THROW 50012,'Category name already exists.',1;
 IF @CategoryId IS NULL
 BEGIN
  INSERT [Master].ApplicationCategories(CategoryName,DisplayOrder,Active) VALUES(@CategoryName,@DisplayOrder,@Active);
  SET @CategoryId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE UPDATE [Master].ApplicationCategories SET CategoryName=@CategoryName,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE ApplicationCategoryId=@CategoryId AND EXISTS(
  SELECT @CategoryName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@Active EXCEPT SELECT CategoryName COLLATE Latin1_General_100_BIN2,DisplayOrder,Active FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId);
 COMMIT;
 SELECT @CategoryId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
