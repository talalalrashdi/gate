-- Local development acceptance. Each test rolls back its temporary card/order rows.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
DECLARE @UserId int=(SELECT UserId FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN() AND Active=1);
IF @UserId IS NULL THROW 51000,'Register the current developer before testing.',1;
DECLARE @Apps Portal.AppIdInput;
INSERT @Apps SELECT TOP(1) g.AppId FROM SecurityDB.dbo.UserApplicationAccess g JOIN SecurityDB.dbo.Applications a ON a.AppId=g.AppId
WHERE g.UserId=@UserId AND g.Active=1 AND a.Active=1 ORDER BY g.AppId;
IF NOT EXISTS(SELECT 1 FROM @Apps) THROW 51000,'An authorized sample app is required.',1;
DECLARE @Mode int=1,@Id int,@Name nvarchar(200),@Expected int;
WHILE @Mode<=3
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @Name=N'Ownership rollback test '+CONVERT(nvarchar(36),NEWID());
        EXEC Portal.UserCards_save @UserId=@UserId,@CardName=@Name,@Apps=@Apps;
        SELECT @Id=UserCardId FROM Portal.UserCards WHERE UserId=@UserId AND CardName=@Name;
        IF @Mode=1 EXEC Portal.UserCards_delete @UserId=2147483647,@UserCardId=@Id;
        IF @Mode=2 EXEC Portal.UserCards_save @UserId=2147483647,@UserCardId=@Id,@CardName=@Name,@Apps=@Apps;
        IF @Mode=3
        BEGIN
            DECLARE @Order Portal.CardOrderInput;
            INSERT @Order SELECT ROW_NUMBER() OVER(ORDER BY DisplayOrder,CardId)-1,CardKey FROM [Master].Cards WHERE Active=1;
            INSERT @Order SELECT COUNT(*),N'custom-'+CONVERT(nvarchar(20),@Id) FROM [Master].Cards WHERE Active=1;
            EXEC Portal.UserCardOrder_set @UserId=2147483647,@Cards=@Order;
        END;
        THROW 51000,'An ownership bypass was accepted.',1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        SET @Expected=CASE WHEN @Mode=3 THEN 50004 ELSE 50008 END;
        IF ERROR_NUMBER()<>@Expected THROW;
        PRINT CONCAT('Ownership test ',@Mode,' passed; temporary rows rolled back.');
    END CATCH;
    SET @Mode+=1;
END;
GO
