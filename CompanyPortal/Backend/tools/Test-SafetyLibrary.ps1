param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local fixture tests only.'}
function Assert($value,[string]$text){if(-not $value){throw $text}}
function Request([string]$path,[string]$method='GET',$body=$null,[hashtable]$headers=@{},[bool]$authenticated=$true){
 $r=[Net.HttpWebRequest]::Create($BaseUrl+$path);$r.Method=$method;$r.UseDefaultCredentials=$authenticated;$r.AllowAutoRedirect=$false;$r.Timeout=15000
 foreach($key in $headers.Keys){$r.Headers[$key]=$headers[$key]}
 if($null-ne $body){$bytes=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 8 -Compress));$r.ContentType='application/json';$r.ContentLength=$bytes.Length;$s=$r.GetRequestStream();try{$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 try{$response=$r.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content;location=$response.Headers['Location'];cache=$response.Headers['Cache-Control']}}finally{$response.Close()}
}
function ReadJson([string]$path){$r=Request $path;Assert ($r.status-eq 200) "GET $path failed: $($r.status) $($r.content)";($r.content|ConvertFrom-Json)|ForEach-Object {$_}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5'
 try{$connection.Open();$command=$connection.CreateCommand();$command.CommandText=$query;foreach($key in $parameters.Keys){$value=$parameters[$key];if($null-eq $value){$value=[DBNull]::Value};[void]$command.Parameters.AddWithValue($key,$value)};$command.ExecuteScalar()}finally{$connection.Dispose()}
}

