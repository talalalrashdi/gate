USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET XACT_ABORT ON;
GO
IF COL_LENGTH(N'Mng.CurrentStatus',N'ChangedBy') IS NULL ALTER TABLE Mng.CurrentStatus ADD ChangedBy nvarchar(512) NULL;
IF COL_LENGTH(N'Mng.CurrentStatus',N'UserId') IS NULL ALTER TABLE Mng.CurrentStatus ADD UserId int NULL;
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
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='header-content',@ItemType='current-status',@ItemId=@Id,@ItemTitle=N'حالة المؤسسة',@OldJson=@Before,@NewJson=@After,@Action='update';
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
 FROM Portal.AdminChanges WHERE Section='header-content' AND ItemType='current-status' ORDER BY AdminChangeId DESC;
END;
GO
