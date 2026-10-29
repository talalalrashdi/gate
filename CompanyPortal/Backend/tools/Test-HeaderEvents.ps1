param([string]$ApiBase='http://localhost:5877')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local test API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$method='GET',$body=$null,$header=$true,$origin=$null){
 $args=@{Uri=$ApiBase+$path;Method=$method;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true}
 if($body){$args.ContentType='application/json';$args.Body=$body|ConvertTo-Json -Depth 5}
 $headers=@{};if($header){$headers['X-CompanyPortal-Request']='events'};if($origin){$headers.Origin=$origin};$args.Headers=$headers
 Invoke-WebRequest @args
}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
$marker='Event test '+[guid]::NewGuid().ToString('N');$ids=[Collections.Generic.List[int]]::new()
function Scalar($text){$cmd=$c.CreateCommand();$cmd.CommandText=$text;$cmd.ExecuteScalar()}
try{
 $c.Open()
 Assert ((Invoke-WebRequest ($ApiBase+'/api/header-events') -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous catalog allowed.'
 Assert ((Invoke-WebRequest ($ApiBase+'/api/admin/events') -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous admin allowed.'
 $body=@{title=$marker;appUrl='https://events.example.local/registration';startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');endAt=[DateTimeOffset]::UtcNow.AddDays(7).ToString('O');isDisplayed=$true}
 Assert ((Call '/api/admin/events' 'POST' $body $false).StatusCode -eq 400) 'Missing header accepted.'
 Assert ((Call '/api/admin/events' 'POST' $body $true 'https://not-allowed.example').StatusCode -eq 403) 'Bad origin accepted.'
 $bad=$body.Clone();$bad.appUrl='javascript:alert(1)';Assert ((Call '/api/admin/events' 'POST' $bad).StatusCode -eq 400) 'Script URL accepted.'
 $bad=$body.Clone();$bad.endAt=$bad.startAt;Assert ((Call '/api/admin/events' 'POST' $bad).StatusCode -eq 400) 'Invalid date range accepted.'
 $create=Call '/api/admin/events' 'POST' $body;Assert ($create.StatusCode -eq 201) 'Create failed.';$id=($create.Content|ConvertFrom-Json).eventId;$ids.Add($id)
 $rows=(Call '/api/header-events').Content|ConvertFrom-Json;Assert (@($rows|Where-Object eventId -eq $id).Count -eq 1) 'Active event missing.'
 Assert ((Scalar "SELECT CONVERT(nvarchar(8),DATEADD(hour,4,EndAt),108) FROM Mng.Events WHERE EventId=$id") -eq '23:59:00') 'Event end time was not normalized to 11:59 PM.'
 $before=Scalar "SELECT CONVERT(nvarchar(30),LastChangeAt,126) FROM Mng.Events WHERE EventId=$id"
 $audit=Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$id'"
 Start-Sleep -Milliseconds 100
 Assert ((Call "/api/admin/events/$id" 'PUT' $body).StatusCode -eq 204) 'No-op update failed.'
 Assert ((Scalar "SELECT CONVERT(nvarchar(30),LastChangeAt,126) FROM Mng.Events WHERE EventId=$id") -eq $before) 'No-op changed timestamp.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$id'") -eq $audit) 'No-op added history.'
 Assert ((Scalar "SELECT Active FROM Mng.Events WHERE EventId=$id") -eq 1) 'Created event is inactive.'
 $body.isDisplayed=$false;Assert ((Call "/api/admin/events/$id" 'PUT' $body).StatusCode -eq 204) 'Hide failed.'
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Hidden event exposed.'
 Assert ((Scalar "SELECT COUNT(*) FROM Mng.Events WHERE EventId=$id AND Active=1 AND IsDisplayed=0") -eq 1) 'Hide changed deletion flag instead of IsDisplayed.'
 $body.isDisplayed=$true;$body.startAt=[DateTimeOffset]::UtcNow.AddDays(2).ToString('O');$body.endAt=[DateTimeOffset]::UtcNow.AddDays(3).ToString('O');[void](Call "/api/admin/events/$id" 'PUT' $body)
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Future event exposed.'
 $body.startAt=[DateTimeOffset]::UtcNow.AddDays(-3).ToString('O');$body.endAt=[DateTimeOffset]::UtcNow.AddDays(-2).ToString('O');[void](Call "/api/admin/events/$id" 'PUT' $body)
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Expired event exposed.'
 Assert (((Call '/api/admin/events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id) 'Admin cannot see expired event.'
 Assert ((Call "/api/admin/events/$id" 'DELETE').StatusCode -eq 204) 'Delete failed.'
 Assert ((Scalar "SELECT COUNT(*) FROM Mng.Events WHERE EventId=$id AND Active=0") -eq 1) 'Delete removed the row instead of setting Active=0.'
 Assert (-not (((Call '/api/admin/events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Deleted event exposed to admin list.'
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Deleted event exposed to portal.'
 Assert ((Call "/api/admin/events/$id" 'DELETE').StatusCode -eq 404) 'Repeated delete should be not found.'

 Assert ((Call "/api/admin/events/$id" 'PUT' $body).StatusCode -eq 404) 'Missing item not rejected.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$id' AND Action='delete'") -eq 1) 'Delete history missing.'
 $filesResponse=Call '/api/admin/events/files';Assert ($filesResponse.StatusCode -eq 200) 'File catalog failed.'
 $files=($filesResponse.Content|ConvertFrom-Json).files
 foreach($kind in @(0,2)){
  $sample=$files|Where-Object eventType -eq $kind|Select-Object -First 1;Assert ($null -ne $sample) "No local fixture file for type $kind."
  $fileBody=@{title=$marker;eventType=$kind;eventTarget=$sample.path;startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');endAt=[DateTimeOffset]::UtcNow.AddDays(1).ToString('O');isDisplayed=$true}
  $create=Call '/api/admin/events' 'POST' $fileBody;Assert ($create.StatusCode -eq 201) "File event create failed: $($create.Content)";$fileId=($create.Content|ConvertFrom-Json).eventId;$ids.Add($fileId)
  $visible=@((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $fileId
  Assert ($visible.eventType -eq $kind -and $null -eq $visible.eventTarget -and $visible.fileUrl -match "/api/header-events/$fileId/file") 'File catalog exposed path or incorrect type/URL.'
  $file=Call "/api/header-events/$fileId/file";Assert ($file.StatusCode -eq 200) 'File read failed.'
  Assert ($file.Headers['Content-Type'] -match $(if($kind -eq 0){'application/pdf'}else{'video/mp4'})) 'Wrong MIME.'
  $range=Invoke-WebRequest -Uri ($ApiBase+"/api/header-events/$fileId/file") -UseDefaultCredentials -AllowUnencryptedAuthentication -SkipHttpErrorCheck -Headers @{Range='bytes=0-15'}
  Assert ($range.StatusCode -eq 206) 'Range read failed.'
  $fileBody.isDisplayed=$false;[void](Call "/api/admin/events/$fileId" 'PUT' $fileBody)
  Assert ((Call "/api/header-events/$fileId/file").StatusCode -eq 404) 'Hidden file event accessible.'
  $count=Scalar "SELECT COUNT(*) FROM Mng.Events WHERE Title=N'$marker'"
  $fileBody.isDisplayed=$true;$fileBody.startAt=[DateTimeOffset]::UtcNow.AddYears(1).ToString('O');$fileBody.endAt=[DateTimeOffset]::UtcNow.AddYears(1).AddDays(1).ToString('O')
  Assert ((Call "/api/admin/events/$fileId" 'PUT' $fileBody).StatusCode -eq 204) 'Reactivation failed.'
  Assert ((Scalar "SELECT COUNT(*) FROM Mng.Events WHERE Title=N'$marker'") -eq $count) 'Reactivation duplicated event.'
  Assert ((Call "/api/header-events/$fileId/file").StatusCode -eq 404) 'Scheduled file event accessible early.'
  $fileBody.eventTarget=$sample.path+'.missing.pdf';$fileBody.isDisplayed=$false
  Assert ((Call "/api/admin/events/$fileId" 'PUT' $fileBody).StatusCode -eq 204) 'Cannot hide an event whose file is missing.'
  $fileBody.isDisplayed=$true;Assert ((Call "/api/admin/events/$fileId" 'PUT' $fileBody).StatusCode -eq 400) 'Missing file could be republished.'
  $fileBody.eventTarget='C:\Windows\win.ini';Assert ((Call '/api/admin/events' 'POST' $fileBody).StatusCode -eq 400) 'Out-of-root or wrong-format file accepted.'
  $restore=@{title=$marker;eventType=$kind;eventTarget=$sample.path;startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');endAt=[DateTimeOffset]::UtcNow.AddDays(1).ToString('O');isDisplayed=$true}
  Assert ((Call "/api/admin/events/$fileId" 'PUT' $restore).StatusCode -eq 204) 'Restore visibility failed.'
  Assert ((Call "/api/header-events/$fileId/file").StatusCode -eq 200) 'Visible file unreadable before deletion.'
  Assert ((Call "/api/admin/events/$fileId" 'DELETE').StatusCode -eq 204) 'File event delete failed.'
  Assert ((Scalar "SELECT COUNT(*) FROM Mng.Events WHERE EventId=$fileId AND Active=0") -eq 1) 'Deleted file event row was not retained.'
  Assert ((Call "/api/header-events/$fileId/file").StatusCode -eq 404) 'Deleted file event still readable.'
  Assert ((Call "/api/admin/events/$fileId" 'PUT' $restore).StatusCode -eq 404) 'Deleted event could be restored by normal update.'
  Assert ((Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$fileId' AND Action='delete' AND JSON_VALUE(NewJson,'$.Active')='false'") -eq 1) 'Soft delete audit has no Active=false snapshot.'

 }
 $bad=$body.Clone();$bad.eventType=3;Assert ((Call '/api/admin/events' 'POST' $bad).StatusCode -eq 400) 'Invalid event type accepted.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed.'
 Write-Output 'PASS: PDF/video catalog and MIME/ranges, path protection, schedule-file gates, reuse without duplication; event CRUD, anonymous/header/origin gates, invalid URL/date, scheduling, hidden/expired, no-op timestamps/history, soft-delete retention/non-restoration/file denial/history and Swagger.'
}finally{
 foreach($id in $ids){[void](Scalar "DELETE Mng.Events WHERE EventId=$id AND Title=N'$marker'; DELETE Portal.AdminChanges WHERE Section='events' AND ItemType='event' AND ItemId=N'$id' AND ItemTitle=N'$marker';")};$c.Dispose()
}
