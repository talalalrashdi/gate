param(
 [Parameter(Mandatory=$true)][string]$PortalUrl,
 [string]$ApiBaseUrl,
 [switch]$RequireExchange,
 [string]$ReportPath=(Join-Path $PSScriptRoot 'Destination-Test-Result.json')
)
# Read-only checks. Run as a registered employee from Windows PowerShell.
# Does not create Exchange items, change permissions or modify SQL records.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Net.Http
if(!$ApiBaseUrl){$ApiBaseUrl=$PortalUrl.TrimEnd('/')+'/backend/'}
$ApiBaseUrl=$ApiBaseUrl.TrimEnd('/')+'/'
$checks=[Collections.Generic.List[object]]::new()
$os=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$machine=[ordered]@{Windows=$os.ProductName;Edition=$os.EditionID;Version=$os.DisplayVersion;Build=$os.CurrentBuildNumber;Is64Bit=[Environment]::Is64BitOperatingSystem;IisInstalled=(Test-Path "$env:windir\System32\inetsrv\appcmd.exe");AspNetCoreModule=(Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll")}
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true;$handler.AllowAutoRedirect=$false
$client=[Net.Http.HttpClient]::new($handler);$client.Timeout=[TimeSpan]::FromSeconds(30)
function Check([string]$name,[string]$url,[bool]$exchange=$false) {
 try {
  $response=$client.GetAsync($url).GetAwaiter().GetResult()
  try {
   $code=[int]$response.StatusCode
   $result=if($code -eq 200){'PASS'}elseif($exchange -and $code -eq 503 -and !$RequireExchange){'PENDING'}else{'FAIL'}
   $checks.Add([pscustomobject]@{Check=$name;Result=$result;HttpStatus=$code})
  }finally{$response.Dispose()}
 }catch{$checks.Add([pscustomobject]@{Check=$name;Result='FAIL';HttpStatus=0;Error=$_.Exception.GetBaseException().Message})}
}
try {
 Check 'Portal page' $PortalUrl
 foreach($path in 'health','api/access','api/themes','api/user-settings/theme','api/user-settings/card-order','api/user-cards','api/news') {Check $path ($ApiBaseUrl+$path)}
 Check 'Employee inbox' ($ApiBaseUrl+'api/mail/inbox') $true
 Check 'Calendar access' ($ApiBaseUrl+'api/schedule/calendars') $true
 $from=[DateTime]::Today.ToString('yyyy-MM-dd');$to=[DateTime]::Today.AddDays(31).ToString('yyyy-MM-dd')
 Check 'Calendar and tasks' ($ApiBaseUrl+"api/schedule?from=$from&to=$to&calendar=own") $true
 # Verify the private API is not exposed to an anonymous caller.
 $anonymous=[Net.Http.HttpClient]::new();$anonymous.Timeout=[TimeSpan]::FromSeconds(30)
 try {
  $response=$anonymous.GetAsync($ApiBaseUrl+'api/mail/inbox').GetAwaiter().GetResult()
  try {$code=[int]$response.StatusCode;$checks.Add([pscustomobject]@{Check='Anonymous denied';Result=$(if($code -eq 401){'PASS'}else{'FAIL'});HttpStatus=$code})}finally{$response.Dispose()}
 }catch{$checks.Add([pscustomobject]@{Check='Anonymous denied';Result='FAIL';HttpStatus=0;Error=$_.Exception.GetBaseException().Message})}
 finally{$anonymous.Dispose()}
}finally{$client.Dispose()}
$checks | Format-Table Check,Result,HttpStatus -AutoSize
[pscustomobject]@{CheckedAt=(Get-Date -Format o);Machine=$machine;Checks=@($checks.ToArray());ManualChecks='Live arrivals, shared/private permissions, OWA links, IIS recycling and disconnected-internet browser checks remain manual.'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Output "Saved $ReportPath"
if(@($checks|Where-Object Result -eq 'FAIL').Count){exit 1}
if(@($checks|Where-Object Result -eq 'PENDING').Count){Write-Output 'Exchange is pending; this is not a full Exchange acceptance pass.'}
