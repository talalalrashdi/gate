param([string]$OutputPath = (Join-Path $PSScriptRoot '../Deployment/CompanyPortal-Setup.sql'))
$ErrorActionPreference = 'Stop'
$database = Join-Path $PSScriptRoot '../Backend/Database'
$parts = [Collections.Generic.List[string]]::new()
$parts.Add(@'
/* CompanyPortal fresh installation, generated from migrations 001-040.
   Open this entire UTF-8 file in SSMS and Execute (normal mode, no SQLCMD mode).
   Or: sqlcmd -S SQLSERVER -E -b -f 65001 -i CompanyPortal-Setup.sql
   FRESH INSTALL ONLY. Never run on an existing CompanyPortal database.
   TestSources=1 creates NEW sample SecurityDB and Pubs_Info_V4 databases.
   TestSources=0 leaves external databases alone; configure the four Security
   adapter procedures and dbo.VNews against the real sources AFTER this script.
   No current employee preferences, uploaded images or custom themes are exported.
*/
USE master;
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
CREATE TABLE #PortalDeployment (
 TestSources bit NOT NULL, TestNTName nvarchar(512) NOT NULL,
 ApiIdentity nvarchar(512) NOT NULL, PortalUrl nvarchar(2048) NOT NULL
);
-- EDIT these values. TestNTName is the employee using the browser, NOT the API service account.
INSERT #PortalDeployment VALUES (
 1,                         -- 1 = isolated sample sources; 0 = real external sources
 N'COMPANY\employee1',       -- exact DOMAIN\username: gets an explicit TEST admin grant
 N'',                       -- optional DOMAIN\svcCompanyPortal; empty = DBA grants later
 N'https://portal.company.local/'
);
IF DB_ID(N'CompanyPortal') IS NOT NULL
 OR EXISTS(SELECT 1 FROM #PortalDeployment WHERE TestSources=1
   AND (DB_ID(N'SecurityDB') IS NOT NULL OR DB_ID(N'Pubs_Info_V4') IS NOT NULL
        OR TestNTName=N'COMPANY\employee1' OR TestNTName=N''))
BEGIN
 RAISERROR('STOP: use a fresh CompanyPortal; sample mode also requires NEW external databases and an edited TestNTName. No setup ran. Reconnect before retrying.',16,1);
 SET NOEXEC ON;
