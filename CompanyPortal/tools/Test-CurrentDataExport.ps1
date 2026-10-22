param(
 [string]$Server='localhost',
 [string]$DatabaseSuffix='_CurrentDataCheck',
 [string]$ManifestPath=(Join-Path $PSScriptRoot '../Deployment/CompanyPortal-CurrentData.sql.manifest.json')
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Data
function Query([string]$database,[string]$sql) {
 $connection=New-Object System.Data.SqlClient.SqlConnection "Server=$Server;Database=$database;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;"
 try {
  $connection.Open(); $command=$connection.CreateCommand(); $command.CommandText=$sql; $command.CommandTimeout=120
  $table=New-Object System.Data.DataTable
  $reader=$command.ExecuteReader(); $table.Load($reader); $reader.Dispose()
  return ,$table
 } finally {$connection.Dispose()}
}
$items=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach($item in $items) {
 $db=$item.Database+$DatabaseSuffix
 $qualified='['+$item.Schema.Replace(']',']]')+'].['+$item.Table.Replace(']',']]')+']'
 $literal=$qualified.Replace("'","''")
 $keys=Query $db "SELECT QUOTENAME(c.name) Name FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.is_primary_key=1 AND i.object_id=OBJECT_ID(N'$literal') ORDER BY ic.key_ordinal"
 $order=(@($keys.Rows|ForEach-Object {$_.Name}) -join ',')
 $result=(Query $db "SELECT COUNT_BIG(*) [RowCount],CONVERT(varchar(64),HASHBYTES('SHA2_256',(SELECT * FROM $qualified ORDER BY $order FOR JSON PATH,INCLUDE_NULL_VALUES)),2) DataHash FROM $qualified").Rows[0]
 if([long]$result.RowCount -ne $item.Rows -or $result.DataHash -ne $item.SHA256){throw "Data mismatch: $db.$qualified"}
}
foreach($name in @('CompanyPortal','SecurityDB','Pubs_Info_V4')) {
 $sql=@'
SELECT s.name [Schema],t.name [Table],c.name [Column],
 CONVERT(nvarchar(100),c.seed_value) Seed,CONVERT(nvarchar(100),c.increment_value) Increment,
 CONVERT(nvarchar(100),c.last_value) LastValue
FROM sys.identity_columns c JOIN sys.tables t ON t.object_id=c.object_id
JOIN sys.schemas s ON s.schema_id=t.schema_id ORDER BY s.name,t.name,c.name
'@
 $source=Query $name $sql; $target=Query ($name+$DatabaseSuffix) $sql
 $a=@($source.Rows|ForEach-Object {($_.ItemArray|ForEach-Object {"$_"}) -join '|'}) -join "`n"
 $b=@($target.Rows|ForEach-Object {($_.ItemArray|ForEach-Object {"$_"}) -join '|'}) -join "`n"
 if($a -ne $b){throw "Identity state differs: $name"}
 $sql="SELECT type_desc,COUNT(*) ObjectsCount FROM sys.objects WHERE is_ms_shipped=0 GROUP BY type_desc ORDER BY type_desc"
 $source=Query $name $sql; $target=Query ($name+$DatabaseSuffix) $sql
 $a=@($source.Rows|ForEach-Object {($_.ItemArray|ForEach-Object {"$_"}) -join '|'}) -join "`n"
 $b=@($target.Rows|ForEach-Object {($_.ItemArray|ForEach-Object {"$_"}) -join '|'}) -join "`n"
 if($a -ne $b){throw "Schema object counts differ: $name"}
}
Write-Output "PASS: all $($items.Count) table row counts and SHA256 data hashes (including image bytes), identity states and schema object counts match."
