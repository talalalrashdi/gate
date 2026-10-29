USE CompanyPortal;
GO
IF COL_LENGTH(N'Mng.HeaderEvents',N'EventTarget') IS NULL
 EXEC sp_rename N'Mng.HeaderEvents.AppUrl',N'EventTarget',N'COLUMN';
IF COL_LENGTH(N'Mng.HeaderEvents',N'EventType') IS NULL
 ALTER TABLE Mng.HeaderEvents ADD EventType int NOT NULL CONSTRAINT DF_HeaderEvents_Type DEFAULT(1) CONSTRAINT CK_HeaderEvents_Type CHECK(EventType IN(0,1,2));
GO
USE CompanyPortal;
GO
-- Event links are always appended after the fixed secondary navigation. No configurable order.
-- Event windows are UTC; LastChangeAt follows the portal's existing SQL GETDATE convention.
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetActive AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,EventType,EventTarget,StartAt,EndAt FROM Mng.HeaderEvents
 WHERE Active=1 AND StartAt<=GETUTCDATE() AND EndAt>GETUTCDATE()
 ORDER BY EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_GetAll AS
BEGIN SET NOCOUNT ON;
 SELECT EventId,Title,EventType,EventTarget,StartAt,EndAt,Active,LastChangeAt FROM Mng.HeaderEvents ORDER BY EventId;
END;
GO
CREATE OR ALTER PROCEDURE Mng.HeaderEvents_Save
 @EventType int=1,@EventId int=NULL,@Title nvarchar(150),@EventTarget nvarchar(2048),@StartAt datetime,@EndAt datetime,
 @Active bit,@ChangedBy nvarchar(512)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @Title=LTRIM(RTRIM(@Title));SET @EventTarget=LTRIM(RTRIM(@EventTarget));
 IF NULLIF(@Title,N'') IS NULL OR NULLIF(@EventTarget,N'') IS NULL OR @EventType IS NULL OR @EventType NOT IN (0,1,2) OR (@EventType=1 AND @EventTarget NOT LIKE N'https://%' AND @EventTarget NOT LIKE N'http://%')
 OR @StartAt IS NULL OR @EndAt IS NULL OR @EndAt<=@StartAt OR @Active IS NULL
 THROW 50051,'Check the event title, HTTP(S) address, dates.',1;
 BEGIN TRY
 BEGIN TRAN;
 DECLARE @Old nvarchar(max),@New nvarchar(max);
 IF @EventId IS NOT NULL
 BEGIN
  SELECT @Old=(SELECT Title,EventType,EventTarget,StartAt,EndAt,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
  FROM Mng.HeaderEvents WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
  IF @Old IS NULL THROW 50052,'Event not found.',1;
 END;
 IF @EventId IS NULL
 BEGIN
  INSERT Mng.HeaderEvents(Title,EventType,EventTarget,StartAt,EndAt,Active) VALUES(@Title,@EventType,@EventTarget,@StartAt,@EndAt,@Active);
  SET @EventId=CONVERT(int,SCOPE_IDENTITY());
 END
 ELSE
  UPDATE Mng.HeaderEvents SET Title=@Title,EventType=@EventType,EventTarget=@EventTarget,StartAt=@StartAt,EndAt=@EndAt,Active=@Active,LastChangeAt=GETDATE()
  WHERE EventId=@EventId AND (Title COLLATE Latin1_General_100_BIN2<>@Title COLLATE Latin1_General_100_BIN2
   OR EventType<>@EventType OR EventTarget COLLATE Latin1_General_100_BIN2<>@EventTarget COLLATE Latin1_General_100_BIN2
   OR StartAt<>@StartAt OR EndAt<>@EndAt OR Active<>@Active);
 SELECT @New=(SELECT Title,EventType,EventTarget,StartAt,EndAt,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) FROM Mng.HeaderEvents WHERE EventId=@EventId;
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
 SELECT @Title=Title,@Old=(SELECT Title,EventType,EventTarget,StartAt,EndAt,Active FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
 FROM Mng.HeaderEvents WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
 IF @Old IS NULL THROW 50052,'Event not found.',1;
 DELETE Mng.HeaderEvents WHERE EventId=@EventId;
 EXEC Portal.AdminChanges_Add @ChangedBy=@ChangedBy,@Section='events',@ItemType='event',@ItemId=@ItemId,@ItemTitle=@Title,@OldJson=@Old,@Action='delete';
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO

