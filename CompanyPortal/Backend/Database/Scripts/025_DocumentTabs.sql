USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Portal.DocumentTabs',N'U') IS NULL
CREATE TABLE Portal.DocumentTabs(
 DocumentTabID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentTabs PRIMARY KEY,
 TabName nvarchar(200) NOT NULL,
 FolderID int NOT NULL,
 DisplayOrder int NOT NULL CONSTRAINT DF_DocumentTabs_Order DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_DocumentTabs_LastChange DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_DocumentTabs_Active DEFAULT(1),
 CONSTRAINT CK_DocumentTabs_Order CHECK(DisplayOrder>=0)
);
IF OBJECT_ID(N'Portal.DocumentTabItems',N'U') IS NULL
CREATE TABLE Portal.DocumentTabItems(
 DocumentTabItemID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentTabItems PRIMARY KEY,
 DocumentTabID int NOT NULL CONSTRAINT FK_DocumentTabItems_Tab REFERENCES Portal.DocumentTabs(DocumentTabID),
 DocumentID uniqueidentifier NOT NULL CONSTRAINT FK_DocumentTabItems_Document REFERENCES Mng.Document(DocumentID),
 CONSTRAINT UQ_DocumentTabItems UNIQUE(DocumentTabID,DocumentID)
);
COMMIT;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Get @IncludeHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT DocumentTabID,TabName,FolderID,DisplayOrder,LastChangeAt,Active
 FROM Portal.DocumentTabs WHERE Active=1 OR @IncludeHidden=1 ORDER BY DisplayOrder,DocumentTabID;
 SELECT i.DocumentTabID,i.DocumentID FROM Portal.DocumentTabItems i
 JOIN Portal.DocumentTabs t ON t.DocumentTabID=i.DocumentTabID WHERE t.Active=1 OR @IncludeHidden=1;
END;
GO
CREATE OR ALTER PROCEDURE Portal.DocumentTabs_Save
 @DocumentTabID int=NULL,@TabName nvarchar(200),@FolderID int,@DisplayOrder int,@Active bit,@DocumentIds nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@TabName)),N'') IS NULL OR @DisplayOrder<0 OR ISJSON(@DocumentIds)<>1
  THROW 50012,'Invalid document tab.',1;
 DECLARE @Items TABLE(DocumentID uniqueidentifier NOT NULL PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM OPENJSON(@DocumentIds) WHERE TRY_CONVERT(uniqueidentifier,value) IS NULL)
  THROW 50012,'Invalid document selection.',1;
 INSERT @Items SELECT DISTINCT CONVERT(uniqueidentifier,value) FROM OPENJSON(@DocumentIds);
 IF NOT EXISTS(SELECT 1 FROM @Items) OR (SELECT COUNT(*) FROM @Items)>500
  THROW 50012,'Select between one and 500 PDF documents.',1;
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM @Items i LEFT JOIN Mng.Document d WITH(UPDLOCK,HOLDLOCK) ON d.DocumentID=i.DocumentID
  WHERE d.DocumentID IS NULL OR d.FolderID<>@FolderID OR d.Active<>1 OR LOWER(RIGHT(d.DocumentPath,4))<>N'.pdf')
  THROW 50012,'Selection must contain active PDFs from the selected folder.',1;
 IF @DocumentTabID IS NULL
 BEGIN
  INSERT Portal.DocumentTabs(TabName,FolderID,DisplayOrder,Active) VALUES(@TabName,@FolderID,@DisplayOrder,@Active);
  SET @DocumentTabID=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.DocumentTabs WITH(UPDLOCK,HOLDLOCK) WHERE DocumentTabID=@DocumentTabID)
   THROW 50011,'Document tab not found.',1;
  UPDATE Portal.DocumentTabs SET TabName=@TabName,FolderID=@FolderID,DisplayOrder=@DisplayOrder,Active=@Active,LastChangeAt=GETDATE()
  WHERE DocumentTabID=@DocumentTabID AND (TabName COLLATE Latin1_General_100_BIN2<>@TabName COLLATE Latin1_General_100_BIN2
   OR FolderID<>@FolderID OR DisplayOrder<>@DisplayOrder OR Active<>@Active
   OR EXISTS(SELECT DocumentID FROM @Items EXCEPT SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID)
   OR EXISTS(SELECT DocumentID FROM Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID EXCEPT SELECT DocumentID FROM @Items));
 END;
 DELETE Portal.DocumentTabItems WHERE DocumentTabID=@DocumentTabID AND DocumentID NOT IN(SELECT DocumentID FROM @Items);
 INSERT Portal.DocumentTabItems(DocumentTabID,DocumentID)
 SELECT @DocumentTabID,DocumentID FROM @Items i WHERE NOT EXISTS(
  SELECT 1 FROM Portal.DocumentTabItems t WHERE t.DocumentTabID=@DocumentTabID AND t.DocumentID=i.DocumentID);
 COMMIT;
 SELECT @DocumentTabID;
END;
GO
