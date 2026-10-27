USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON;SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;SET ARITHABORT ON;SET NUMERIC_ROUNDABORT OFF;
GO
/* Admin change history. Every admin save procedure takes @ChangedBy (the employee's Windows name, passed by
   the API; falls back to ORIGINAL_LOGIN() for direct SQL calls), snapshots the item before (after its locks)
   and after (before COMMIT), and calls Portal.AdminChanges_Add inside the same transaction. No-op saves are
   not recorded. Snapshots exclude LastChangeAt and binary image data.
   Later migrations that ALTER these procedures must keep the history lines. */
IF OBJECT_ID(N'Portal.AdminChanges',N'U') IS NULL
CREATE TABLE Portal.AdminChanges(
 AdminChangeId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AdminChanges PRIMARY KEY,
 ChangedAt datetime NOT NULL CONSTRAINT DF_AdminChanges_ChangedAt DEFAULT GETDATE(),
 ChangedBy nvarchar(512) NOT NULL,
 Section varchar(40) NOT NULL,
 Action varchar(20) NOT NULL CONSTRAINT CK_AdminChanges_Action CHECK(Action IN('create','update','delete','apply-to-all')),
 ItemType varchar(40) NOT NULL,
 ItemId nvarchar(100) NOT NULL,
 ItemTitle nvarchar(300) NULL,
 OldJson nvarchar(max) NULL,
 NewJson nvarchar(max) NULL);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_AdminChanges_Section' AND object_id=OBJECT_ID(N'Portal.AdminChanges'))
 CREATE INDEX IX_AdminChanges_Section ON Portal.AdminChanges(Section,AdminChangeId DESC);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_AdminChanges_Item' AND object_id=OBJECT_ID(N'Portal.AdminChanges'))
 CREATE INDEX IX_AdminChanges_Item ON Portal.AdminChanges(Section,ItemType,ItemId,AdminChangeId DESC);
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_Add
 @ChangedBy nvarchar(512)=NULL,@Section varchar(40),@ItemType varchar(40),@ItemId nvarchar(100),@ItemTitle nvarchar(300)=NULL,
 @OldJson nvarchar(max)=NULL,@NewJson nvarchar(max)=NULL,@Action varchar(20)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @OldJson IS NULL AND @NewJson IS NULL RETURN;
 IF @Action IS NULL AND @OldJson COLLATE Latin1_General_100_BIN2=@NewJson COLLATE Latin1_General_100_BIN2 RETURN; -- no-op save
 INSERT Portal.AdminChanges(ChangedBy,Section,Action,ItemType,ItemId,ItemTitle,OldJson,NewJson)
 VALUES(COALESCE(NULLIF(LTRIM(RTRIM(@ChangedBy)),N''),ORIGINAL_LOGIN()),@Section,
  COALESCE(@Action,CASE WHEN @OldJson IS NULL THEN 'create' WHEN @NewJson IS NULL THEN 'delete' ELSE 'update' END),
  @ItemType,@ItemId,LEFT(@ItemTitle,300),@OldJson,@NewJson);
