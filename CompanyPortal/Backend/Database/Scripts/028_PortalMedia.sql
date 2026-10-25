USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Portal.MediaGroups',N'U') IS NULL
CREATE TABLE Portal.MediaGroups(
 MediaGroupID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_MediaGroups PRIMARY KEY,
 GroupName nvarchar(200) NOT NULL,
 CoverMediaID int NULL,
 DisplayOrder int NOT NULL CONSTRAINT DF_MediaGroups_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_MediaGroups_Change DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_MediaGroups_Active DEFAULT(1),
 CONSTRAINT CK_MediaGroups_Order CHECK(DisplayOrder>=0)
);
IF OBJECT_ID(N'Portal.Media',N'U') IS NULL
CREATE TABLE Portal.Media(
 MediaID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Media PRIMARY KEY,
 MediaName nvarchar(300) NOT NULL,
 MediaPath nvarchar(2000) NOT NULL,
 MediaType nvarchar(20) NOT NULL,
 MediaGroupID int NULL CONSTRAINT FK_Media_Group REFERENCES Portal.MediaGroups(MediaGroupID),
 DisplayOrder int NOT NULL CONSTRAINT DF_Media_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_Media_Change DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_Media_Active DEFAULT(1),
 CONSTRAINT CK_Media_Type CHECK(MediaType IN(N'image',N'video') AND (MediaType=N'image' OR MediaGroupID IS NULL)),
 CONSTRAINT CK_Media_Order CHECK(DisplayOrder>=0)
);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_MediaGroups_Cover' AND parent_object_id=OBJECT_ID(N'Portal.MediaGroups'))
 ALTER TABLE Portal.MediaGroups ADD CONSTRAINT FK_MediaGroups_Cover FOREIGN KEY(CoverMediaID) REFERENCES Portal.Media(MediaID);
COMMIT;
GO
-- Fixed source contract: groups first, media second. Adapt these SELECTs internally.
CREATE OR ALTER PROCEDURE Portal.Media_GetAll @IncludeHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT MediaGroupID,GroupName,CoverMediaID,DisplayOrder,LastChangeAt,Active
 FROM Portal.MediaGroups WHERE @IncludeHidden=1 OR Active=1 ORDER BY DisplayOrder,MediaGroupID;
 SELECT m.MediaID,m.MediaName,m.MediaPath,m.MediaType,m.MediaGroupID,m.DisplayOrder,m.LastChangeAt,m.Active
 FROM Portal.Media m LEFT JOIN Portal.MediaGroups g ON g.MediaGroupID=m.MediaGroupID
 WHERE @IncludeHidden=1 OR (m.Active=1 AND (m.MediaGroupID IS NULL OR g.Active=1))
 ORDER BY m.DisplayOrder,m.MediaID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Media_GetById @MediaID int,@IncludeHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT m.MediaID,m.MediaName,m.MediaPath,m.MediaType,m.MediaGroupID,m.DisplayOrder,m.LastChangeAt,m.Active
 FROM Portal.Media m LEFT JOIN Portal.MediaGroups g ON g.MediaGroupID=m.MediaGroupID
 WHERE m.MediaID=@MediaID AND (@IncludeHidden=1 OR (m.Active=1 AND (m.MediaGroupID IS NULL OR g.Active=1)));
END;
GO
CREATE OR ALTER PROCEDURE Portal.Media_Save
 @MediaID int=NULL,@MediaName nvarchar(300),@MediaPath nvarchar(2000),@MediaType nvarchar(20),@MediaGroupID int=NULL,@DisplayOrder int,@Active bit
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@MediaName)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@MediaPath)),N'') IS NULL OR @MediaType NOT IN(N'image',N'video')
  OR @DisplayOrder<0 OR (@MediaType=N'video' AND @MediaGroupID IS NOT NULL)
  THROW 50012,'Invalid media fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
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
 COMMIT;SELECT @MediaID;
END;
GO
CREATE OR ALTER PROCEDURE Portal.MediaGroups_Save
 @MediaGroupID int=NULL,@GroupName nvarchar(200),@CoverMediaID int=NULL,@DisplayOrder int,@Active bit
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@GroupName)),N'') IS NULL OR @DisplayOrder<0 THROW 50012,'Invalid group fields.',1;
 BEGIN TRANSACTION;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MediaCatalog',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
 IF @Lock<0 THROW 50012,'Media catalog is busy; retry.',1;
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
 COMMIT;SELECT @MediaGroupID;
END;
GO
