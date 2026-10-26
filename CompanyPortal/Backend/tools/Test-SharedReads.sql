-- Local integration checks. All test changes roll back, including notice settings.
USE CompanyPortal;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
 DECLARE @User int=2147483000,@Content nvarchar(200)=N'__shared_read_test__';
 IF EXISTS(SELECT 1 FROM Portal.UserReads WHERE UserId=@User AND ContentId=@Content) THROW 50012,'Test identity already exists.',1;
 EXEC Portal.UserReads_MarkRead @User,2,@Content;
 UPDATE Portal.UserReads SET ReadAt='20200101' WHERE UserId=@User AND ContentTypeID=2 AND ContentId=@Content;
 EXEC Portal.UserReads_MarkRead @User,2,@Content;
 EXEC Portal.UserReads_MarkRead @User,2,@Content;
 IF (SELECT COUNT(*) FROM Portal.UserReads WHERE UserId=@User AND ContentTypeID=2 AND ContentId=@Content)<>1 OR
 EXISTS(SELECT 1 FROM Portal.UserReads WHERE UserId=@User AND ContentTypeID=2 AND ContentId=@Content AND ReadAt<>'20200101') THROW 50012,'Duplicate read/no-op failed.',1;
 EXEC Portal.UserReads_MarkRead 2147482999,2,@Content;
 EXEC Portal.UserReads_MarkRead @User,1,@Content;
 IF (SELECT COUNT(*) FROM Portal.UserReads WHERE ContentId=@Content)<>3 THROW 50012,'User/type isolation failed.',1;
 DECLARE @Changed datetime;
 EXEC Portal.DecisionNotices_Save 1,4,N'["تنويه","إعلان"]',1;
 SELECT @Changed=LastChangeAt FROM Portal.DecisionNoticeSettings WHERE ChannelID=1;
 EXEC Portal.DecisionNotices_Save 1,4,N'["إعلان","تنويه"]',1;
 IF EXISTS(SELECT 1 FROM Portal.DecisionNoticeSettings WHERE ChannelID=1 AND LastChangeAt<>@Changed) THROW 50012,'Equivalent type selection changed timestamp.',1;
 EXEC Portal.DecisionNoticeWindows_Save 1,9223372036854775806,'20261026 09:00','20261030 09:00',0;
 SELECT @Changed=LastChangeAt FROM Portal.DecisionNoticeWindows WHERE ChannelID=1 AND DecisionId=9223372036854775806;
 EXEC Portal.DecisionNoticeWindows_Save 1,9223372036854775806,'20261026 09:00','20261030 09:00',0;
 IF EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WHERE ChannelID=1 AND DecisionId=9223372036854775806 AND LastChangeAt<>@Changed) THROW 50012,'Window no-op failed.',1;
 EXEC Portal.DecisionNoticeWindows_Save 1,9223372036854775806,NULL,NULL,1;
 IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WHERE ChannelID=1 AND DecisionId=9223372036854775806 AND IsHidden=1 AND FromAt IS NULL AND ToAt IS NULL) THROW 50012,'Window hide failed.',1;
 EXEC Portal.DecisionNoticeWindows_Save 1,9223372036854775806,NULL,NULL,0;
 IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WHERE ChannelID=1 AND DecisionId=9223372036854775806 AND IsHidden=0 AND FromAt IS NULL AND ToAt IS NULL) THROW 50012,'Window reset failed.',1;
 ROLLBACK;
 PRINT 'Shared read isolation/no-op and notice settings/window checks passed. All test changes rolled back.';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
