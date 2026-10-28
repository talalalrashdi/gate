USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Master.ThemeImagePositions',N'U') IS NULL
CREATE TABLE [Master].ThemeImagePositions(
 ThemeImagePositionId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ThemeImagePositions PRIMARY KEY,
 ThemeId int NOT NULL CONSTRAINT FK_ThemeImagePositions_Theme REFERENCES [Master].Themes(ThemeId),
 ImageId int NOT NULL CONSTRAINT FK_ThemeImagePositions_Image REFERENCES [Master].Images(ImageId),
 FocalX decimal(5,2) NOT NULL CONSTRAINT DF_ThemeImagePositions_X DEFAULT(50),
 FocalY decimal(5,2) NOT NULL CONSTRAINT DF_ThemeImagePositions_Y DEFAULT(50),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_ThemeImagePositions_Changed DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_ThemeImagePositions_Active DEFAULT(1),
 CONSTRAINT UQ_ThemeImagePositions UNIQUE(ThemeId,ImageId),
 CONSTRAINT CK_ThemeImagePositions_Range CHECK(FocalX BETWEEN 0 AND 100 AND FocalY BETWEEN 0 AND 100)
);
GO
CREATE OR ALTER PROCEDURE [Master].ThemeImagePositions_Get @ThemeId int=NULL AS
BEGIN
 SET NOCOUNT ON;
 SELECT p.ThemeId,p.ImageId,p.FocalX,p.FocalY FROM [Master].ThemeImagePositions p
 WHERE p.Active=1 AND (@ThemeId IS NULL OR p.ThemeId=@ThemeId)
  AND EXISTS(SELECT 1 FROM [Master].Themes t JOIN [Master].ImageGroupItems g ON g.ImageGroupId=t.ImageGroupId
    WHERE t.ThemeId=p.ThemeId AND g.ImageId=p.ImageId)
 ORDER BY p.ThemeId,p.ImageId;
