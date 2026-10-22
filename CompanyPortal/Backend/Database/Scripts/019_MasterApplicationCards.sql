USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF COL_LENGTH(N'Master.Cards',N'CardType') IS NULL
 ALTER TABLE [Master].Cards ADD CardType nvarchar(30) NOT NULL CONSTRAINT DF_Cards_Type DEFAULT(N'connected'),
 Audience nvarchar(20) NOT NULL CONSTRAINT DF_Cards_Audience DEFAULT(N'everyone');
GO
IF OBJECT_ID(N'Master.CardApplications',N'U') IS NULL
 CREATE TABLE [Master].CardApplications(
  CardApplicationId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_MasterCardApplications PRIMARY KEY,
  CardId int NOT NULL CONSTRAINT FK_MasterCardApplications_Card REFERENCES [Master].Cards(CardId),
  AppId int NOT NULL,
  Active bit NOT NULL CONSTRAINT DF_MasterCardApplications_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_MasterCardApplications_Changed DEFAULT(GETDATE()),
  CONSTRAINT UQ_MasterCardApplications UNIQUE(CardId,AppId));
IF OBJECT_ID(N'Master.CardRoles',N'U') IS NULL
 CREATE TABLE [Master].CardRoles(
  CardRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_MasterCardRoles PRIMARY KEY,
  CardId int NOT NULL CONSTRAINT FK_MasterCardRoles_Card REFERENCES [Master].Cards(CardId),
  RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 NOT NULL,
  Active bit NOT NULL CONSTRAINT DF_MasterCardRoles_Active DEFAULT(1),
  LastChangeAt datetime NOT NULL CONSTRAINT DF_MasterCardRoles_Changed DEFAULT(GETDATE()),
  CONSTRAINT UQ_MasterCardRoles UNIQUE(CardId,RoleName));
IF OBJECT_ID(N'Master.CK_Cards_Type',N'C') IS NULL
 ALTER TABLE [Master].Cards ADD CONSTRAINT CK_Cards_Type CHECK(CardType IN(N'connected',N'applications')),
 CONSTRAINT CK_Cards_Audience CHECK(Audience IN(N'everyone',N'roles'));
GO
-- Administrators configure only these connected cards and newly created app cards.
-- Retired baseline definitions remain untouched and unavailable in this editor.
CREATE OR ALTER PROCEDURE [Master].Cards_get AS
BEGIN
 SET NOCOUNT ON;
 SELECT CardId,CardKey,CardName,DisplayOrder,IsFixed,LastChangeAt,CardType,Active,Audience
 FROM [Master].Cards WHERE CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services')
 ORDER BY DisplayOrder,CardId;
 SELECT a.CardId,a.AppId FROM [Master].CardApplications a JOIN [Master].Cards c ON c.CardId=a.CardId WHERE a.Active=1 ORDER BY a.CardId,a.AppId;
 SELECT CardId,RoleName FROM [Master].CardRoles WHERE Active=1 ORDER BY CardId,RoleName;
