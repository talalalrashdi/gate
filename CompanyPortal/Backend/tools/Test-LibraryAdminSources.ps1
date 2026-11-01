param([string]$ApiUrl='http://localhost:5877',[string]$PortalUrl='http://localhost:5876')
$ErrorActionPreference='Stop';if(-not ([uri]$ApiUrl).IsLoopback -or -not ([uri]$PortalUrl).IsLoopback){throw 'Local checks only.'}
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true;$client=[Net.Http.HttpClient]::new($handler)
function Check($value,$message){if(-not $value){throw $message}}
function Read($url){$r=$client.GetAsync($url).GetAwaiter().GetResult();try{@{status=[int]$r.StatusCode;body=$r.Content.ReadAsStringAsync().GetAwaiter().GetResult();type=[string]$r.Content.Headers.ContentType}}finally{$r.Dispose()}}
try{
 foreach($route in @('document-library','safety-library')){
  $r=Read ($ApiUrl+'/api/admin/'+$route);Check ($r.status-eq 200) 'Admin catalog failed';$data=$r.body|ConvertFrom-Json
  Check ($data.source.folderKey-eq 'docs' -and $data.source.table-eq 'Mng.Document' -and @($data.source.roots).Count-gt 0) 'Source/root metadata missing'
  foreach($doc in $data.documents){Check (@($doc.sourcePaths).Count-gt 0) 'Full file path missing';foreach($path in $doc.sourcePaths){Check ([IO.Path]::IsPathRooted($path)) 'Path is not absolute';Check ($path.EndsWith($doc.fileName)) 'Wrong filename in path'}}
  $public=Read ($ApiUrl+'/api/'+$route);Check ($public.status-eq 200) 'Employee catalog failed';Check ($public.body-notmatch 'sourcePaths|folderPath|fileName|"roots"') 'Admin paths leaked to employee catalog'
  $tab=@($public.body|ConvertFrom-Json)|Select-Object -First 1;$id=$tab.documents[0].documentId;$file=Read ($ApiUrl+'/api/'+$route+'/'+$id+'/file');Check ($file.status-eq 200 -and $file.type-match 'application/pdf') 'Protected PDF reader changed'
 }
 $anonymous=[Net.Http.HttpClient]::new();try{$r=$anonymous.GetAsync($ApiUrl+'/api/admin/document-library').GetAwaiter().GetResult();try{Check ([int]$r.StatusCode-eq 401) 'Anonymous source metadata allowed'}finally{$r.Dispose()}}finally{$anonymous.Dispose()}
 foreach($route in @('','/documents','/safety','/themes','/history','/health')){$r=Read ($PortalUrl+'/admin'+$route);Check ($r.status-eq 200) "Admin page failed: $route";Check ($r.body-notmatch 'class="admin-context"|class="admin-status-bar"|تم التحقق من صلاحية الإدارة') 'Removed admin markup remains';if($route-ne '/health'){Check ($r.body-match 'id="admin-status"' -and $r.body-match 'id="admin-retry"') "Error/retry hooks removed: $route"}}
 Write-Output 'PASS: authorized source roots/full paths, employee path isolation, protected PDFs, anonymous denial and removed shared markup across six admin pages.'
}finally{$client.Dispose()}
