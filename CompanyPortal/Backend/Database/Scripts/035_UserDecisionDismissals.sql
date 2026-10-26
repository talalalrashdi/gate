USE CompanyPortal;
GO
IF OBJECT_ID(N'Portal.UserDecisionDismissals',N'U') IS NULL
 CREATE TABLE Portal.UserDecisionDismissals(
  UserDecisionDismissalID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserDecisionDismissals PRIMARY KEY,
  UserId int NOT NULL,DecisionId bigint NOT NULL,ChannelId int NOT NULL,
  DismissedAt datetime NOT NULL CONSTRAINT DF_UserDecisionDismissals_At DEFAULT(GETDATE()),
  Active bit NOT NULL CONSTRAINT DF_UserDecisionDismissals_Active DEFAULT(1),
  CONSTRAINT UQ_UserDecisionDismissals_User_Decision_Channel UNIQUE(UserId,DecisionId,ChannelId),
  CONSTRAINT CK_UserDecisionDismissals_IDs CHECK(UserId>0 AND DecisionId>0 AND ChannelId IN(1,2)));
GO
CREATE OR ALTER PROCEDURE Portal.UserDecisionDismissals_Get @UserId int,@ChannelId int AS
BEGIN SET NOCOUNT ON;SELECT DecisionId FROM Portal.UserDecisionDismissals WHERE UserId=@UserId AND ChannelId=@ChannelId AND Active=1;END;
GO
CREATE OR ALTER PROCEDURE Portal.UserDecisionDismissals_Dismiss @UserId int,@DecisionId bigint,@ChannelId int AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @UserId<=0 OR @DecisionId<=0 OR @ChannelId NOT IN(1,2) THROW 50012,'Invalid dismissal identity.',1;
 BEGIN TRANSACTION;
 DECLARE @Active bit;
 SELECT @Active=Active FROM Portal.UserDecisionDismissals WITH(UPDLOCK,HOLDLOCK)
 WHERE UserId=@UserId AND DecisionId=@DecisionId AND ChannelId=@ChannelId;
 IF @Active IS NULL INSERT Portal.UserDecisionDismissals(UserId,DecisionId,ChannelId) VALUES(@UserId,@DecisionId,@ChannelId);
 ELSE IF @Active=0 UPDATE Portal.UserDecisionDismissals SET Active=1,DismissedAt=GETDATE() WHERE UserId=@UserId AND DecisionId=@DecisionId AND ChannelId=@ChannelId;
 -- Repeated closes are no-ops, preserving the original dismissal time.
 COMMIT;
END;
GO