END;
GO
'@)
# Keep the exact historical migration sequence; do not replay it on a live database.
foreach ($file in Get-ChildItem (Join-Path $database 'Scripts/*.sql') | Sort-Object Name) {
 $parts.Add("`n-- BEGIN $($file.Name)`n" + [IO.File]::ReadAllText($file.FullName) + "`nGO`n")
}
# Each dynamic batch runs in this connection, sharing #PortalDeployment.
foreach ($name in '001_CreateSampleSecurityDB.sql','002_CreateSampleApplications.sql','003_CreateSampleRoles.sql','006_SeedApplicationDirectory.sql') {
 $source = [IO.File]::ReadAllText((Join-Path $database "Development/$name"))
 $source = $source.Replace('ORIGINAL_LOGIN()', '(SELECT TestNTName FROM #PortalDeployment)')
 $source = $source.Replace("N'http://localhost:5080/#workspace'", "(SELECT PortalUrl+N'#workspace' FROM #PortalDeployment)")
 $context = 'master'
 foreach ($batch in [regex]::Split($source, '(?im)^\s*GO\s*\r?$')) {
  if ($batch.Trim()) {
   $use = [regex]::Match($batch, '(?im)^USE\s+\[?(\w+)\]?;')
   if ($use.Success) { $context = $use.Groups[1].Value }
   $escaped = ("USE [$context];`n" + $batch).Replace("'", "''")
   $parts.Add("IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'$escaped');`nGO`n")
  }
 }
}
$parts.Add(@'
USE master;
GO
IF (SELECT TestSources FROM #PortalDeployment)=1
 EXEC(N'CREATE DATABASE Pubs_Info_V4');
GO
IF (SELECT TestSources FROM #PortalDeployment)=1
 EXEC(N'USE Pubs_Info_V4;
 CREATE TABLE dbo.Public_info_News (
  PIN_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  PIN_Date datetime NOT NULL DEFAULT(GETDATE()), PIN_Subject nvarchar(1000) NOT NULL,
  PIN_PicturePath nvarchar(4000) NULL, PIN_Publish bit NOT NULL DEFAULT(1),
  PIN_IsImportant bit NOT NULL DEFAULT(0), PIN_Detailes nvarchar(4000) NULL,
  PIN_Active bit NOT NULL DEFAULT(1), PIN_Portal bit NOT NULL DEFAULT(1));
 CREATE TABLE dbo.Attachment (
  ATT_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  PIN_ID int NOT NULL REFERENCES dbo.Public_info_News(PIN_ID),
  ATT_File_Path nvarchar(4000) NOT NULL, ATT_FileType nvarchar(100) NOT NULL,
  ATT_Active bit NOT NULL DEFAULT(1), ATT_Note nvarchar(1000) NULL);
 CREATE TABLE dbo.Public_info_News_Prodc (
  PIP_ID int IDENTITY(1,1) NOT NULL PRIMARY KEY,
  News_ID int NOT NULL REFERENCES dbo.Public_info_News(PIN_ID), Active bit NOT NULL DEFAULT(1));
 INSERT dbo.Public_info_News(PIN_Subject) VALUES(N''خبر تجريبي لاختبار البوابة'');
 INSERT dbo.Public_info_News_Prodc(News_ID) VALUES(1);');
GO
USE CompanyPortal;
GO
-- Empty integration view in real-source mode, until the DBA installs the real view.
CREATE OR ALTER VIEW dbo.VNews AS
 SELECT CAST(NULL AS int) PIN_ID, CAST(NULL AS datetime) PIN_Date,
 CAST(NULL AS nvarchar(1000)) PIN_Subject, CAST(NULL AS nvarchar(4000)) PIN_PicturePath,
 CAST(NULL AS bit) PIN_Publish, CAST(NULL AS nvarchar(4000)) ATT_File_Path,
 CAST(NULL AS nvarchar(100)) ATT_FileType, CAST(NULL AS bit) PIN_IsImportant,
 CAST(NULL AS nvarchar(4000)) PIN_Detailes, CAST(NULL AS bit) PIN_Active,
 CAST(NULL AS bit) PIN_Portal, CAST(NULL AS bit) ATT_Active,
 CAST(NULL AS nvarchar(200)) Expr1, CAST(NULL AS int) ATT_ID,
 CAST(NULL AS nvarchar(1000)) ATT_Note, CAST(NULL AS int) PIP_ID WHERE 1=0;
GO
IF (SELECT TestSources FROM #PortalDeployment)=1
 EXEC(N'CREATE OR ALTER VIEW dbo.VNews AS
 SELECT n.*,a.ATT_File_Path,a.ATT_FileType,a.ATT_Active,
 CAST(NULL AS nvarchar(200)) Expr1,a.ATT_ID,a.ATT_Note,p.PIP_ID
 FROM Pubs_Info_V4.dbo.Public_info_News n
 LEFT JOIN Pubs_Info_V4.dbo.Attachment a ON a.PIN_ID=n.PIN_ID
 JOIN Pubs_Info_V4.dbo.Public_info_News_Prodc p ON p.News_ID=n.PIN_ID;');
GO
'@)
foreach ($name in 'ConfigureSecurityLookup.sample.sql','ConfigureAppAccess.sample.sql','ConfigureRoleLookup.sample.sql','ConfigureAdminAppCatalog.sample.sql') {
 foreach ($batch in [regex]::Split([IO.File]::ReadAllText((Join-Path $database "Integration/$name")), '(?im)^\s*GO\s*\r?$')) {
  if ($batch.Trim()) {
   $parts.Add("IF (SELECT TestSources FROM #PortalDeployment)=1 EXEC(N'$($batch.Replace("'", "''"))');`nGO`n")
  }
 }
}
$parts.Add(@'
-- Grant only the API service identity, never every employee.
USE master;
GO
DECLARE @account nvarchar(512)=(SELECT ApiIdentity FROM #PortalDeployment);
IF @account<>N''
BEGIN
 DECLARE @sql nvarchar(max);
 IF SUSER_ID(@account) IS NULL
 BEGIN
  SET @sql=N'CREATE LOGIN '+QUOTENAME(@account)+N' FROM WINDOWS';
  EXEC(@sql);
 END;
 SET @sql=N'USE CompanyPortal; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
 EXEC(@sql);
END;
GO
USE CompanyPortal;
GO
DECLARE @account nvarchar(512)=(SELECT ApiIdentity FROM #PortalDeployment), @sql nvarchar(max)=N'';
IF @account<>N''
BEGIN
 SELECT @sql+=N'GRANT EXECUTE ON OBJECT::'+QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N' TO '+QUOTENAME(@account)+N';'
 FROM sys.procedures WHERE SCHEMA_NAME(schema_id) IN(N'Security',N'Portal',N'Master',N'News',N'Mstr');
 SELECT @sql+=N'GRANT EXECUTE, REFERENCES ON TYPE::'+QUOTENAME(SCHEMA_NAME(schema_id))+N'.'+QUOTENAME(name)+N' TO '+QUOTENAME(@account)+N';'
 FROM sys.table_types;
 EXEC(@sql);
 IF (SELECT TestSources FROM #PortalDeployment)=1
 BEGIN
  SET @sql=N'USE SecurityDB; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
  SELECT @sql+=N'GRANT SELECT ON OBJECT::dbo.'+QUOTENAME(n)+N' TO '+QUOTENAME(@account)+N';'
  FROM (VALUES(N'Users'),(N'Applications'),(N'UserApplicationAccess'),(N'Roles'),(N'UserRoles')) t(n);
  EXEC(@sql);
  SET @sql=N'USE Pubs_Info_V4; CREATE USER '+QUOTENAME(@account)+N' FOR LOGIN '+QUOTENAME(@account)+N';';
  SELECT @sql+=N'GRANT SELECT ON OBJECT::dbo.'+QUOTENAME(n)+N' TO '+QUOTENAME(@account)+N';'
  FROM (VALUES(N'Public_info_News'),(N'Attachment'),(N'Public_info_News_Prodc')) t(n);
  EXEC(@sql);
 END;
END;
PRINT N'Fresh setup completed. Real-source mode requires Security adapters and dbo.VNews mapping. Empty ApiIdentity requires DBA runtime grants.';
SELECT ThemeId,ThemeName,LayoutKey,IsDefault FROM Master.Themes;
DROP TABLE #PortalDeployment;
GO
'@)
$target = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
[IO.File]::WriteAllText($target, ($parts -join "`r`n"), [Text.UTF8Encoding]::new($true))
Write-Output "Generated $target"
