USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRAN;
IF EXISTS(SELECT 1 FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID(N'Master.ApplicationDetails') AND name=N'DF_ApplicationDetails_Description')
 ALTER TABLE Master.ApplicationDetails DROP CONSTRAINT DF_ApplicationDetails_Description;
ALTER TABLE Master.ApplicationDetails ALTER COLUMN AppDescription nvarchar(2000) NULL;
-- Normalize representation only: display/API still use an empty string; preserve LastChangeAt.
UPDATE Master.ApplicationDetails SET AppDescription=NULL WHERE LTRIM(RTRIM(AppDescription))=N'';
COMMIT;
GO
CREATE OR ALTER PROCEDURE [Master].Applications_save
 @AppId int,@Description nvarchar(2000)=NULL,@CategoryId int=NULL,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET @Description=NULLIF(LTRIM(RTRIM(@Description)),N'');
 DECLARE @Apps TABLE(AppId int PRIMARY KEY,AppName nvarchar(200));
 INSERT @Apps EXEC Security.Apps_getForAdministration;
 IF NOT EXISTS(SELECT 1 FROM @Apps WHERE AppId=@AppId) THROW 50011,'Application not found in current catalog.',1;
 DECLARE @AppName nvarchar(200)=(SELECT AppName FROM @Apps WHERE AppId=@AppId); -- history
 BEGIN TRY
 BEGIN TRAN;
 IF @CategoryId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [Master].ApplicationCategories WITH(HOLDLOCK) WHERE ApplicationCategoryId=@CategoryId)
  THROW 50012,'Category not found.',1;
 DECLARE @Existing int=(SELECT ApplicationDetailId FROM [Master].ApplicationDetails WITH(UPDLOCK,HOLDLOCK) WHERE AppId=@AppId);
 DECLARE @Before nvarchar(max)=Portal.AdminSnapshot_Application(@AppId); -- history
 IF @Existing IS NULL
  INSERT [Master].ApplicationDetails(AppId,ApplicationCategoryId,AppDescription) VALUES(@AppId,@CategoryId,@Description);
 ELSE
  UPDATE [Master].ApplicationDetails SET ApplicationCategoryId=@CategoryId,AppDescription=@Description,Active=1,LastChangeAt=GETDATE()
  WHERE ApplicationDetailId=@Existing AND (Active=0 OR EXISTS(
   SELECT @CategoryId,@Description COLLATE Latin1_General_100_BIN2 EXCEPT SELECT ApplicationCategoryId,AppDescription COLLATE Latin1_General_100_BIN2 FROM [Master].ApplicationDetails WHERE ApplicationDetailId=@Existing));
 DECLARE @After nvarchar(max)=Portal.AdminSnapshot_Application(@AppId); -- history
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='applications',@ItemType='application',@ItemId=@AppId,@ItemTitle=@AppName,@OldJson=@Before,@NewJson=@After; -- history
 COMMIT;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
