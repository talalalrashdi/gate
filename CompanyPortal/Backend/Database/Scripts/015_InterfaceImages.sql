USE [CompanyPortal];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Master.Images', N'U') IS NULL
CREATE TABLE [Master].Images (
    ImageId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Images PRIMARY KEY,
    ImageName nvarchar(200) NOT NULL,
    ContentType nvarchar(100) NOT NULL,
    ImageData varbinary(max) NOT NULL,
    PixelWidth int NOT NULL,
    PixelHeight int NOT NULL,
    Active bit NOT NULL CONSTRAINT DF_Images_Active DEFAULT (1),
    LastChangeAt datetime NOT NULL CONSTRAINT DF_Images_LastChangeAt DEFAULT (GETDATE()),
    CONSTRAINT CK_Images_Size CHECK (DATALENGTH(ImageData) BETWEEN 1 AND 10485760),
    CONSTRAINT CK_Images_Dimensions CHECK (PixelWidth BETWEEN 1 AND 12000 AND PixelHeight BETWEEN 1 AND 12000),
    CONSTRAINT CK_Images_Type CHECK (ContentType IN (N'image/jpeg',N'image/png',N'image/webp',N'image/svg+xml'))
);
IF OBJECT_ID(N'Master.ImageGroups', N'U') IS NULL
CREATE TABLE [Master].ImageGroups (
    ImageGroupId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImageGroups PRIMARY KEY,
    GroupName nvarchar(200) NOT NULL,
    RotateImages bit NOT NULL CONSTRAINT DF_ImageGroups_Rotate DEFAULT (1),
    RotationSeconds int NOT NULL CONSTRAINT DF_ImageGroups_Seconds DEFAULT (8),
    DefaultImageId int NULL CONSTRAINT FK_ImageGroups_Default REFERENCES [Master].Images(ImageId),
    Active bit NOT NULL CONSTRAINT DF_ImageGroups_Active DEFAULT (1),
    LastChangeAt datetime NOT NULL CONSTRAINT DF_ImageGroups_LastChangeAt DEFAULT (GETDATE()),
    CONSTRAINT CK_ImageGroups_Seconds CHECK (RotationSeconds BETWEEN 3 AND 3600)
);
IF OBJECT_ID(N'Master.ImageGroupItems', N'U') IS NULL
CREATE TABLE [Master].ImageGroupItems (
    ImageGroupItemId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImageGroupItems PRIMARY KEY,
    ImageGroupId int NOT NULL CONSTRAINT FK_ImageGroupItems_Group REFERENCES [Master].ImageGroups(ImageGroupId),
    ImageId int NOT NULL CONSTRAINT FK_ImageGroupItems_Image REFERENCES [Master].Images(ImageId),
    DisplayOrder int NOT NULL,
    Active bit NOT NULL CONSTRAINT DF_ImageGroupItems_Active DEFAULT (1),
    LastChangeAt datetime NOT NULL CONSTRAINT DF_ImageGroupItems_LastChangeAt DEFAULT (GETDATE()),
    CONSTRAINT UQ_ImageGroupItems UNIQUE(ImageGroupId,ImageId),
    CONSTRAINT CK_ImageGroupItems_Order CHECK (DisplayOrder > 0)
);
IF COL_LENGTH(N'Master.Themes', N'ImageGroupId') IS NULL
    ALTER TABLE [Master].Themes ADD ImageGroupId int NULL CONSTRAINT FK_Themes_ImageGroups REFERENCES [Master].ImageGroups(ImageGroupId);
IF TYPE_ID(N'Master.ImageSelection') IS NULL
    EXEC(N'CREATE TYPE [Master].ImageSelection AS TABLE(ImageId int NOT NULL PRIMARY KEY, DisplayOrder int NOT NULL UNIQUE, Active bit NOT NULL);');
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Images_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageId,ImageName,ContentType,PixelWidth,PixelHeight,DATALENGTH(ImageData) ByteLength,LastChangeAt
 FROM [Master].Images WHERE Active=1 ORDER BY ImageId DESC;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_add
 @ImageName nvarchar(200), @ContentType nvarchar(100), @ImageData varbinary(max), @PixelWidth int, @PixelHeight int
AS
BEGIN
 SET NOCOUNT ON;
 IF LEN(LTRIM(RTRIM(@ImageName)))=0 THROW 50007,'Image name is required.',1;
 INSERT [Master].Images(ImageName,ContentType,ImageData,PixelWidth,PixelHeight)
 VALUES(@ImageName,@ContentType,@ImageData,@PixelWidth,@PixelHeight);
 SELECT CAST(SCOPE_IDENTITY() AS int);
END;
GO
CREATE OR ALTER PROCEDURE [Master].ImageGroups_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageGroupId,GroupName,RotateImages,RotationSeconds,DefaultImageId,Active,LastChangeAt FROM [Master].ImageGroups ORDER BY ImageGroupId;
 SELECT ImageGroupId,ImageId,DisplayOrder,Active FROM [Master].ImageGroupItems ORDER BY ImageGroupId,DisplayOrder,ImageId;
 SELECT ThemeId,ThemeName,LayoutKey,ImageGroupId FROM [Master].Themes WHERE Active=1 ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].ImageGroups_save
 @ImageGroupId int=NULL, @GroupName nvarchar(200), @RotateImages bit, @RotationSeconds int,
 @DefaultImageId int=NULL, @Active bit, @Items [Master].ImageSelection READONLY
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
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
 COMMIT;
 SELECT @ImageGroupId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_setImageGroup @ThemeId int,@ImageGroupId int=NULL AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Select an active image group.',1; END;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId AND Active=1)
 BEGIN ROLLBACK; THROW 50007,'Theme was not found.',1; END;
 UPDATE [Master].Themes SET ImageGroupId=@ImageGroupId,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND Active=1 AND ISNULL(ImageGroupId,0)<>ISNULL(@ImageGroupId,0);
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getImages @ThemeId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT g.ImageGroupId,g.RotateImages,g.RotationSeconds,g.DefaultImageId
 FROM [Master].Themes t JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1 WHERE t.ThemeId=@ThemeId AND t.Active=1;
 SELECT i.ImageId,i.ImageName,m.DisplayOrder FROM [Master].Themes t
 JOIN [Master].ImageGroups g ON t.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].ImageGroupItems m ON g.ImageGroupId=m.ImageGroupId AND m.Active=1
 JOIN [Master].Images i ON m.ImageId=i.ImageId AND i.Active=1
 WHERE t.ThemeId=@ThemeId AND t.Active=1 ORDER BY m.DisplayOrder,i.ImageId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_getContent @ImageId int,@IsAdmin bit AS
BEGIN
 SET NOCOUNT ON;
 SELECT ImageData,ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1));
END;
GO
