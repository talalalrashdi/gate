USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @LegacyId int=OBJECT_ID(N'Mng.DocumentSampleFolders',N'U'),@Seed bigint;
 IF @LegacyId IS NOT NULL AND OBJECT_ID(N'Mng.Folder',N'U') IS NOT NULL
  THROW 50042,'Both folder tables exist. Resolve the collision before applying this migration.',1;
 IF @LegacyId IS NOT NULL
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
   THROW 50043,'The legacy folder table is not a marked development source.',1;
  IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=@LegacyId)<>5
   OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@LegacyId OR referenced_object_id=@LegacyId)
   OR EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@LegacyId)
   OR EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@LegacyId AND is_primary_key=0 AND index_id>0)
   OR EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=@LegacyId)
   OR EXISTS(SELECT 1 FROM sys.sql_expression_dependencies WHERE referenced_id=@LegacyId AND referencing_id<>OBJECT_ID(N'dbo.VFolder'))
   OR OBJECTPROPERTY(OBJECT_ID(N'dbo.VFolder'),N'IsSchemaBound')=1
   THROW 50044,'Legacy folder customizations need review before rebuilding its column order.',1;
  SELECT @Seed=CONVERT(bigint,last_value) FROM sys.identity_columns WHERE object_id=@LegacyId;
 END;
 IF OBJECT_ID(N'Mng.Folder',N'U') IS NULL
 CREATE TABLE Mng.Folder(
  FolderID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Folder PRIMARY KEY,
  ParentID int NULL,
  FolderName nvarchar(200) NOT NULL,
  UnitMstID int NULL,
  IsForDisplay bit NOT NULL CONSTRAINT DF_Folder_IsForDisplay DEFAULT(1),
  [Timestamp] datetime NOT NULL CONSTRAINT DF_Folder_Timestamp DEFAULT(GETDATE()),
  Active bit NOT NULL CONSTRAINT DF_Folder_Active DEFAULT(1)
 );
 IF @LegacyId IS NOT NULL
 BEGIN
  SET IDENTITY_INSERT Mng.Folder ON;
  EXEC(N'INSERT Mng.Folder(FolderID,ParentID,FolderName,IsForDisplay,Active)
   SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.DocumentSampleFolders;
   IF EXISTS(SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.DocumentSampleFolders
    EXCEPT SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.Folder)
   OR EXISTS(SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.Folder
    EXCEPT SELECT FolderID,ParentID,FolderName,IsForDisplay,Active FROM Mng.DocumentSampleFolders)
    THROW 50045,''Folder data comparison failed.'',1;');
  SET IDENTITY_INSERT Mng.Folder OFF;
  IF @Seed IS NOT NULL EXEC(N'DBCC CHECKIDENT (''Mng.Folder'',RESEED,'+@Seed+N') WITH NO_INFOMSGS;');
  EXEC(N'DROP TABLE Mng.DocumentSampleFolders;');
 END;
 -- Change only the marked sample view; preserve a real external view on other installations.
 IF EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1)
  EXEC(N'CREATE OR ALTER VIEW dbo.VFolder AS
   SELECT FolderID,ParentID,FolderName,UnitMstID,IsForDisplay,[Timestamp],Active FROM Mng.Folder;');
 IF EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'Documents')
  AND EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'docs')
  THROW 50046,'Both Documents and docs folder keys exist. Review the intended roots before renaming.',1;
 UPDATE Mstr.Utls SET [Key]=N'docs',LastChangeAt=GETDATE() WHERE [Key]=N'Documents';
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
