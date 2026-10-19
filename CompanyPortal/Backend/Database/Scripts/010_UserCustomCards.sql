USE [CompanyPortal];
GO
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Portal.UserCards',N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserCards
    (
        UserCardId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserCards PRIMARY KEY,
        UserId int NOT NULL,
        CardName nvarchar(200) NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserCards_Active DEFAULT(1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserCards_LastChangeAt DEFAULT(GETDATE()),
        CONSTRAINT CK_UserCards_Name CHECK(LEN(LTRIM(RTRIM(CardName)))>0)
    );
    CREATE INDEX IX_UserCards_Owner ON Portal.UserCards(UserId,Active,UserCardId);
END;
IF OBJECT_ID(N'Portal.UserCardApplications',N'U') IS NULL
    CREATE TABLE Portal.UserCardApplications
    (
        UserCardApplicationId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserCardApplications PRIMARY KEY,
        UserCardId int NOT NULL CONSTRAINT FK_UserCardApplications_UserCards REFERENCES Portal.UserCards(UserCardId),
        AppId int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserCardApplications_Active DEFAULT(1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserCardApplications_LastChangeAt DEFAULT(GETDATE()),
        CONSTRAINT UQ_UserCardApplications_CardApp UNIQUE(UserCardId,AppId)
    );
IF OBJECT_ID(N'Portal.UserWorkspaceOrder',N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserWorkspaceOrder
    (
        UserWorkspaceOrderId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserWorkspaceOrder PRIMARY KEY,
        UserId int NOT NULL,
        CardKey nvarchar(100) NOT NULL,
        SortOrder int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserWorkspaceOrder_Active DEFAULT(1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserWorkspaceOrder_LastChangeAt DEFAULT(GETDATE()),
        CONSTRAINT UQ_UserWorkspaceOrder_UserKey UNIQUE(UserId,CardKey),
        CONSTRAINT CK_UserWorkspaceOrder_SortOrder CHECK(SortOrder>=0)
    );
    -- Preserve existing master ordering and timestamps once; retain historical rows/table.
    INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder,Active,LastChangeAt)
    SELECT s.UserId,c.CardKey,s.SortOrder,s.Active,s.LastChangeAt
    FROM Portal.UserCardOrder s JOIN [Master].Cards c ON c.CardId=s.CardId WHERE c.Active=1;
END;
IF TYPE_ID(N'Portal.AppIdInput') IS NULL
    EXEC(N'CREATE TYPE Portal.AppIdInput AS TABLE(AppId int NOT NULL PRIMARY KEY);');
COMMIT TRANSACTION;
GO
CREATE OR ALTER PROCEDURE Portal.UserCards_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Allowed TABLE(AppId int PRIMARY KEY,AppName nvarchar(200),LaunchUrl nvarchar(2048));
    INSERT @Allowed EXEC Security.Apps_getForUser @UserId=@UserId;
    SELECT UserCardId,CardName,LastChangeAt FROM Portal.UserCards
    WHERE UserId=@UserId AND Active=1 ORDER BY UserCardId;
    SELECT c.UserCardId,a.AppId,a.AppName FROM Portal.UserCards c
    JOIN Portal.UserCardApplications m ON m.UserCardId=c.UserCardId AND m.Active=1
    JOIN @Allowed a ON a.AppId=m.AppId
    WHERE c.UserId=@UserId AND c.Active=1 ORDER BY c.UserCardId,a.AppId;
END;
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
        IF EXISTS(SELECT 1 FROM Portal.UserCards WHERE UserCardId=@UserCardId AND CardName<>LTRIM(RTRIM(@CardName)))
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
CREATE OR ALTER PROCEDURE Portal.UserCards_delete
    @UserId int,
    @UserCardId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM Portal.UserCards WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId AND UserCardId=@UserCardId AND Active=1)
            THROW 50008,'Card not found.',1;
        UPDATE Portal.UserCards SET Active=0,LastChangeAt=GETDATE() WHERE UserId=@UserId AND UserCardId=@UserCardId;
        UPDATE Portal.UserCardApplications SET Active=0,LastChangeAt=GETDATE() WHERE UserCardId=@UserCardId AND Active=1;
        UPDATE Portal.UserWorkspaceOrder SET Active=0,LastChangeAt=GETDATE()
        WHERE UserId=@UserId AND CardKey=N'custom-'+CONVERT(nvarchar(20),@UserCardId) AND Active=1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MasterCount int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1);
    IF EXISTS(SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND DisplayOrder>@MasterCount)
        THROW 50005,'Configure fixed positions within the master card count.',1;
    ;WITH Definitions AS
    (
        SELECT c.CardKey,c.CardName,c.IsFixed,c.DisplayOrder,CAST(0 AS bit) AS IsCustom,CAST(NULL AS int) AS UserCardId
        FROM [Master].Cards c WHERE c.Active=1
        UNION ALL
        SELECT N'custom-'+CONVERT(nvarchar(20),c.UserCardId),c.CardName,CAST(0 AS bit),
          CONVERT(int,@MasterCount+ROW_NUMBER() OVER(ORDER BY c.UserCardId)),CAST(1 AS bit),c.UserCardId
        FROM Portal.UserCards c WHERE c.UserId=@UserId AND c.Active=1
    ), Base AS
    (
        SELECT d.*,s.SortOrder,CAST(CASE WHEN s.UserWorkspaceOrderId IS NULL THEN 0 ELSE 1 END AS bit) AS IsSaved,s.LastChangeAt
        FROM Definitions d LEFT JOIN Portal.UserWorkspaceOrder s ON s.CardKey=d.CardKey AND s.UserId=@UserId AND s.Active=1
    ), Slots AS
    (
        SELECT ROW_NUMBER() OVER(ORDER BY CardKey)-1 AS Position FROM Base
    ), FreeSlots AS
    (
        SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) AS RowNumber FROM Slots p
        WHERE NOT EXISTS(SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=p.Position+1)
    ), Movable AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY IsSaved DESC,SortOrder,DisplayOrder,CardKey) AS RowNumber FROM Base WHERE IsFixed=0
    ), Resolved AS
    (
        SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt,DisplayOrder-1 AS Position FROM Base WHERE IsFixed=1
        UNION ALL
        SELECT m.CardKey,m.CardName,m.IsFixed,m.DisplayOrder,m.IsCustom,m.UserCardId,m.IsSaved,m.LastChangeAt,p.Position
        FROM Movable m JOIN FreeSlots p ON p.RowNumber=m.RowNumber
    )
    SELECT CardKey,CardName,IsFixed,DisplayOrder,IsCustom,UserCardId,IsSaved,LastChangeAt FROM Resolved ORDER BY Position;