END;
GO
-- Item snapshots (JSON). NULL when the item does not exist.
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Card(@CardId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT c.CardName,c.CardType,c.DisplayOrder,c.IsFixed,c.Active,c.Audience,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(CONVERT(nvarchar(20),a.AppId),N',') WITHIN GROUP(ORDER BY a.AppId) FROM [Master].CardApplications a WHERE a.CardId=c.CardId AND a.Active=1),N'')+N']') Apps,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(N'"'+STRING_ESCAPE(r.RoleName,'json')+N'"',N',') WITHIN GROUP(ORDER BY r.RoleName) FROM [Master].CardRoles r WHERE r.CardId=c.CardId AND r.Active=1),N'')+N']') Roles
  FROM [Master].Cards c WHERE c.CardId=@CardId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_ApplicationCategory(@CategoryId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT CategoryName,DisplayOrder,Active FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Application(@AppId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT d.AppDescription [Description],d.ApplicationCategoryId CategoryId,c.CategoryName Category,d.Active
  FROM [Master].ApplicationDetails d LEFT JOIN [Master].ApplicationCategories c ON c.ApplicationCategoryId=d.ApplicationCategoryId
  WHERE d.AppId=@AppId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_DocumentTab(@DocumentTabID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT t.TabName,t.SectionKey,t.FolderID,t.DisplayOrder,t.Active,
  JSON_QUERY((SELECT i.DocumentID,d.DocumentName FROM Portal.DocumentTabItems i LEFT JOIN Mng.Document d ON d.DocumentID=i.DocumentID
   WHERE i.DocumentTabID=t.DocumentTabID ORDER BY i.DocumentID FOR JSON PATH,INCLUDE_NULL_VALUES)) Documents
  FROM Portal.DocumentTabs t WHERE t.DocumentTabID=@DocumentTabID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_FixedOrder(@FixedOrderID bigint) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT [Timestamp],Timestamp2,TimestampType,ContentBefor,ContentAfter,ContentText FROM Portal.FixedOrders WHERE FixedOrderID=@FixedOrderID
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_NoticeSettings(@ChannelID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT DurationDays,JSON_QUERY(CASE WHEN ISJSON(DecisionTypes)=1 THEN DecisionTypes END) DecisionTypes,Active
  FROM Portal.DecisionNoticeSettings WHERE ChannelID=@ChannelID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_NoticeWindow(@ChannelID int,@DecisionId bigint) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT DecisionId,FromAt,ToAt,IsHidden,Active FROM Portal.DecisionNoticeWindows WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Media(@MediaID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT MediaName,MediaType,MediaPath,MediaGroupID,DisplayOrder,Active FROM Portal.Media WHERE MediaID=@MediaID
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_MediaGroup(@MediaGroupID int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT GroupName,CoverMediaID,DisplayOrder,Active FROM Portal.MediaGroups WHERE MediaGroupID=@MediaGroupID
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Image(@ImageId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT ImageName,ContentType,PixelWidth,PixelHeight,Active FROM [Master].Images WHERE ImageId=@ImageId
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_ImageGroup(@ImageGroupId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT g.GroupName,g.RotateImages,g.RotationSeconds,g.DefaultImageId,g.Active,
  JSON_QUERY((SELECT i.ImageId,i.DisplayOrder,i.Active FROM [Master].ImageGroupItems i WHERE i.ImageGroupId=g.ImageGroupId
   ORDER BY i.DisplayOrder,i.ImageId FOR JSON PATH)) Items
  FROM [Master].ImageGroups g WHERE g.ImageGroupId=@ImageGroupId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Theme(@ThemeId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT t.ThemeName,t.LayoutKey,t.DisplayOrder,t.IsDefault,t.Active,t.Visibility,t.Deleted,t.PrimaryColor,t.AccentColor,t.BackgroundColor,
  t.OverlayOpacity,t.ForegroundPreset,t.ImagePresentation,t.ImageGroupId,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(N'"'+STRING_ESCAPE(r.RoleName,'json')+N'"',N',') WITHIN GROUP(ORDER BY r.RoleName) FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=t.ThemeId AND r.Active=1),N'')+N']') PreviewRoles
  FROM [Master].Themes t WHERE t.ThemeId=@ThemeId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_ImportantNumber(@Id int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT Title,Number,SortOrder,Active FROM Mng.ImportantNumbers WHERE Id=@Id FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_StatusLevel(@ColorValue tinyint) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT Title,ColorName,Summary,GuideText,Actions FROM Mng.StatusLevels WHERE ColorValue=@ColorValue FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO

/* ===== Admin save procedures (bodies unchanged except the lines marked -- history) ===== */

CREATE OR ALTER PROCEDURE [Master].ApplicationCategories_save
 @CategoryName nvarchar(200),@DisplayOrder int,@Active bit,@CategoryId int=NULL,@ChangedBy nvarchar(512)=NULL
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
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_ApplicationCategory(@CategoryId); -- history
 IF @CategoryId IS NULL
 BEGIN
  INSERT [Master].ApplicationCategories(CategoryName,DisplayOrder,Active) VALUES(@CategoryName,@DisplayOrder,@Active);
  SET @CategoryId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE UPDATE [Master].ApplicationCategories SET CategoryName=@CategoryName,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE ApplicationCategoryId=@CategoryId AND EXISTS(
  SELECT @CategoryName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@Active EXCEPT SELECT CategoryName COLLATE Latin1_General_100_BIN2,DisplayOrder,Active FROM [Master].ApplicationCategories WHERE ApplicationCategoryId=@CategoryId);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_ApplicationCategory(@CategoryId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='applications',@ItemType='category',@ItemId=@CategoryId,@ItemTitle=@CategoryName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @CategoryId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_save
 @AppId int,@Description nvarchar(2000),@CategoryId int=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @Description IS NULL THROW 50012,'Supply a description, optionally empty.',1;
 SET @Description=LTRIM(RTRIM(@Description));
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 IF NOT EXISTS(SELECT 1 FROM @Apps WHERE AppId=@AppId) THROW 50011,'Application not found in current catalog.',1;
 DECLARE @AppName nvarchar(200)=(SELECT AppName FROM @Apps WHERE AppId=@AppId); -- history
 BEGIN TRY
 BEGIN TRAN;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WITH(HOLDLOCK) WHERE ApplicationCategoryId=@CategoryId)
  THROW 50012,'Category not found.',1;
 DECLARE @Existing int=(SELECT ApplicationDetailId FROM [Master].ApplicationDetails WITH(UPDLOCK,HOLDLOCK) WHERE AppId=@AppId);
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Application(@AppId); -- history
 IF @Existing IS NULL
  INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription) VALUES(@AppId,@CategoryId,@Description);
 ELSE
  UPDATE [Master].ApplicationDetails SET ApplicationCategoryId=@CategoryId,AppDescription=@Description,Active=1,LastChangeAt=GETDATE()
  WHERE ApplicationDetailId=@Existing AND (Active=0 OR EXISTS(
   SELECT @CategoryId,@Description COLLATE Latin1_General_100_BIN2 EXCEPT SELECT ApplicationCategoryId,AppDescription COLLATE Latin1_General_100_BIN2 FROM [Master].ApplicationDetails WHERE ApplicationDetailId=@Existing));
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Application(@AppId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='applications',@ItemType='application',@ItemId=@AppId,@ItemTitle=@AppName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_save
 @CardName nvarchar(200),@IsFixed bit,@DisplayOrder int,@Active bit,@Audience nvarchar(20),
 @AppsJson nvarchar(max),@RolesJson nvarchar(max),@CardId int=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET ARITHABORT ON;
 SET NUMERIC_ROUNDABORT OFF;
 SET @CardName=LTRIM(RTRIM(@CardName));
 IF @CardName IS NULL OR LEN(@CardName)=0 OR @IsFixed IS NULL OR @Active IS NULL
 OR @DisplayOrder IS NULL OR @DisplayOrder<1 OR @Audience NOT IN(N'everyone',N'roles') OR @Audience IS NULL
 OR ISJSON(@AppsJson)<>1 OR ISJSON(@RolesJson)<>1
  THROW 50006,'Check card details.',1;
 DECLARE @Apps TABLE(AppId int PRIMARY KEY);
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@AppsJson) WHERE type<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value)<1)
 OR EXISTS(SELECT 1 FROM OPENJSON(@RolesJson) WHERE type<>1 OR LEN(value)>200 OR LEN(LTRIM(RTRIM(value)))=0)
  THROW 50006,'Invalid applications or roles.',1;
 INSERT @Apps SELECT DISTINCT CONVERT(int,value) FROM OPENJSON(@AppsJson);
 INSERT @Roles SELECT DISTINCT CONVERT(nvarchar(200),value) COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@RolesJson);
 IF (SELECT COUNT(*) FROM @Apps)>100 OR (SELECT COUNT(*) FROM @Roles)>50
 OR (@Audience=N'roles' AND NOT EXISTS(SELECT 1 FROM @Roles))
 OR (@Audience=N'everyone' AND EXISTS(SELECT 1 FROM @Roles)) THROW 50006,'Check audience roles.',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MasterCards',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50006,'Card settings are busy. Retry.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Card(@CardId); -- history
 DECLARE @Type nvarchar(30)=N'applications';
 IF @CardId IS NOT NULL
 BEGIN
  SELECT @Type=CardType FROM [Master].Cards WITH(UPDLOCK,HOLDLOCK) WHERE CardId=@CardId;
  IF NOT EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId=@CardId AND (CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services')))
   THROW 50006,'Select an available card.',1;
 END;
 IF (@Type=N'applications' AND NOT EXISTS(SELECT 1 FROM @Apps)) OR (@Type=N'connected' AND EXISTS(SELECT 1 FROM @Apps))
  THROW 50006,'Application cards require apps; connected cards do not accept app membership.',1;
 -- Validate membership against the current approved catalog, not employee grants.
 IF @Type=N'applications'
 BEGIN
  DECLARE @Catalog TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
  INSERT @Catalog EXEC Security.Apps_getForAdministration;
  IF EXISTS(SELECT 1 FROM @Apps a LEFT JOIN @Catalog c ON c.AppId=a.AppId WHERE c.AppId IS NULL)
   THROW 50006,'Select applications from the current catalog.',1;
 END;
 IF @CardId IS NULL
 BEGIN
  IF (SELECT COUNT(*) FROM [Master].Cards WHERE CardType=N'applications')>=100 THROW 50006,'Application card limit reached.',1;
  INSERT [Master].Cards(CardKey,CardName,DisplayOrder,IsFixed,Active,CardType,Audience)
  VALUES(N'master-'+LOWER(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')),@CardName,@DisplayOrder,0,0,N'applications',@Audience);
  SET @CardId=CONVERT(int,SCOPE_IDENTITY());
 END;
 DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1 AND CardId<>@CardId)+CONVERT(int,@Active);
 IF (@Active=1 AND @DisplayOrder>CASE WHEN @Count=0 THEN 1 ELSE @Count END)
 OR @DisplayOrder>200
 OR (@Active=1 AND @IsFixed=1 AND EXISTS(SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND CardId<>@CardId AND DisplayOrder=@DisplayOrder))
 OR EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId<>@CardId AND Active=1 AND IsFixed=1 AND DisplayOrder>@Count)
  THROW 50006,'Check position and other fixed slots before hiding or moving cards.',1;
 DECLARE @Changed bit=0;
 IF EXISTS(SELECT @CardName COLLATE Latin1_General_100_BIN2,@DisplayOrder,@IsFixed,@Active,@Audience
  EXCEPT SELECT CardName COLLATE Latin1_General_100_BIN2,DisplayOrder,IsFixed,Active,Audience FROM [Master].Cards WHERE CardId=@CardId)
 OR EXISTS(SELECT AppId FROM @Apps EXCEPT SELECT AppId FROM [Master].CardApplications WHERE CardId=@CardId AND Active=1)
 OR EXISTS(SELECT AppId FROM [Master].CardApplications WHERE CardId=@CardId AND Active=1 EXCEPT SELECT AppId FROM @Apps)
 OR EXISTS(SELECT RoleName FROM @Roles EXCEPT SELECT RoleName FROM [Master].CardRoles WHERE CardId=@CardId AND Active=1)
 OR EXISTS(SELECT RoleName FROM [Master].CardRoles WHERE CardId=@CardId AND Active=1 EXCEPT SELECT RoleName FROM @Roles)
  SET @Changed=1;
 IF @Changed=1
 UPDATE [Master].Cards SET CardName=@CardName,DisplayOrder=@DisplayOrder,IsFixed=@IsFixed,Active=@Active,Audience=@Audience,LastChangeAt=GETDATE() WHERE CardId=@CardId;
 UPDATE a SET Active=CASE WHEN s.AppId IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM [Master].CardApplications a LEFT JOIN @Apps s ON s.AppId=a.AppId
 WHERE a.CardId=@CardId AND a.Active<>CASE WHEN s.AppId IS NULL THEN 0 ELSE 1 END;
 INSERT [Master].CardApplications(CardId,AppId) SELECT @CardId,a.AppId FROM @Apps a WHERE NOT EXISTS(SELECT 1 FROM [Master].CardApplications x WHERE x.CardId=@CardId AND x.AppId=a.AppId);
 UPDATE r SET Active=CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM [Master].CardRoles r LEFT JOIN @Roles s ON s.RoleName=r.RoleName
 WHERE r.CardId=@CardId AND r.Active<>CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END;
 INSERT [Master].CardRoles(CardId,RoleName) SELECT @CardId,r.RoleName FROM @Roles r WHERE NOT EXISTS(SELECT 1 FROM [Master].CardRoles x WHERE x.CardId=@CardId AND x.RoleName=r.RoleName);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Card(@CardId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='cards',@ItemType='card',@ItemId=@CardId,@ItemTitle=@CardName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @CardId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].ImageGroups_save
 @ImageGroupId int=NULL, @GroupName nvarchar(200), @RotateImages bit, @RotationSeconds int,
 @DefaultImageId int=NULL, @Active bit, @Items [Master].ImageSelection READONLY, @ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
 IF LEN(LTRIM(RTRIM(@GroupName)))=0 OR @RotationSeconds NOT BETWEEN 3 AND 3600 OR (SELECT COUNT(*) FROM @Items)>100
    THROW 50007,'Invalid image group.',1;
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN [Master].Images m WITH(HOLDLOCK) ON i.ImageId=m.ImageId AND m.Active=1 WHERE m.ImageId IS NULL OR i.DisplayOrder<1)
    THROW 50007,'Select active images and valid positions.',1;
 IF @DefaultImageId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Items WHERE ImageId=@DefaultImageId AND Active=1)
    THROW 50007,'Default image must be an active member.',1;
 IF @ImageGroupId IS NULL
 BEGIN
   INSERT [Master].ImageGroups(GroupName,RotateImages,RotationSeconds,DefaultImageId,Active)
   VALUES(@GroupName,@RotateImages,@RotationSeconds,@DefaultImageId,@Active);
   SET @ImageGroupId=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 BEGIN
   IF NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(UPDLOCK,HOLDLOCK) WHERE ImageGroupId=@ImageGroupId)
      THROW 50007,'Image group was not found.',1;
   SET @Before=Portal.AdminSnapshot_ImageGroup(@ImageGroupId); -- history
   DECLARE @Changed bit=0;
   IF EXISTS(SELECT @GroupName COLLATE Latin1_General_100_BIN2,@RotateImages,@RotationSeconds,@DefaultImageId,@Active
      EXCEPT SELECT GroupName COLLATE Latin1_General_100_BIN2,RotateImages,RotationSeconds,DefaultImageId,Active FROM [Master].ImageGroups WHERE ImageGroupId=@ImageGroupId)
      OR EXISTS(SELECT ImageId,DisplayOrder,Active FROM @Items EXCEPT SELECT ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems WHERE ImageGroupId=@ImageGroupId)
      OR EXISTS(SELECT ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems WHERE ImageGroupId=@ImageGroupId EXCEPT SELECT ImageId,DisplayOrder,Active FROM @Items)
      SET @Changed=1;
   UPDATE [Master].ImageGroups WITH(UPDLOCK) SET GroupName=@GroupName,RotateImages=@RotateImages,RotationSeconds=@RotationSeconds,
     DefaultImageId=@DefaultImageId,Active=@Active,LastChangeAt=CASE WHEN @Changed=1 THEN GETDATE() ELSE LastChangeAt END WHERE ImageGroupId=@ImageGroupId;
 END;
 -- Removing a membership does not remove its reusable image.
 DELETE m FROM [Master].ImageGroupItems m
 WHERE m.ImageGroupId=@ImageGroupId AND NOT EXISTS(SELECT 1 FROM @Items i WHERE i.ImageId=m.ImageId);
 UPDATE m SET DisplayOrder=i.DisplayOrder,Active=i.Active,LastChangeAt=GETDATE()
 FROM [Master].ImageGroupItems m JOIN @Items i ON i.ImageId=m.ImageId WHERE m.ImageGroupId=@ImageGroupId AND (m.DisplayOrder<>i.DisplayOrder OR m.Active<>i.Active);
 INSERT [Master].ImageGroupItems(ImageGroupId,ImageId,DisplayOrder,Active)
 SELECT @ImageGroupId,i.ImageId,i.DisplayOrder,i.Active FROM @Items i
 WHERE NOT EXISTS(SELECT 1 FROM [Master].ImageGroupItems m WHERE m.ImageGroupId=@ImageGroupId AND m.ImageId=i.ImageId);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_ImageGroup(@ImageGroupId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image-group',@ItemId=@ImageGroupId,@ItemTitle=@GroupName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @ImageGroupId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_add
 @ImageName nvarchar(200), @ContentType nvarchar(100), @ImageData varbinary(max), @PixelWidth int, @PixelHeight int, @ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: insert and history row commit together
 IF LEN(LTRIM(RTRIM(@ImageName)))=0 THROW 50007,'Image name is required.',1;
 BEGIN TRANSACTION; -- history
 INSERT [Master].Images(ImageName,ContentType,ImageData,PixelWidth,PixelHeight)
 VALUES(@ImageName,@ContentType,@ImageData,@PixelWidth,@PixelHeight);
 DECLARE @ImageId int=CAST(SCOPE_IDENTITY() AS int); -- history
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image',@ItemId=@ImageId,@ItemTitle=@ImageName,@NewJson=@After; -- history
 COMMIT; -- history
 SELECT @ImageId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_delete @ImageId int,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM [Master].Images WITH(UPDLOCK,HOLDLOCK) WHERE ImageId=@ImageId AND Active=1)
 BEGIN COMMIT; SELECT CAST(0 AS bit); RETURN; END;
 IF EXISTS(SELECT 1 FROM [Master].ImageGroupItems WHERE ImageId=@ImageId)
 OR EXISTS(SELECT 1 FROM [Master].ImageGroups WHERE DefaultImageId=@ImageId)
 BEGIN ROLLBACK; THROW 50009,'Remove the image from saved groups before deleting it.',1; END;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId); -- history
 UPDATE [Master].Images SET Active=0,LastChangeAt=GETDATE() WHERE ImageId=@ImageId;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId),@ImageName nvarchar(200)=JSON_VALUE(@Before,'$.ImageName'); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image',@ItemId=@ImageId,@ItemTitle=@ImageName,@OldJson=@Before,@NewJson=@After,@Action='delete'; -- history
 COMMIT;
 SELECT CAST(1 AS bit);
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_applyToAll @ThemeId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND Active=1 AND Deleted=0 AND Visibility=N'public')
 THROW 50008,'Only live public themes can be applied to everyone.',1;
 DECLARE @OldDefault int=(SELECT TOP(1) ThemeId FROM [Master].Themes WHERE IsDefault=1 AND ThemeId<>@ThemeId ORDER BY ThemeId); -- history
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId),@OldBefore nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault); -- history
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND ThemeId<>@ThemeId;
 UPDATE [Master].Themes SET IsDefault=1,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND IsDefault=0;
 UPDATE Portal.UserSettings SET ThemeId=@ThemeId,LastChangeAt=GETDATE() WHERE Active=1 AND ThemeId<>@ThemeId;
 DECLARE @UsersUpdated int=@@ROWCOUNT; -- history
 DECLARE @After nvarchar(max)=JSON_MODIFY(Portal.AdminSnapshot_Theme(@ThemeId),'$.UsersUpdated',@UsersUpdated),@Title nvarchar(200)=JSON_VALUE(@Before,'$.ThemeName'); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After,@Action='apply-to-all'; -- history
 IF @OldDefault IS NOT NULL -- history: the previous default loses IsDefault
 BEGIN
  DECLARE @OldAfter nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault),@OldTitle nvarchar(200)=JSON_VALUE(@OldBefore,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@OldDefault,@ItemTitle=@OldTitle,@OldJson=@OldBefore,@NewJson=@OldAfter;
 END;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_delete @ThemeId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) THROW 50008,'Choose another default first.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 UPDATE [Master].Themes SET Deleted=1,Active=0,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND Deleted=0;
 DECLARE @Found bit=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
 IF @Found=1 -- history
 BEGIN
  DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId),@Title nvarchar(200)=JSON_VALUE(@Before,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After,@Action='delete';
 END;
 COMMIT; SELECT @Found;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL,@Visibility nvarchar(20)=NULL,@PreviewRolesJson nvarchar(max)=N'[]',
 @ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 SET @Visibility=CASE WHEN @Active=0 THEN N'hidden' ELSE COALESCE(@Visibility,N'public') END;
 IF @Visibility NOT IN(N'hidden',N'preview',N'public') OR (@Active=1 AND @Visibility=N'hidden') OR (@IsDefault=1 AND @Visibility<>N'public')
 THROW 50008,'Default must be live for everyone.',1;
 IF ISJSON(@PreviewRolesJson)<>1 OR LEFT(LTRIM(@PreviewRolesJson),1)<>N'[' THROW 50008,'Invalid roles.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@PreviewRolesJson))>50 OR EXISTS(SELECT 1 FROM OPENJSON(@PreviewRolesJson) WHERE [type]<>1 OR LEN(LTRIM(RTRIM(value))) NOT BETWEEN 1 AND 200)
 THROW 50008,'Enter up to 50 role names.',1;
 DECLARE @SelectedRoles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 INSERT @SelectedRoles SELECT DISTINCT LTRIM(RTRIM(value)) COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@PreviewRolesJson);
 IF @Visibility=N'preview' AND NOT EXISTS(SELECT 1 FROM @SelectedRoles) THROW 50008,'Choose preview roles.',1;
 BEGIN TRANSACTION;
 -- Serialize catalog writes, including changes to the single default.
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF LEN(LTRIM(RTRIM(@ThemeName)))=0 OR @DisplayOrder<0 OR @LayoutKey NOT IN(N'official',N'work',N'national-day') OR (@IsDefault=1 AND @Active=0)
 THROW 50008,'Check the theme details.',1;
 IF @ThemeId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId AND Deleted=0)
 THROW 50008,'Theme not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) AND (@IsDefault=0 OR @Active=0 OR @Visibility<>N'public')
 THROW 50008,'Choose another default before disabling this default.',1;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 THROW 50008,'Choose an active image group.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 DECLARE @OldDefault int=(SELECT TOP(1) ThemeId FROM [Master].Themes WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId) ORDER BY ThemeId); -- history
 DECLARE @OldBefore nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault); -- history
 DECLARE @ApplyToAll bit=CASE WHEN @IsDefault=1 AND NOT EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) THEN 1 ELSE 0 END;
 IF @IsDefault=1
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId);
 IF @ThemeId IS NULL
 BEGIN
 INSERT [Master].Themes(ThemeName,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId,Visibility)
 VALUES(@ThemeName,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId,@Visibility);
 SET @ThemeId=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 UPDATE [Master].Themes SET ThemeName=@ThemeName,LayoutKey=@LayoutKey,DisplayOrder=@DisplayOrder,Active=@Active,IsDefault=@IsDefault,
 PrimaryColor=@PrimaryColor,AccentColor=@AccentColor,BackgroundColor=@BackgroundColor,OverlayOpacity=@OverlayOpacity,ForegroundPreset=@ForegroundPreset,ImagePresentation=@ImagePresentation,ImageGroupId=@ImageGroupId,Visibility=@Visibility,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND EXISTS(
 SELECT @ThemeName COLLATE Latin1_General_100_BIN2,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId,@Visibility
 EXCEPT SELECT ThemeName COLLATE Latin1_General_100_BIN2,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId,Visibility FROM [Master].Themes WHERE ThemeId=@ThemeId);
 IF EXISTS(SELECT RoleName FROM @SelectedRoles EXCEPT SELECT RoleName FROM [Master].ThemePreviewRoles WHERE ThemeId=@ThemeId AND Active=1)
 OR EXISTS(SELECT RoleName FROM [Master].ThemePreviewRoles WHERE ThemeId=@ThemeId AND Active=1 EXCEPT SELECT RoleName FROM @SelectedRoles)
 BEGIN
  UPDATE [Master].Themes SET LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId;
  UPDATE r SET Active=CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
  FROM [Master].ThemePreviewRoles r LEFT JOIN @SelectedRoles s ON r.RoleName=s.RoleName
  WHERE r.ThemeId=@ThemeId AND r.Active<>CASE WHEN s.RoleName IS NULL THEN 0 ELSE 1 END;
  INSERT [Master].ThemePreviewRoles(ThemeId,RoleName) SELECT @ThemeId,s.RoleName FROM @SelectedRoles s
  WHERE NOT EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=@ThemeId AND r.RoleName=s.RoleName);
 END;
 IF @ApplyToAll=1 UPDATE Portal.UserSettings SET ThemeId=@ThemeId,LastChangeAt=GETDATE() WHERE Active=1 AND ThemeId<>@ThemeId;
 IF (SELECT COUNT(*) FROM [Master].Themes WHERE Active=1 AND IsDefault=1)<>1 THROW 50008,'Exactly one active default is required.',1;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@ThemeName,@OldJson=@Before,@NewJson=@After; -- history
 IF @OldDefault IS NOT NULL -- history: a new default clears the previous one (no-op otherwise)
 BEGIN
  DECLARE @OldAfter nvarchar(max)=Portal.AdminSnapshot_Theme(@OldDefault),@OldTitle nvarchar(200)=JSON_VALUE(@OldBefore,'$.ThemeName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='themes',@ItemType='theme',@ItemId=@OldDefault,@ItemTitle=@OldTitle,@OldJson=@OldBefore,@NewJson=@OldAfter;
 END;
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_setImageGroup @ThemeId int,@ImageGroupId int=NULL,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Select an active image group.',1; END;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Theme was not found.',1; END;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId); -- history
 UPDATE [Master].Themes SET ImageGroupId=@ImageGroupId,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND Active=1 AND ISNULL(ImageGroupId,0)<>ISNULL(@ImageGroupId,0);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Theme(@ThemeId),@Title nvarchar(200)=JSON_VALUE(@Before,'$.ThemeName'); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='theme',@ItemId=@ThemeId,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Delete @Id int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: delete and history row commit together
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_ImportantNumber(Id) FROM Mng.ImportantNumbers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
 DELETE Mng.ImportantNumbers WHERE Id=@Id;
 IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Important number not found.',1; END;
 DECLARE @Title nvarchar(150)=JSON_VALUE(@Before,'$.Title');
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='important-number',@ItemId=@Id,@ItemTitle=@Title,@OldJson=@Before;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Save
 @Id int=NULL,@Title nvarchar(150),@Number nvarchar(50),@SortOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: save and history row commit together
 SET @Title=LTRIM(RTRIM(@Title));SET @Number=LTRIM(RTRIM(@Number));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@Number,N'')=N'' THROW 50039,'Title and number are required.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max),@After nvarchar(max);
 IF @Id IS NULL
 BEGIN
  INSERT Mng.ImportantNumbers(Title,Number,SortOrder,Active) VALUES(@Title,@Number,@SortOrder,@Active);
  SET @Id=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 BEGIN
  SET @Before=(SELECT Portal.AdminSnapshot_ImportantNumber(Id) FROM Mng.ImportantNumbers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
  UPDATE Mng.ImportantNumbers SET Title=@Title,Number=@Number,SortOrder=@SortOrder,Active=@Active,LastChangeAt=GETDATE() WHERE Id=@Id;
  IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Important number not found.',1; END;
 END;
 SET @After=Portal.AdminSnapshot_ImportantNumber(@Id);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='important-number',@ItemId=@Id,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After;
 COMMIT;
 SELECT @Id AS Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_Save
 @ColorValue tinyint,@Title nvarchar(100),@ColorName nvarchar(30),@Summary nvarchar(600),@GuideText nvarchar(300)=NULL,@Actions nvarchar(1500)=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: save and history row commit together
 SET @Title=LTRIM(RTRIM(@Title));SET @ColorName=LTRIM(RTRIM(@ColorName));SET @Summary=LTRIM(RTRIM(@Summary));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@ColorName,N'')=N'' OR ISNULL(@Summary,N'')=N'' THROW 50039,'Title, colour name and description are required.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_StatusLevel(ColorValue) FROM Mng.StatusLevels WITH(UPDLOCK,HOLDLOCK) WHERE ColorValue=@ColorValue);
 UPDATE Mng.StatusLevels SET Title=@Title,ColorName=@ColorName,Summary=@Summary,
  GuideText=NULLIF(LTRIM(RTRIM(@GuideText)),N''),Actions=NULLIF(LTRIM(RTRIM(@Actions)),N''),LastChangeAt=GETDATE()
 WHERE ColorValue=@ColorValue;
 IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Status level not found.',1; END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_StatusLevel(@ColorValue);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='status-level',@ItemId=@ColorValue,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNotices_Save @ChannelID int,@DurationDays int,@DecisionTypes nvarchar(4000),@Active bit,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DurationDays NOT BETWEEN 1 AND 365 OR ISJSON(@DecisionTypes)<>1 OR LEFT(@DecisionTypes,1)<>'[' THROW 50012,'Invalid notice settings.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@DecisionTypes))>16 OR EXISTS(SELECT 1 FROM OPENJSON(@DecisionTypes) WHERE type<>1 OR LEN(value) NOT BETWEEN 1 AND 200) THROW 50012,'Invalid decision types.',1;
 BEGIN TRANSACTION; -- history
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_NoticeSettings(ChannelID) FROM Portal.DecisionNoticeSettings WITH(UPDLOCK,HOLDLOCK) WHERE ChannelID=@ChannelID); -- history
 UPDATE Portal.DecisionNoticeSettings SET DurationDays=@DurationDays,DecisionTypes=@DecisionTypes,Active=@Active,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND (DurationDays<>@DurationDays OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes)) OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes)) OR Active<>@Active);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_NoticeSettings(@ChannelID), -- history
  @Section varchar(40)=CASE WHEN @ChannelID=1 THEN 'notices' ELSE 'alerts' END,@Title nvarchar(50)=CASE WHEN @ChannelID=1 THEN N'التنويهات' ELSE N'التنبيهات' END;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section=@Section,@ItemType='notice-settings',@ItemId=@ChannelID,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT; -- history
