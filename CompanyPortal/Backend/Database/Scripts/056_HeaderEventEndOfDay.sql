USE CompanyPortal;
GO
-- Align existing events with the new 23:59 (+04:00) end-date rule.
-- Preserve the selected local date, identity, target and availability; audit actual changes.
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF EXISTS(SELECT 1 FROM Mng.HeaderEvents
  WHERE DATEADD(minute,1199,CONVERT(datetime,CONVERT(date,DATEADD(hour,4,EndAt))))<=StartAt)
  THROW 50051,'An event starts after 23:59 on its end date. Correct its dates before applying migration 056.',1;
 DECLARE @Id int,@Title nvarchar(150),@Type int,@Target nvarchar(2048),@Start datetime,@End datetime,@Active bit;
 DECLARE @Actor nvarchar(512)=ORIGINAL_LOGIN();
 DECLARE events_end_cursor CURSOR LOCAL FAST_FORWARD FOR
  SELECT EventId,Title,EventType,EventTarget,StartAt,
   DATEADD(minute,1199,CONVERT(datetime,CONVERT(date,DATEADD(hour,4,EndAt)))),Active
  FROM Mng.HeaderEvents
  WHERE EndAt<>DATEADD(minute,1199,CONVERT(datetime,CONVERT(date,DATEADD(hour,4,EndAt))));
 OPEN events_end_cursor;
 FETCH NEXT FROM events_end_cursor INTO @Id,@Title,@Type,@Target,@Start,@End,@Active;
 WHILE @@FETCH_STATUS=0
 BEGIN
  EXEC Mng.HeaderEvents_Save @EventId=@Id,@Title=@Title,@EventType=@Type,@EventTarget=@Target,@StartAt=@Start,@EndAt=@End,@Active=@Active,@ChangedBy=@Actor;
  FETCH NEXT FROM events_end_cursor INTO @Id,@Title,@Type,@Target,@Start,@End,@Active;
 END;
 CLOSE events_end_cursor;DEALLOCATE events_end_cursor;
 COMMIT;
END TRY
BEGIN CATCH
 IF CURSOR_STATUS('local','events_end_cursor')>=0 CLOSE events_end_cursor;
 IF CURSOR_STATUS('local','events_end_cursor')>=-1 DEALLOCATE events_end_cursor;
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
