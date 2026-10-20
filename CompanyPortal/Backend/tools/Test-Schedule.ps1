param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local development only.'}
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true
$client=[Net.Http.HttpClient]::new($handler)
function Check($condition,$message){if(-not $condition){throw $message}}
function Read($path,$origin=''){
 $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get,$BaseUrl+$path)
 if($origin){$request.Headers.Add('Origin',$origin)}
 try{$response=$client.SendAsync($request).GetAwaiter().GetResult();try{@{Status=[int]$response.StatusCode;Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult();Cache=[string]$response.Headers.CacheControl}}finally{$response.Dispose()}}finally{$request.Dispose()}
}
try{
 $swagger=Read '/swagger/v1/swagger.json';Check ($swagger.Status -eq 200) 'Swagger failed.'
 $definition=$swagger.Body|ConvertFrom-Json
 Check ($null -ne $definition.paths.'/api/schedule/calendars'.get -and $null -ne $definition.paths.'/api/schedule/stream'.get) 'Schedule endpoints missing from Swagger.'
 foreach($path in '/api/schedule/calendars','/api/schedule?from=2026-10-01&to=2026-11-01','/api/schedule/stream?from=2026-10-01&to=2026-11-01'){
  $result=Read $path;Check ($result.Status -eq 503) "Expected disabled503: $path ($($result.Status))";Check ($result.Cache.Contains('no-store')) 'Private response can be cached.'
 }
 foreach($query in 'from=2026-10-01&to=2027-01-01','from=2026-02-30&to=2026-03-01','from=2026-10-01&to=2026-11-01&calendar=boss@example.com'){
  Check ((Read ('/api/schedule?'+$query)).Status -eq 400) 'Invalid date range/calendar key accepted.'
 }
 Check ((Read '/api/schedule/stream?from=2026-10-01&to=2026-11-01' 'https://untrusted.invalid').Status -eq 403) 'Untrusted SSE origin accepted.'
 $anonymous=[Net.Http.HttpClient]::new()
 try{$response=$anonymous.GetAsync($BaseUrl+'/api/schedule/calendars').GetAwaiter().GetResult();try{Check ([int]$response.StatusCode -eq 401) 'Anonymous schedule access accepted.'}finally{$response.Dispose()}}finally{$anonymous.Dispose()}
 $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post,$BaseUrl+'/api/schedule');try{$response=$client.SendAsync($request).GetAwaiter().GetResult();try{Check ([int]$response.StatusCode -in @(404,405)) 'Unexpected calendar write endpoint.'}finally{$response.Dispose()}}finally{$request.Dispose()}
 Write-Output 'PASS: Swagger, authenticated disabled state/no-store, date/key validation, anonymous denial, origin protection and no write endpoints.'
}finally{$client.Dispose()}
