USE [CompanyPortal];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'Master.Themes',N'PrimaryColor') IS NULL
BEGIN
 ALTER TABLE [Master].Themes ADD
 PrimaryColor nvarchar(7) NULL, AccentColor nvarchar(7) NULL, BackgroundColor nvarchar(7) NULL,
 OverlayOpacity int NULL, ForegroundPreset nvarchar(10) NULL,
 ImagePresentation nvarchar(20) NOT NULL CONSTRAINT DF_Themes_ImagePresentation DEFAULT(N'background');
 EXEC(N'ALTER TABLE [Master].Themes ADD
 CONSTRAINT CK_Themes_Overlay CHECK(OverlayOpacity IS NULL OR OverlayOpacity BETWEEN 0 AND 85),
 CONSTRAINT CK_Themes_Foreground CHECK(ForegroundPreset IS NULL OR ForegroundPreset IN(N''light'',N''dark'')),
 CONSTRAINT CK_Themes_Presentation CHECK(ImagePresentation IN(N''background'',N''artwork'')),
 CONSTRAINT CK_Themes_Colors CHECK(
 (PrimaryColor IS NULL OR (LEN(PrimaryColor)=7 AND PrimaryColor COLLATE Latin1_General_100_BIN2 LIKE N''#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'')) AND
 (AccentColor IS NULL OR (LEN(AccentColor)=7 AND AccentColor COLLATE Latin1_General_100_BIN2 LIKE N''#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'')) AND
 (BackgroundColor IS NULL OR (LEN(BackgroundColor)=7 AND BackgroundColor COLLATE Latin1_General_100_BIN2 LIKE N''#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'')));');
END;
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId
 FROM [Master].Themes WHERE Active=1 ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getForAdministration AS
BEGIN
 SET NOCOUNT ON;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,Active,LastChangeAt,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId
 FROM [Master].Themes ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 -- Serialize catalog writes, including changes to the single default.
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF LEN(LTRIM(RTRIM(@ThemeName)))=0 OR @DisplayOrder<0 OR @LayoutKey NOT IN(N'official',N'work',N'national-day') OR (@IsDefault=1 AND @Active=0)
 THROW 50008,'Check the theme details.',1;
 IF @ThemeId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].Themes WITH(UPDLOCK,HOLDLOCK) WHERE ThemeId=@ThemeId)
 THROW 50008,'Theme not found.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) AND (@IsDefault=0 OR @Active=0)
 THROW 50008,'Choose another default before disabling this default.',1;
 IF @ImageGroupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ImageGroups WITH(HOLDLOCK) WHERE ImageGroupId=@ImageGroupId AND Active=1)
 THROW 50008,'Choose an active image group.',1;
 IF @IsDefault=1
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND (@ThemeId IS NULL OR ThemeId<>@ThemeId);
 IF @ThemeId IS NULL
 BEGIN
 INSERT [Master].Themes(ThemeName,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId)
 VALUES(@ThemeName,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId);
 SET @ThemeId=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 UPDATE [Master].Themes SET ThemeName=@ThemeName,LayoutKey=@LayoutKey,DisplayOrder=@DisplayOrder,Active=@Active,IsDefault=@IsDefault,
 PrimaryColor=@PrimaryColor,AccentColor=@AccentColor,BackgroundColor=@BackgroundColor,OverlayOpacity=@OverlayOpacity,ForegroundPreset=@ForegroundPreset,ImagePresentation=@ImagePresentation,ImageGroupId=@ImageGroupId,LastChangeAt=GETDATE()
 WHERE ThemeId=@ThemeId AND EXISTS(
 SELECT @ThemeName COLLATE Latin1_General_100_BIN2,@LayoutKey,@DisplayOrder,@Active,@IsDefault,@PrimaryColor,@AccentColor,@BackgroundColor,@OverlayOpacity,@ForegroundPreset,@ImagePresentation,@ImageGroupId
 EXCEPT SELECT ThemeName COLLATE Latin1_General_100_BIN2,LayoutKey,DisplayOrder,Active,IsDefault,PrimaryColor,AccentColor,BackgroundColor,OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId FROM [Master].Themes WHERE ThemeId=@ThemeId);
 IF (SELECT COUNT(*) FROM [Master].Themes WHERE Active=1 AND IsDefault=1)<>1 THROW 50008,'Exactly one active default is required.',1;
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
