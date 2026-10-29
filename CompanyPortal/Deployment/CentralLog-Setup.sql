/* Run separately from CompanyPortal-Setup.sql. SQL Server 2017 compatible.
   Existing CentralLog tables are preserved. Creates the two error tables only when absent.
   AuditUser, UnAllowedAccess and VisitHistory are not changed or used by error logging. */
USE [master];
GO
IF DB_ID(N'CentralLog') IS NULL EXEC(N'CREATE DATABASE [CentralLog]');
GO
USE [CentralLog];
GO
IF OBJECT_ID(N'dbo.ApplicationError', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ApplicationError (
        ApplicationErrorID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ApplicationError PRIMARY KEY,
        SystemID int NULL, NameSpace nvarchar(150) NULL, FileName nvarchar(150) NULL,
        ExceptionType nvarchar(150) NULL, MethodSignature nvarchar(400) NULL,
        StackTrace nvarchar(max) NULL, ErrorMessage nvarchar(500) NULL, ExtraDetails nvarchar(max) NULL,
        UserId int NULL, WorkStation nvarchar(100) NULL, NtUserName nvarchar(100) NULL,
        [Timestamp] datetime NULL CONSTRAINT DF_ApplicationError_Timestamp DEFAULT(GETDATE())
    );
END;
IF OBJECT_ID(N'dbo.DatabaseError', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DatabaseError (
        DatabaseErrorID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatabaseError PRIMARY KEY,
        DBName nvarchar(100) NULL, ErrorNumber int NULL, ErrorSeverity int NULL,
        ErrorState int NULL, ErrorProcedure nvarchar(128) NULL, ErrorLine int NULL,
        ErrorMessage nvarchar(4000) NULL, WorkStation nvarchar(100) NULL, NTUserName nvarchar(100) NULL,
        [Timestamp] datetime NULL CONSTRAINT DF_DatabaseError_Timestamp DEFAULT(GETDATE())
    );
END;
GO
CREATE OR ALTER PROCEDURE dbo.ApplicationError_Insert
    @SystemID int = NULL, @NameSpace nvarchar(150) = NULL, @FileName nvarchar(150) = NULL,
    @ExceptionType nvarchar(150) = NULL, @MethodSignature nvarchar(400) = NULL,
    @StackTrace nvarchar(max) = NULL, @ErrorMessage nvarchar(500) = NULL,
    @ExtraDetails nvarchar(max) = NULL, @UserId int = NULL,
    @WorkStation nvarchar(100) = NULL, @NtUserName nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.ApplicationError(SystemID, NameSpace, FileName, ExceptionType, MethodSignature,
        StackTrace, ErrorMessage, ExtraDetails, UserId, WorkStation, NtUserName, [Timestamp])
    VALUES(@SystemID, @NameSpace, @FileName, @ExceptionType, @MethodSignature,
        @StackTrace, @ErrorMessage, @ExtraDetails, @UserId, @WorkStation, @NtUserName, GETDATE());
    SELECT CONVERT(bigint, SCOPE_IDENTITY()) AS ApplicationErrorID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.DatabaseError_Insert
    @DBName nvarchar(100) = NULL, @ErrorNumber int = NULL, @ErrorSeverity int = NULL,
    @ErrorState int = NULL, @ErrorProcedure nvarchar(128) = NULL, @ErrorLine int = NULL,
    @ErrorMessage nvarchar(4000) = NULL, @WorkStation nvarchar(100) = NULL,
    @NTUserName nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.DatabaseError(DBName, ErrorNumber, ErrorSeverity, ErrorState,
        ErrorProcedure, ErrorLine, ErrorMessage, WorkStation, NTUserName, [Timestamp])
    VALUES(@DBName, @ErrorNumber, @ErrorSeverity, @ErrorState,
        @ErrorProcedure, @ErrorLine, @ErrorMessage, @WorkStation, @NTUserName, GETDATE());
    SELECT CONVERT(bigint, SCOPE_IDENTITY()) AS DatabaseErrorID;
END;
GO
/* Grant the actual application identity EXECUTE on these two procedures only.
   Example after creating the appropriate database user:
   GRANT EXECUTE ON dbo.ApplicationError_Insert TO [DOMAIN\CompanyPortalService];
   GRANT EXECUTE ON dbo.DatabaseError_Insert TO [DOMAIN\CompanyPortalService]; */
