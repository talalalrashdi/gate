-- DEVELOPMENT ONLY: one sample organization status (green). Do not deploy internally;
-- the real status rows are maintained by the owning department.
USE [CompanyPortal];
GO
IF OBJECT_ID(N'Mng.CurrentStatus',N'U') IS NULL
 THROW 50036,'Apply Scripts/036_CurrentStatus.sql first.',1;
IF NOT EXISTS(SELECT 1 FROM Mng.CurrentStatus)
 INSERT Mng.CurrentStatus(ColorValue,LastUpdated,[No]) VALUES(1,'2026-10-01T08:00:00',1);
GO
