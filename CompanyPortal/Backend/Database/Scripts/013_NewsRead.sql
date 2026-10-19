USE [CompanyPortal];
GO
IF SCHEMA_ID(N'News') IS NULL EXEC(N'CREATE SCHEMA News');
GO
-- dbo.VNews is an integration prerequisite, owned by the existing news system.
-- This script never creates/replaces that view or writes to Pubs_Info_V4.
CREATE OR ALTER PROCEDURE News.Items_get
 @Page int=1,
 @PageSize int=8,
 @NewsId bigint=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @Page<1 OR @Page>1000000 OR @PageSize<1 OR @PageSize>50
  THROW 50011,'Invalid news page.',1;
 -- Filter news independently of attachment activity: a missing attachment must not
 -- remove an otherwise published item from this left-joined source.
 ;WITH Source AS (
  SELECT TRY_CONVERT(bigint,PIN_ID) AS NewsId,
   TRY_CONVERT(datetime,PIN_Date) AS PublishedAt,
   CONVERT(nvarchar(4000),PIN_Subject) AS Subject,
   NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(4000),PIN_PicturePath))),N'') AS PicturePath,
   COALESCE(TRY_CONVERT(int,PIN_IsImportant),0) AS IsImportant,
   CASE WHEN TRY_CONVERT(bit,ATT_Active)=1
     AND LOWER(RIGHT(RTRIM(CONVERT(nvarchar(4000),ATT_File_Path)),4))=N'.pdf'
    THEN NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(4000),ATT_File_Path))),N'') END AS PdfPath
  FROM dbo.VNews
  WHERE TRY_CONVERT(bit,PIN_Publish)=1 AND TRY_CONVERT(bit,PIN_Active)=1 AND TRY_CONVERT(bit,PIN_Portal)=1
   AND (@NewsId IS NULL OR TRY_CONVERT(bigint,PIN_ID)=@NewsId)
 )
 SELECT NewsId,MAX(PublishedAt) AS PublishedAt,MAX(Subject) AS Subject,
  CAST(MAX(CASE WHEN IsImportant<>0 THEN 1 ELSE 0 END) AS bit) AS IsImportant,
  CASE WHEN COUNT(DISTINCT PicturePath)=1 THEN MAX(PicturePath) END AS PicturePath,
  CASE WHEN COUNT(DISTINCT PdfPath)=1 THEN MAX(PdfPath) END AS PdfPath,
  CAST(CASE WHEN COUNT(DISTINCT PdfPath)>1 THEN 1 ELSE 0 END AS bit) AS AttachmentConflict
 INTO #Items FROM Source WHERE NewsId>0 GROUP BY NewsId;
 SELECT NewsId,PublishedAt,Subject,IsImportant,PicturePath,PdfPath,AttachmentConflict FROM #Items
 ORDER BY PublishedAt DESC,NewsId DESC
 OFFSET (CONVERT(bigint,@Page)-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
 SELECT COUNT(*) AS TotalCount FROM #Items;
END;
GO