Assert ((Sql "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1")-eq 1) 'Requires marked local document fixture.'
$header=@{'X-CompanyPortal-Request'='safety-library'}
$tag='SafetyTest-'+[guid]::NewGuid().ToString('N');$tabId=$null;$restrictedId=$null;$role=$null
$userId=Sql 'SELECT UserID FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN()'
$jobActive=Sql 'SELECT Active FROM Mng.DocumentSampleJobs WHERE UserID=@UserId' @{'@UserId'=$userId}
try{
 Assert ((Request '/api/safety-library' 'GET' $null @{} $false).status-eq 401) 'Anonymous library allowed.'
 Assert ((Request '/api/safety-library/d0250000-0000-0000-0000-000000000201/file' 'GET' $null @{} $false).status-eq 401) 'Anonymous PDF allowed.'
 Assert ((Request '/api/admin/safety-library' 'GET' $null @{} $false).status-eq 401) 'Anonymous admin allowed.'
 $list=@(ReadJson '/api/safety-library');Assert ($list.Count-ge 3) 'Need the three sample tabs.'
 Assert ((Request '/api/safety-library').content-notmatch 'FolderPath|document-fixture|DocumentPath') 'Paths leaked into library.'
 $pdf=Request '/api/safety-library/d0250000-0000-0000-0000-000000000201/file'
 Assert ($pdf.status-eq 200 -and $pdf.content.StartsWith('%PDF-') -and $pdf.cache-match 'no-store') 'Sample PDF failed.'
 Assert ((Request '/api/safety-library/d0250000-0000-0000-0000-000000000001/file').status-eq 404) 'DOCX accepted in library.'
 Assert ((Request '/api/safety-library/d0250000-0000-0000-0000-000000000004/file').status-eq 404) 'Unselected PDF accepted in library.'
 $body=@{tabName=$tag;folderId=110;displayOrder=88;active=$true;documentIds=@('d0250000-0000-0000-0000-000000000201')}
 Assert ((Request '/api/admin/safety-library' 'POST' $body).status-eq 400) 'Missing header accepted.'
 Assert ((Request '/api/admin/safety-library' 'POST' $body @{'X-CompanyPortal-Request'='safety-library';Origin='https://untrusted.invalid'}).status-eq 403) 'Foreign origin allowed.'
 $created=Request '/api/admin/safety-library' 'POST' $body $header;Assert ($created.status-eq 200) "Creation failed: $($created.content)"
 $tabId=($created.content|ConvertFrom-Json).documentTabId
 $before=Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.DocumentTabs WHERE DocumentTabID=@Id' @{'@Id'=$tabId}
 Assert ((Request "/api/admin/safety-library/$tabId" 'PUT' $body $header).status-eq 200) 'No-op save failed.'
 Assert ((Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.DocumentTabs WHERE DocumentTabID=@Id' @{'@Id'=$tabId})-eq $before) 'No-op changed timestamp.'
 $body.tabName=$tag+' edited';$body.displayOrder=89
 Assert ((Request "/api/admin/safety-library/$tabId" 'PUT' $body $header).status-eq 200) 'Edit failed.'
 $saved=(ReadJson '/api/admin/safety-library').tabs|Where-Object documentTabId -eq $tabId
 Assert ($saved.tabName-eq $body.tabName -and $saved.displayOrder-eq 89 -and $saved.active) 'Save/reload mismatch.'
 Assert ((Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.DocumentTabs WHERE DocumentTabID=@Id' @{'@Id'=$tabId})-ne $before) 'Changed timestamp not updated.'
 Assert (-not (@(ReadJson '/api/document-library').documentTabId-contains $tabId)) 'Safety entry leaked into document tabs.'
 Assert ((Request '/api/document-library/d0250000-0000-0000-0000-000000000201/file').status-eq 404) 'Safety publication granted document-library membership.'
 Assert ((Request "/api/admin/document-library/$tabId" 'PUT' $body @{'X-CompanyPortal-Request'='document-library'}).status-eq 404) 'Cross-section update allowed.'
 $body.documentIds=@('d0250000-0000-0000-0000-000000000201','d0250000-0000-0000-0000-000000000202')
 Assert ((Request '/api/admin/safety-library' 'POST' $body $header).status-eq 400) 'Multiple PDFs accepted for one booklet.'
 $body.documentIds=@('d0250000-0000-0000-0000-000000000201')
 $body.active=$false
 Assert ((Request "/api/admin/safety-library/$tabId" 'PUT' $body $header).status-eq 200) 'Hide failed.'
 Assert (-not (@(ReadJson '/api/safety-library').documentTabId-contains $tabId)) 'Hidden tab leaked.'
 $body.active=$true;$body.folderId=20
 Assert ((Request "/api/admin/safety-library/$tabId" 'PUT' $body $header).status-eq 400) 'Cross-folder selection allowed.'
 $body.folderId=11;$body.documentIds=@('d0250000-0000-0000-0000-000000000001')
 Assert ((Request "/api/admin/safety-library/$tabId" 'PUT' $body $header).status-eq 400) 'DOCX selection allowed.'
 $body.folderId=110;$body.documentIds=@();Assert ((Request '/api/admin/safety-library' 'POST' $body $header).status-eq 400) 'Empty selection allowed.'
 $body.folderId=74;$body.documentIds=@('d0250000-0000-0000-0000-000000000005')
 $created=Request '/api/admin/safety-library' 'POST' $body $header;Assert ($created.status-eq 200) 'Restricted fixture tab failed.';$restrictedId=($created.content|ConvertFrom-Json).documentTabId
 Assert ((Request '/api/safety-library/d0250000-0000-0000-0000-000000000005/file').status-eq 200) 'Granted folder74 PDF failed.'
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=0 WHERE UserID=@UserId' @{'@UserId'=$userId})
 Assert (-not (@(ReadJson '/api/safety-library').documentTabId-contains $restrictedId)) 'Restricted tab leaked after revocation.'
 Assert ((Request '/api/safety-library/d0250000-0000-0000-0000-000000000005/file').status-eq 404) 'Revoked PDF remained accessible.'
 Assert ((Request "/api/admin/safety-library/$restrictedId" 'PUT' $body $header).status-eq 400) 'Admin bypassed document permission.'
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=@Active WHERE UserID=@UserId' @{'@UserId'=$userId;'@Active'=$jobActive})
 $body.active=$false;Assert ((Request "/api/admin/safety-library/$restrictedId" 'PUT' $body $header).status-eq 200) 'Hide restricted tab failed.'
 Assert ((Request '/api/safety-library/d0250000-0000-0000-0000-000000000005/file').status-eq 404) 'Hidden-only PDF link remained accessible.'
 $role=(Sql "SELECT ur.UserRoleId,ur.Active,ur.LastChangeAt FROM SecurityDB.dbo.UserRoles ur JOIN SecurityDB.dbo.Users u ON u.UserId=ur.UserId JOIN SecurityDB.dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER")|ConvertFrom-Json
 Assert ($role) 'Requires sample admin grant.'
 [void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=0 WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId})
 Assert ((Request '/api/admin/safety-library').status-eq 403) 'Revoked admin read allowed.'
 Assert ((Request "/api/admin/safety-library/$tabId" 'PUT' $body $header).status-eq 403) 'Revoked admin write allowed.'
 Assert ((Request '/api/safety-library').status-eq 200) 'Admin revocation broke employee library.'
 $swagger=ReadJson '/swagger/v1/swagger.json';Assert ($null-ne $swagger.paths.'/api/admin/safety-library'.post) 'Swagger failed.'
 'PASS: PDF list/view, admin create/edit/hide/order/no-op, validation/origin/header, folder74 grant/revocation and direct links, admin revocation, Swagger.'
}finally{
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=@Active WHERE UserID=@UserId' @{'@UserId'=$userId;'@Active'=$jobActive})
 if($role){[void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=@Active,LastChangeAt=@At WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId;'@Active'=$role.Active;'@At'=[datetime]$role.LastChangeAt})}
 foreach($id in @($tabId,$restrictedId)){if($id){[void](Sql 'DELETE Portal.DocumentTabItems WHERE DocumentTabID=@Id;DELETE Portal.DocumentTabs WHERE DocumentTabID=@Id' @{'@Id'=$id})}}
}
