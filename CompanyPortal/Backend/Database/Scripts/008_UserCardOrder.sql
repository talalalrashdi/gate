USE [CompanyPortal];
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'Master.Cards', N'U') IS NULL
BEGIN
    CREATE TABLE [Master].Cards
    (
        CardId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cards PRIMARY KEY,
        CardKey nvarchar(100) NOT NULL CONSTRAINT UQ_Cards_CardKey UNIQUE,
        CardName nvarchar(200) NOT NULL,
        DisplayOrder int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_Cards_Active DEFAULT (1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_Cards_LastChangeAt DEFAULT (GETDATE()),
        CONSTRAINT CK_Cards_DisplayOrder CHECK (DisplayOrder >= 0)
    );
    INSERT [Master].Cards(CardKey, CardName, DisplayOrder) VALUES
(N'library', N'القرارات', 1),
(N'inbox', N'مراسلات', 2),
(N'email', N'البريد الإلكتروني', 3),
(N'requests', N'نظام الاستمارات', 4),
(N'services', N'مركز الخدمات', 5),
(N'electronic-services', N'الخدمات الإلكترونية', 6),
(N'meetings', N'الاجتماعات', 7),
(N'tasks', N'المهام', 8),
(N'employees', N'شؤون الموظفين', 9),
(N'attendance', N'الحضور والانصراف', 10),
(N'leave', N'الإجازات', 11),
(N'learning', N'التعلّم والتدريب', 12),
(N'projects', N'إدارة المشاريع', 13),
(N'assets', N'الأصول والعُهد', 14),
(N'purchases', N'المشتريات', 15),
(N'finance', N'الشؤون المالية', 16),
(N'contracts', N'العقود', 17),
(N'warehouse', N'المخازن', 18),
(N'reports', N'التقارير والمؤشرات', 19),
(N'archive', N'الأرشيف الإلكتروني', 20),
(N'ideas', N'الأفكار والمقترحات', 21),
(N'support', N'الدعم التقني', 22);
END;
IF OBJECT_ID(N'Portal.UserCardOrder', N'U') IS NULL
BEGIN
    CREATE TABLE Portal.UserCardOrder
    (
        UserCardOrderId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserCardOrder PRIMARY KEY,
        UserId int NOT NULL,
        CardId int NOT NULL CONSTRAINT FK_UserCardOrder_Cards REFERENCES [Master].Cards(CardId),
        SortOrder int NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_UserCardOrder_Active DEFAULT (1),
        LastChangeAt datetime NOT NULL CONSTRAINT DF_UserCardOrder_LastChangeAt DEFAULT (GETDATE()),
        CONSTRAINT UQ_UserCardOrder_UserCard UNIQUE (UserId, CardId),
        CONSTRAINT CK_UserCardOrder_SortOrder CHECK (SortOrder >= 0)
    );
END;
IF TYPE_ID(N'Portal.CardOrderInput') IS NULL
    EXEC(N'CREATE TYPE Portal.CardOrderInput AS TABLE
        (SortOrder int NOT NULL PRIMARY KEY, CardKey nvarchar(100) NOT NULL UNIQUE);');
COMMIT TRANSACTION;
GO
CREATE OR ALTER PROCEDURE Portal.UserCardOrder_get
    @UserId int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CardKey,
        CAST(CASE WHEN s.UserCardOrderId IS NULL THEN 0 ELSE 1 END AS bit) AS IsSaved,
        s.LastChangeAt
    FROM [Master].Cards c
    LEFT JOIN Portal.UserCardOrder s ON s.CardId = c.CardId AND s.UserId = @UserId AND s.Active = 1
    WHERE c.Active = 1
    ORDER BY CASE WHEN s.UserCardOrderId IS NULL THEN 1 ELSE 0 END, s.SortOrder, c.DisplayOrder, c.CardId;
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
