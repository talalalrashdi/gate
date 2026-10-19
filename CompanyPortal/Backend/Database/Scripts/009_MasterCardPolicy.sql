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
-- Initialize this policy once; reruns must preserve later administrator choices.
IF COL_LENGTH(N'Master.Cards',N'IsFixed') IS NULL
BEGIN
    ALTER TABLE [Master].Cards ADD IsFixed bit NOT NULL CONSTRAINT DF_Cards_IsFixed DEFAULT (0);
    UPDATE [Master].Cards SET Active=0, LastChangeAt=GETDATE()
    WHERE CardKey NOT IN (N'library',N'inbox',N'email',N'requests',N'electronic-services') AND Active=1;
    UPDATE c SET CardName=v.CardName,DisplayOrder=v.DisplayOrder,Active=1,LastChangeAt=GETDATE()
    FROM [Master].Cards c JOIN (VALUES
      (N'library',N'القرارات',1),
      (N'inbox',N'مرسالات',2),
      (N'email',N'البريد الالكتروني',3),
      (N'requests',N'نظام الاستمارات',4),
      (N'electronic-services',N'الخدمات الالكترونية',5)
    ) v(CardKey,CardName,DisplayOrder) ON v.CardKey=c.CardKey;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'Master.Cards') AND name=N'UQ_Cards_FixedPosition')
    EXEC(N'CREATE UNIQUE INDEX UQ_Cards_FixedPosition ON [Master].Cards(DisplayOrder) WHERE Active=1 AND IsFixed=1;');
IF OBJECT_ID(N'Master.CK_Cards_FixedPosition',N'C') IS NULL
    EXEC(N'ALTER TABLE [Master].Cards ADD CONSTRAINT CK_Cards_FixedPosition CHECK(IsFixed=0 OR DisplayOrder>=1);');
COMMIT TRANSACTION;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WHERE Active=1);
    IF EXISTS (SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND DisplayOrder>@Count)
        THROW 50005, 'Configure fixed positions within the active card count.', 1;
    ;WITH Base AS
    (
        SELECT c.CardId,c.CardKey,c.CardName,c.IsFixed,c.DisplayOrder,s.SortOrder,
          CAST(CASE WHEN s.UserCardOrderId IS NULL THEN 0 ELSE 1 END AS bit) AS IsSaved,s.LastChangeAt
        FROM [Master].Cards c
        LEFT JOIN Portal.UserCardOrder s ON s.CardId=c.CardId AND s.UserId=@UserId AND s.Active=1
        WHERE c.Active=1
    ), Slots AS
    (
        SELECT ROW_NUMBER() OVER(ORDER BY CardId)-1 AS Position FROM Base
    ), FreeSlots AS
    (
        SELECT Position,ROW_NUMBER() OVER(ORDER BY Position) AS RowNumber FROM Slots p
        WHERE NOT EXISTS (SELECT 1 FROM Base b WHERE b.IsFixed=1 AND b.DisplayOrder=p.Position+1)
    ), Movable AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY IsSaved DESC,SortOrder,DisplayOrder,CardId) AS RowNumber
        FROM Base WHERE IsFixed=0
    ), Resolved AS
    (
        SELECT CardKey,CardName,IsFixed,DisplayOrder,IsSaved,LastChangeAt,DisplayOrder-1 AS Position FROM Base WHERE IsFixed=1
        UNION ALL
        SELECT m.CardKey,m.CardName,m.IsFixed,m.DisplayOrder,m.IsSaved,m.LastChangeAt,p.Position
        FROM Movable m JOIN FreeSlots p ON p.RowNumber=m.RowNumber
    )
    SELECT CardKey,CardName,IsFixed,DisplayOrder,IsSaved,LastChangeAt FROM Resolved ORDER BY Position;
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
       OR EXISTS (SELECT 1 FROM @Cards WHERE SortOrder < 0)
       OR (SELECT MIN(SortOrder) FROM @Cards) <> 0
       OR (SELECT MAX(SortOrder) FROM @Cards) <> (SELECT COUNT(*) - 1 FROM @Cards)
        THROW 50004, 'Supply unique card keys with consecutive positions.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Keep catalog validation stable until the complete order is committed.
        DECLARE @Available int = (SELECT COUNT(*) FROM [Master].Cards WITH (HOLDLOCK) WHERE Active = 1);
        IF @Available <> (SELECT COUNT(*) FROM @Cards)
           OR EXISTS (SELECT 1 FROM @Cards i LEFT JOIN [Master].Cards c ON c.CardKey = i.CardKey AND c.Active = 1 WHERE c.CardId IS NULL)
            THROW 50004, 'The available cards changed. Reload before saving.', 1;
        IF EXISTS (SELECT 1 FROM @Cards i JOIN [Master].Cards c ON c.CardKey=i.CardKey
                   WHERE c.Active=1 AND c.IsFixed=1 AND i.SortOrder<>c.DisplayOrder-1)
            THROW 50004, 'A fixed card cannot change position.', 1;
        -- Lock this user's indexed range, including an initially empty range.
        DECLARE @Existing int = (SELECT COUNT(*) FROM Portal.UserCardOrder WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId);
        UPDATE s SET SortOrder = i.SortOrder, Active = 1, LastChangeAt = GETDATE()
        FROM Portal.UserCardOrder s
        JOIN [Master].Cards c ON c.CardId = s.CardId
        JOIN @Cards i ON i.CardKey = c.CardKey
        WHERE s.UserId = @UserId AND (s.SortOrder <> i.SortOrder OR s.Active = 0);
        INSERT Portal.UserCardOrder(UserId,CardId,SortOrder)
        SELECT @UserId,c.CardId,i.SortOrder FROM @Cards i JOIN [Master].Cards c ON c.CardKey=i.CardKey
        WHERE NOT EXISTS (SELECT 1 FROM Portal.UserCardOrder s WHERE s.UserId=@UserId AND s.CardId=c.CardId);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_setPosition
    @CardId int,
    @IsFixed bit,
    @DisplayOrder int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Count int=(SELECT COUNT(*) FROM [Master].Cards WITH (UPDLOCK,HOLDLOCK) WHERE Active=1);
        IF @IsFixed IS NULL OR @DisplayOrder IS NULL OR @DisplayOrder<1 OR @DisplayOrder>@Count
           OR NOT EXISTS (SELECT 1 FROM [Master].Cards WHERE CardId=@CardId AND Active=1)
            THROW 50006, 'Select an active card and a position within the active card count.', 1;
        IF @IsFixed=1 AND EXISTS (SELECT 1 FROM [Master].Cards WHERE Active=1 AND IsFixed=1 AND DisplayOrder=@DisplayOrder AND CardId<>@CardId)
            THROW 50006, 'Another fixed card already occupies that position.', 1;
        UPDATE [Master].Cards SET IsFixed=@IsFixed,DisplayOrder=@DisplayOrder,LastChangeAt=GETDATE()
        WHERE CardId=@CardId AND (IsFixed<>@IsFixed OR DisplayOrder<>@DisplayOrder);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
