-- Requires dbo.VFolder(FolderID,ParentID,FolderName,Active,IsForDisplay)
-- and dbo.VJobMainPeriod(UserID,ID). Verify these mappings against the real views.
USE CompanyPortal;
GO
CREATE OR ALTER FUNCTION App.CreateFolderPath(@fId int) RETURNS nvarchar(1000)
AS
BEGIN
 DECLARE @ParentID int,@NextID int,@Name nvarchar(1000),@FolderPath nvarchar(1000)=N'',
  @Visited nvarchar(4000)=N'|'+CONVERT(nvarchar(12),@fId)+N'|',@Depth int=0;
 IF (SELECT COUNT(*) FROM dbo.VFolder WHERE FolderID=@fId AND Active=1)<>1 RETURN NULL;
 SELECT @ParentID=ParentID FROM dbo.VFolder WHERE FolderID=@fId AND Active=1;
 WHILE @ParentID IS NOT NULL
 BEGIN
  IF @Depth>=128 OR CHARINDEX(N'|'+CONVERT(nvarchar(12),@ParentID)+N'|',@Visited)>0 RETURN NULL;
  IF (SELECT COUNT(*) FROM dbo.VFolder WHERE FolderID=@ParentID AND Active=1)<>1 RETURN NULL;
  SET @Name=NULL;SET @NextID=NULL;
  SELECT @Name=FolderName,@NextID=ParentID FROM dbo.VFolder WHERE FolderID=@ParentID AND Active=1;
  IF NULLIF(LTRIM(RTRIM(@Name)),N'') IS NULL OR LEN(@Name)+3+LEN(@FolderPath)>1000 RETURN NULL;
  SET @FolderPath=@Name+N' \ '+@FolderPath;
  SET @Visited+=CONVERT(nvarchar(12),@ParentID)+N'|';
  SET @ParentID=@NextID;SET @Depth+=1;
 END;
 RETURN @FolderPath;
END;
GO
CREATE OR ALTER PROCEDURE Portal.Document_GetAll @UserId int AS
BEGIN
 SET NOCOUNT ON;
 -- Maintain the authorized VJobMainPeriod.ID values manually in this procedure.
 DECLARE @FullAccessIds TABLE(ID int NOT NULL PRIMARY KEY);
 -- DOCUMENT_FULL_ACCESS_IDS
 -- Example only: INSERT @FullAccessIds(ID) VALUES(12345),(23456);
 DECLARE @FullAccess bit=CASE WHEN EXISTS(SELECT 1 FROM dbo.VJobMainPeriod j
  INNER JOIN @FullAccessIds a ON a.ID=j.ID WHERE j.UserID=@UserId) THEN 1 ELSE 0 END;
 ;WITH Restricted AS(
  SELECT FolderID,CONVERT(nvarchar(4000),N'|74|') AS Visited,0 AS Depth FROM dbo.VFolder WHERE FolderID=74
  UNION ALL
  SELECT v.FolderID,CONVERT(nvarchar(4000),r.Visited+CONVERT(nvarchar(12),v.FolderID)+N'|'),r.Depth+1
  FROM dbo.VFolder v INNER JOIN Restricted r ON v.ParentID=r.FolderID
  WHERE r.Depth<128 AND CHARINDEX(N'|'+CONVERT(nvarchar(12),v.FolderID)+N'|',r.Visited)=0
 )
 SELECT DISTINCT FolderID INTO #Restricted FROM Restricted OPTION(MAXRECURSION 129);
 SELECT d.DocumentID,d.DocumentName,d.DocumentPath,vf.FolderID,vf.ParentID,vf.FolderName,
  p.Ancestors+vf.FolderName AS FolderPath
 FROM Mng.Document d INNER JOIN dbo.VFolder vf ON d.FolderID=vf.FolderID
 CROSS APPLY(SELECT App.CreateFolderPath(vf.FolderID) AS Ancestors) p
 WHERE d.Active=1 AND vf.Active=1 AND vf.IsForDisplay=1 AND p.Ancestors IS NOT NULL
 AND LEN(p.Ancestors)+LEN(vf.FolderName)<=1000
 AND (@FullAccess=1 OR NOT EXISTS(SELECT 1 FROM #Restricted r WHERE r.FolderID=vf.FolderID))
 ORDER BY d.DocumentName,d.DocumentID;
END;
GO
