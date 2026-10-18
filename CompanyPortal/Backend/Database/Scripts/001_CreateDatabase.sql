-- Run against the selected SQL Server using a database deployment account.
-- Uses that server's default file locations; contains no machine-specific paths.
USE [master];
GO

SET NOCOUNT ON;

IF DB_ID(N'CompanyPortal') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [CompanyPortal];');
    PRINT N'Created CompanyPortal database.';
END
ELSE
BEGIN
    PRINT N'CompanyPortal already exists; no changes made.';
END;
GO
