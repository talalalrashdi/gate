-- Run once on the OFFLINE imported databases. Does not recreate tables or data.
USE master;
GO
IF CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) < 14
BEGIN
 RAISERROR('This package requires SQL Server 2017 or later. Stop and check the server version.',16,1);
 SET NOEXEC ON;
END;
GO
ALTER DATABASE [CompanyPortal] SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE [SecurityDB] SET COMPATIBILITY_LEVEL = 140;
ALTER DATABASE [Pubs_Info_V4] SET COMPATIBILITY_LEVEL = 140;
SELECT name,compatibility_level FROM sys.databases
WHERE name IN(N'CompanyPortal',N'SecurityDB',N'Pubs_Info_V4');
GO
