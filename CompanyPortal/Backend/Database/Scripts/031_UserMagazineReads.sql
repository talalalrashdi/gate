USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Portal.UserMagazineReads',N'U') IS NULL
 CREATE TABLE Portal.UserMagazineReads(
  UserMagazineReadID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserMagazineReads PRIMARY KEY,
  UserId int NOT NULL,MagazineID int NOT NULL,
  ReadAt datetime NOT NULL CONSTRAINT DF_UserMagazineReads_ReadAt DEFAULT GETDATE(),
  Active bit NOT NULL CONSTRAINT DF_UserMagazineReads_Active DEFAULT 1,
  CONSTRAINT UQ_UserMagazineReads_User_Issue UNIQUE(UserId,MagazineID),
  CONSTRAINT CK_UserMagazineReads_IDs CHECK(UserId>0 AND MagazineID>0));
GO
-- User and magazine identities can be supplied by external mapped sources; no cross-source FK.
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_Get @UserId int AS
BEGIN SET NOCOUNT ON;SELECT MagazineID FROM Portal.UserMagazineReads WHERE UserId=@UserId AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserMagazineReads_MarkRead @UserId int,@MagazineID int AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @MagazineID<=0 THROW 50012,'Invalid read identity.',1;
 BEGIN TRANSACTION;
 DECLARE @Active bit;
 SELECT @Active=Active FROM Portal.UserMagazineReads WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND MagazineID=@MagazineID;
 IF @Active IS NULL INSERT Portal.UserMagazineReads(UserId,MagazineID) VALUES(@UserId,@MagazineID);
 ELSE IF @Active=0 UPDATE Portal.UserMagazineReads SET Active=1,ReadAt=GETDATE() WHERE UserId=@UserId AND MagazineID=@MagazineID;
 -- Already read: preserve the original timestamp; no UPDATE.
 COMMIT;
END;
GO
