-- Local-only, rollback-only policy test. No production grants are changed.
USE CompanyPortal;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @User int=2147480001;
 IF EXISTS(SELECT 1 FROM Portal.UserWorkspaceOrder WHERE UserId=@User)
 OR EXISTS(SELECT 1 FROM SecurityDB.dbo.Users WHERE UserId=@User)
  THROW 50020,'Synthetic test identity is occupied.',1;
 DECLARE @Count int=(SELECT COUNT(*) FROM Master.Cards WHERE Active=1);
 DECLARE @Visible int=(SELECT COUNT(*) FROM Master.Cards_visible(N'[]'));
 DECLARE @Tag nvarchar(40)=LOWER(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''));
 INSERT Master.Cards(CardKey,CardName,DisplayOrder,IsFixed,CardType,Audience)
 VALUES(N'master-test-role-'+@Tag,N'Rollback role card',@Count+1,1,N'applications',N'roles');
 DECLARE @Restricted int=CONVERT(int,SCOPE_IDENTITY());
 INSERT Master.CardRoles(CardId,RoleName) VALUES(@Restricted,N'CompanyPortal.Rollback.Test');
 INSERT Master.Cards(CardKey,CardName,DisplayOrder,IsFixed,CardType,Audience)
 VALUES(N'master-test-public-'+@Tag,N'Rollback public card',@Count+2,1,N'applications',N'everyone');
 DECLARE @Public int=CONVERT(int,SCOPE_IDENTITY());
 IF EXISTS(SELECT 1 FROM Master.Cards_visible(N'[]') WHERE CardId=@Restricted)
  THROW 50020,'Restricted card visible without role.',1;
 IF NOT EXISTS(SELECT 1 FROM Master.Cards_visible(N'["CompanyPortal.Rollback.Test"]') WHERE CardId=@Restricted)
  THROW 50020,'Matching role card missing.',1;
 IF EXISTS(SELECT 1 FROM Master.Cards_visible(N'["companyportal.rollback.test"]') WHERE CardId=@Restricted)
  THROW 50020,'Role matching lost case-sensitive boundary.',1;
 IF NOT EXISTS(SELECT 1 FROM Master.Cards_visible(N'[]') WHERE CardId=@Public AND DisplayOrder=@Visible+1)
 OR NOT EXISTS(SELECT 1 FROM Master.Cards_visible(N'["CompanyPortal.Rollback.Test"]') WHERE CardId=@Public AND DisplayOrder=@Visible+2)
  THROW 50020,'Fixed slot did not compact for employee audience.',1;
 DECLARE @Cards Portal.CardOrderInput;
 INSERT Portal.UserCards(UserId,CardName) VALUES(@User,N'Rollback personal card');
 DECLARE @CustomKey nvarchar(100)=N'custom-'+CONVERT(nvarchar(20),CONVERT(int,SCOPE_IDENTITY()));
 INSERT @Cards SELECT DisplayOrder-1,CardKey FROM Master.Cards_visible(N'[]');
 INSERT @Cards VALUES((SELECT COUNT(*) FROM @Cards),@CustomKey);
 EXEC Portal.UserCardOrder_set @User,@Cards;
 DECLARE @Key nvarchar(100)=(SELECT CardKey FROM Master.Cards WHERE CardId=@Public);
 DECLARE @Changed datetime=(SELECT LastChangeAt FROM Portal.UserWorkspaceOrder WHERE UserId=@User AND CardKey=@Key);
 UPDATE Master.Cards SET Active=0 WHERE CardId=@Public;
 DELETE @Cards;
 INSERT @Cards SELECT DisplayOrder-1,CardKey FROM Master.Cards_visible(N'[]');
 INSERT @Cards VALUES((SELECT COUNT(*) FROM @Cards),@CustomKey);
 EXEC Portal.UserCardOrder_set @User,@Cards;
 IF NOT EXISTS(SELECT 1 FROM Portal.UserWorkspaceOrder WHERE UserId=@User AND CardKey=@Key AND Active=1 AND LastChangeAt=@Changed)
  THROW 50020,'Hidden-card preference was erased or changed.',1;
 ROLLBACK;
 PRINT 'PASS: role allow/deny/case, per-audience fixed-slot compaction and hidden preference preservation (rolled back).';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
