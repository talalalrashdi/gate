USE CompanyPortal;
GO
-- Preserve the explicitly agreed table shape and existing records.
CREATE OR ALTER PROCEDURE Portal.FixedOrders_Save
 @FixedOrderID bigint=NULL,@Timestamp date=NULL,@Timestamp2 date=NULL,
 @ContentBefor nvarchar(500)=NULL,@ContentAfter nvarchar(1000),@ContentText nvarchar(1000),@TimestampType int
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ContentAfter)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@ContentText)),N'') IS NULL
  OR (CHARINDEX(N'ds{0}de',@ContentText)>0 AND NULLIF(LTRIM(RTRIM(@ContentBefor)),N'') IS NULL)
  THROW 50012,'Provide title, wording and any referenced previous text.',1;
 BEGIN TRANSACTION;
 IF @FixedOrderID IS NULL
 BEGIN
  INSERT Portal.FixedOrders([Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType)
  VALUES(@Timestamp,@Timestamp2,@ContentBefor,@ContentAfter,@ContentText,@TimestampType);
  SET @FixedOrderID=CONVERT(bigint,SCOPE_IDENTITY());
 END
 ELSE
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM Portal.FixedOrders WITH(UPDLOCK,HOLDLOCK) WHERE FixedOrderID=@FixedOrderID)
   THROW 50011,'Fixed order not found.',1;
  UPDATE Portal.FixedOrders SET [Timestamp]=@Timestamp,Timestamp2=@Timestamp2,ContentBefor=@ContentBefor,
   ContentAfter=@ContentAfter,ContentText=@ContentText,TimestampType=@TimestampType
  WHERE FixedOrderID=@FixedOrderID AND (EXISTS(
   SELECT [Timestamp],Timestamp2,ContentBefor COLLATE Latin1_General_100_BIN2,ContentAfter COLLATE Latin1_General_100_BIN2,ContentText COLLATE Latin1_General_100_BIN2,TimestampType
   EXCEPT SELECT @Timestamp,@Timestamp2,@ContentBefor COLLATE Latin1_General_100_BIN2,@ContentAfter COLLATE Latin1_General_100_BIN2,@ContentText COLLATE Latin1_General_100_BIN2,@TimestampType)
   OR ISNULL(DATALENGTH(ContentBefor),-1)<>ISNULL(DATALENGTH(@ContentBefor),-1)
   OR ISNULL(DATALENGTH(ContentAfter),-1)<>ISNULL(DATALENGTH(@ContentAfter),-1)
   OR ISNULL(DATALENGTH(ContentText),-1)<>ISNULL(DATALENGTH(@ContentText),-1));
 END;
 COMMIT;
 SELECT @FixedOrderID;
END;
GO
