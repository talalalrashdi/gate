-- DEVELOPMENT ONLY. Preserve existing source numbers; never modify an unmarked internal Formsdb.
USE Formsdb;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 BEGIN SET NOEXEC ON; THROW 50040,'Marked development Formsdb required.',1; END;
GO
IF COL_LENGTH(N'dbo.FormInbox',N'FormNumber') IS NULL
 ALTER TABLE dbo.FormInbox ADD FormNumber nvarchar(100) NULL;
GO
UPDATE dbo.FormInbox SET FormNumber=CONVERT(nvarchar(4),YEAR(SentAt))+N'/'+CONVERT(nvarchar(20),FormId)
 WHERE FormNumber IS NULL;
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Portal.Forms_Inbox_Get @UserId int,@FormId bigint=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT FormId,FormNumber,Title,SenderName,Purpose,SentAt,IsOpened,CAST(1 AS bit) IsSample
 FROM Formsdb.dbo.FormInbox WHERE UserId=@UserId AND Active=1 AND (@FormId IS NULL OR FormId=@FormId)
 ORDER BY SentAt DESC,FormId DESC;
END;
GO
