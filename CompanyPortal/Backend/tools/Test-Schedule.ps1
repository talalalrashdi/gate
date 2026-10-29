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
 $anonymous=[Net.Http.HttpClient]::new()
 try{$request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post,$BaseUrl+'/api/schedule/appointments');$request.Headers.Add('X-CompanyPortal-Request','schedule');$request.Content=[Net.Http.StringContent]::new('{}',[Text.Encoding]::UTF8,'application/json');try{$response=$anonymous.SendAsync($request).GetAwaiter().GetResult();try{Check ([int]$response.StatusCode -eq 401) 'Anonymous calendar write accepted.'}finally{$response.Dispose()}}finally{$request.Dispose()}}finally{$anonymous.Dispose()}
 function WriteCheck($method,$path,$json,$expected,$header=$true,$origin=''){
  $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method),$BaseUrl+$path)
  $request.Content=[Net.Http.StringContent]::new($json,[Text.Encoding]::UTF8,'application/json')
  if($header){$request.Headers.Add('X-CompanyPortal-Request','schedule')}
  if($origin){$request.Headers.Add('Origin',$origin)}
  try{$response=$client.SendAsync($request).GetAwaiter().GetResult();try{Check ([int]$response.StatusCode -eq $expected) "$method $path expected $expected got $([int]$response.StatusCode)"}finally{$response.Dispose()}}finally{$request.Dispose()}
 }
 Check ($null -ne $definition.paths.'/api/schedule/appointments'.post -and $null -ne $definition.paths.'/api/schedule/appointments'.put -and $null -ne $definition.paths.'/api/schedule/appointments'.delete -and $null -ne $definition.paths.'/api/schedule/calendars/open'.post) 'Calendar editing routes missing.'
 $draft='{"subject":"Test","start":"2026-10-20T09:00:00+04:00","end":"2026-10-20T10:00:00+04:00","calendarKey":"own"}'
 WriteCheck 'POST' '/api/schedule/appointments' $draft 503
 WriteCheck 'POST' '/api/schedule/appointments' $draft 400 $false
 WriteCheck 'POST' '/api/schedule/appointments' $draft 403 $true 'https://untrusted.invalid'
 WriteCheck 'POST' '/api/schedule/appointments' '{}' 400
 WriteCheck 'POST' '/api/schedule/appointments' '{"subject":"Test","start":"2026-10-20T11:00Z","end":"2026-10-20T10:00Z"}' 400
 WriteCheck 'POST' '/api/schedule/calendars/open' '{"mailbox":"bad"}' 400
 WriteCheck 'POST' '/api/schedule/calendars/open' '{"mailbox":"boss@example.test"}' 503
 WriteCheck 'PUT' '/api/schedule/appointments' $draft 400
 WriteCheck 'DELETE' '/api/schedule/appointments' '{}' 400
 Write-Output 'PASS: Swagger reads/writes, disabled state/no-store, date/key/body validation, anonymous denial, write header and origin protection.'

}finally{$client.Dispose()}
