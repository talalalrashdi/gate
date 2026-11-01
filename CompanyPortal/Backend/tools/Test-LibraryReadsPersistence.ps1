param([string]$BaseUrl='http://localhost:5877')
# Local fixture only. Validate real HTTP persistence and restore just the test's new acknowledgements.
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local development fixtures only.'}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$c.Open()
function Scalar($query){$cmd=$c.CreateCommand();$cmd.CommandText=$query;return $cmd.ExecuteScalar()}
function Check($condition,$message){if(-not $condition){throw $message}}
function GetCatalog($route){return @(Invoke-RestMethod ($BaseUrl+'/api/'+$route) -UseDefaultCredentials)}
function Post($route,$body){Invoke-RestMethod ($BaseUrl+'/api/'+$route) -Method Post -UseDefaultCredentials -ContentType 'application/json' -Headers @{'X-CompanyPortal-Request'='library-read'} -Body ($body|ConvertTo-Json -Compress) | Out-Null}
$uid=[int](Scalar 'SELECT UserId FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN() AND Active=1')
Check ((Scalar "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name='CompanyPortalDocumentFixture'")-eq 1) 'Requires local marked fixture'
$since=[long](Scalar 'SELECT ISNULL(MAX(UserReadID),0) FROM Portal.UserReads');$cleanup=[Collections.Generic.List[string]]::new()
try{
 foreach($entry in @(@('document-library','documents'),@('safety-library','safety'))){
  $route=$entry[0];$section=$entry[1];$docs=@((GetCatalog $route)|ForEach-Object {$_.documents});$doc=$docs|Where-Object {-not $_.hasRead -and -not $_.hasSeen}|Select-Object -First 1
  Check ($null-ne $doc) 'Need an unread sample PDF';$id=[guid]$doc.documentId;$cleanup.Add("(ContentTypeID=4 AND ContentId=N'$id') OR (ContentTypeID=5 AND ContentId=N'${section}:$id')")
  Post ($route+'/seen') @{documentIds=@([string]$id)}
  $now=@((GetCatalog $route)|ForEach-Object {$_.documents})|Where-Object {$_.documentId-eq [string]$id}|Select-Object -First 1
  Check ($now.hasSeen -and -not $now.hasRead) 'Header visit must persist without reading PDF'
  Post ($route+'/'+$id+'/read') @{}
  $now=@((GetCatalog $route)|ForEach-Object {$_.documents})|Where-Object {$_.documentId-eq [string]$id}|Select-Object -First 1
  Check ($now.hasRead -and $now.hasSeen) 'PDF read did not persist across catalog requests'
  $first=Scalar "SELECT CONVERT(nvarchar(30),ReadAt,121) FROM Portal.UserReads WHERE UserId=$uid AND ContentTypeID=4 AND ContentId=N'$id'"
  Post ($route+'/'+$id+'/read') @{}
  Check ((Scalar "SELECT CONVERT(nvarchar(30),ReadAt,121) FROM Portal.UserReads WHERE UserId=$uid AND ContentTypeID=4 AND ContentId=N'$id'")-eq $first) 'Repeated opening changed read timestamp'
 }
 Write-Output 'PASS: real API section/PDF persistence in both libraries, independent states and repeated-read idempotency.'
}finally{
 if($cleanup.Count){$cmd=$c.CreateCommand();$cmd.CommandText="DELETE FROM Portal.UserReads WHERE UserReadID>@since AND UserId=$uid AND ("+($cleanup-join ' OR ')+')';[void]$cmd.Parameters.AddWithValue('@since',$since);[void]$cmd.ExecuteNonQuery()};$c.Dispose()
}
