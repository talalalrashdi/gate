param([string]$BaseUrl='http://localhost:5091',[string]$ReportPath='')
# Read-only regression sweep: no uploads, saves, read markers, launches or permission changes.
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Run this development regression sweep on loopback only.'}
$results=[Collections.Generic.List[object]]::new()
function Request($path,[bool]$authenticated=$true,[bool]$range=$false){
 $headers=@{};if($range){$headers.Range='bytes=0-4'}
 Invoke-WebRequest ($BaseUrl.TrimEnd('/')+$path) -UseDefaultCredentials:$authenticated -AllowUnencryptedAuthentication -SkipHttpErrorCheck -MaximumRedirection 0 -TimeoutSec 75 -Headers $headers
}
function Check($name,[scriptblock]$test){
 try{& $test;$results.Add(@{name=$name;status='passed'});Write-Output "PASS: $name"}
 catch{$results.Add(@{name=$name;status='failed';detail=$_.Exception.Message});Write-Output "FAIL: $name - $($_.Exception.Message)"}
}
function Assert($value,$message){if(-not $value){throw $message}}
$swagger=Request '/swagger/v1/swagger.json';Assert ($swagger.StatusCode -eq 200) 'Swagger unavailable.'
$paths=($swagger.Content|ConvertFrom-Json).paths
foreach($entry in $paths.PSObject.Properties){
 $path=$entry.Name
 if(-not $entry.Value.get -or $path.Contains('{') -or $path -notlike '/api/*' -or $path -match '/open$|/stream$|/diagnostics/|/schedule$|/phone-directory$|/phone-directory/more$|/changes/latest$'){continue}
 Check "$path authenticated + anonymous" {
  $r=Request $path
  $expected=if($path -eq '/api/phone-directory/photo/me'){@(200,404,503)}elseif($path -match '^/api/mail/|^/api/schedule/|^/api/phone-directory/'){@(200,503)}else{@(200,204)}
  Assert ([int]$r.StatusCode -in $expected) "Unexpected HTTP $($r.StatusCode): $($r.Content)"
  Assert ((Request $path $false).StatusCode -eq 401) 'Anonymous request was not denied.'
  Assert ($r.Headers['Cache-Control'] -match 'no-store') 'Private response lacks no-store.'
 }
}
foreach($section in 'documents','safety'){
 $route=if($section -eq 'documents'){'document-library'}else{'safety-library'}
 Check "$section catalog, all selected PDFs and file permissions" {
  $tabs=@((Request "/api/$route").Content|ConvertFrom-Json)
  $admin=(Request "/api/admin/$route").Content|ConvertFrom-Json
  foreach($tab in $tabs){
   Assert (@($tab.documents).Count -gt 0) 'Empty tab published.'
   $expected=@($admin.items|Where-Object { $_.documentTabId -eq $tab.documentTabId -and $_.documentId -in $admin.documents.documentId })
   Assert ($tab.documents.Count -eq $expected.Count) 'Employee tab lost selected PDF records.'
   foreach($doc in $tab.documents){
    Assert ($expected.documentId -contains $doc.documentId) 'PDF mapped to wrong tab.'
    $pdf=Request "/api/$route/$($doc.documentId)/file" $true $true
    Assert ($pdf.StatusCode -eq 206 -and $pdf.Headers['Content-Type'] -match 'application/pdf') 'PDF/range failed.'
    Assert ((Request "/api/$route/$($doc.documentId)/file" $false).StatusCode -eq 401) 'Anonymous PDF accepted.'
   }
  }
  Assert ((Request "/api/$route/00000000-0000-0000-0000-000000000001/file").StatusCode -eq 404) 'Unknown PDF accepted.'
 }
}
Check 'System health checks' {
 $health=(Request '/api/admin/health').Content|ConvertFrom-Json
 $failures=@($health.checks|Where-Object status -eq 'failed')
 Assert ($failures.Count -eq 0) (($failures|ForEach-Object {"$($_.title): $($_.detail)"}) -join '; ')
 Write-Output (($health.checks|Group-Object status|ForEach-Object {"$($_.Count) $($_.Name)"}) -join ', ')
}
if($ReportPath){$results|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ReportPath}
if(@($results|Where-Object status -eq 'failed').Count){exit 1}
