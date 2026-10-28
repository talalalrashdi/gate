-- DEVELOPMENT ONLY: upgrade existing marked local samples; real sources map Purpose in their SP.
USE Formsdb;
GO
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1)
 BEGIN SET NOEXEC ON; THROW 50040,'Marked development Formsdb required.',1; END;
GO
IF COL_LENGTH(N'dbo.FormInbox',N'Purpose') IS NULL
BEGIN
 ALTER TABLE dbo.FormInbox ADD Purpose nvarchar(100) NOT NULL CONSTRAINT DF_FormInbox_Purpose DEFAULT(N'للعلم') WITH VALUES;
 EXEC(N'UPDATE dbo.FormInbox SET Purpose=N''للإجراء'' WHERE Title IN(N''طلب شراء جهاز جديد'',N''طلب اعتماد إجازة'',N''طلب صيانة جهاز'')');
END;
GO
USE CompanyPortal;
GO
CREATE OR ALTER PROCEDURE Portal.Forms_Inbox_Get @UserId int,@FormId bigint=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT FormId,Title,SenderName,Purpose,SentAt,IsOpened,CAST(1 AS bit) IsSample
 FROM Formsdb.dbo.FormInbox WHERE UserId=@UserId AND Active=1 AND (@FormId IS NULL OR FormId=@FormId)
 ORDER BY SentAt DESC,FormId DESC;
END;
GO
