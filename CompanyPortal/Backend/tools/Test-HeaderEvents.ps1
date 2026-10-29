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
 $body=@{title=$marker;appUrl='https://events.example.local/registration';startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');endAt=[DateTimeOffset]::UtcNow.AddDays(7).ToString('O');active=$true}
 Assert ((Call '/api/admin/events' 'POST' $body $false).StatusCode -eq 400) 'Missing header accepted.'
 Assert ((Call '/api/admin/events' 'POST' $body $true 'https://not-allowed.example').StatusCode -eq 403) 'Bad origin accepted.'
 $bad=$body.Clone();$bad.appUrl='javascript:alert(1)';Assert ((Call '/api/admin/events' 'POST' $bad).StatusCode -eq 400) 'Script URL accepted.'
 $bad=$body.Clone();$bad.endAt=$bad.startAt;Assert ((Call '/api/admin/events' 'POST' $bad).StatusCode -eq 400) 'Invalid date range accepted.'
 $create=Call '/api/admin/events' 'POST' $body;Assert ($create.StatusCode -eq 201) 'Create failed.';$id=($create.Content|ConvertFrom-Json).eventId;$ids.Add($id)
 $rows=(Call '/api/header-events').Content|ConvertFrom-Json;Assert (@($rows|Where-Object eventId -eq $id).Count -eq 1) 'Active event missing.'
 $before=Scalar "SELECT CONVERT(nvarchar(30),LastChangeAt,126) FROM Mng.HeaderEvents WHERE EventId=$id"
 $audit=Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$id'"
 Start-Sleep -Milliseconds 100
 Assert ((Call "/api/admin/events/$id" 'PUT' $body).StatusCode -eq 204) 'No-op update failed.'
 Assert ((Scalar "SELECT CONVERT(nvarchar(30),LastChangeAt,126) FROM Mng.HeaderEvents WHERE EventId=$id") -eq $before) 'No-op changed timestamp.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$id'") -eq $audit) 'No-op added history.'
 $body.active=$false;Assert ((Call "/api/admin/events/$id" 'PUT' $body).StatusCode -eq 204) 'Hide failed.'
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Hidden event exposed.'
 $body.active=$true;$body.startAt=[DateTimeOffset]::UtcNow.AddDays(2).ToString('O');$body.endAt=[DateTimeOffset]::UtcNow.AddDays(3).ToString('O');[void](Call "/api/admin/events/$id" 'PUT' $body)
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Future event exposed.'
 $body.startAt=[DateTimeOffset]::UtcNow.AddDays(-3).ToString('O');$body.endAt=[DateTimeOffset]::UtcNow.AddDays(-2).ToString('O');[void](Call "/api/admin/events/$id" 'PUT' $body)
 Assert (-not (((Call '/api/header-events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id)) 'Expired event exposed.'
 Assert (((Call '/api/admin/events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id) 'Admin cannot see expired event.'
 Assert ((Call "/api/admin/events/$id" 'DELETE').StatusCode -eq 204) 'Delete failed.'
 Assert ((Call "/api/admin/events/$id" 'PUT' $body).StatusCode -eq 404) 'Missing item not rejected.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.AdminChanges WHERE Section='events' AND ItemId=N'$id' AND Action='delete'") -eq 1) 'Delete history missing.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed.'
 Write-Output 'PASS: event CRUD, anonymous/header/origin gates, invalid URL/date, scheduling, hidden/expired, no-op timestamps/history, deletion/history and Swagger.'
}finally{
 foreach($id in $ids){[void](Scalar "DELETE Mng.HeaderEvents WHERE EventId=$id AND Title=N'$marker'; DELETE Portal.AdminChanges WHERE Section='events' AND ItemType='event' AND ItemId=N'$id' AND ItemTitle=N'$marker';")};$c.Dispose()
}
