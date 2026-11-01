USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
GO
-- Display copy for older oversized raster images (uploaded before the 050 browser shrink):
-- long side at most 2560 px, made once by the admin browser with the same settings as new uploads.
-- The original ImageData is never changed; the portal uses the copy when one exists.
IF COL_LENGTH(N'Master.Images',N'DisplayData') IS NULL
 ALTER TABLE [Master].Images ADD DisplayData varbinary(max) NULL, DisplayType nvarchar(100) NULL;
GO
IF OBJECT_ID(N'Master.CK_Images_Display',N'C') IS NULL
 ALTER TABLE [Master].Images ADD CONSTRAINT CK_Images_Display CHECK(
  (DisplayData IS NULL AND DisplayType IS NULL)
  OR (DATALENGTH(DisplayData) BETWEEN 1 AND 4194304 AND DisplayType IN (N'image/jpeg',N'image/png',N'image/webp')));
GO
-- Compatibility: existing result sets keep their exact columns; display copies are an extra result set,
-- which older API builds ignore, so the database and the applications can be updated in either order.
CREATE OR ALTER PROCEDURE [Master].Images_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageId,ImageName,ContentType,PixelWidth,PixelHeight,DATALENGTH(ImageData) ByteLength,LastChangeAt,
  CAST(CASE WHEN ThumbnailData IS NULL THEN 0 ELSE 1 END AS bit) HasThumbnail
 FROM [Master].Images WHERE Active=1 ORDER BY ImageId DESC;
 SELECT ImageId FROM [Master].Images WHERE Active=1 AND DisplayData IS NOT NULL;
END;
GO
-- Set once only, so its URL can be cached for good. Raster originals only, and only when the copy is smaller.
-- Not recorded in the change history: the snapshot (no bytes) does not change.
CREATE OR ALTER PROCEDURE [Master].Images_setDisplay @ImageId int,@DisplayData varbinary(max),@DisplayType nvarchar(100) AS
BEGIN
 SET NOCOUNT ON;
 UPDATE [Master].Images SET DisplayData=@DisplayData,DisplayType=@DisplayType
 WHERE ImageId=@ImageId AND Active=1 AND DisplayData IS NULL AND ContentType<>N'image/svg+xml'
  AND DATALENGTH(@DisplayData)<DATALENGTH(ImageData);
 SELECT CAST(@@ROWCOUNT AS bit);
END;
GO
-- Same access rule as Images_getContent.
CREATE OR ALTER PROCEDURE [Master].Images_getDisplay @ImageId int,@IsAdmin bit,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT DisplayData ImageData,DisplayType ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND i.DisplayData IS NOT NULL AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1 AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)))));
END;
GO
-- Unchanged from 018 except a third result set: the theme's images that have a display copy.
CREATE OR ALTER PROCEDURE [Master].Themes_getImages @ThemeId int,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT g.ImageGroupId,g.RotateImages,g.RotationSeconds,g.DefaultImageId
 FROM [Master].Themes t JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1 WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)));
 SELECT i.ImageId,i.ImageName,m.DisplayOrder FROM [Master].Themes t
 JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].ImageGroupItems m ON g.ImageGroupId=m.ImageGroupId AND m.Active=1
 JOIN [Master].Images i ON m.ImageId=i.ImageId AND i.Active=1
 WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))) ORDER BY m.DisplayOrder,i.ImageId;
 SELECT i.ImageId FROM [Master].Themes t
 JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].ImageGroupItems m ON g.ImageGroupId=m.ImageGroupId AND m.Active=1
 JOIN [Master].Images i ON m.ImageId=i.ImageId AND i.Active=1 AND i.DisplayData IS NOT NULL
 WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)));
END;
GO
COMMIT;
GO
