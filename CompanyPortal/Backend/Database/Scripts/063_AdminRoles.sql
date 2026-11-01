USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON;SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;SET ARITHABORT ON;SET NUMERIC_ROUNDABORT OFF;SET XACT_ABORT ON;
GO
BEGIN TRAN;
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'Portal.AdminSectionRoles') AND name=N'CK_AdminSectionRoles_Key')
 ALTER TABLE Portal.AdminSectionRoles DROP CONSTRAINT CK_AdminSectionRoles_Key;
DECLARE @First bit=CASE WHEN COL_LENGTH(N'Portal.AdminSectionRoles',N'AdminSectionRoleId') IS NULL THEN 1 ELSE 0 END;
IF @First=1
BEGIN
 ALTER TABLE Portal.AdminSectionRoles ADD AdminSectionRoleId int IDENTITY(1,1) NOT NULL;
 ALTER TABLE Portal.AdminSectionRoles ADD Active bit NOT NULL CONSTRAINT DF_AdminSectionRoles_Active DEFAULT(1);
 ALTER TABLE Portal.AdminSectionRoles DROP CONSTRAINT PK_AdminSectionRoles;
 ALTER TABLE Portal.AdminSectionRoles ALTER COLUMN SectionKey nvarchar(40) NOT NULL;
 ALTER TABLE Portal.AdminSectionRoles ALTER COLUMN RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 NOT NULL;
 ALTER TABLE Portal.AdminSectionRoles ADD CONSTRAINT PK_AdminSectionRoles PRIMARY KEY(AdminSectionRoleId);
 ALTER TABLE Portal.AdminSectionRoles ADD CONSTRAINT UQ_AdminSectionRoles_SectionRole UNIQUE(SectionKey,RoleName);
END;
COMMIT;
GO
-- Preserve existing grants when separating the two former header-content screens.
INSERT Portal.AdminSectionRoles(SectionKey,RoleName,Active,LastChangeAt)
SELECT v.SectionKey,r.RoleName,r.Active,r.LastChangeAt FROM Portal.AdminSectionRoles r CROSS JOIN(VALUES(N'important-numbers'),(N'institution-status'))v(SectionKey)
WHERE r.SectionKey=N'header-content' AND NOT EXISTS(SELECT 1 FROM Portal.AdminSectionRoles x WHERE x.RoleName=r.RoleName AND x.SectionKey=v.SectionKey);
DELETE Portal.AdminSectionRoles WHERE SectionKey=N'header-content';
GO
ALTER TABLE Portal.AdminSectionRoles WITH CHECK ADD CONSTRAINT CK_AdminSectionRoles_Key CHECK(SectionKey IN(N'cards',N'applications',N'documents',N'safety',N'fixed-orders',N'important-numbers',N'institution-status',N'notices',N'alerts',N'media',N'images',N'themes',N'events'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'Portal.AdminSectionRoles') AND name=N'IX_AdminSectionRoles_Role')
 CREATE INDEX IX_AdminSectionRoles_Role ON Portal.AdminSectionRoles(RoleName,Active) INCLUDE(SectionKey);
