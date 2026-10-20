USE [CompanyPortal];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH(N'Master.Themes',N'Visibility') IS NULL
BEGIN
 ALTER TABLE [Master].Themes ADD Visibility nvarchar(20) NOT NULL CONSTRAINT DF_Themes_Visibility DEFAULT(N'public'),
 Deleted bit NOT NULL CONSTRAINT DF_Themes_Deleted DEFAULT(0);
 EXEC(N'UPDATE [Master].Themes SET Visibility=N''hidden'' WHERE Active=0;
 ALTER TABLE [Master].Themes ADD CONSTRAINT CK_Themes_Visibility CHECK(Visibility IN(N''hidden'',N''preview'',N''public'')),
 CONSTRAINT CK_Themes_PublicDefault CHECK(IsDefault=0 OR (Active=1 AND Deleted=0 AND Visibility=N''public''));');
END;
IF OBJECT_ID(N'Master.ThemePreviewRoles',N'U') IS NULL
CREATE TABLE [Master].ThemePreviewRoles(
 ThemePreviewRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ThemePreviewRoles PRIMARY KEY,
 ThemeId int NOT NULL CONSTRAINT FK_ThemePreviewRoles_Theme REFERENCES [Master].Themes(ThemeId),
 RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Active bit NOT NULL CONSTRAINT DF_ThemePreviewRoles_Active DEFAULT(1),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_ThemePreviewRoles_LastChangeAt DEFAULT(GETDATE()),
 CONSTRAINT UQ_ThemePreviewRoles UNIQUE(ThemeId,RoleName)
);
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getAll @UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId
 FROM [Master].Themes t WHERE t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))) ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_getForAdministration AS
BEGIN
 SET NOCOUNT ON;
 SELECT ThemeId,ThemeName,LayoutKey,DisplayOrder,IsDefault,Active,LastChangeAt,PrimaryColor,AccentColor,BackgroundColor,
 OverlayOpacity,ForegroundPreset,ImagePresentation,ImageGroupId,Visibility,
 COALESCE((SELECT RoleName FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=t.ThemeId AND r.Active=1 ORDER BY RoleName FOR JSON PATH),N'[]') PreviewRolesJson
 FROM [Master].Themes t WHERE Deleted=0 ORDER BY DisplayOrder,ThemeId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL,@Visibility nvarchar(20)=NULL,@PreviewRolesJson nvarchar(max)=N'[]'
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
 COMMIT;
 SELECT @ThemeId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_delete @ThemeId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND IsDefault=1) THROW 50008,'Choose another default first.',1;
 UPDATE [Master].Themes SET Deleted=1,Active=0,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND Deleted=0;
 DECLARE @Found bit=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
 COMMIT; SELECT @Found;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_applyToAll @ThemeId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.ThemeCatalog',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50008,'Theme catalog is busy.',1;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes WHERE ThemeId=@ThemeId AND Active=1 AND Deleted=0 AND Visibility=N'public')
 THROW 50008,'Only live public themes can be applied to everyone.',1;
 UPDATE [Master].Themes SET IsDefault=0,LastChangeAt=GETDATE() WHERE IsDefault=1 AND ThemeId<>@ThemeId;
 UPDATE [Master].Themes SET IsDefault=1,LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId AND IsDefault=0;
 UPDATE Portal.UserSettings SET ThemeId=@ThemeId,LastChangeAt=GETDATE() WHERE Active=1 AND ThemeId<>@ThemeId;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_getTheme @UserId int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT TOP(1) t.ThemeId,t.ThemeName,t.LayoutKey,CAST(CASE WHEN s.UserSettingId IS NOT NULL THEN 1 ELSE 0 END AS bit) IsSaved,s.LastChangeAt
 FROM [Master].Themes t
 LEFT JOIN Portal.UserSettings s ON s.ThemeId=t.ThemeId AND s.UserId=@UserId AND s.Active=1
 WHERE t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))) AND (s.UserSettingId IS NOT NULL OR t.IsDefault=1)
 ORDER BY CASE WHEN s.UserSettingId IS NOT NULL THEN 0 ELSE 1 END;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserSettings_setTheme @UserId int,@ThemeId int AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 IF NOT EXISTS(SELECT 1 FROM [Master].Themes t WITH(HOLDLOCK) WHERE t.ThemeId=@ThemeId AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1))))
 THROW 50002,'Select an available theme.',1;
 UPDATE Portal.UserSettings WITH(UPDLOCK,SERIALIZABLE)
 SET LastChangeAt=CASE WHEN ThemeId<>@ThemeId OR Active=0 THEN GETDATE() ELSE LastChangeAt END,ThemeId=@ThemeId,Active=1 WHERE UserId=@UserId;
 IF @@ROWCOUNT=0 INSERT Portal.UserSettings(UserId,ThemeId) VALUES(@UserId,@ThemeId);
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
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
END;
GO
CREATE OR ALTER PROCEDURE [Master].Images_getContent @ImageId int,@IsAdmin bit,@UserId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;

 SELECT ImageData,ContentType FROM [Master].Images i WHERE i.ImageId=@ImageId AND i.Active=1 AND
 (@IsAdmin=1 OR EXISTS(SELECT 1 FROM [Master].ImageGroupItems m
 JOIN [Master].ImageGroups g ON m.ImageGroupId=g.ImageGroupId AND g.Active=1
 JOIN [Master].Themes t ON g.ImageGroupId=t.ImageGroupId AND t.Active=1
 WHERE m.ImageId=i.ImageId AND m.Active=1 AND t.Active=1 AND t.Deleted=0 AND (t.Visibility=N'public' OR (t.Visibility=N'preview' AND EXISTS(SELECT 1 FROM [Master].ThemePreviewRoles pr JOIN @Roles ur ON ur.RoleName=pr.RoleName WHERE pr.ThemeId=t.ThemeId AND pr.Active=1)))));
END;
GO