END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNoticeWindows_Save @ChannelID int,@DecisionId bigint,@FromAt datetime=NULL,@ToAt datetime=NULL,@IsHidden bit=0,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DecisionId<=0 OR (@FromAt IS NULL AND @ToAt IS NOT NULL) OR (@FromAt IS NOT NULL AND (@ToAt IS NULL OR @ToAt<=@FromAt)) THROW 50012,'Invalid notice window.',1;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WITH(UPDLOCK,HOLDLOCK) WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId)
 BEGIN
  IF @FromAt IS NOT NULL OR @IsHidden=1 INSERT Portal.DecisionNoticeWindows(ChannelID,DecisionId,FromAt,ToAt,IsHidden) VALUES(@ChannelID,@DecisionId,@FromAt,@ToAt,@IsHidden);
 END
 ELSE
 BEGIN
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_NoticeWindow(@ChannelID,@DecisionId); -- history
 UPDATE Portal.DecisionNoticeWindows SET FromAt=@FromAt,ToAt=@ToAt,IsHidden=@IsHidden,Active=1,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId AND (ISNULL(FromAt,'17530101')<>ISNULL(@FromAt,'17530101') OR ISNULL(ToAt,'17530101')<>ISNULL(@ToAt,'17530101') OR IsHidden<>@IsHidden OR Active<>1);
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_NoticeWindow(@ChannelID,@DecisionId), -- history
  @Section varchar(40)=CASE WHEN @ChannelID=1 THEN 'notices' ELSE 'alerts' END,@ItemId nvarchar(100)=CONCAT(@ChannelID,N':',@DecisionId);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section=@Section,@ItemType='notice-window',@ItemId=@ItemId,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Save
 @DocumentTabID int=NULL,@TabName nvarchar(200),@FolderID int,@DisplayOrder int,@Active bit,@DocumentIds nvarchar(max),@SectionKey nvarchar(30)=N'documents',@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @SectionKey NOT IN(N'documents',N'safety') THROW 50012,'Invalid section.',1;
 IF NULLIF(LTRIM(RTRIM(@TabName)),N'') IS NULL OR @DisplayOrder<0 OR ISJSON(@DocumentIds)<>1
  THROW 50012,'Invalid document tab.',1;
 DECLARE @Items TABLE(DocumentID uniqueidentifier NOT NULL PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@DocumentIds) WHERE TRY_CONVERT(uniqueidentifier,value) IS NULL)
  THROW 50012,'Invalid document selection.',1;
 INSERT @Items SELECT DISTINCT CONVERT(uniqueidentifier,value) FROM OPENJSON(@DocumentIds);
 IF NOT EXISTS(SELECT 1 FROM @Items) OR (SELECT COUNT(*) FROM @Items)>500
  THROW 50012,'Select between one and 500 PDF documents.',1;
 IF @SectionKey=N'safety' AND (SELECT COUNT(*) FROM @Items)<>1 THROW 50012,'Select one PDF per safety booklet.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN Mng.Document d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentID=i.DocumentID
  WHERE d.DocumentID IS NULL OR d.FolderID<>@FolderID OR d.Active<>1 OR LOWER(RIGHT(d.DocumentPath,4))<>N'.pdf')
  THROW 50012,'Selection must contain active PDFs from the selected folder.',1;
 IF @DocumentTabID IS NULL
 BEGIN
  INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder,Active,SectionKey) VALUES(@TabName,@FolderID,@DisplayOrder,@Active,@SectionKey);
  SET @DocumentTabID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.DocumentTabs WITH(UPDLOCK,HOLDLOCK) WHERE DocumentTabID=@DocumentTabID AND SectionKey=@SectionKey)
   THROW 50011,'Document tab not found.',1;
  SET @Before=Portal.AdminSnapshot_DocumentTab(@DocumentTabID); -- history
  UPDATE Portal.DocumentTabs SET TabName=@TabName,FolderID=@FolderID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE DocumentTabID=@DocumentTabID AND SectionKey=@SectionKey AND (TabName COLLATE Latin1_General_100_BIN2<>@TabName COLLATE Latin1_General_100_BIN2
   OR FolderID<>@FolderID OR DisplayOrder<>@DisplayOrder OR Active<>@Active
   OR EXISTS(SELECT DocumentID FROM @Items EXCEPT SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID)
   OR EXISTS(SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID EXCEPT SELECT DocumentID FROM @Items));
 END;
 DELETE Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID AND DocumentID NOT IN(SELECT DocumentID FROM @Items);
 INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
 SELECT @DocumentTabID,DocumentID FROM @Items i WHERE NOT EXISTS(
  SELECT 1 FROM Portal.DocumentTabItems t WHERE t.DocumentTabID=@DocumentTabID AND t.DocumentID=i.DocumentID);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_DocumentTab(@DocumentTabID),@Section varchar(40)=@SectionKey; -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section=@Section,@ItemType='tab',@ItemId=@DocumentTabID,@ItemTitle=@TabName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @DocumentTabID;
