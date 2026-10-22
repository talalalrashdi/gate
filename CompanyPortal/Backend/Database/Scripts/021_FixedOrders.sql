USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'Portal.FixedOrders',N'U') IS NULL
 CREATE TABLE Portal.FixedOrders
 (
  FixedOrderID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FixedOrders PRIMARY KEY,
  [Timestamp] date NULL,
  Timestamp2 date NULL,
  ContentBefor nvarchar(500) NULL,
  ContentAfter nvarchar(1000) NULL,
  ContentText nvarchar(1000) NULL,
  TimestampType int NOT NULL
 );
GO
CREATE OR ALTER PROCEDURE Portal.FixedOrders_getAll AS
BEGIN
 SET NOCOUNT ON;
 SELECT FixedOrderID,[Timestamp],Timestamp2,ContentBefor,ContentAfter,ContentText,TimestampType
 FROM Portal.FixedOrders ORDER BY [Timestamp] DESC,FixedOrderID DESC;
END;
GO
