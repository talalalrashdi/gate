USE CompanyPortal;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID(N'Mng.Events',N'U') IS NOT NULL AND OBJECT_ID(N'Mng.HeaderEvents',N'U') IS NOT NULL
  THROW 50051,'Both event tables exist. Resolve the duplicate before applying migration 057.',1;
 IF OBJECT_ID(N'Mng.Events',N'U') IS NULL EXEC sp_rename N'Mng.HeaderEvents',N'Events';
 IF COL_LENGTH(N'Mng.Events',N'IsDisplayed') IS NULL
 BEGIN
  ALTER TABLE Mng.Events ADD IsDisplayed bit NOT NULL CONSTRAINT DF_Events_IsDisplayed DEFAULT(1) WITH VALUES;
  -- All old rows are retained events. Old Active meant visibility, not deletion.
  EXEC(N'UPDATE Mng.Events SET IsDisplayed=Active,Active=1;');
 END;
 COMMIT;
END TRY
BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetActive AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,EventType,EventTarget,StartAt,EndAt FROM Mng.Events
 WHERE Active=1 AND IsDisplayed=1 AND StartAt<=GETUTCDATE() AND EndAt>GETUTCDATE()
 ORDER BY EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetAll AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,EventType,EventTarget,StartAt,EndAt,IsDisplayed,Active,LastChangeAt FROM Mng.Events WHERE Active=1 ORDER BY EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Save
 @EventType int=1,@EventId int=NULL,@Title nvarchar(150),@EventTarget nvarchar(2048),@StartAt datetime,@EndAt datetime,
 @IsDisplayed bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @EventTarget=LTRIM(RTRIM(@EventTarget));
 IF NULLIF(@Title,N'') IS NULL OR NULLIF(@EventTarget,N'') IS NULL OR @EventType IS NULL OR @EventType NOT IN (0,1,2) OR (@EventType=1 AND @EventTarget NOT LIKE N'https://%' AND @EventTarget NOT LIKE N'http://%')
 OR @StartAt IS NULL OR @EndAt IS NULL OR @EndAt<=@StartAt OR @IsDisplayed IS NULL
 THROW 50051,'Check the event title, HTTP(S) address, dates.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@New nvarchar(max);
 IF @EventId IS NOT NULL
 BEGIN
  SELECT @Old=(SELECT Title,EventType,EventTarget,StartAt,EndAt,IsDisplayed,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
  FROM Mng.Events WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId AND Active=1;
  IF @Old IS NULL THROW 50052,'Event not found.',1;
 END;
 IF @EventId IS NULL
 BEGIN
  INSERT Mng.Events(Title,EventType,EventTarget,StartAt,EndAt,IsDisplayed) VALUES(@Title,@EventType,@EventTarget,@StartAt,@EndAt,@IsDisplayed);
  SET @EventId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
  UPDATE Mng.Events SET Title=@Title,EventType=@EventType,EventTarget=@EventTarget,StartAt=@StartAt,EndAt=@EndAt,IsDisplayed=@IsDisplayed,LastChangeAt=GETDATE()
  WHERE EventId=@EventId AND Active=1 AND (Title COLLATE Latin1_General_100_BIN2<>@Title COLLATE Latin1_General_100_BIN2
   OR EventType<>@EventType OR EventTarget COLLATE Latin1_General_100_BIN2<>@EventTarget COLLATE Latin1_General_100_BIN2
   OR StartAt<>@StartAt OR EndAt<>@EndAt OR IsDisplayed<>@IsDisplayed);
 SELECT @New=(SELECT Title,EventType,EventTarget,StartAt,EndAt,IsDisplayed,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) FROM Mng.Events WHERE EventId=@EventId AND Active=1;
 DECLARE @ItemId nvarchar(100)=CONVERT(nvarchar(100),@EventId);
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@NewJson=@New;
 COMMIT;SELECT @EventId EventId;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Delete @EventId int,@ChangedBy nvarchar(512)=NULL AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@Title nvarchar(150),@ItemId nvarchar(100)=CONVERT(nvarchar(100),@EventId);
 SELECT @Title=Title,@Old=(SELECT Title,EventType,EventTarget,StartAt,EndAt,IsDisplayed,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
 FROM Mng.Events WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId AND Active=1;
 IF @Old IS NULL THROW 50052,'Event not found.',1;
 UPDATE Mng.Events SET Active=0,LastChangeAt=GETDATE() WHERE EventId=@EventId AND Active=1;
 DECLARE @New nvarchar(max);
 SELECT @New=(SELECT Title,EventType,EventTarget,StartAt,EndAt,IsDisplayed,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) FROM Mng.Events WHERE EventId=@EventId;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@NewJson=@New,@Action='delete';
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO

