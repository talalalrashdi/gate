-- DEVELOPMENT ONLY. Real installations should return their own DecisionNumber from the legal adapter.
USE CompanyPortal;
GO
IF NOT EXISTS(SELECT 1 FROM LegelAffairs.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
BEGIN
 SET NOEXEC ON;
 THROW 50040,'Refusing to modify an unmarked legal database.',1;
END;
GO
USE LegelAffairs;
GO
IF COL_LENGTH(N'dbo.Decisions',N'DecisionNumber') IS NULL
 ALTER TABLE dbo.Decisions ADD DecisionNumber nvarchar(100) NULL;
GO
-- Number samples once; never replace a manually configured decision number.
UPDATE dbo.Decisions SET DecisionNumber=CONVERT(nvarchar(4),YEAR(PublishedAt))+N'/'+CONVERT(nvarchar(30),DecisionId+65)
WHERE DecisionNumber IS NULL AND DecisionId BETWEEN 1 AND 9;
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Legal.Decisions_getForUser @UserId int,@DecisionId bigint=NULL AS
BEGIN
 SET NOCOUNT ON;
 SELECT d.DecisionId,d.DecisionType,d.Title,d.PublishedAt,d.PdfFileName,d.DecisionNumber
 FROM LegelAffairs.dbo.Decisions d
 WHERE d.Active=1 AND d.PublishedAt<=GETDATE() AND (@DecisionId IS NULL OR d.DecisionId=@DecisionId)
 AND (d.IsPublic=1 OR EXISTS(SELECT 1 FROM LegelAffairs.dbo.DecisionUsers g
 WHERE g.DecisionId=d.DecisionId AND g.UserId=@UserId AND g.Active=1))
 ORDER BY d.PublishedAt DESC,d.DecisionId DESC;
END;
GO
