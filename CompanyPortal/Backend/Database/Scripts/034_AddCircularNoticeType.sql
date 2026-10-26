USE CompanyPortal;
GO
-- Add the requested type once, preserving the administrator's other settings.
-- The migration marker prevents a later rerun from undoing an intentional admin removal.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=1 AND major_id=OBJECT_ID(N'Portal.DecisionNoticeSettings') AND name=N'CircularNoticeTypeAdded')
BEGIN
 UPDATE Portal.DecisionNoticeSettings SET DecisionTypes=JSON_MODIFY(DecisionTypes,'append $',N'تعميم'),LastChangeAt=GETDATE()
 WHERE ChannelID=1 AND NOT EXISTS(SELECT 1 FROM OPENJSON(DecisionTypes) WHERE value=N'تعميم');
 EXEC sys.sp_addextendedproperty @name=N'CircularNoticeTypeAdded',@value=1,@level0type=N'SCHEMA',@level0name=N'Portal',@level1type=N'TABLE',@level1name=N'DecisionNoticeSettings';
END;
COMMIT;
GO
