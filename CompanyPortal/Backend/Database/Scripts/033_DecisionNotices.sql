USE CompanyPortal;
GO
IF OBJECT_ID(N'Portal.DecisionNoticeSettings',N'U') IS NULL
 CREATE TABLE Portal.DecisionNoticeSettings(
 SettingID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DecisionNoticeSettings PRIMARY KEY,
 ChannelID int NOT NULL CONSTRAINT UQ_DecisionNoticeSettings_Channel UNIQUE,
 DurationDays int NOT NULL,DecisionTypes nvarchar(4000) NOT NULL,
 LastChangeAt datetime NOT NULL CONSTRAINT DF_DecisionNoticeSettings_Changed DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_DecisionNoticeSettings_Active DEFAULT(1),
 CONSTRAINT CK_DecisionNoticeSettings_Channel CHECK(ChannelID IN(1,2)),
 CONSTRAINT CK_DecisionNoticeSettings_Days CHECK(DurationDays BETWEEN 1 AND 365),
 CONSTRAINT CK_DecisionNoticeSettings_Types CHECK(ISJSON(DecisionTypes)=1));
IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeSettings WHERE ChannelID=1) INSERT Portal.DecisionNoticeSettings(ChannelID,DurationDays,DecisionTypes) VALUES(1,7,N'["تنويه"]');
IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeSettings WHERE ChannelID=2) INSERT Portal.DecisionNoticeSettings(ChannelID,DurationDays,DecisionTypes) VALUES(2,7,N'["إعلان"]');
IF OBJECT_ID(N'Portal.DecisionNoticeWindows',N'U') IS NULL
 CREATE TABLE Portal.DecisionNoticeWindows(
 WindowID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DecisionNoticeWindows PRIMARY KEY,
 ChannelID int NOT NULL,DecisionId bigint NOT NULL,FromAt datetime NULL,ToAt datetime NULL,IsHidden bit NOT NULL DEFAULT(0),
 LastChangeAt datetime NOT NULL CONSTRAINT DF_DecisionNoticeWindows_Changed DEFAULT(GETDATE()),
 Active bit NOT NULL CONSTRAINT DF_DecisionNoticeWindows_Active DEFAULT(1),
 CONSTRAINT UQ_DecisionNoticeWindows_Channel_Decision UNIQUE(ChannelID,DecisionId),
 CONSTRAINT FK_DecisionNoticeWindows_Channel FOREIGN KEY(ChannelID) REFERENCES Portal.DecisionNoticeSettings(ChannelID),
 CONSTRAINT CK_DecisionNoticeWindows_Dates CHECK((FromAt IS NULL AND ToAt IS NULL) OR (FromAt IS NOT NULL AND ToAt>FromAt)),
 CONSTRAINT CK_DecisionNoticeWindows_Id CHECK(DecisionId>0));
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNotices_Get AS
BEGIN SET NOCOUNT ON;SELECT ChannelID,DurationDays,DecisionTypes,LastChangeAt,Active FROM Portal.DecisionNoticeSettings ORDER BY ChannelID;
 SELECT ChannelID,DecisionId,FromAt,ToAt,IsHidden FROM Portal.DecisionNoticeWindows WHERE Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNotices_Save @ChannelID int,@DurationDays int,@DecisionTypes nvarchar(4000),@Active bit AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DurationDays NOT BETWEEN 1 AND 365 OR ISJSON(@DecisionTypes)<>1 OR LEFT(@DecisionTypes,1)<>'[' THROW 50012,'Invalid notice settings.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@DecisionTypes))>16 OR EXISTS(SELECT 1 FROM OPENJSON(@DecisionTypes) WHERE type<>1 OR LEN(value) NOT BETWEEN 1 AND 200) THROW 50012,'Invalid decision types.',1;
 UPDATE Portal.DecisionNoticeSettings SET DurationDays=@DurationDays,DecisionTypes=@DecisionTypes,Active=@Active,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND (DurationDays<>@DurationDays OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes)) OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@DecisionTypes) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(DecisionTypes)) OR Active<>@Active);
END;
GO
CREATE OR ALTER PROCEDURE Portal.DecisionNoticeWindows_Save @ChannelID int,@DecisionId bigint,@FromAt datetime=NULL,@ToAt datetime=NULL,@IsHidden bit=0 AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @ChannelID NOT IN(1,2) OR @DecisionId<=0 OR (@FromAt IS NULL AND @ToAt IS NOT NULL) OR (@FromAt IS NOT NULL AND (@ToAt IS NULL OR @ToAt<=@FromAt)) THROW 50012,'Invalid notice window.',1;
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM Portal.DecisionNoticeWindows WITH(UPDLOCK,HOLDLOCK) WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId)
 BEGIN
  IF @FromAt IS NOT NULL OR @IsHidden=1 INSERT Portal.DecisionNoticeWindows(ChannelID,DecisionId,FromAt,ToAt,IsHidden) VALUES(@ChannelID,@DecisionId,@FromAt,@ToAt,@IsHidden);
 END
 ELSE UPDATE Portal.DecisionNoticeWindows SET FromAt=@FromAt,ToAt=@ToAt,IsHidden=@IsHidden,Active=1,LastChangeAt=GETDATE()
 WHERE ChannelID=@ChannelID AND DecisionId=@DecisionId AND (ISNULL(FromAt,'17530101')<>ISNULL(@FromAt,'17530101') OR ISNULL(ToAt,'17530101')<>ISNULL(@ToAt,'17530101') OR IsHidden<>@IsHidden OR Active<>1);
 COMMIT;
END;
GO
