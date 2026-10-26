USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Mstr.ContentType',N'U') IS NULL
 CREATE TABLE Mstr.ContentType(
 ContentTypeID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ContentType PRIMARY KEY,
 ContentTypeName nvarchar(200) NOT NULL,
 Active bit NOT NULL CONSTRAINT DF_ContentType_Active DEFAULT(1));
IF EXISTS(SELECT 1 FROM Mstr.ContentType WHERE (ContentTypeID=1 AND ContentTypeName<>N'المجلات') OR (ContentTypeID=2 AND ContentTypeName<>N'القرارات'))
 THROW 50012,'Reserved content type identity conflicts with an existing type.',1;
SET IDENTITY_INSERT Mstr.ContentType ON;
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=1) INSERT Mstr.ContentType(ContentTypeID,ContentTypeName) VALUES(1,N'المجلات');
IF NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=2) INSERT Mstr.ContentType(ContentTypeID,ContentTypeName) VALUES(2,N'القرارات');
SET IDENTITY_INSERT Mstr.ContentType OFF;
IF OBJECT_ID(N'Portal.UserReads',N'U') IS NULL
 CREATE TABLE Portal.UserReads(
 UserReadID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserReads PRIMARY KEY,
 UserId int NOT NULL,ContentTypeID int NOT NULL,ContentId nvarchar(200) NOT NULL,
 ReadAt datetime NOT NULL CONSTRAINT DF_UserReads_ReadAt DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_UserReads_Active DEFAULT(1),
 CONSTRAINT FK_UserReads_ContentType FOREIGN KEY(ContentTypeID) REFERENCES Mstr.ContentType(ContentTypeID),
 CONSTRAINT UQ_UserReads_User_Type_Content UNIQUE(UserId,ContentTypeID,ContentId),
 CONSTRAINT CK_UserReads_Identity CHECK(UserId>0 AND LEN(ContentId)>0));
-- One-time migration: legacy table is retained as an archive, never written by the application again.
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE major_id=OBJECT_ID(N'Portal.UserReads') AND name=N'MagazineReadsMigrated')
BEGIN
 INSERT Portal.UserReads(UserId,ContentTypeID,ContentId,ReadAt,Active)
 SELECT r.UserId,1,CONVERT(nvarchar(200),r.MagazineID),r.ReadAt,r.Active FROM Portal.UserMagazineReads r
 WHERE NOT EXISTS(SELECT 1 FROM Portal.UserReads u WHERE u.UserId=r.UserId AND u.ContentTypeID=1 AND u.ContentId=CONVERT(nvarchar(200),r.MagazineID));
 EXEC sys.sp_addextendedproperty @name=N'MagazineReadsMigrated',@value=1,@level0type=N'SCHEMA',@level0name=N'Portal',@level1type=N'TABLE',@level1name=N'UserReads';
END;
COMMIT;
GO
CREATE OR ALTER PROCEDURE Portal.UserReads_Get @UserId int,@ContentTypeID int AS
BEGIN SET NOCOUNT ON;SELECT ContentId FROM Portal.UserReads WHERE UserId=@UserId AND ContentTypeID=@ContentTypeID AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserReads_MarkRead @UserId int,@ContentTypeID int,@ContentId nvarchar(200) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR NULLIF(LTRIM(RTRIM(@ContentId)),N'') IS NULL OR NOT EXISTS(SELECT 1 FROM Mstr.ContentType WHERE ContentTypeID=@ContentTypeID AND Active=1) THROW 50012,'Invalid read identity.',1;
 BEGIN TRANSACTION;
 DECLARE @Active bit;
 SELECT @Active=Active FROM Portal.UserReads WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND ContentTypeID=@ContentTypeID AND ContentId=@ContentId;
 IF @Active IS NULL INSERT Portal.UserReads(UserId,ContentTypeID,ContentId) VALUES(@UserId,@ContentTypeID,@ContentId);
 ELSE IF @Active=0 UPDATE Portal.UserReads SET Active=1,ReadAt=GETDATE() WHERE UserId=@UserId AND ContentTypeID=@ContentTypeID AND ContentId=@ContentId;
 COMMIT;
END;
GO
-- Compatibility for callers of the old contracts; no duplicate storage.
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_Get @UserId int AS
BEGIN SET NOCOUNT ON;SELECT CONVERT(int,ContentId) MagazineID FROM Portal.UserReads WHERE UserId=@UserId AND ContentTypeID=1 AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_MarkRead @UserId int,@MagazineID int AS
BEGIN SET NOCOUNT ON;DECLARE @Id nvarchar(200)=CONVERT(nvarchar(200),@MagazineID);EXEC Portal.UserReads_MarkRead @UserId,1,@Id;END;
GO
