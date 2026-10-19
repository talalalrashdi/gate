USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_get
AS
BEGIN
 SET NOCOUNT ON;
 SELECT CardId,CardKey,CardName,DisplayOrder,IsFixed,LastChangeAt
 FROM [Master].Cards WHERE Active=1 ORDER BY DisplayOrder,CardId;
END;
GO
CREATE OR ALTER PROCEDURE [Master].Cards_save
 @CardId int,
 @CardName nvarchar(200),
 @IsFixed bit,
 @DisplayOrder int
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET ARITHABORT ON;
 SET NUMERIC_ROUNDABORT OFF;
 SET @CardName=LTRIM(RTRIM(@CardName));
 IF @CardName IS NULL OR LEN(@CardName)=0
  THROW 50006,'Supply a card name.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Reuse the existing locked policy validation, including fixed-slot conflicts.
  EXEC [Master].Cards_setPosition @CardId,@IsFixed,@DisplayOrder;
  UPDATE [Master].Cards SET CardName=@CardName,LastChangeAt=GETDATE()
  WHERE CardId=@CardId AND CardName COLLATE Latin1_General_100_BIN2<>@CardName COLLATE Latin1_General_100_BIN2;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
