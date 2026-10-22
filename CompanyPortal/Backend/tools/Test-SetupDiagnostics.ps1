param([string]$BaseUrl='http://localhost:5091',[string]$BrokenDatabaseBaseUrl='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Net.Http
function Request($base,[bool]$authenticated=$true,[string]$header='diagnostics',[string]$origin='') {
 $handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$authenticated
 $client=[Net.Http.HttpClient]::new($handler);$client.Timeout=[TimeSpan]::FromSeconds(70)
 $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post,$base+'/api/admin/diagnostics/run')
 if($header){$request.Headers.Add('X-CompanyPortal-Request',$header)}
 if($origin){$request.Headers.Add('Origin',$origin)}
 try {$response=$client.SendAsync($request).GetAwaiter().GetResult();try{@{Status=[int]$response.StatusCode;Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult();Cache=[string]$response.Headers.CacheControl}}finally{$response.Dispose()}}
 finally{$request.Dispose();$client.Dispose()}
}
function Assert($ok,$message){if(!$ok){throw $message}}
Assert ((Request $BaseUrl $false).Status -eq 401) 'Anonymous diagnostics allowed.'
Assert ((Request $BaseUrl $true '').Status -eq 400) 'Missing custom header accepted.'
Assert ((Request $BaseUrl $true 'diagnostics' 'https://untrusted.invalid').Status -eq 403) 'Foreign origin accepted.'
$result=Request $BaseUrl
Assert ($result.Status -eq 200) "Authorized diagnostics failed: $($result.Status)"
Assert ($result.Cache -match 'no-store') 'Diagnostics cache protection missing.'
$data=$result.Body|ConvertFrom-Json
Assert ([bool]$data.reference) 'Log reference missing.'
Assert (($data.checks|Where-Object code -eq 'SQL').status -eq 'pass') 'Database connection check did not pass.'
Assert (($data.checks|Where-Object code -eq 'SCHEMA').status -eq 'pass') 'Required object check did not pass.'
Assert (($data.checks|Where-Object code -eq 'LIVE_ACCEPTANCE').status -eq 'manual') 'Live acceptance incorrectly treated as automatic.'
Assert ($result.Body -notmatch 'Server=|Password=|StackTrace|SqlException:') 'Raw connection/error details leaked.'
if($BrokenDatabaseBaseUrl){
 $result=Request $BrokenDatabaseBaseUrl
 Assert ($result.Status -eq 200) 'Bootstrap diagnostics failed while SQL unavailable.'
 $data=$result.Body|ConvertFrom-Json
 Assert ([bool]($data.checks|Where-Object {$_.code -like 'SQL:*' -and $_.status -eq 'fail' -and $_.nextStep})) 'Missing useful database failure.'
 Assert (($data.checks|Where-Object code -eq 'SQL_DEPENDENTS').status -eq 'skip') 'Dependent checks incorrectly passed.'
 Assert ($result.Body -notmatch 'Server=|Password=|StackTrace|SqlException:') 'Raw SQL exception leaked.'
}
Write-Output 'PASS: authorization, request/origin protection, no-store, database/schema checks, useful bootstrap SQL failures, redaction and explicit manual live acceptance.'
