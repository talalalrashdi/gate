USE CompanyPortal;
GO
SET XACT_ABORT ON;
GO
IF COL_LENGTH(N'Portal.AdminChanges',N'WorkStation') IS NULL ALTER TABLE Portal.AdminChanges ADD WorkStation nvarchar(100) NULL CONSTRAINT DF_AdminChanges_WorkStation DEFAULT(HOST_NAME());
IF COL_LENGTH(N'Mng.CurrentStatus',N'WorkStation') IS NULL ALTER TABLE Mng.CurrentStatus ADD WorkStation nvarchar(100) NULL CONSTRAINT DF_CurrentStatus_WorkStation DEFAULT(HOST_NAME());
IF OBJECT_ID(N'Portal.ManagedRoles',N'U') IS NULL CREATE TABLE Portal.ManagedRoles(ManagedRoleId int IDENTITY PRIMARY KEY,RoleName nvarchar(200) NOT NULL UNIQUE,LastChangeAt datetime NOT NULL DEFAULT(GETDATE()),Active bit NOT NULL DEFAULT(1));
INSERT Portal.ManagedRoles(RoleName) SELECT v.RoleName FROM(VALUES(N'CompanyPortal.Content'),(N'CompanyPortal.Library'),(N'CompanyPortal.Appearance'),(N'CompanyPortal.Applications'),(N'CompanyPortal.Notices'),(N'CompanyPortal.Directory'),(N'CompanyPortal.Status'))v(RoleName) WHERE NOT EXISTS(SELECT 1 FROM Portal.ManagedRoles m WHERE m.RoleName=v.RoleName);
GO
IF OBJECT_ID(N'Security.Role_Create',N'P') IS NULL EXEC(N'CREATE PROCEDURE Security.Role_Create @RoleName nvarchar(200) AS THROW 50010,''Configure Security.Role_Create for the security database.'',1;');
IF OBJECT_ID(N'Security.Role_Deactivate',N'P') IS NULL EXEC(N'CREATE PROCEDURE Security.Role_Deactivate @RoleName nvarchar(200) AS THROW 50010,''Configure Security.Role_Deactivate for the security database.'',1;');
GO
CREATE OR ALTER PROCEDURE Portal.ManagedRoles_Get AS SELECT RoleName FROM Portal.ManagedRoles WHERE Active=1;
GO
CREATE OR ALTER PROCEDURE Portal.ManagedRoles_Create @RoleName nvarchar(200),@SectionsJson nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @RoleName<>LTRIM(RTRIM(@RoleName)) OR LEFT(@RoleName,14) COLLATE Latin1_General_100_BIN2<>N'CompanyPortal.' OR LEN(@RoleName)<=14 OR @RoleName COLLATE Latin1_General_100_CI_AS=N'CompanyPortal.Admin' THROW 50006,'Use a new CompanyPortal role name.',1;
 BEGIN TRAN;
 EXEC Security.Role_Create @RoleName;
 IF EXISTS(SELECT 1 FROM Portal.ManagedRoles WHERE RoleName=@RoleName) THROW 50006,'Role name already registered.',1;
 INSERT Portal.ManagedRoles(RoleName) VALUES(@RoleName);
 EXEC Portal.AdminSectionRoles_Save @RoleName,@SectionsJson;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Portal.ManagedRoles_Deactivate @RoleName nvarchar(200) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @RoleName COLLATE Latin1_General_100_CI_AS=N'CompanyPortal.Admin' THROW 50006,'Super administrator role is protected.',1;
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM Portal.ManagedRoles WITH(UPDLOCK,HOLDLOCK) WHERE RoleName=@RoleName AND Active=1) THROW 50006,'Only portal-managed roles can be deactivated.',1;
 EXEC Security.Role_Deactivate @RoleName;
 UPDATE Portal.ManagedRoles SET Active=0,LastChangeAt=GETDATE() WHERE RoleName=@RoleName;
 UPDATE Portal.AdminSectionRoles SET Active=0,LastChangeAt=GETDATE() WHERE RoleName=@RoleName AND Active=1;
 COMMIT;