END;
GO
-- The real-source adapter is installed separately, never guessed here.
IF OBJECT_ID(N'Security.Apps_getForAdministration',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Security.Apps_getForAdministration AS
 BEGIN SET NOCOUNT ON; THROW 50010,''Configure the approved administration application catalog adapter.'',1; END');
GO
CREATE OR ALTER PROCEDURE [Master].Cards_save
 @CardName nvarchar(200),@IsFixed bit,@DisplayOrder int,@Active bit,@Audience nvarchar(20),
 @AppsJson nvarchar(max),@RolesJson nvarchar(max),@CardId int=NULL
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
 COMMIT;
 SELECT @CardId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
-- Normalize global fixed slots first, then compact only the employee-visible
-- master list. A role-restricted card never leaves empty slots for other users.
CREATE OR ALTER FUNCTION [Master].Cards_visible(@RolesJson nvarchar(max))
RETURNS TABLE AS RETURN
(
 WITH Base AS(SELECT CardId,CardKey,CardName,IsFixed,DisplayOrder,CardType,Audience FROM [Master].Cards WHERE Active=1),
 Slots AS(SELECT ROW_NUMBER() OVER(ORDER BY CardId) Position FROM Base),
 FreeSlots AS(SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) RowNumber FROM Slots s WHERE NOT EXISTS(SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=s.Position)),
 Movable AS(SELECT *,ROW_NUMBER() OVER(ORDER BY DisplayOrder,CardId) RowNumber FROM Base WHERE IsFixed=0),
 GlobalOrder AS(
 SELECT CardId,CardKey,CardName,IsFixed,DisplayOrder Position,CardType,Audience FROM Base WHERE IsFixed=1
 UNION ALL SELECT m.CardId,m.CardKey,m.CardName,m.IsFixed,f.Position,m.CardType,m.Audience FROM Movable m JOIN FreeSlots f ON f.RowNumber=m.RowNumber),
 Eligible AS(SELECT g.* FROM GlobalOrder g WHERE Audience=N'everyone' OR EXISTS(
 SELECT 1 FROM [Master].CardRoles r JOIN OPENJSON(@RolesJson) j ON r.RoleName=j.value COLLATE Latin1_General_100_BIN2
 WHERE r.CardId=g.CardId AND r.Active=1))
 SELECT CardId,CardKey,CardName,IsFixed,CONVERT(int,ROW_NUMBER() OVER(ORDER BY Position)) DisplayOrder,CardType FROM Eligible
);
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 DECLARE @RolesJson nvarchar(max)=(SELECT N'['+ISNULL(STRING_AGG(CONVERT(nvarchar(max),N'"'+STRING_ESCAPE(RoleName,'json')+N'"'),N','),N'')+N']' FROM @Roles);
 DECLARE @Definitions TABLE(CardKey nvarchar(100) PRIMARY KEY,CardName nvarchar(200),IsFixed bit,DisplayOrder int,IsCustom bit,UserCardId int NULL,CardType nvarchar(30));
 INSERT @Definitions SELECT CardKey,CardName,IsFixed,DisplayOrder,0,NULL,CardType FROM [Master].Cards_visible(@RolesJson);
 DECLARE @MasterCount int=(SELECT COUNT(*) FROM @Definitions);
 INSERT @Definitions SELECT N'custom-'+CONVERT(nvarchar(20),UserCardId),CardName,0,
 @MasterCount+CONVERT(int,ROW_NUMBER() OVER(ORDER BY UserCardId)),1,UserCardId,N'custom' FROM Portal.UserCards WHERE UserId=@UserId AND Active=1;
 ;WITH Base AS(
 SELECT d.*,s.SortOrder,CAST(CASE WHEN s.UserWorkspaceOrderId IS NULL THEN 0 ELSE 1 END AS bit) IsSaved,s.LastChangeAt
 FROM @Definitions d LEFT JOIN Portal.UserWorkspaceOrder s ON s.UserId=@UserId AND s.CardKey=d.CardKey AND s.Active=1),
 Slots AS(SELECT ROW_NUMBER() OVER(ORDER BY CardKey)-1 Position FROM Base),
 FreeSlots AS(SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) RowNumber FROM Slots s WHERE NOT EXISTS(SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=s.Position+1)),
 Movable AS(SELECT *,ROW_NUMBER() OVER(ORDER BY IsSaved DESC,SortOrder,DisplayOrder,CardKey) RowNumber FROM Base WHERE IsFixed=0),
 Resolved AS(
 SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt,CardType,DisplayOrder-1 Position FROM Base WHERE IsFixed=1
 UNION ALL SELECT m.CardKey,m.CardName,m.IsFixed,m.DisplayOrder,m.IsCustom,m.UserCardId,m.IsSaved,m.LastChangeAt,m.CardType,f.Position FROM Movable m JOIN FreeSlots f ON f.RowNumber=m.RowNumber)
 SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt,CardType FROM Resolved ORDER BY Position;
 DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
 INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
 SELECT d.CardKey,a.AppId,a.AppName FROM @Definitions d JOIN [Master].Cards c ON c.CardKey=d.CardKey AND c.CardType=N'applications'
 JOIN [Master].CardApplications m ON m.CardId=c.CardId AND m.Active=1 JOIN @Allowed a ON a.AppId=m.AppId ORDER BY d.CardKey,a.AppId;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_set @UserId int,@Cards Portal.CardOrderInput READONLY AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF (SELECT COUNT(*) FROM @Cards)>200 OR EXISTS(SELECT 1 FROM @Cards WHERE SortOrder<0)
 OR ((SELECT COUNT(*) FROM @Cards)>0 AND ((SELECT MIN(SortOrder) FROM @Cards)<>0 OR (SELECT MAX(SortOrder) FROM @Cards)<>(SELECT COUNT(*)-1 FROM @Cards)))
 THROW 50004,'Supply unique consecutive positions.',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.MasterCards',@LockMode=N'Shared',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50004,'Catalog is busy. Reload.',1;
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 DECLARE @RolesJson nvarchar(max)=(SELECT N'['+ISNULL(STRING_AGG(CONVERT(nvarchar(max),N'"'+STRING_ESCAPE(RoleName,'json')+N'"'),N','),N'')+N']' FROM @Roles);
 DECLARE @Valid TABLE(CardKey nvarchar(100) PRIMARY KEY,IsFixed bit,DisplayOrder int);
 INSERT @Valid SELECT CardKey,IsFixed,DisplayOrder FROM [Master].Cards_visible(@RolesJson);
 INSERT @Valid SELECT N'custom-'+CONVERT(nvarchar(20),UserCardId),0,0 FROM Portal.UserCards WITH(HOLDLOCK) WHERE UserId=@UserId AND Active=1;
 IF EXISTS(SELECT CardKey FROM @Cards EXCEPT SELECT CardKey FROM @Valid)
 OR EXISTS(SELECT CardKey FROM @Valid EXCEPT SELECT CardKey FROM @Cards)
 OR EXISTS(SELECT 1 FROM @Cards i JOIN @Valid v ON v.CardKey=i.CardKey WHERE v.IsFixed=1 AND i.SortOrder<>v.DisplayOrder-1)
 THROW 50004,'Supply current visible cards and preserve fixed positions.',1;
 DECLARE @Count int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId);
 UPDATE s SET SortOrder=i.SortOrder,Active=1,LastChangeAt=GETDATE() FROM Portal.UserWorkspaceOrder s JOIN @Cards i ON i.CardKey=s.CardKey
 WHERE s.UserId=@UserId AND (s.SortOrder<>i.SortOrder OR s.Active=0);
 INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder) SELECT @UserId,i.CardKey,i.SortOrder FROM @Cards i
 WHERE NOT EXISTS(SELECT 1 FROM Portal.UserWorkspaceOrder s WHERE s.UserId=@UserId AND s.CardKey=i.CardKey);
 -- Hidden or no-longer-authorized card preferences are deliberately retained.
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
