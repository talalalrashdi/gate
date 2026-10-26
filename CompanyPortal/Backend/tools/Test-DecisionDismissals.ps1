param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local fixture API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$method='GET',$headers=@{}){Invoke-WebRequest -Uri ($ApiBase+$path) -Method $method -Headers $headers -UseDefaultCredentials -AllowUnencryptedAuthentication -SkipHttpErrorCheck}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
$id=0;$title='Dismissal verification '+[guid]::NewGuid().ToString()
try{
 $c.Open()
 Assert ((Scalar "SELECT COUNT(*) FROM LegelAffairs.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture'") -eq 1) 'Marked local fixture required.'
 $cmd=$c.CreateCommand();$cmd.CommandText='Security.User_getByUsername';$cmd.CommandType='StoredProcedure';[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar()
 Assert ($user -gt 0) 'Registered user required.'
 $id=[long](Scalar "INSERT LegelAffairs.dbo.Decisions(DecisionType,Title,PublishedAt,PdfFileName,IsPublic,Active) OUTPUT INSERTED.DecisionId VALUES(N'تعميم',N'$title',GETDATE(),N'decision-1.pdf',1,1)")
 $path="/api/decisions/$id/dismiss-notice";$headers=@{'X-CompanyPortal-Request'='decision-dismiss';Origin='http://localhost:5082'}
 $before=((Call '/api/decisions').Content|ConvertFrom-Json)|Where-Object decisionId -eq "$id"
 Assert ($before.notices.channelId -contains 1) 'Fixture must qualify for notice.'
 Assert ((Call $path 'POST').StatusCode -eq 400) 'Missing header accepted.'
 Assert ((Call $path 'POST' @{'X-CompanyPortal-Request'='decision-dismiss';Origin='https://untrusted.invalid'}).StatusCode -eq 403) 'Untrusted origin accepted.'
 Assert ((Call '/api/decisions/9223372036854775807/dismiss-notice' 'POST' $headers).StatusCode -eq 404) 'Unknown decision accepted.'
 Assert ((Invoke-WebRequest ($ApiBase+$path) -Method POST -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous dismissal accepted.'
 Assert ((Call ($path+'?userId=2147483000') 'POST' $headers).StatusCode -eq 204) 'Dismissal failed.'
 $at=Scalar "SELECT DismissedAt FROM Portal.UserDecisionDismissals WHERE UserId=$user AND DecisionId=$id AND ChannelId=1"
 Assert ((Call $path 'POST' $headers).StatusCode -eq 204) 'Repeat failed.'
 Assert ((Scalar "SELECT DismissedAt FROM Portal.UserDecisionDismissals WHERE UserId=$user AND DecisionId=$id AND ChannelId=1") -eq $at) 'Repeat changed timestamp.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.UserDecisionDismissals WHERE DecisionId=$id") -eq 1) 'Duplicate or wrong user.'
 $after=((Call '/api/decisions').Content|ConvertFrom-Json)|Where-Object decisionId -eq "$id"
 Assert ($null -ne $after) 'Dismissal removed main decision.'
 Assert ($after.notices.channelId -notcontains 1) 'Dismissal not persisted in reloaded catalog.'
 Assert ($after.hasRead -eq $before.hasRead) 'Dismissal changed reading state.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.UserReads WHERE ContentTypeID=2 AND ContentId=N'$id'") -eq 0) 'Dismissal created read history.'
 Assert ((Call "/api/decisions/$id/pdf").StatusCode -eq 200) 'Dismissed PDF inaccessible.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed.'
 Write-Output 'PASS: persisted notice suppression, retained decision/PDF, unchanged read state, repeat no-op, server-derived user, header/origin/anonymous/unknown-ID checks and Swagger.'
}finally{
 if($id -gt 0){
  # Remove only this uniquely named disposable fixture and its dismissal, never existing user history.
  [void](Scalar "IF EXISTS(SELECT 1 FROM LegelAffairs.dbo.Decisions WHERE DecisionId=$id AND Title=N'$title') BEGIN DELETE Portal.UserDecisionDismissals WHERE DecisionId=$id AND UserId=$user AND ChannelId=1; DELETE LegelAffairs.dbo.Decisions WHERE DecisionId=$id AND Title=N'$title'; END")
 }
 $c.Dispose()
}
