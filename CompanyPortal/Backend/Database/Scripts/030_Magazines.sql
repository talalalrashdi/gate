USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Portal.Magazines',N'U') IS NULL
 CREATE TABLE Portal.Magazines(
  MagazineID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Magazines PRIMARY KEY,
  MagazineName nvarchar(300) NOT NULL,
  IssueNumber nvarchar(100) NOT NULL,
  IssueDate date NOT NULL,
  FileName nvarchar(1000) NOT NULL,
  DisplayOrder int NOT NULL CONSTRAINT DF_Magazines_DisplayOrder DEFAULT 0,
  LastChangeAt datetime NOT NULL CONSTRAINT DF_Magazines_LastChangeAt DEFAULT GETDATE(),
  Active bit NOT NULL CONSTRAINT DF_Magazines_Active DEFAULT 1,
  CONSTRAINT CK_Magazines_DisplayOrder CHECK(DisplayOrder>=0));
GO
-- Preserve a customized source adapter when reapplying this migration.
IF OBJECT_ID(N'Portal.Magazines_GetAll',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Magazines_GetAll @MagazineID int=NULL AS BEGIN
 SET NOCOUNT ON;
 SELECT MagazineID,MagazineName,IssueNumber,IssueDate,FileName,DisplayOrder,LastChangeAt,Active
 FROM Portal.Magazines WHERE Active=1 AND (@MagazineID IS NULL OR MagazineID=@MagazineID)
 ORDER BY IssueDate DESC,DisplayOrder,MagazineID DESC;
 END;');
GO
