USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRAN;
IF EXISTS(SELECT 1 FROM Mstr.ContentType WHERE (ContentTypeID=4 AND ContentTypeName<>N'ملفات الوثائق') OR (ContentTypeID=5 AND ContentTypeName<>N'مشاهدة المكتبات'))
 THROW 50012,'Library content types are already reserved.',1;
SET IDENTITY_INSERT Mstr.ContentType ON;
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=4) INSERT Mstr.ContentType(ContentTypeID,ContentTypeName) VALUES(4,N'ملفات الوثائق');
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=5) INSERT Mstr.ContentType(ContentTypeID,ContentTypeName) VALUES(5,N'مشاهدة المكتبات');
SET IDENTITY_INSERT Mstr.ContentType OFF;
COMMIT;
GO
-- IDs are rechecked against the user's current, published PDF catalog by the API.
-- Type4: GUID = PDF opened (shared by both library sections).
-- Type5: section:GUID = section entry seen. Visiting a section does not mark its PDFs read.
CREATE OR ALTER PROCEDURE Portal.LibraryReads_Get @UserId int AS
BEGIN
 SET NOCOUNT ON;
 SELECT ContentTypeID,ContentId FROM Portal.UserReads WHERE UserId=@UserId AND ContentTypeID IN(4,5) AND Active=1;
END;
GO
CREATE OR ALTER PROCEDURE Portal.LibraryReads_Mark @UserId int,@Section nvarchar(20),@DocumentIdsJson nvarchar(max),@MarkRead bit AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @Section NOT IN(N'documents',N'safety') OR ISJSON(@DocumentIdsJson)<>1 OR (SELECT COUNT(*) FROM Mstr.ContentType WHERE ContentTypeID IN(4,5) AND Active=1)<>2
  THROW 50012,'Invalid library acknowledgement.',1;
 DECLARE @Docs TABLE(Id uniqueidentifier PRIMARY KEY);
 INSERT @Docs SELECT DISTINCT TRY_CONVERT(uniqueidentifier,value) FROM OPENJSON(@DocumentIdsJson) WHERE TRY_CONVERT(uniqueidentifier,value) IS NOT NULL;
 IF (SELECT COUNT(*) FROM @Docs)>500 THROW 50012,'Library acknowledgement batch is too large.',1;
 DECLARE @Ids TABLE(ContentTypeID int,ContentId nvarchar(200),PRIMARY KEY(ContentTypeID,ContentId));
 INSERT @Ids SELECT 5,@Section+N':'+LOWER(CONVERT(nvarchar(36),Id)) FROM @Docs;
 IF @MarkRead=1 INSERT @Ids SELECT 4,LOWER(CONVERT(nvarchar(36),Id)) FROM @Docs;
 BEGIN TRAN;
 DECLARE @Lock int,@Resource nvarchar(255)=N'Portal.Library.Reads.'+CONVERT(nvarchar(20),@UserId);
 EXEC @Lock=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
 IF @Lock<0 THROW 50012,'Library acknowledgement is busy.',1;
 UPDATE r SET Active=1,ReadAt=GETDATE() FROM Portal.UserReads r JOIN @Ids i ON i.ContentId=r.ContentId AND i.ContentTypeID=r.ContentTypeID WHERE r.UserId=@UserId AND r.Active=0;
 INSERT Portal.UserReads(UserId,ContentTypeID,ContentId)
 SELECT @UserId,i.ContentTypeID,i.ContentId FROM @Ids i WHERE NOT EXISTS(SELECT 1 FROM Portal.UserReads r WHERE r.UserId=@UserId AND r.ContentTypeID=i.ContentTypeID AND r.ContentId=i.ContentId);
 COMMIT;
END;
GO