GO
-- Initial templates only. Reruns do not restore rights removed by an administrator.
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=1 AND major_id=OBJECT_ID(N'Portal.AdminSectionRoles') AND name=N'RoleTemplates063')
BEGIN
 DECLARE @Defaults TABLE(RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2,SectionKey nvarchar(40));
 INSERT @Defaults VALUES
 (N'CompanyPortal.Content',N'media'),(N'CompanyPortal.Content',N'events'),(N'CompanyPortal.Content',N'fixed-orders'),
 (N'CompanyPortal.Library',N'documents'),(N'CompanyPortal.Library',N'safety'),
 (N'CompanyPortal.Appearance',N'images'),(N'CompanyPortal.Appearance',N'themes'),
 (N'CompanyPortal.Applications',N'cards'),(N'CompanyPortal.Applications',N'applications'),
 (N'CompanyPortal.Notices',N'notices'),(N'CompanyPortal.Notices',N'alerts'),
 (N'CompanyPortal.Directory',N'important-numbers'),(N'CompanyPortal.Status',N'institution-status');
 INSERT Portal.AdminSectionRoles(RoleName,SectionKey)
 SELECT d.RoleName,d.SectionKey FROM @Defaults d WHERE NOT EXISTS(SELECT 1 FROM Portal.AdminSectionRoles r WHERE r.RoleName=d.RoleName);
 EXEC sys.sp_addextendedproperty @name=N'RoleTemplates063',@value=1,@level0type=N'SCHEMA',@level0name=N'Portal',@level1type=N'TABLE',@level1name=N'AdminSectionRoles';
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminAccess_get @Username nvarchar(512) AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Users TABLE(UserId int);DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Users EXEC Security.User_getByUsername @Username=@Username;
 DECLARE @UserId int=(SELECT TOP(1) UserId FROM @Users);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM @Roles WHERE RoleName COLLATE Latin1_General_100_BIN2=N'CompanyPortal.Admin') THEN 1 ELSE 0 END) IsSuperAdmin;
 SELECT DISTINCT s.SectionKey FROM Portal.AdminSectionRoles s JOIN @Roles r ON r.RoleName COLLATE Latin1_General_100_BIN2=s.RoleName
 WHERE s.Active=1;
END;
GO
-- Adapter is installed once. Map to the authoritative active-role catalog internally.
IF OBJECT_ID(N'Security.Roles_getForAdministration',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Security.Roles_getForAdministration AS BEGIN SET NOCOUNT ON;THROW 50010,''Configure the approved security role catalog adapter.'',1;END');
GO
CREATE OR ALTER PROCEDURE Portal.AdminSectionRoles_Get AS
BEGIN
 SET NOCOUNT ON;
 SELECT AdminSectionRoleId,RoleName,SectionKey,Active,LastChangeAt FROM Portal.AdminSectionRoles ORDER BY RoleName,SectionKey;
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminSectionRoles_Save @RoleName nvarchar(200),@SectionsJson nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@RoleName)),N'') IS NULL OR @RoleName COLLATE Latin1_General_100_BIN2=N'CompanyPortal.Admin' OR ISJSON(@SectionsJson)<>1 OR LEFT(LTRIM(@SectionsJson),1)<>N'[' THROW 50006,'Check role and sections.',1;
 DECLARE @Roles TABLE(RoleName nvarchar(200));INSERT @Roles EXEC Security.Roles_getForAdministration;
 IF NOT EXISTS(SELECT 1 FROM @Roles WHERE RoleName COLLATE Latin1_General_100_BIN2=@RoleName COLLATE Latin1_General_100_BIN2) THROW 50006,'Select an active role from the security source.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@SectionsJson))>13 OR EXISTS(SELECT 1 FROM OPENJSON(@SectionsJson) WHERE type<>1 OR value COLLATE Latin1_General_100_BIN2 NOT IN(N'cards',N'applications',N'documents',N'safety',N'fixed-orders',N'important-numbers',N'institution-status',N'notices',N'alerts',N'media',N'images',N'themes',N'events')) THROW 50006,'Invalid administration section.',1;
 DECLARE @Selected TABLE(SectionKey nvarchar(40) PRIMARY KEY);INSERT @Selected SELECT DISTINCT CONVERT(nvarchar(40),value) FROM OPENJSON(@SectionsJson);
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.AdminSectionRoles',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50006,'Permission settings are busy. Retry.',1;
 UPDATE r SET Active=CASE WHEN s.SectionKey IS NULL THEN 0 ELSE 1 END,LastChangeAt=GETDATE()
 FROM Portal.AdminSectionRoles r LEFT JOIN @Selected s ON s.SectionKey=r.SectionKey
 WHERE r.RoleName=@RoleName COLLATE Latin1_General_100_BIN2 AND r.Active<>CASE WHEN s.SectionKey IS NULL THEN 0 ELSE 1 END;
 INSERT Portal.AdminSectionRoles(RoleName,SectionKey) SELECT @RoleName,s.SectionKey FROM @Selected s
 WHERE NOT EXISTS(SELECT 1 FROM Portal.AdminSectionRoles r WHERE r.RoleName=@RoleName COLLATE Latin1_General_100_BIN2 AND r.SectionKey=s.SectionKey);
 -- Deliberately no audit entry: requested by the user. No membership or AD changes.
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Portal.KnownRoles_get
 @Username nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Users TABLE(UserId int);
 DECLARE @Roles TABLE(RoleName nvarchar(200));
 INSERT @Users EXEC Security.User_getByUsername @Username=@Username;
 DECLARE @UserId int=(SELECT TOP(1) UserId FROM @Users WHERE UserId IS NOT NULL);
 IF @UserId IS NOT NULL INSERT @Roles EXEC Security.UserRoles_get @UserId=@UserId;
 SELECT RoleName FROM (
  SELECT LTRIM(RTRIM(RoleName)) COLLATE Latin1_General_100_BIN2 RoleName FROM @Roles
  UNION SELECT RoleName COLLATE Latin1_General_100_BIN2 FROM [Master].CardRoles WHERE Active=1
  UNION SELECT RoleName COLLATE Latin1_General_100_BIN2 FROM [Master].ThemePreviewRoles WHERE Active=1
  UNION SELECT RoleName COLLATE Latin1_General_100_BIN2 FROM Portal.AdminSectionRoles WHERE Active=1
 ) r WHERE LEN(RoleName)>0 ORDER BY RoleName;
