param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local fixtures only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$body=$null,$headers=@{}){
 $args=@{Uri=$ApiBase+$path;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true;Headers=$headers}
 if($null-ne $body){$args.Method='POST';$args.ContentType='application/json';$args.Body=ConvertTo-Json $body -Compress}
 Invoke-WebRequest @args
}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
$keys=[Collections.Generic.List[guid]]::new();$marker='Technical service verification '+[guid]::NewGuid()
try{
 $c.Open()
 foreach($db in @('IsnadDB','ReportsDB')){Assert ((Scalar "SELECT COUNT(*) FROM $db.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture'") -eq 1) 'Marked development databases required.'}
 $cmd=$c.CreateCommand();$cmd.CommandText='Security.User_getByUsername';$cmd.CommandType='StoredProcedure';[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar();Assert ($user-gt 0) 'Registered employee required.'
 $catalogResponse=Call '/api/technical-services';Assert ($catalogResponse.StatusCode -eq 200) 'Lookup failed.';$catalog=$catalogResponse.Content|ConvertFrom-Json
 $direct=$catalog.reportCategories|Where-Object requiresRecipient|Select-Object -First 1;$general=$catalog.reportCategories|Where-Object {-not $_.requiresRecipient}|Select-Object -First 1
 Assert ($direct -and $general -and $catalog.initiativeTypes.Count -gt 0) 'Classification sample branches missing.'
 $headers=@{'X-CompanyPortal-Request'='technical-services';Origin='http://localhost:5082'}
 $cases=@(
  @{Kind='assignment';Table='IsnadDB.dbo.Requests';Id='RequestId';Body=@{recipientId=$catalog.assignmentRecipients[0].id;officeNumber='1312';documentNumber='2026/123'}},
  @{Kind='report';Table='ReportsDB.dbo.Reports';Id='ReportId';Body=@{categoryId=$direct.id;recipientId=($catalog.reportRecipients|Where-Object categoryId -eq $direct.id|Select-Object -First 1).id;typeId=($catalog.reportTypes|Where-Object categoryId -eq $direct.id|Select-Object -First 1).id;title=$marker}},
  @{Kind='report';Table='ReportsDB.dbo.Reports';Id='ReportId';Body=@{categoryId=$general.id;recipientId=$null;typeId=($catalog.reportTypes|Where-Object categoryId -eq $general.id|Select-Object -First 1).id;title=$marker}},
  @{Kind='initiative';Table='ReportsDB.dbo.Initiatives';Id='InitiativeId';Body=@{typeId=$catalog.initiativeTypes[0].id;title=$marker}}
 )
 foreach($case in $cases){
  $body=$case.Body;$key=[guid]::NewGuid();$keys.Add($key);$body.requestKey=$key;$body.details=$marker
  Assert ((Call ('/api/technical-services/'+$case.Kind) $body).StatusCode -eq 400) 'Missing request header accepted.'
  Assert ((Call ('/api/technical-services/'+$case.Kind) $body @{'X-CompanyPortal-Request'='technical-services';Origin='https://untrusted.invalid'}).StatusCode -eq 403) 'Untrusted origin accepted.'
  $response=Call ('/api/technical-services/'+$case.Kind+'?userId=2147483000') $body $headers
  Assert ($response.StatusCode -eq 201) $response.Content;$id=($response.Content|ConvertFrom-Json).requestId
  Assert ((Scalar "SELECT UserId FROM $($case.Table) WHERE $($case.Id)=$id AND RequestKey='$key'") -eq $user) 'Caller identity not enforced.'
  $at=Scalar "SELECT Timestamp FROM $($case.Table) WHERE $($case.Id)=$id"
  $repeat=Call ('/api/technical-services/'+$case.Kind) $body $headers
  Assert (($repeat.Content|ConvertFrom-Json).requestId -eq $id) 'Repeat created another ID.'
  Assert ((Scalar "SELECT COUNT(*) FROM $($case.Table) WHERE UserId=$user AND RequestKey='$key'") -eq 1) 'Duplicate rows.'
  Assert ((Scalar "SELECT Timestamp FROM $($case.Table) WHERE $($case.Id)=$id") -eq $at) 'Repeat changed timestamp.'
 }
 $invalid=@{requestKey=[guid]::NewGuid();details=$marker;title=$marker;categoryId=$direct.id;recipientId=$null;typeId=($catalog.reportTypes|Where-Object categoryId -eq $general.id|Select-Object -First 1).id}
 Assert ((Call '/api/technical-services/report' $invalid $headers).StatusCode -eq 400) 'Cross-category type accepted.'
 $invalid.typeId=($catalog.reportTypes|Where-Object categoryId -eq $direct.id|Select-Object -First 1).id
 Assert ((Call '/api/technical-services/report' $invalid $headers).StatusCode -eq 400) 'Required recipient omitted.'
 $invalid.categoryId=$general.id;$invalid.typeId=($catalog.reportTypes|Where-Object categoryId -eq $general.id|Select-Object -First 1).id;$invalid.recipientId=$catalog.reportRecipients[0].id
 Assert ((Call '/api/technical-services/report' $invalid $headers).StatusCode -eq 400) 'Recipient accepted for general classification.'
 $invalid.title='x'*501
 Assert ((Call '/api/technical-services/report' $invalid $headers).StatusCode -eq 400) 'Oversized title accepted.'
 Assert ((Invoke-WebRequest ($ApiBase+'/api/technical-services') -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous catalog accepted.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed.'
 Write-Output 'PASS: four submission branches, source rows/caller identity, duplicate/no-op timestamps, invalid dependent choices, missing recipient, oversized input, header/Origin, anonymous and Swagger.'
}finally{
 foreach($key in $keys){foreach($table in @('IsnadDB.dbo.Requests','ReportsDB.dbo.Reports','ReportsDB.dbo.Initiatives')){[void](Scalar "DELETE $table WHERE RequestKey='$key' AND Details=N'$marker'")}}
 $c.Dispose()
}
