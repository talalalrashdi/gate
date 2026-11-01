USE CompanyPortal;
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRAN;
IF NOT EXISTS(SELECT 1 FROM Master.Cards WITH(UPDLOCK,HOLDLOCK) WHERE CardKey=N'technical-inbox')
 INSERT Master.Cards(CardKey,CardName,DisplayOrder,IsFixed)
 SELECT N'technical-inbox',N'الإسناد الفني',COUNT(*)+1,0 FROM Master.Cards WHERE Active=1;
COMMIT;
GO
-- Replace only these adapter bodies when mapping the internal application.
IF OBJECT_ID(N'Portal.Isnad_Inbox_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Isnad_Inbox_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical inbox source is not configured.'',1; END');
GO
IF OBJECT_ID(N'Portal.Isnad_UnreadCount_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Isnad_UnreadCount_Get @UserId int AS BEGIN SET NOCOUNT ON; THROW 50030,''Technical inbox source is not configured.'',1; END');
GO

CREATE OR ALTER PROCEDURE [Master].Cards_get AS
BEGIN
 SET NOCOUNT ON;
 SELECT CardId,CardKey,CardName,DisplayOrder,IsFixed,LastChangeAt,CardType,Active,Audience
 FROM [Master].Cards WHERE CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services',N'technical-inbox')
 ORDER BY DisplayOrder,CardId;
 SELECT a.CardId,a.AppId FROM [Master].CardApplications a JOIN [Master].Cards c ON c.CardId=a.CardId WHERE a.Active=1 ORDER BY a.CardId,a.AppId;
 SELECT CardId,RoleName FROM [Master].CardRoles WHERE Active=1 ORDER BY CardId,RoleName;
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
  IF NOT EXISTS(SELECT 1 FROM [Master].Cards WHERE CardId=@CardId AND (CardType=N'applications' OR CardKey IN(N'library',N'inbox',N'email',N'requests',N'electronic-services',N'technical-inbox')))
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
