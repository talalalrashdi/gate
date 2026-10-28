USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
GO
-- Small preview copy made by the admin browser (about 480 px, WebP) so the admin library and theme
-- cards do not download full-size originals. The portal itself keeps using ImageData.
IF COL_LENGTH(N'Master.Images',N'ThumbnailData') IS NULL
 ALTER TABLE [Master].Images ADD ThumbnailData varbinary(max) NULL, ThumbnailType nvarchar(100) NULL;
GO
IF OBJECT_ID(N'Master.CK_Images_Thumbnail',N'C') IS NULL
 ALTER TABLE [Master].Images ADD CONSTRAINT CK_Images_Thumbnail CHECK(
  (ThumbnailData IS NULL AND ThumbnailType IS NULL)
  OR (DATALENGTH(ThumbnailData) BETWEEN 1 AND 524288 AND ThumbnailType IN (N'image/jpeg',N'image/png',N'image/webp')));
GO
CREATE OR ALTER PROCEDURE [Master].Images_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageId,ImageName,ContentType,PixelWidth,PixelHeight,DATALENGTH(ImageData) ByteLength,LastChangeAt,
  CAST(CASE WHEN ThumbnailData IS NULL THEN 0 ELSE 1 END AS bit) HasThumbnail
 FROM [Master].Images WHERE Active=1 ORDER BY ImageId DESC;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_add
 @ImageName nvarchar(200), @ContentType nvarchar(100), @ImageData varbinary(max), @PixelWidth int, @PixelHeight int, @ChangedBy nvarchar(512)=NULL,
 @ThumbnailData varbinary(max)=NULL, @ThumbnailType nvarchar(100)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: insert and history row commit together
 IF LEN(LTRIM(RTRIM(@ImageName)))=0 THROW 50007,'Image name is required.',1;
 BEGIN TRANSACTION; -- history
 INSERT [Master].Images(ImageName,ContentType,ImageData,PixelWidth,PixelHeight,ThumbnailData,ThumbnailType)
 VALUES(@ImageName,@ContentType,@ImageData,@PixelWidth,@PixelHeight,@ThumbnailData,@ThumbnailType);
 DECLARE @ImageId int=CAST(SCOPE_IDENTITY() AS int); -- history
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Image(@ImageId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='images',@ItemType='image',@ItemId=@ImageId,@ItemTitle=@ImageName,@NewJson=@After; -- history
 COMMIT; -- history
 SELECT @ImageId;
END;
GO
-- Adds a preview copy to an older image. Set once only, so its URL can be cached for good.
-- Not recorded in the change history: the snapshot (no bytes) does not change.
CREATE OR ALTER PROCEDURE [Master].Images_setThumbnail @ImageId int,@ThumbnailData varbinary(max),@ThumbnailType nvarchar(100) AS
BEGIN
 SET NOCOUNT ON;
 UPDATE [Master].Images SET ThumbnailData=@ThumbnailData,ThumbnailType=@ThumbnailType
 WHERE ImageId=@ImageId AND Active=1 AND ThumbnailData IS NULL;
 SELECT CAST(@@ROWCOUNT AS bit);
END;
GO
-- Same access rule as Images_getContent.
CREATE OR ALTER PROCEDURE [Master].Images_getThumbnail @ImageId int,@IsAdmin bit,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT ThumbnailData ImageData,ThumbnailType ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND i.ThumbnailData IS NOT NULL AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1 AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)))));
END;
GO
COMMIT;
GO