END;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_set
    @UserId int,
    @Cards Portal.CardOrderInput READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF (SELECT COUNT(*) FROM @Cards) NOT BETWEEN 1 AND 200
       OR EXISTS(SELECT 1 FROM @Cards WHERE SortOrder<0)
       OR (SELECT MIN(SortOrder) FROM @Cards)<>0
       OR (SELECT MAX(SortOrder) FROM @Cards)<>(SELECT COUNT(*)-1 FROM @Cards)
        THROW 50004,'Supply unique card keys with consecutive positions.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Valid TABLE(CardKey nvarchar(100) PRIMARY KEY,IsFixed bit,DisplayOrder int);
        INSERT @Valid SELECT CardKey,IsFixed,DisplayOrder FROM [Master].Cards WITH(HOLDLOCK) WHERE Active=1;
        INSERT @Valid SELECT N'custom-'+CONVERT(nvarchar(20),UserCardId),0,0
        FROM Portal.UserCards WITH(HOLDLOCK) WHERE UserId=@UserId AND Active=1;
        IF (SELECT COUNT(*) FROM @Valid)<>(SELECT COUNT(*) FROM @Cards)
           OR EXISTS(SELECT 1 FROM @Cards i LEFT JOIN @Valid v ON v.CardKey=i.CardKey WHERE v.CardKey IS NULL)
            THROW 50004,'Supply only the current master cards and your own active custom cards.',1;
        IF EXISTS(SELECT 1 FROM @Cards i JOIN @Valid v ON v.CardKey=i.CardKey WHERE v.IsFixed=1 AND i.SortOrder<>v.DisplayOrder-1)
            THROW 50004,'A fixed card cannot change position.',1;
        DECLARE @Existing int=(SELECT COUNT(*) FROM Portal.UserWorkspaceOrder WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId);
        UPDATE s SET SortOrder=i.SortOrder,Active=1,LastChangeAt=GETDATE()
        FROM Portal.UserWorkspaceOrder s JOIN @Cards i ON i.CardKey=s.CardKey
        WHERE s.UserId=@UserId AND (s.SortOrder<>i.SortOrder OR s.Active=0);
        INSERT Portal.UserWorkspaceOrder(UserId,CardKey,SortOrder)
        SELECT @UserId,i.CardKey,i.SortOrder FROM @Cards i
        WHERE NOT EXISTS(SELECT 1 FROM Portal.UserWorkspaceOrder s WHERE s.UserId=@UserId AND s.CardKey=i.CardKey);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