END;
GO
IF OBJECT_ID(N'Mng.CustomPopups',N'U') IS NULL CREATE TABLE Mng.CustomPopups(
 PopupId int IDENTITY PRIMARY KEY,PopupType nvarchar(100) NOT NULL,Details nvarchar(2000) NOT NULL,
 StartAt datetime NOT NULL,EndAt datetime NOT NULL,IsDisplayed bit NOT NULL DEFAULT(0),
 LastChangeAt datetime NOT NULL DEFAULT(GETDATE()),Active bit NOT NULL DEFAULT(1),CONSTRAINT CK_CustomPopups_Dates CHECK(EndAt>StartAt));
IF OBJECT_ID(N'Portal.UserPopupDismissals',N'U') IS NULL CREATE TABLE Portal.UserPopupDismissals(
 DismissalId bigint IDENTITY PRIMARY KEY,UserId int NOT NULL,PopupId int NOT NULL REFERENCES Mng.CustomPopups(PopupId),
 DismissedAt datetime NOT NULL DEFAULT(GETDATE()),WorkStation nvarchar(100) NULL DEFAULT(HOST_NAME()),Active bit NOT NULL DEFAULT(1),UNIQUE(UserId,PopupId));
GO
CREATE OR ALTER PROCEDURE Mng.CustomPopups_GetAll AS SELECT * FROM Mng.CustomPopups WHERE Active=1 ORDER BY PopupId DESC;
GO
CREATE OR ALTER PROCEDURE Mng.CustomPopups_GetVisible @UserId int AS
 SELECT p.* FROM Mng.CustomPopups p WHERE p.Active=1 AND p.IsDisplayed=1 AND p.StartAt<=GETUTCDATE() AND p.EndAt>GETUTCDATE()
 AND NOT EXISTS(SELECT 1 FROM Portal.UserPopupDismissals d WHERE d.UserId=@UserId AND d.PopupId=p.PopupId AND d.Active=1) ORDER BY p.PopupId DESC;