END;
GO
CREATE OR ALTER FUNCTION Portal.AdminSnapshot_Theme(@ThemeId int) RETURNS nvarchar(max) AS
BEGIN
 RETURN (SELECT t.ThemeName,t.LayoutKey,t.DisplayOrder,t.IsDefault,t.Active,t.Visibility,t.Deleted,t.PrimaryColor,t.AccentColor,t.BackgroundColor,
  t.OverlayOpacity,t.ForegroundPreset,t.ImagePresentation,t.ImageGroupId,
  JSON_QUERY((SELECT p.ImageId,p.FocalX,p.FocalY FROM [Master].ThemeImagePositions p
    WHERE p.ThemeId=t.ThemeId AND p.Active=1 ORDER BY p.ImageId FOR JSON PATH)) ImagePositions,
  JSON_QUERY(N'['+ISNULL((SELECT STRING_AGG(N'"'+STRING_ESCAPE(r.RoleName,'json')+N'"',N',') WITHIN GROUP(ORDER BY r.RoleName) FROM [Master].ThemePreviewRoles r WHERE r.ThemeId=t.ThemeId AND r.Active=1),N'')+N']') PreviewRoles
  FROM [Master].Themes t WHERE t.ThemeId=@ThemeId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
GO
CREATE OR ALTER PROCEDURE [Master].Themes_save
 @ThemeId int=NULL,@ThemeName nvarchar(200),@LayoutKey nvarchar(50),@DisplayOrder int,@Active bit,@IsDefault bit,
 @PrimaryColor nvarchar(7)=NULL,@AccentColor nvarchar(7)=NULL,@BackgroundColor nvarchar(7)=NULL,
 @OverlayOpacity int=NULL,@ForegroundPreset nvarchar(10)=NULL,@ImagePresentation nvarchar(20)=N'background',@ImageGroupId int=NULL,@Visibility nvarchar(20)=NULL,@PreviewRolesJson nvarchar(max)=N'[]',
 @ChangedBy nvarchar(512)=NULL,@ImagePositionsJson nvarchar(max)=NULL
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

 -- An omitted payload preserves saved positions for older callers. Explicit [] clears them.
 IF @ImagePositionsJson IS NOT NULL
 BEGIN
  IF ISJSON(@ImagePositionsJson)<>1 OR LEFT(LTRIM(@ImagePositionsJson),1)<>N'['
   THROW 50008,'Invalid image positions.',1;
  DECLARE @Positions TABLE(ImageId int NOT NULL PRIMARY KEY,FocalX decimal(5,2) NOT NULL,FocalY decimal(5,2) NOT NULL);
  IF (SELECT COUNT(*) FROM OPENJSON(@ImagePositionsJson))>100
   OR EXISTS(SELECT 1 FROM OPENJSON(@ImagePositionsJson) j WHERE j.[type]<>5
    OR TRY_CONVERT(int,JSON_VALUE(j.value,'$.ImageId')) IS NULL
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalX')) NOT BETWEEN 0 AND 100
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalY')) NOT BETWEEN 0 AND 100
    OR JSON_VALUE(j.value,'$.FocalX') IS NULL OR JSON_VALUE(j.value,'$.FocalY') IS NULL
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalX')) IS NULL
    OR TRY_CONVERT(decimal(18,8),JSON_VALUE(j.value,'$.FocalY')) IS NULL)
   THROW 50008,'Use up to 100 valid image positions.',1;
  IF EXISTS(SELECT JSON_VALUE(value,'$.ImageId') FROM OPENJSON(@ImagePositionsJson) GROUP BY JSON_VALUE(value,'$.ImageId') HAVING COUNT(*)>1)
   THROW 50008,'Duplicate image position.',1;
  INSERT @Positions SELECT ImageId,FocalX,FocalY FROM OPENJSON(@ImagePositionsJson)
   WITH(ImageId int '$.ImageId',FocalX decimal(5,2) '$.FocalX',FocalY decimal(5,2) '$.FocalY');
  IF EXISTS(SELECT 1 FROM @Positions p LEFT JOIN [Master].Images i ON i.ImageId=p.ImageId
    LEFT JOIN [Master].ImageGroupItems g ON g.ImageId=p.ImageId AND g.ImageGroupId=@ImageGroupId
    WHERE i.ImageId IS NULL OR g.ImageId IS NULL)
   THROW 50008,'Positioned images must belong to the selected group.',1;
  IF EXISTS(SELECT ImageId,FocalX,FocalY FROM @Positions EXCEPT SELECT ImageId,FocalX,FocalY FROM [Master].ThemeImagePositions WHERE ThemeId=@ThemeId AND Active=1)
   OR EXISTS(SELECT ImageId,FocalX,FocalY FROM [Master].ThemeImagePositions WHERE ThemeId=@ThemeId AND Active=1 EXCEPT SELECT ImageId,FocalX,FocalY FROM @Positions)
  BEGIN
   UPDATE [Master].Themes SET LastChangeAt=GETDATE() WHERE ThemeId=@ThemeId;
   UPDATE saved SET FocalX=COALESCE(p.FocalX,saved.FocalX),FocalY=COALESCE(p.FocalY,saved.FocalY),
    Active=CASE WHEN p.ImageId IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
   FROM [Master].ThemeImagePositions saved LEFT JOIN @Positions p ON p.ImageId=saved.ImageId
   WHERE saved.ThemeId=@ThemeId AND (saved.Active<>CASE WHEN p.ImageId IS NULL THEN 0 ELSE 1 END OR p.FocalX<>saved.FocalX OR p.FocalY<>saved.FocalY);
   INSERT [Master].ThemeImagePositions(ThemeId,ImageId,FocalX,FocalY)
    SELECT @ThemeId,p.ImageId,p.FocalX,p.FocalY FROM @Positions p
    WHERE NOT EXISTS(SELECT 1 FROM [Master].ThemeImagePositions saved WHERE saved.ThemeId=@ThemeId AND saved.ImageId=p.ImageId);
  END;
 END;
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
COMMIT;
GO