END;
GO
-- Existing business writers retain history, with separate section authorization scopes.
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Save
 @Id int=NULL,@Title nvarchar(150),@Number nvarchar(50),@SortOrder int,@Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: save and history row commit together
 SET @Title=LTRIM(RTRIM(@Title));SET @Number=LTRIM(RTRIM(@Number));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@Number,N'')=N'' THROW 50039,'Title and number are required.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max),@After nvarchar(max);
 IF @Id IS NULL
 BEGIN
  INSERT Mng.ImportantNumbers(Title,Number,SortOrder,Active) VALUES(@Title,@Number,@SortOrder,@Active);
  SET @Id=CAST(SCOPE_IDENTITY() AS int);
 END
 ELSE
 BEGIN
  SET @Before=(SELECT Portal.AdminSnapshot_ImportantNumber(Id) FROM Mng.ImportantNumbers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
  UPDATE Mng.ImportantNumbers SET Title=@Title,Number=@Number,SortOrder=@SortOrder,Active=@Active,LastChangeAt=GETDATE() WHERE Id=@Id;
  IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Important number not found.',1; END;
 END;
 SET @After=Portal.AdminSnapshot_ImportantNumber(@Id);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='important-numbers',@ItemType='important-number',@ItemId=@Id,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After;
 COMMIT;
 SELECT @Id AS Id;
END;
GO
CREATE OR ALTER PROCEDURE Mng.ImportantNumbers_Delete @Id int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: delete and history row commit together
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_ImportantNumber(Id) FROM Mng.ImportantNumbers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@Id);
 DELETE Mng.ImportantNumbers WHERE Id=@Id;
 IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Important number not found.',1; END;
 DECLARE @Title nvarchar(150)=JSON_VALUE(@Before,'$.Title');
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='important-numbers',@ItemType='important-number',@ItemId=@Id,@ItemTitle=@Title,@OldJson=@Before;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Mng.StatusLevels_Save
 @ColorValue tinyint,@Title nvarchar(100),@ColorName nvarchar(30),@Summary nvarchar(600),@GuideText nvarchar(300)=NULL,@Actions nvarchar(1500)=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON; -- history: save and history row commit together
 SET @Title=LTRIM(RTRIM(@Title));SET @ColorName=LTRIM(RTRIM(@ColorName));SET @Summary=LTRIM(RTRIM(@Summary));
 IF ISNULL(@Title,N'')=N'' OR ISNULL(@ColorName,N'')=N'' OR ISNULL(@Summary,N'')=N'' THROW 50039,'Title, colour name and description are required.',1;
 BEGIN TRANSACTION;
 DECLARE @Before nvarchar(max)=(SELECT Portal.AdminSnapshot_StatusLevel(ColorValue) FROM Mng.StatusLevels WITH(UPDLOCK,HOLDLOCK) WHERE ColorValue=@ColorValue);
 UPDATE Mng.StatusLevels SET Title=@Title,ColorName=@ColorName,Summary=@Summary,
  GuideText=NULLIF(LTRIM(RTRIM(@GuideText)),N''),Actions=NULLIF(LTRIM(RTRIM(@Actions)),N''),LastChangeAt=GETDATE()
 WHERE ColorValue=@ColorValue;
 IF @@ROWCOUNT=0 BEGIN ROLLBACK; THROW 50011,'Status level not found.',1; END;
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_StatusLevel(@ColorValue);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='institution-status',@ItemType='status-level',@ItemId=@ColorValue,@ItemTitle=@Title,@OldJson=@Before,@NewJson=@After;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Mng.CurrentStatus_Set @ColorValue int,@ChangedBy nvarchar(512) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ColorValue NOT BETWEEN 1 AND 4 OR @ColorValue IS NULL OR NULLIF(LTRIM(RTRIM(@ChangedBy)),N'') IS NULL THROW 50039,'Select an available status.',1;
 DECLARE @Users TABLE(UserId int);DECLARE @UserId int;
 INSERT @Users EXEC Security.User_getByUsername @Username=@ChangedBy;
 SELECT @UserId=UserId FROM @Users;
 IF @UserId IS NULL THROW 50039,'Registered active employee required.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource=N'CompanyPortal.CurrentStatus',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50039,'Status settings are busy. Retry.',1;
 DECLARE @Before nvarchar(max),@Previous int,@Id int,@Title nvarchar(100);
 SELECT TOP(1) @Previous=s.ColorValue FROM Mng.CurrentStatus s WITH(UPDLOCK,HOLDLOCK) ORDER BY LastUpdated DESC,Id DESC;
 IF @Previous=@ColorValue BEGIN COMMIT;RETURN;END;
 SELECT @Title=Title FROM Mng.StatusLevels WHERE ColorValue=@ColorValue;
 IF @Title IS NULL THROW 50039,'Status definition missing.',1;
 SET @Before=(SELECT @Previous ColorValue,(SELECT Title FROM Mng.StatusLevels WHERE ColorValue=@Previous) Title FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
 INSERT Mng.CurrentStatus(ColorValue,ChangedBy,UserId) VALUES(@ColorValue,@ChangedBy,@UserId);
 SET @Id=SCOPE_IDENTITY();
 DECLARE @After nvarchar(max)=(SELECT @ColorValue ColorValue,@Title Title FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='institution-status',@ItemType='current-status',@ItemId=@Id,@ItemTitle=N'حالة المؤسسة',@OldJson=@Before,@NewJson=@After,@Action='update';
 COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Mng.CurrentStatus_AdminGet AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(1) Id,ColorValue,LastUpdated,ChangedBy,UserId FROM Mng.CurrentStatus ORDER BY LastUpdated DESC,Id DESC;
 SELECT TOP(50) AdminChangeId,ChangedAt,ChangedBy,TRY_CONVERT(int,ItemId) StatusId,
 TRY_CONVERT(int,JSON_VALUE(OldJson,'$.ColorValue')) FromColorValue,JSON_VALUE(OldJson,'$.Title') FromTitle,
 TRY_CONVERT(int,JSON_VALUE(NewJson,'$.ColorValue')) ToColorValue,JSON_VALUE(NewJson,'$.Title') ToTitle
 FROM Portal.AdminChanges WHERE Section='institution-status' AND ItemType='current-status' ORDER BY AdminChangeId DESC;
END;
GO
UPDATE Portal.AdminChanges SET Section=CASE WHEN ItemType='important-number' THEN 'important-numbers' ELSE 'institution-status' END WHERE Section='header-content' AND ItemType IN('important-number','status-level','current-status');
GO
