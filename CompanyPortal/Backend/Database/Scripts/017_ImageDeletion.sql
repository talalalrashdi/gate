USE [CompanyPortal];
GO
CREATE OR ALTER PROCEDURE [Master].Images_delete @ImageId int
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM [Master].Images WITH(UPDLOCK,HOLDLOCK) WHERE ImageId=@ImageId AND Active=1)
 BEGIN COMMIT; SELECT CAST(0 AS bit); RETURN; END;
 IF EXISTS(SELECT 1 FROM [Master].ImageGroupItems WHERE ImageId=@ImageId)
 OR EXISTS(SELECT 1 FROM [Master].ImageGroups WHERE DefaultImageId=@ImageId)
 BEGIN ROLLBACK; THROW 50009,'Remove the image from saved groups before deleting it.',1; END;
 UPDATE [Master].Images SET Active=0,LastChangeAt=GETDATE() WHERE ImageId=@ImageId;
 COMMIT;
 SELECT CAST(1 AS bit);
END;
GO
