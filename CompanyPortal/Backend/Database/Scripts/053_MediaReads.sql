USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRAN;
IF EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=3 AND ContentTypeName<>N'أخبارنا')
 THROW 50012,'ContentTypeID 3 is already reserved for a different type.',1;
SET IDENTITY_INSERT Mstr.ContentType ON;
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=3)
 INSERT Mstr.ContentType(ContentTypeID,ContentTypeName,Active) VALUES(3,N'أخبارنا',1);
SET IDENTITY_INSERT Mstr.ContentType OFF;
COMMIT;
GO
-- The API revalidates these IDs against its configured visible media source before this batch.
CREATE OR ALTER PROCEDURE Portal.Media_MarkSeen @UserId int,@MediaIdsJson nvarchar(max) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR ISJSON(@MediaIdsJson)<>1 OR NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=3 AND Active=1)
  THROW 50012,'Invalid media acknowledgement.',1;
 DECLARE @Ids TABLE(ContentId nvarchar(200) PRIMARY KEY);
 INSERT @Ids SELECT DISTINCT CONVERT(nvarchar(200),TRY_CONVERT(int,value)) FROM OPENJSON(@MediaIdsJson) WHERE TRY_CONVERT(int,value)>0;
 BEGIN TRAN;
 -- Serialize per user/batch so repeat clicks/tabs cannot create duplicate read records.
 DECLARE @Lock int,@Resource nvarchar(255)=N'Portal.Media.Reads.'+CONVERT(nvarchar(20),@UserId);
 EXEC @Lock=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50012,'Media acknowledgement is busy.',1;
 UPDATE r SET Active=1,ReadAt=GETDATE() FROM Portal.UserReads r JOIN @Ids i ON i.ContentId=r.ContentId
 WHERE r.UserId=@UserId AND r.ContentTypeID=3 AND r.Active=0;
 INSERT Portal.UserReads(UserId,ContentTypeID,ContentId)
 SELECT @UserId,3,i.ContentId FROM @Ids i WHERE NOT EXISTS(SELECT 1 FROM Portal.UserReads r WHERE r.UserId=@UserId AND r.ContentTypeID=3 AND r.ContentId=i.ContentId);
 COMMIT;
END;
GO