END;
GO
-- Preserve the explicitly agreed table shape and existing records.
CREATE OR ALTER PROCEDURE Portal.FixedOrders_Save
 @FixedOrderID bigint=NULL,@Timestamp date=NULL,@Timestamp2 date=NULL,
 @ContentBefor nvarchar(500)=NULL,@ContentAfter nvarchar(1000),@ContentText nvarchar(1000),@TimestampType int,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ContentAfter)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@ContentText)),N'') IS NULL
  OR (CHARINDEX(N'ds{0}de',@ContentText)>0 AND NULLIF(LTRIM(RTRIM(@ContentBefor)),N'') IS NULL)
  THROW 50012,'Provide title, wording and any referenced previous text.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max); -- history
 IF @FixedOrderID IS NULL
 BEGIN
  INSERT Portal.FixedOrders([Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType)
  VALUES(@Timestamp,@Timestamp2,@ContentBefor,@ContentAfter,@ContentText,@TimestampType);
  SET @FixedOrderID=CONVERT(bigint,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.FixedOrders WITH(UPDLOCK,HOLDLOCK) WHERE FixedOrderID=@FixedOrderID)
   THROW 50011,'Fixed order not found.',1;
  SET @Before=Portal.AdminSnapshot_FixedOrder(@FixedOrderID); -- history
  UPDATE Portal.FixedOrders SET [Timestamp]=@Timestamp,Timestamp2=@Timestamp2,ContentBefor=@ContentBefor,
   ContentAfter=@ContentAfter,ContentText=@ContentText,TimestampType=@TimestampType
  WHERE FixedOrderID=@FixedOrderID AND (EXISTS(
   SELECT [Timestamp],Timestamp2,ContentBefor COLLATE Latin1_General_100_BIN2,ContentAfter COLLATE Latin1_General_100_BIN2,ContentText COLLATE Latin1_General_100_BIN2,TimestampType
   EXCEPT SELECT @Timestamp,@Timestamp2,@ContentBefor COLLATE Latin1_General_100_BIN2,@ContentAfter COLLATE Latin1_General_100_BIN2,@ContentText COLLATE Latin1_General_100_BIN2,@TimestampType)
   OR ISNULL(DATALENGTH(ContentBefor),-1)<>ISNULL(DATALENGTH(@ContentBefor),-1)
   OR ISNULL(DATALENGTH(ContentAfter),-1)<>ISNULL(DATALENGTH(@ContentAfter),-1)
   OR ISNULL(DATALENGTH(ContentText),-1)<>ISNULL(DATALENGTH(@ContentText),-1));
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_FixedOrder(@FixedOrderID),@Title nvarchar(300)=LEFT(@ContentAfter,300); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='fixed-orders',@ItemType='directive',@ItemId=@FixedOrderID,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 SELECT @FixedOrderID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Media_Save
 @MediaID int=NULL,@MediaName nvarchar(300),@MediaPath nvarchar(2000),@MediaType nvarchar(20),@MediaGroupID int=NULL,@DisplayOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@MediaName)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@MediaPath)),N'') IS NULL OR @MediaType NOT IN(N'image',N'video')
  OR @DisplayOrder<0 OR (@MediaType=N'video' AND @MediaGroupID IS NOT NULL)
  THROW 50012,'Invalid media fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Media(@MediaID), -- history
  @CoverGroup int=(SELECT TOP(1) MediaGroupID FROM Portal.MediaGroups WHERE CoverMediaID=@MediaID);
 DECLARE @CoverBefore nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@CoverGroup); -- history
 -- Lock groups before media consistently with group saves/cover selection.
 IF @MediaGroupID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.MediaGroups WITH(UPDLOCK,HOLDLOCK) WHERE MediaGroupID=@MediaGroupID)
  THROW 50012,'Unknown photo group.',1;
 IF @MediaID IS NULL
 BEGIN
  INSERT Portal.Media(MediaName,MediaPath,MediaType,MediaGroupID,DisplayOrder,Active)
  VALUES(@MediaName,@MediaPath,@MediaType,@MediaGroupID,@DisplayOrder,@Active);
  SET @MediaID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  -- Clear any saved cover before moving its photo or changing it to video.
  UPDATE Portal.MediaGroups SET CoverMediaID=NULL,LastChangeAt=GETDATE()
   WHERE CoverMediaID=@MediaID AND (@MediaType<>N'image' OR @MediaGroupID IS NULL OR MediaGroupID<>@MediaGroupID);
  IF NOT EXISTS(SELECT 1 FROM Portal.Media WITH(UPDLOCK,HOLDLOCK) WHERE MediaID=@MediaID) THROW 50011,'Media not found.',1;
  UPDATE Portal.Media SET MediaName=@MediaName,MediaPath=@MediaPath,MediaType=@MediaType,MediaGroupID=@MediaGroupID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE MediaID=@MediaID AND EXISTS(
   SELECT MediaName COLLATE Latin1_General_100_BIN2,MediaPath COLLATE Latin1_General_100_BIN2,MediaType,MediaGroupID,DisplayOrder,Active
   EXCEPT SELECT @MediaName COLLATE Latin1_General_100_BIN2,@MediaPath COLLATE Latin1_General_100_BIN2,@MediaType,@MediaGroupID,@DisplayOrder,@Active);
 END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Media(@MediaID); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='media',@ItemType='media',@ItemId=@MediaID,@ItemTitle=@MediaName,@OldJson=@Before,@NewJson=@After; -- history
 IF @CoverGroup IS NOT NULL -- history: moving the cover photo clears the album cover (no-op otherwise)
 BEGIN
  DECLARE @CoverAfter nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@CoverGroup),@CoverTitle nvarchar(200)=JSON_VALUE(@CoverBefore,'$.GroupName');
  EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='media',@ItemType='album',@ItemId=@CoverGroup,@ItemTitle=@CoverTitle,@OldJson=@CoverBefore,@NewJson=@CoverAfter;
 END;
 COMMIT;SELECT @MediaID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.MediaGroups_Save
 @MediaGroupID int=NULL,@GroupName nvarchar(200),@CoverMediaID int=NULL,@DisplayOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@GroupName)),N'') IS NULL OR @DisplayOrder<0 THROW 50012,'Invalid group fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@MediaGroupID); -- history
 IF @MediaGroupID IS NULL
 BEGIN
  IF @CoverMediaID IS NOT NULL THROW 50012,'Create the group before selecting its cover.',1;
  INSERT Portal.MediaGroups(GroupName,DisplayOrder,Active) VALUES(@GroupName,@DisplayOrder,@Active);
  SET @MediaGroupID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE IF NOT EXISTS(SELECT 1 FROM Portal.MediaGroups WITH(UPDLOCK,HOLDLOCK) WHERE MediaGroupID=@MediaGroupID) THROW 50011,'Group not found.',1;
 IF @CoverMediaID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.Media WITH(UPDLOCK,HOLDLOCK)
  WHERE MediaID=@CoverMediaID AND MediaGroupID=@MediaGroupID AND MediaType=N'image') THROW 50012,'Cover must be a photo in this album.',1;
 UPDATE Portal.MediaGroups SET GroupName=@GroupName,CoverMediaID=@CoverMediaID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
 WHERE MediaGroupID=@MediaGroupID AND EXISTS(
  SELECT GroupName COLLATE Latin1_General_100_BIN2,CoverMediaID,DisplayOrder,Active
  EXCEPT SELECT @GroupName COLLATE Latin1_General_100_BIN2,@CoverMediaID,@DisplayOrder,@Active);
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_MediaGroup(@MediaGroupID); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='media',@ItemType='album',@ItemId=@MediaGroupID,@ItemTitle=@GroupName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;SELECT @MediaGroupID;
END;
GO

