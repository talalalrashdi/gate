param([string]$BaseUrl='http://localhost:5877')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local checks only.'}
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true;$client=[Net.Http.HttpClient]::new($handler)
function Check($value,$message){if(-not $value){throw $message}}
function Call($path,$method='GET',$body=$null,$header=$true,$origin=''){
 $r=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method),$BaseUrl+$path)
 if($null-ne $body){$r.Content=[Net.Http.StringContent]::new(($body|ConvertTo-Json -Depth 6 -Compress),[Text.Encoding]::UTF8,'application/json')}
 if($header){$r.Headers.Add('X-CompanyPortal-Request','library-read')};if($origin){$r.Headers.Add('Origin',$origin)}
 try{$response=$client.SendAsync($r).GetAwaiter().GetResult();try{@{status=[int]$response.StatusCode;body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult();cache=[string]$response.Headers.CacheControl}}finally{$response.Dispose()}}finally{$r.Dispose()}
}
try{
 $person=Call '/api/profile/person?userId=2147483000';Check ($person.status-eq 200) 'Profile unavailable';$p=($person.body|ConvertFrom-Json).data
 $sql=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=SecurityDB;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
 try{$sql.Open();$cmd=$sql.CreateCommand();$cmd.CommandText='SELECT DisplayName FROM dbo.Users WHERE UserId=@id AND NTName=ORIGINAL_LOGIN() AND Active=1';[void]$cmd.Parameters.AddWithValue('@id',[int]$p.userId);$name=$cmd.ExecuteScalar();Check ($name-eq $p.displayName -and $name) 'Profile did not come from current SecurityDB UserId/name'}finally{$sql.Dispose()}
 foreach($route in @('document-library','safety-library')){
  $result=Call ('/api/'+$route);Check ($result.status-eq 200 -and $result.cache.Contains('no-store')) "$route catalog failed";$tabs=@($result.body|ConvertFrom-Json);$docs=@($tabs|ForEach-Object {$_.documents});Check ($docs.Count-gt 0) 'No fixture PDFs';Check ($null-ne $docs[0].hasRead -and $null-ne $docs[0].hasSeen) 'Read flags missing';
  Check ((Call ('/api/'+$route+'/seen') 'POST' @{documentIds=@()} $false).status-eq 400) 'Missing write header accepted';
  Check ((Call ('/api/'+$route+'/seen') 'POST' @{documentIds=@()} $true 'https://untrusted.invalid').status-eq 403) 'Untrusted origin accepted';
  Check ((Call ('/api/'+$route+'/seen') 'POST' @{documentIds=@('10000000-0000-0000-0000-000000000001')}).status-eq 404) 'Unauthorized seen ID accepted';
  Check ((Call ('/api/'+$route+'/10000000-0000-0000-0000-000000000001/read') 'POST' @{}).status-eq 404) 'Unauthorized read ID accepted';
  Check ((Call ('/api/'+$route+'/seen') 'POST' @{documentIds=@('not-a-guid')}).status-eq 400) 'Invalid GUID accepted';
 }
 $anonymous=[Net.Http.HttpClient]::new();try{$r=$anonymous.GetAsync($BaseUrl+'/api/document-library').GetAwaiter().GetResult();try{Check ([int]$r.StatusCode-eq 401) 'Anonymous library accepted'}finally{$r.Dispose()};$r=$anonymous.PostAsync($BaseUrl+'/api/document-library/seen',[Net.Http.StringContent]::new('{}',[Text.Encoding]::UTF8,'application/json')).GetAwaiter().GetResult();try{Check ([int]$r.StatusCode-eq 401) 'Anonymous seen write accepted'}finally{$r.Dispose()}}finally{$anonymous.Dispose()}
 $swagger=Call '/swagger/v1/swagger.json';Check ($swagger.status-eq 200) 'Swagger failed';$definition=$swagger.body|ConvertFrom-Json;Check ($null-ne $definition.paths.'/api/document-library/{id}/read'.post) 'Read endpoint missing from Swagger'
 Write-Output 'PASS: SecurityDB name/UserId (client UserId ignored), document/safety flags, no-store, anonymous denial, origin/header validation, unauthorized/invalid IDs and Swagger.'
}finally{$client.Dispose()}
