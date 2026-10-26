-- Organization status (حالة المؤسسة) shown in the portal header.
-- ColorValue: 1 green, 2 yellow, 3 orange, 4 red. The current status is the most recently updated row.
USE [CompanyPortal];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'Mng') IS NULL EXEC(N'CREATE SCHEMA Mng');
GO
IF OBJECT_ID(N'Mng.CurrentStatus',N'U') IS NULL
 CREATE TABLE Mng.CurrentStatus
 (
  Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_CurrentStatus PRIMARY KEY,
  ColorValue tinyint NOT NULL CONSTRAINT CK_CurrentStatus_ColorValue CHECK (ColorValue BETWEEN 1 AND 4),
  LastUpdated datetime NOT NULL CONSTRAINT DF_CurrentStatus_LastUpdated DEFAULT (GETDATE()),
  [No] int NULL
 );
GO
CREATE OR ALTER PROCEDURE Mng.CurrentStatus_get AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP (1) Id,ColorValue,LastUpdated,[No]
 FROM Mng.CurrentStatus
 ORDER BY LastUpdated DESC,Id DESC;
END;
GO