GO
CREATE OR ALTER PROCEDURE Mng.CustomPopups_Save @PopupId int=NULL,@PopupType nvarchar(100),@Details nvarchar(2000),@StartAt datetime,@EndAt datetime,@IsDisplayed bit,@ChangedBy nvarchar(512) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@PopupType)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Details)),N'') IS NULL OR @EndAt<=@StartAt THROW 50006,'Type, details and valid display dates are required.',1;
 BEGIN TRAN;
 DECLARE @Before nvarchar(max),@After nvarchar(max),@Key nvarchar(100);
 IF @PopupId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Mng.CustomPopups WITH(UPDLOCK,HOLDLOCK) WHERE PopupId=@PopupId AND Active=1) THROW 50052,'Popup not found.',1;
 SELECT @Before=(SELECT PopupType,Details,StartAt,EndAt,IsDisplayed,Active FROM Mng.CustomPopups WHERE PopupId=@PopupId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 IF @PopupId IS NULL BEGIN INSERT Mng.CustomPopups(PopupType,Details,StartAt,EndAt,IsDisplayed) VALUES(@PopupType,@Details,@StartAt,@EndAt,@IsDisplayed);SET @PopupId=SCOPE_IDENTITY();END
 ELSE UPDATE Mng.CustomPopups SET PopupType=@PopupType,Details=@Details,StartAt=@StartAt,EndAt=@EndAt,IsDisplayed=@IsDisplayed,LastChangeAt=GETDATE()
 WHERE PopupId=@PopupId AND (PopupType COLLATE Latin1_General_100_BIN2<>@PopupType OR Details COLLATE Latin1_General_100_BIN2<>@Details OR StartAt<>@StartAt OR EndAt<>@EndAt OR IsDisplayed<>@IsDisplayed);
 SELECT @After=(SELECT PopupType,Details,StartAt,EndAt,IsDisplayed,Active FROM Mng.CustomPopups WHERE PopupId=@PopupId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);SET @Key=CONVERT(nvarchar(100),@PopupId);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='notices',@ItemType='custom-popup',@ItemId=@Key,@ItemTitle=@PopupType,@OldJson=@Before,@NewJson=@After;
 COMMIT;SELECT @PopupId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.CustomPopups_Delete @PopupId int,@ChangedBy nvarchar(512) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;BEGIN TRAN;
 DECLARE @Before nvarchar(max),@Title nvarchar(100),@Key nvarchar(100)=CONVERT(nvarchar(100),@PopupId);
 SELECT @Title=PopupType FROM Mng.CustomPopups WITH(UPDLOCK,HOLDLOCK) WHERE PopupId=@PopupId AND Active=1;
 IF @Title IS NULL THROW 50052,'Popup not found.',1;
 SET @Before=(SELECT PopupType,Details,StartAt,EndAt,IsDisplayed,Active FROM Mng.CustomPopups WHERE PopupId=@PopupId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 UPDATE Mng.CustomPopups SET Active=0,LastChangeAt=GETDATE() WHERE PopupId=@PopupId;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='notices',@ItemType='custom-popup',@ItemId=@Key,@ItemTitle=@Title,@OldJson=@Before;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserPopupDismissals_Save @UserId int,@PopupId int AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM Mng.CustomPopups WHERE PopupId=@PopupId AND Active=1 AND IsDisplayed=1 AND StartAt<=GETUTCDATE() AND EndAt>GETUTCDATE()) THROW 50052,'Popup not available.',1;
 IF NOT EXISTS(SELECT 1 FROM Portal.UserPopupDismissals WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND PopupId=@PopupId)
 INSERT Portal.UserPopupDismissals(UserId,PopupId) VALUES(@UserId,@PopupId);
 COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetPage
 @Section varchar(40)=NULL,@ChangedBy nvarchar(512)=NULL,@FromAt datetime=NULL,@ToAt datetime=NULL,
 @Page int=1,@PageSize int=25
AS
BEGIN
 SET NOCOUNT ON;
 SET @Page=CASE WHEN @Page BETWEEN 1 AND 1000000 THEN @Page ELSE 1 END;
 SET @PageSize=CASE WHEN @PageSize BETWEEN 1 AND 100 THEN @PageSize ELSE 25 END;
 DECLARE @Rows TABLE(AdminChangeId bigint PRIMARY KEY);
 INSERT @Rows SELECT AdminChangeId FROM Portal.AdminChanges
 WHERE (@Section IS NULL OR Section=@Section)
 AND (NULLIF(@ChangedBy,N'') IS NULL OR ChangedBy LIKE N'%'+REPLACE(REPLACE(REPLACE(@ChangedBy,N'[',N'[[]'),N'%',N'[%]'),N'_',N'[_]')+N'%')
 AND (@FromAt IS NULL OR ChangedAt>=@FromAt) AND (@ToAt IS NULL OR ChangedAt<@ToAt);
 SELECT COUNT(*) Total FROM @Rows;
 SELECT CONVERT(nvarchar(20),c.AdminChangeId) ChangeId,c.ChangedAt,c.ChangedBy,c.WorkStation,c.Section,c.Action,c.ItemType,c.ItemId,c.ItemTitle
 FROM @Rows r JOIN Portal.AdminChanges c ON c.AdminChangeId=r.AdminChangeId
 ORDER BY c.AdminChangeId DESC OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE Portal.AdminChanges_GetById @AdminChangeId bigint AS
BEGIN
 SET NOCOUNT ON;
 SELECT CONVERT(nvarchar(20),AdminChangeId) ChangeId,ChangedAt,ChangedBy,WorkStation,Section,Action,ItemType,ItemId,ItemTitle,OldJson,NewJson
 FROM Portal.AdminChanges WHERE AdminChangeId=@AdminChangeId;
END;
GO