/* ===== Reading the history (used by the overview, history page and "last changed by") ===== */

-- @SectionsJson: JSON array of section keys the caller may see; NULL = all.
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetRecent @Top int=10,@SectionsJson nvarchar(max)=NULL AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(CASE WHEN @Top BETWEEN 1 AND 100 THEN @Top ELSE 10 END)
  AdminChangeId,ChangedAt,ChangedBy,Section,Action,ItemType,ItemId,ItemTitle
 FROM Portal.AdminChanges
 WHERE @SectionsJson IS NULL OR Section IN(SELECT value FROM OPENJSON(@SectionsJson))
 ORDER BY AdminChangeId DESC;
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_Search
 @SectionsJson nvarchar(max)=NULL,@Section varchar(40)=NULL,@ChangedBy nvarchar(512)=NULL,@FromAt datetime=NULL,@ToAt datetime=NULL,
 @Page int=1,@PageSize int=50
AS
BEGIN
 SET NOCOUNT ON;
 SET @Page=CASE WHEN @Page>=1 THEN @Page ELSE 1 END;SET @PageSize=CASE WHEN @PageSize BETWEEN 1 AND 200 THEN @PageSize ELSE 50 END;
 DECLARE @Rows TABLE(AdminChangeId bigint PRIMARY KEY);
 INSERT @Rows SELECT AdminChangeId FROM Portal.AdminChanges
 WHERE (@SectionsJson IS NULL OR Section IN(SELECT value FROM OPENJSON(@SectionsJson)))
  AND (@Section IS NULL OR Section=@Section)
  AND (NULLIF(@ChangedBy,N'') IS NULL OR ChangedBy LIKE N'%'+REPLACE(REPLACE(REPLACE(@ChangedBy,N'[',N'[[]'),N'%',N'[%]'),N'_',N'[_]')+N'%')
  AND (@FromAt IS NULL OR ChangedAt>=@FromAt) AND (@ToAt IS NULL OR ChangedAt<@ToAt);
 DECLARE @Total int=(SELECT COUNT(*) FROM @Rows);
 -- One result set; Total repeats on every row (no rows = nothing matched on this page).
 SELECT @Total Total,c.AdminChangeId,c.ChangedAt,c.ChangedBy,c.Section,c.Action,c.ItemType,c.ItemId,c.ItemTitle,c.OldJson,c.NewJson
 FROM @Rows r JOIN Portal.AdminChanges c ON c.AdminChangeId=r.AdminChangeId
 ORDER BY c.AdminChangeId DESC OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
-- Latest change per item in one section ("آخر تعديل: الاسم · التاريخ").
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetLatestByItem @Section varchar(40) AS
BEGIN
 SET NOCOUNT ON;
 SELECT ItemType,ItemId,ChangedAt,ChangedBy,Action FROM(
  SELECT ItemType,ItemId,ChangedAt,ChangedBy,Action,ROW_NUMBER() OVER(PARTITION BY ItemType,ItemId ORDER BY AdminChangeId DESC) n
  FROM Portal.AdminChanges WHERE Section=@Section) x
 WHERE n=1;
END;
GO
