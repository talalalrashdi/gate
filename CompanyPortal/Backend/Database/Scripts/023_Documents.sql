USE CompanyPortal;
GO
IF SCHEMA_ID(N'Mng') IS NULL EXEC(N'CREATE SCHEMA Mng');
IF SCHEMA_ID(N'App') IS NULL EXEC(N'CREATE SCHEMA App');
GO
IF OBJECT_ID(N'Mng.Document',N'U') IS NULL
CREATE TABLE Mng.Document(
 DocumentID uniqueidentifier NOT NULL CONSTRAINT DF_Document_DocumentID DEFAULT(NEWID()) CONSTRAINT PK_Document PRIMARY KEY,
 DocumentName nvarchar(100) NOT NULL,
 DocumentPath nvarchar(150) NOT NULL,
 FolderID int NOT NULL,
 [Timestamp] datetime NOT NULL CONSTRAINT EForm_EFormUploadedDate DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_Document_Active DEFAULT(1)
);
GO
-- Install the real lookup only after its views exist; never replace an installed adapter here.
IF OBJECT_ID(N'Portal.Document_GetAll',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Document_GetAll @UserId int AS
 BEGIN SET NOCOUNT ON; THROW 50040,''Document source views/access list are not configured.'',1; END');
GO
