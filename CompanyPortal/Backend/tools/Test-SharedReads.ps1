param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local fixture API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$method='GET',$headers=@{},$body=$null){
 $args=@{Uri=$ApiBase+$path;Method=$method;Headers=$headers;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true}
 if($null-ne $body){$args.ContentType='application/json';$args.Body=ConvertTo-Json $body -Depth 8 -Compress}
 Invoke-WebRequest @args
}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
$created=[Collections.Generic.List[object]]::new()
try{
 $c.Open()
 Assert ((Scalar "SELECT COUNT(*) FROM LegelAffairs.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture'") -eq 1) 'Marked legal fixture required.'
 $cmd=$c.CreateCommand();$cmd.CommandText='Security.User_getByUsername';$cmd.CommandType='StoredProcedure';[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar();Assert ($user-gt 0) 'Registered employee required.'
 $catalog=(Call '/api/decisions').Content|ConvertFrom-Json
 $decision=$catalog|Where-Object decisionType -eq 'إعلان'|Select-Object -First 1
 $magazine=((Call '/api/magazines').Content|ConvertFrom-Json)|Select-Object -First 1
 Assert ($decision -and $magazine) 'Development samples missing.'
 Assert ($decision.notices.channelId -contains 2) 'Announcement channel missing.'
 foreach($pair in @(@{Type=2;Id=$decision.decisionId;Path='decisions';Header='decision-read'},@{Type=1;Id=$magazine.magazineId;Path='magazines';Header='magazine-read'})){
  $id=[long]$pair.Id;$type=$pair.Type;$where="UserId=$user AND ContentTypeID=$type AND ContentId=N'$id'"
  $original=Scalar "SELECT UserReadID FROM Portal.UserReads WHERE $where";$originalAt=Scalar "SELECT ReadAt FROM Portal.UserReads WHERE $where"
  $headers=@{'X-CompanyPortal-Request'=$pair.Header;Origin='http://localhost:5082'};$path="/api/$($pair.Path)/$id/read"
  Assert ((Call $path 'POST').StatusCode-eq 400) 'Header check failed.'
  Assert ((Call $path 'POST' @{'X-CompanyPortal-Request'=$pair.Header;Origin='https://untrusted.invalid'}).StatusCode-eq 403) 'Origin check failed.'
  Assert ((Call ($path+'?userId=2147483000') 'POST' $headers).StatusCode-eq 204) 'Authorized mark failed.'
  $readId=[long](Scalar "SELECT UserReadID FROM Portal.UserReads WHERE $where");$readAt=Scalar "SELECT ReadAt FROM Portal.UserReads WHERE $where"
  if(-not $original){$created.Add(@{ID=$readId;User=$user;Type=$type;Content="$id";At=$readAt})}
  foreach($attempt in 1..3){Assert ((Call $path 'POST' $headers).StatusCode-eq 204) 'Repeated mark failed.'}
  Assert ((Scalar "SELECT COUNT(*) FROM Portal.UserReads WHERE $where")-eq 1) 'Duplicate rows.'
  Assert ((Scalar "SELECT ReadAt FROM Portal.UserReads WHERE $where")-eq $readAt) 'Repeat changed first ReadAt.'
  if($original){Assert ($readAt-eq $originalAt) 'Existing history changed.'}
  Assert ((Call "/api/$($pair.Path)/2147483000/read" 'POST' $headers).StatusCode-eq 404) 'Unknown content marked.'
 }
 $catalog=(Call '/api/decisions').Content|ConvertFrom-Json;Assert (($catalog|Where-Object decisionId -eq $decision.decisionId).hasRead-eq $true) 'Decision read catalog missing.'
 $admin=Call '/api/admin/decision-notices';Assert ($admin.StatusCode-eq 200) 'Admin catalog failed.';$settings=($admin.Content|ConvertFrom-Json).settings
 $before=Scalar 'SELECT LastChangeAt FROM Portal.DecisionNoticeSettings WHERE ChannelID=1';$one=$settings|Where-Object channelID -eq 1
 $headers=@{'X-CompanyPortal-Request'='decision-notices';Origin='http://localhost:5082'}
 Assert ((Call '/api/admin/decision-notices/1' 'PUT' $headers @{DurationDays=$one.durationDays;DecisionTypes=@($one.decisionTypes);Active=$one.active}).StatusCode-eq 204) 'No-op save failed.'
 Assert ((Scalar 'SELECT LastChangeAt FROM Portal.DecisionNoticeSettings WHERE ChannelID=1')-eq $before) 'No-op changed timestamp.'
 Assert ((Call '/api/admin/decision-notices/1' 'PUT' $headers @{DurationDays=0;DecisionTypes=@('تنويه');Active=$true}).StatusCode-eq 400) 'Invalid duration accepted.'
 Assert ((Call '/api/admin/decision-notices/2/window' 'PUT' $headers @{DecisionId=$decision.decisionId;FromAt='2026-10-26T12:00:00';ToAt='2026-10-25T12:00:00';IsHidden=$false}).StatusCode-eq 400) 'Invalid window accepted.'
 Assert ((Call '/api/admin/decision-notices/2/window' 'PUT' $headers @{DecisionId='2147483000';FromAt=$null;ToAt=$null;IsHidden=$true}).StatusCode-eq 404) 'Unknown decision window accepted.'
 # Existing private fixture: revoking the grant must reject both the PDF and read endpoint.
 $grant=Scalar "SELECT DecisionUserId FROM LegelAffairs.dbo.DecisionUsers WHERE DecisionId=6 AND UserId=$user AND Active=1"
 if($grant){
  try{$cmd=$c.CreateCommand();$cmd.CommandText="UPDATE LegelAffairs.dbo.DecisionUsers SET Active=0 WHERE DecisionUserId=$grant";[void]$cmd.ExecuteNonQuery()
   Assert ((Call '/api/decisions/6/read' 'POST' @{'X-CompanyPortal-Request'='decision-read'}).StatusCode-eq 404) 'Revoked decision was marked.'
   Assert ((Call '/api/decisions/6/pdf').StatusCode-eq 404) 'Revoked PDF accessible.'
  }finally{$cmd=$c.CreateCommand();$cmd.CommandText="UPDATE LegelAffairs.dbo.DecisionUsers SET Active=1 WHERE DecisionUserId=$grant";[void]$cmd.ExecuteNonQuery()}
 }
 $role=Scalar "SELECT r.RoleId FROM SecurityDB.dbo.Roles r WHERE r.RoleName=N'CompanyPortal.Admin' AND r.Active=1"
 if($role){
  try{$cmd=$c.CreateCommand();$cmd.CommandText="UPDATE SecurityDB.dbo.Roles SET Active=0 WHERE RoleId=$role";[void]$cmd.ExecuteNonQuery()
   Assert ((Call '/api/admin/decision-notices').StatusCode-eq 403) 'Revoked admin read accepted.'
   Assert ((Call '/api/admin/decision-notices/1' 'PUT' $headers @{DurationDays=7;DecisionTypes=@('تنويه');Active=$true}).StatusCode-eq 403) 'Revoked admin write accepted.'
  }finally{$cmd=$c.CreateCommand();$cmd.CommandText="UPDATE SecurityDB.dbo.Roles SET Active=1 WHERE RoleId=$role";[void]$cmd.ExecuteNonQuery()}
 }
 $anonymous=Invoke-WebRequest ($ApiBase+'/api/decisions/'+$decision.decisionId+'/read') -Method POST -SkipHttpErrorCheck
 Assert ($anonymous.StatusCode-eq 401) 'Anonymous mark accepted.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode-eq 200) 'Swagger failed.'
 Write-Output 'Shared read/API checks passed: canonical IDs, repeat/no-op timestamps, magazine regression, header/origin, unknown IDs, notice defaults/admin validation and Swagger.'
}finally{
 # Back up and delete only exact records this test created. Never delete pre-existing history.
 if($created.Count){$created|ConvertTo-Json -Depth 5|Set-Content (Join-Path $PSScriptRoot '../../../.local/shared-read-test-backup.json') -Encoding utf8
  foreach($row in $created){$cmd=$c.CreateCommand();$cmd.CommandText='DELETE Portal.UserReads WHERE UserReadID=@Id AND UserId=@User AND ContentTypeID=@Type AND ContentId=@Content AND ReadAt=@At AND Active=1';foreach($key in $row.Keys){[void]$cmd.Parameters.AddWithValue('@'+$key,$row[$key])};[void]$cmd.ExecuteNonQuery()}}
 $c.Dispose()
}
