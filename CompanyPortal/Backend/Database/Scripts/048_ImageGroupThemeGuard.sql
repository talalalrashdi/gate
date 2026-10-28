USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
GO
-- Themes choose their image group only in the theme editor (Themes_save).
-- The images page lists every non-deleted theme so it can show which themes use a group.
CREATE OR ALTER PROCEDURE [Master].ImageGroups_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageGroupId,GroupName,RotateImages,RotationSeconds,DefaultImageId,Active,LastChangeAt FROM [Master].ImageGroups ORDER BY ImageGroupId;
 SELECT ImageGroupId,ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems ORDER BY ImageGroupId,DisplayOrder,ImageId;
 SELECT ThemeId,ThemeName,LayoutKey,ImageGroupId FROM [Master].Themes WHERE Deleted=0 ORDER BY DisplayOrder,ThemeId;
END;
GO
-- 50013: a group used by a non-deleted theme cannot be deactivated (Themes_save only accepts active groups).
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
   IF @Active=0 AND EXISTS(SELECT 1 FROM [Master].Themes WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Deleted=0)
      THROW 50013,'Choose other images for the themes that use this group before deactivating it.',1;
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
-- The images page no longer assigns groups to themes; that duplicated the theme editor.
DROP PROCEDURE IF EXISTS [Master].Themes_setImageGroup;
GO
COMMIT;
GO
