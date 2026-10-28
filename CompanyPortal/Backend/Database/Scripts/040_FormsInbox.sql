USE CompanyPortal;
GO
-- Integration contracts only. Configure these SELECTs against the real Formsdb.
-- Rerunning setup must never overwrite an installed source adapter.
IF OBJECT_ID(N'Portal.Forms_Inbox_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Forms_Inbox_Get @UserId int,@FormId bigint=NULL AS
 BEGIN SET NOCOUNT ON;
 SELECT CAST(NULL AS bigint) FormId,CAST(NULL AS nvarchar(1000)) Title,
 CAST(NULL AS nvarchar(500)) SenderName,CAST(NULL AS nvarchar(100)) Purpose,CAST(NULL AS datetime) SentAt,
 CAST(NULL AS bit) IsOpened,CAST(0 AS bit) IsSample WHERE 1=0; END');
GO
IF OBJECT_ID(N'Portal.Forms_UnreadCount_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Forms_UnreadCount_Get @UserId int AS
 BEGIN SET NOCOUNT ON;SELECT CAST(0 AS int) UnreadCount; END');
GO
