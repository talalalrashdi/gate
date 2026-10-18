-- DEVELOPMENT ONLY. Never run this against the real internal security database.
USE [master];
GO
IF DB_ID(N'SecurityDB') IS NULL
    EXEC(N'CREATE DATABASE [SecurityDB];');
GO
USE [SecurityDB];
GO
IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users
    (
        UserId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        NTName nvarchar(512) NOT NULL CONSTRAINT UQ_Users_NTName UNIQUE,
        Active bit NOT NULL CONSTRAINT DF_Users_Active DEFAULT (1),
        CreatedAt datetime NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (GETDATE())
    );
END;
GO
-- This script must be run with the same development Windows account used in the browser.
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE NTName = ORIGINAL_LOGIN())
    INSERT dbo.Users (NTName) VALUES (ORIGINAL_LOGIN());
GO
