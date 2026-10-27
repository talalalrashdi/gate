USE CompanyPortal;
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON;SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;SET ARITHABORT ON;SET NUMERIC_ROUNDABORT OFF;
GO
UPDATE Master.Cards SET CardName=N'مراسلات',LastChangeAt=GETDATE() WHERE CardKey=N'inbox' AND CardName=N'مرسالات';
GO
-- Contracts only: preserve configured real-system adapters on rerun.
IF OBJECT_ID(N'Portal.Correspondence_Inbox_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Correspondence_Inbox_Get @UserId int,@CorrespondenceId bigint=NULL AS
 BEGIN SET NOCOUNT ON;THROW 50030,''Correspondence source is not configured.'',1;END');
GO
IF OBJECT_ID(N'Portal.Correspondence_UnreadCount_Get',N'P') IS NULL
 EXEC(N'CREATE PROCEDURE Portal.Correspondence_UnreadCount_Get @UserId int AS
 BEGIN SET NOCOUNT ON;THROW 50030,''Correspondence source is not configured.'',1;END');
GO
