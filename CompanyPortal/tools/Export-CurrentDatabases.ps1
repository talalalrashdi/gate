param(
 [string]$Server = 'localhost',
 [string]$OutputPath = (Join-Path $PSScriptRoot '../Deployment/CompanyPortal-CurrentData.sql'),
 [string]$SmoDirectory = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\Extensions\Microsoft\SQLCommon'
)
$ErrorActionPreference='Stop'
# Windows PowerShell + installed Microsoft SQL Server SMO. No package download.
$clientDirectory=Join-Path $SmoDirectory '../SQLDB/DAC'
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Reflection;
public static class PortalSqlAssemblyResolver {
 public static string[] Folders;
 public static Assembly Resolve(object sender, ResolveEventArgs args) {
  var name = new AssemblyName(args.Name).Name + ".dll";
  foreach (var folder in Folders) {
   var path = Path.Combine(folder, name);
   if (File.Exists(path)) return Assembly.LoadFrom(path);
  }
  return null;
 }
 public static void Register() { AppDomain.CurrentDomain.AssemblyResolve += Resolve; }
}
'@
[PortalSqlAssemblyResolver]::Folders=@([IO.Path]::GetFullPath($SmoDirectory),[IO.Path]::GetFullPath($clientDirectory))
[PortalSqlAssemblyResolver]::Register()
if(Test-Path (Join-Path $clientDirectory 'Microsoft.Data.SqlClient.dll')) {
 foreach($dependency in 'System.Runtime.CompilerServices.Unsafe','System.Buffers','System.Numerics.Vectors','System.Memory','System.Diagnostics.DiagnosticSource') {
  [void][Reflection.Assembly]::LoadFrom((Join-Path $clientDirectory "$dependency.dll"))
 }
 [void][Reflection.Assembly]::LoadFrom((Join-Path $clientDirectory 'Microsoft.Data.SqlClient.dll'))
}
foreach($assembly in 'Microsoft.SqlServer.ConnectionInfo','Microsoft.SqlServer.Management.Sdk.Sfc','Microsoft.SqlServer.Smo') {
 [void][Reflection.Assembly]::LoadFrom((Join-Path $SmoDirectory "$assembly.dll"))
}
$serverObject=New-Object Microsoft.SqlServer.Management.Smo.Server $Server
$serverObject.ConnectionContext.StatementTimeout=0
$names=@('CompanyPortal','SecurityDB','Pubs_Info_V4')
$databases=@($names | ForEach-Object {
 $db=$serverObject.Databases[$_]
 if(!$db){throw "Missing source database $_"}
 $db
})
$output=[IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))|Out-Null
$writer=[IO.StreamWriter]::new($output+'.partial',$false,[Text.UTF8Encoding]::new($true))
$manifest=[Collections.Generic.List[object]]::new()
function Batch([string]$sql) { $writer.WriteLine($sql); $writer.WriteLine('GO') }
function Signature($db,$table) {
 $qualified='['+$table.Schema.Replace(']',']]')+'].['+$table.Name.Replace(']',']]')+']'
 $pk=@($table.Indexes | Where-Object {$_.IndexKeyType -eq 'DriPrimaryKey'})
 if($pk.Count -ne 1){throw "Expected primary key for $qualified"}
 $order=(@($pk[0].IndexedColumns | ForEach-Object {'['+$_.Name.Replace(']',']]')+']'}) -join ',')
 $sql="SELECT COUNT_BIG(*) [RowCount], CONVERT(varchar(64),HASHBYTES('SHA2_256',(SELECT * FROM $qualified ORDER BY $order FOR JSON PATH,INCLUDE_NULL_VALUES)),2) DataHash FROM $qualified"
 try { $row=$db.ExecuteWithResults($sql).Tables[0].Rows[0] }
 catch { throw $_.Exception.ToString() }
 [pscustomobject]@{Database=$db.Name;Schema=$table.Schema;Table=$table.Name;Rows=[long]$row.RowCount;SHA256=[string]$row.DataHash}
}
$schema=New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
$schema.TargetServerVersion='Version140'
$schema.SchemaQualify=$true; $schema.ScriptOwner=$false; $schema.Permissions=$false
$schema.Indexes=$true; $schema.DriPrimaryKey=$true; $schema.DriUniqueKeys=$true
$schema.DriChecks=$true; $schema.DriDefaults=$true; $schema.ExtendedProperties=$true
$data=New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
$data.TargetServerVersion='Version140'; $data.ScriptSchema=$false; $data.ScriptData=$true
$data.SchemaQualify=$true
try {
 Batch @"
/* CURRENT DATABASE STATE — generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz').
   Includes all rows, including inactive/deleted test records and binary image data.
   Fresh SQL Server 2017+ test installation only. No SQLCMD mode required in SSMS.
   No server logins/passwords, IIS/Exchange permissions, or external files are embedded.
   Existing NTNames, role grants and absolute file paths are intentionally preserved.
   Run with: sqlcmd -S TARGET -E -b -I -f 65001 -i CompanyPortal-CurrentData.sql
   Stop on any error; do not continue/replay against a partial installation.
*/
USE master;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON; SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF; SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_ID(N'CompanyPortal') IS NOT NULL OR DB_ID(N'SecurityDB') IS NOT NULL OR DB_ID(N'Pubs_Info_V4') IS NOT NULL
BEGIN
 RAISERROR('STOP: one or more destination databases already exist. Nothing was imported. Reconnect before retrying.',16,1);
 SET NOEXEC ON;
END;
"@
 foreach($db in $databases) {
  Batch "USE master; EXEC(N'CREATE DATABASE [$($db.Name)] COLLATE $($db.Collation)');"
  Batch "ALTER DATABASE [$($db.Name)] SET COMPATIBILITY_LEVEL = 140;"
 }
 # All table definitions/data exist before cross-database views and modules.
 foreach($db in $databases) {
  Batch "USE [$($db.Name)];"
  foreach($s in $db.Schemas | Where-Object {$_.Name -notin @('dbo','guest','sys','INFORMATION_SCHEMA') -and !$_.IsSystemObject}) {
   Batch "CREATE SCHEMA [$($s.Name.Replace(']',']]'))] AUTHORIZATION dbo;"
  }
  foreach($type in $db.UserDefinedTableTypes) {foreach($sql in $type.Script($schema)){Batch $sql}}
  foreach($table in $db.Tables | Where-Object {!$_.IsSystemObject} | Sort-Object Schema,Name) {
   $before=Signature $db $table
   foreach($sql in $table.Script($schema)){Batch $sql}
   foreach($sql in $table.EnumScript($data)){Batch $sql}
   $after=Signature $db $table
   if(($before | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)){throw "Source changed during export: $($table.Name). Retry while portal is idle."}
   $manifest.Add($before)
   foreach($column in $table.Columns | Where-Object Identity) {
    $qualified='['+$table.Schema.Replace(']',']]')+'].['+$table.Name.Replace(']',']]')+']'
    $value=$db.ExecuteWithResults("SELECT CONVERT(varchar(50),IDENT_CURRENT(N'$($qualified.Replace("'","''"))')) CurrentValue, COUNT_BIG(*) [Rows] FROM $qualified").Tables[0].Rows[0]
    # Empty, never-used identities must retain their first-insert behaviour.
    $last=$db.ExecuteWithResults("SELECT last_value FROM sys.identity_columns WHERE object_id=OBJECT_ID(N'$($qualified.Replace("'","''"))')").Tables[0].Rows[0].last_value
    if($last -isnot [DBNull]) {Batch "DBCC CHECKIDENT (N'$qualified', RESEED, $($value.CurrentValue)) WITH NO_INFOMSGS;"}
   }
  }
 }
 foreach($db in $databases) {
  Batch "USE [$($db.Name)];"
  foreach($table in $db.Tables | Where-Object {!$_.IsSystemObject}) {
   foreach($fk in $table.ForeignKeys){foreach($sql in $fk.Script()){Batch $sql}}
   foreach($trigger in $table.Triggers | Where-Object {!$_.IsSystemObject}){foreach($sql in $trigger.Script()){Batch $sql}}
  }
  foreach($objects in @($db.UserDefinedFunctions,$db.Views,$db.StoredProcedures)) {
   foreach($obj in $objects | Where-Object {!$_.IsSystemObject}){foreach($sql in $obj.Script($schema)){Batch $sql}}
  }
  foreach($property in $db.ExtendedProperties){foreach($sql in $property.Script()){Batch $sql}}
 }
 # Detect changes to earlier tables while later databases were being exported.
 foreach($item in $manifest) {
  $db=$serverObject.Databases[$item.Database]
  $current=Signature $db $db.Tables[$item.Table,$item.Schema]
  if(($current|ConvertTo-Json -Compress) -ne ($item|ConvertTo-Json -Compress)){throw 'Source data changed during export. Retry while portal is idle.'}
 }
 Batch "USE CompanyPortal; DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS; PRINT N'Current database state imported. Configure destination service login, NTNames/mailbox mappings and news file paths before testing.';"
 $writer.Dispose()
 Move-Item -LiteralPath ($output+'.partial') -Destination $output -Force
 $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ($output+'.manifest.json') -Encoding UTF8
 Write-Output "Exported $($manifest.Count) tables / $(($manifest | Measure-Object Rows -Sum).Sum) rows to $output"
} finally {
 $writer.Dispose()
 $serverObject.ConnectionContext.Disconnect()
}
