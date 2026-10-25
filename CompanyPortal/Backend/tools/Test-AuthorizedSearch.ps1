param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local sample access checks only.'}
function Assert($value,[string]$text){if(-not $value){throw $text}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
 try{$connection.Open();$command=$connection.CreateCommand();$command.CommandText=$query;foreach($key in $parameters.Keys){[void]$command.Parameters.AddWithValue($key,$parameters[$key])};$command.ExecuteScalar()}finally{$connection.Dispose()}
}
function Request([string]$path,[bool]$authenticated=$true){
 $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$path);$request.UseDefaultCredentials=$authenticated;$request.AllowAutoRedirect=$false;$request.Timeout=15000
 try{$response=$request.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content;cache=$response.Headers['Cache-Control'];location=$response.Headers['Location'];disposition=$response.Headers['Content-Disposition']}}finally{$response.Close()}
}
Assert ((Sql "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1")-eq 1) 'Expected marked local document fixture.'
$user=ConvertFrom-Json -InputObject (Sql 'SELECT UserId,Active FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN() FOR JSON PATH,WITHOUT_ARRAY_WRAPPER')
$job=ConvertFrom-Json -InputObject (Sql 'SELECT ID,Active FROM Mng.DocumentSampleJobs WHERE UserID=@Id FOR JSON PATH,WITHOUT_ARRAY_WRAPPER' @{'@Id'=$user.UserId})
$grant=ConvertFrom-Json -InputObject (Sql "SELECT g.UserApplicationAccessId,g.Active,g.AppId FROM SecurityDB.dbo.UserApplicationAccess g JOIN SecurityDB.dbo.Applications a ON a.AppId=g.AppId WHERE g.UserId=@Id AND a.AppKey=N'people-demo' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER" @{'@Id'=$user.UserId})
$forbidden=Sql "SELECT AppId FROM SecurityDB.dbo.Applications WHERE AppKey=N'reports-demo'"
Assert ($user.Active -and $job.Active -and $grant.Active -and $forbidden) 'Expected explicit local fixtures.'
try{
 foreach($path in @('/api/documents','/api/applications')){
  Assert ((Request $path $false).status-eq 401) 'Anonymous search source accepted.'
  $response=Request $path;Assert ($response.status-eq 200 -and $response.cache-match 'no-store') 'Authorized source/cache failed.'
 }
 $apps=ConvertFrom-Json -InputObject (Request '/api/applications').content
 Assert (@($apps|Where-Object appId -eq $forbidden).Count-eq 0) 'Unauthorized app in search source.'
 Assert ((Request "/api/applications/$forbidden/launch").status-eq 404) 'Unauthorized app launched.'
 Assert ((Request "/api/applications/$($grant.AppId)/launch").status-eq 302) 'Authorized app launch failed.'
 $pdf=Request '/api/documents/d0250000-0000-0000-0000-000000000004/file';Assert ($pdf.status-eq 200 -and $pdf.disposition-match '^inline;') 'PDF is not inline.'
 $word=Request '/api/documents/d0250000-0000-0000-0000-000000000001/file';Assert ($word.status-eq 200 -and $word.disposition-match '^attachment;') 'DOCX is not a download.'
 [void](Sql 'UPDATE SecurityDB.dbo.UserApplicationAccess SET Active=0 WHERE UserApplicationAccessId=@Id' @{'@Id'=$grant.UserApplicationAccessId})
 $revoked=ConvertFrom-Json -InputObject (Request '/api/applications').content
 Assert (@($revoked|Where-Object appId -eq $grant.AppId).Count-eq 0) 'Revoked app still searchable.'
 Assert ((Request "/api/applications/$($grant.AppId)/launch").status-eq 404) 'Revoked app link still works.'
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=0 WHERE ID=@Id' @{'@Id'=$job.ID})
 $limited=ConvertFrom-Json -InputObject (Request '/api/documents').content
 Assert (@($limited|Where-Object {$_.folderId-in 74,75,90}).Count-eq 0) 'Unauthorized/hidden folder searchable.'
 foreach($id in @('d0250000-0000-0000-0000-000000000005','d0250000-0000-0000-0000-000000000006')){Assert ((Request "/api/documents/$id/file").status-eq 404) 'Revoked document link still works.'}
 'PASS: authorized-only uncached search sources, anonymous denial, PDF display, DOCX download, app launch, forbidden apps/folders and revocation rechecks.'
}finally{
 [void](Sql 'UPDATE SecurityDB.dbo.UserApplicationAccess SET Active=@Active WHERE UserApplicationAccessId=@Id' @{'@Id'=$grant.UserApplicationAccessId;'@Active'=$grant.Active})
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=@Active WHERE ID=@Id' @{'@Id'=$job.ID;'@Active'=$job.Active})
}
