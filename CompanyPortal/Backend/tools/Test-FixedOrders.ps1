param([string]$BaseUrl='http://localhost:5091',[switch]$KeepFixture,[switch]$Cleanup,[switch]$TestSampleRevocation)
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local tests only.'}
$path=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../artifacts/fixed-orders-fixture.json'))
function Assert($value,[string]$text){if(-not $value){throw $text}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
 try{$connection.Open();$cmd=$connection.CreateCommand();$cmd.CommandText=$query;foreach($key in $parameters.Keys){[void]$cmd.Parameters.AddWithValue($key,$parameters[$key])};$cmd.ExecuteScalar()}finally{$connection.Dispose()}
}
function RemoveFixture{
 if(-not (Test-Path -LiteralPath $path)){return}
 $ids=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path))
 Assert ($ids.Count-ge 1 -and $ids.Count-le 20 -and @($ids|Where-Object {$_-notmatch '^[1-9][0-9]{0,18}$'}).Count-eq 0) 'Invalid fixture IDs.'
 foreach($fixtureId in $ids){
  [void](Sql 'DELETE FROM Portal.FixedOrders WHERE FixedOrderID=@FixtureId AND TimestampType=-2147483000' @{'@FixtureId'=[long]$fixtureId})
 }
 Remove-Item -LiteralPath $path
}
if($Cleanup){RemoveFixture;'Removed recorded temporary fixed orders.';exit}
if(Test-Path -LiteralPath $path){throw 'Clean up the existing fixture first using -Cleanup.'}
function Request([string]$url,[bool]$authenticated=$true){
 $r=[Net.HttpWebRequest]::Create($url);$r.UseDefaultCredentials=$authenticated;$r.Timeout=15000
 try{$response=$r.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content;cache=$response.Headers['Cache-Control']}}finally{$response.Close()}
}
$user=$null;$passed=$false
try{
 Assert ((Request ($BaseUrl+'/api/fixed-orders') $false).status-eq 401) 'Anonymous request accepted.'
 $before=Request ($BaseUrl+'/api/fixed-orders');Assert ($before.status-eq 200) 'Registered account read failed.'
 Assert ($before.cache-match 'no-store') 'Cache policy missing.'
 $json=Sql ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'FixedOrdersFixture.sql')))
 $ids=@(($json|ConvertFrom-Json)|ForEach-Object {$_.Id})
 [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path));[IO.File]::WriteAllText($path,($ids|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 $response=Request ($BaseUrl+'/api/fixed-orders');Assert ($response.status-eq 200) 'Fixture read failed.'
 $rows=@(($response.content|ConvertFrom-Json)|ForEach-Object {$_});$fixtures=@($rows|Where-Object {$ids-contains $_.fixedOrderId})
 Assert ($fixtures.Count-eq 4) 'Missing fixture rows.'
 Assert (@($fixtures|Where-Object {$_.fixedOrderId-isnot [string]}).Count-eq 0) 'Bigint IDs must be strings.'
 Assert ($fixtures[0].timestamp-eq '2026-10-20' -and $fixtures[0].year-eq 2026 -and $fixtures[0].timestamp2-eq '2030-01-01') 'Date-only fields/year mismatch.'
 Assert ($fixtures[3].timestamp-eq $null -and $fixtures[3].year-eq $null -and $fixtures[3].timestamp2-eq '2024-02-03') 'Timestamp2 used as primary date.'
 Assert (@($fixtures|Where-Object timestampType -ne -2147483000).Count-eq 0) 'TimestampType altered.'
 Assert ($fixtures[0].contentText.Contains('ds{0}de') -and $fixtures[0].contentText.Contains('ss{1}se')) 'Stored templates changed.'
 Assert (-not $fixtures[1].contentText.Contains('ss{1}se')) 'Only-before fixture lost.'
 if($TestSampleRevocation){
  $userJson=Sql 'SELECT UserId,Active FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN() FOR JSON PATH,WITHOUT_ARRAY_WRAPPER';Assert ($userJson) 'Need local sample user.';$user=$userJson|ConvertFrom-Json
  [void](Sql 'UPDATE SecurityDB.dbo.Users SET Active=0 WHERE UserId=@Id' @{'@Id'=$user.UserId})
  Assert ((Request ($BaseUrl+'/api/fixed-orders')).status-eq 403) 'Inactive employee could read orders.'
 }
 $swagger=Request ($BaseUrl+'/swagger/v1/swagger.json');Assert ($swagger.status-eq 200 -and $swagger.content.Contains('/api/fixed-orders')) 'Swagger route missing.'
 $passed=$true
 'PASS: schema-backed read, date-only values/year, nullable fields, raw markers, string bigint IDs, no-store, anonymous denial, Swagger and optional inactive-user denial.'
}finally{
 if($user){[void](Sql 'UPDATE SecurityDB.dbo.Users SET Active=@Active WHERE UserId=@Id' @{'@Id'=$user.UserId;'@Active'=$user.Active})}
 if(-not ($KeepFixture-and $passed)){RemoveFixture}
}
