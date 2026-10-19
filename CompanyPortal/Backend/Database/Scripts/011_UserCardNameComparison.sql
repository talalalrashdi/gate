-- Preserve case-only display-name edits while retaining no-op timestamp behavior.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE Portal.UserCards_save
    @UserId int,
    @CardName nvarchar(200),
    @Apps Portal.AppIdInput READONLY,
    @UserCardId int=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CardName IS NULL OR LEN(LTRIM(RTRIM(@CardName)))=0
       OR (SELECT COUNT(*) FROM @Apps) NOT BETWEEN 1 AND 100
        THROW 50007,'Supply a name and at least one authorized application.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Count int=(SELECT COUNT(*) FROM Portal.UserCards WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND Active=1);
        IF @UserCardId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND UserId=@UserId AND Active=1)
            THROW 50008,'Card not found.',1;
        IF @UserCardId IS NULL AND @Count>=50 THROW 50009,'The custom card limit is 50.',1;
        DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
        INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
        IF EXISTS(SELECT 1 FROM @Apps i LEFT JOIN @Allowed a ON a.AppId=i.AppId WHERE a.AppId IS NULL)
            THROW 50007,'One or more applications are not authorized.',1;
        DECLARE @Changed bit=0;
        IF @UserCardId IS NULL
        BEGIN
            INSERT Portal.UserCards(UserId,CardName) VALUES(@UserId,LTRIM(RTRIM(@CardName)));
            SET @UserCardId=CONVERT(int,SCOPE_IDENTITY());
            DECLARE @Existing int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND Active=1);
            IF @Existing=0
                INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
                SELECT @UserId,CardKey,ROW_NUMBER() OVER(ORDER BY DisplayOrder,CardId)-1 FROM [Master].Cards WHERE Active=1;
            DECLARE @Position int=(SELECT ISNULL(MAX(SortOrder),-1)+1 FROM Portal.UserWorkspaceOrder WHERE UserId=@UserId AND Active=1);
            INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
            VALUES(@UserId,N'custom-'+CONVERT(nvarchar(20),@UserCardId),@Position);
        END;
        IF EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND CardName COLLATE Latin1_General_100_BIN2<>LTRIM(RTRIM(@CardName)) COLLATE Latin1_General_100_BIN2)
           OR EXISTS(SELECT AppId FROM @Apps EXCEPT SELECT AppId FROM Portal.UserCardApplications WHERE UserCardId=@UserCardId AND Active=1)
           OR EXISTS(SELECT AppId FROM Portal.UserCardApplications WHERE UserCardId=@UserCardId AND Active=1 EXCEPT SELECT AppId FROM @Apps)
            SET @Changed=1;
        UPDATE Portal.UserCardApplications SET Active=0,LastChangeAt=GETDATE()
        WHERE UserCardId=@UserCardId AND Active=1 AND AppId NOT IN(SELECT AppId FROM @Apps);
        UPDATE m SET Active=1,LastChangeAt=GETDATE() FROM Portal.UserCardApplications m JOIN @Apps i ON i.AppId=m.AppId
        WHERE m.UserCardId=@UserCardId AND m.Active=0;
        INSERT Portal.UserCardApplications(UserCardId,AppId)
        SELECT @UserCardId,i.AppId FROM @Apps i WHERE NOT EXISTS(SELECT 1 FROM Portal.UserCardApplications m WHERE m.UserCardId=@UserCardId AND m.AppId=i.AppId);
        IF @Changed=1 UPDATE Portal.UserCards SET CardName=LTRIM(RTRIM(@CardName)),LastChangeAt=GETDATE() WHERE UserCardId=@UserCardId;
        COMMIT TRANSACTION;
        SELECT @UserCardId AS UserCardId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
