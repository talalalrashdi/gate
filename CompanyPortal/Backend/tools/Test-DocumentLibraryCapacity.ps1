param([string]$BaseUrl='http://localhost:5092',[string]$Database='CompanyPortal_LibraryCapacity_20261028')
# Requires a disposable library fixture, never the real CompanyPortal database.
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback -or $Database -notmatch '^CompanyPortal_LibraryCapacity_[0-9]{8}$'){throw 'Disposable localhost library fixture required.'}
$connection=[Data.SqlClient.SqlConnection]::new("Server=localhost;Database=$Database;Integrated Security=True;Encrypt=True;TrustServerCertificate=True")
$connection.Open()
function Sql($text){$c=$connection.CreateCommand();$c.CommandText=$text;try{$c.ExecuteScalar()}finally{$c.Dispose()}}
function Assert($condition,$text){if(-not $condition){throw $text}}
function Request($path,$method='GET',$body=$null,$header='document-library'){
 $p=@{Uri=$BaseUrl+$path;Method=$method;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true;TimeoutSec=30}
 if($body){$p.Body=$body|ConvertTo-Json -Depth 5 -Compress;$p.ContentType='application/json';$p.Headers=@{'X-CompanyPortal-Request'=$header}}
 Invoke-WebRequest @p
}
try{
 Assert ((Sql "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalLibraryCapacityFixture' AND CONVERT(int,value)=1") -eq 1) 'Missing disposable-fixture marker.'
 $catalog=(Request '/api/admin/document-library').Content|ConvertFrom-Json
 Assert ($catalog.tabs.Count -eq 0 -and $catalog.documents.Count -eq 500) 'Isolated API must start empty with 500 synthetic PDFs.'
 $ids=@($catalog.documents.documentId)
 $tabs=@()
 for($n=0;$n -lt 20;$n++){
  $body=@{tabName="اختبار تبويب $n";folderId=101;displayOrder=$n;active=$true;documentIds=if($n -eq 0){$ids}else{@($ids|Select-Object -First 10)}}
  $r=Request '/api/admin/document-library' 'POST' $body
  Assert ($r.StatusCode -eq 200) "Create failed: $($r.Content)"
  $tabs+=($r.Content|ConvertFrom-Json).documentTabId
 }
 $list=@((Request '/api/document-library').Content|ConvertFrom-Json)
 Assert ($list.Count -eq 20 -and $list[0].documents.Count -eq 500) 'Employee API lost tabs or PDFs.'
 Assert (@($list[0].documents.documentId|Sort-Object -Unique).Count -eq 500) 'Duplicate/missing employee PDF IDs.'
 $saved=(Request '/api/admin/document-library').Content|ConvertFrom-Json
 Assert (@($saved.items|Where-Object documentTabId -eq $tabs[0]).Count -eq 500) 'Admin reload lost selected PDFs.'
 $body=@{tabName='اختبار تبويب 0';folderId=101;displayOrder=0;active=$true;documentIds=$ids}
 $at=Sql "SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.DocumentTabs WHERE DocumentTabID=$($tabs[0])"
 $audit=Sql 'SELECT COUNT(*) FROM Portal.AdminChanges'
 Assert ((Request "/api/admin/document-library/$($tabs[0])" 'PUT' $body).StatusCode -eq 200) 'No-op save failed.'
 Assert ((Sql "SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.DocumentTabs WHERE DocumentTabID=$($tabs[0])") -eq $at) 'No-op changed timestamp.'
 Assert ((Sql 'SELECT COUNT(*) FROM Portal.AdminChanges') -eq $audit) 'No-op created an audit entry.'
 $body.documentIds=@($ids|Select-Object -Skip 1)
 Assert ((Request "/api/admin/document-library/$($tabs[0])" 'PUT' $body).StatusCode -eq 200) 'Removing one selected file failed.'
 $list=@((Request '/api/document-library').Content|ConvertFrom-Json)
 Assert ($list[0].documents.Count -eq 499 -and $ids[0] -notin $list[0].documents.documentId) 'Removed PDF remains in tab.'
 $body.active=$false
 Assert ((Request "/api/admin/document-library/$($tabs[0])" 'PUT' $body).StatusCode -eq 200) 'Hide failed.'
 Assert (@((Request '/api/document-library').Content|ConvertFrom-Json).Count -eq 19) 'Hidden tab remains visible.'
 $body.active=$true;$body.displayOrder=99
 Assert ((Request "/api/admin/document-library/$($tabs[0])" 'PUT' $body).StatusCode -eq 200) 'Reactivate/reorder failed.'
 $list=@((Request '/api/document-library').Content|ConvertFrom-Json)
 Assert ($list.Count -eq 20 -and $list[-1].documentTabId -eq $tabs[0]) 'Tab order failed.'
 $body.documentIds=@($ids)+@($ids[0]);Assert ((Request '/api/admin/document-library' 'POST' $body).StatusCode -eq 400) '501 selection accepted.'
 $body.documentIds=@($ids[0],$ids[0]);Assert ((Request '/api/admin/document-library' 'POST' $body).StatusCode -eq 400) 'Duplicate IDs accepted.'
 $body.documentIds=@($ids[0]);$body.folderId=999;Assert ((Request '/api/admin/document-library' 'POST' $body).StatusCode -eq 400) 'Cross-folder file accepted.'
 $body.folderId=101;$body.documentIds=@();Assert ((Request '/api/admin/document-library' 'POST' $body).StatusCode -eq 400) 'Empty selection accepted.'
 $body.documentIds=@($ids[0],$ids[1]);Assert ((Request '/api/admin/safety-library' 'POST' $body 'safety-library').StatusCode -eq 400) 'Safety accidentally allows multiple PDFs.'
 'PASS: real API + current SQL save/read procedures; 20 tabs, 500 PDFs/tab, admin/employee reload, no-op timestamp/audit, removal, hide/reactivate/order, 501/duplicate/cross-folder/empty rejection, safety isolation.'
}finally{$connection.Dispose()}
