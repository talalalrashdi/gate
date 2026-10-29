param([string]$ApiBase='http://localhost:5877')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local test API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$method='GET',$body=$null,$header=$true,$origin=$null){$a=@{Uri=$ApiBase+$path;Method=$method;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true};$h=@{};if($header){$h['X-CompanyPortal-Request']='events'};if($origin){$h.Origin=$origin};$a.Headers=$h;if($body){$a.Body=$body|ConvertTo-Json -Depth 6;$a.ContentType='application/json'};Invoke-WebRequest @a}
function Json($response){$text=$response.Content;if($text -is [byte[]]){$text=[Text.Encoding]::UTF8.GetString($text)};$text|ConvertFrom-Json}
function Upload($file,$payload,$header=$true,$origin=$null){$h=@{};if($header){$h['X-CompanyPortal-Request']='events'};if($origin){$h.Origin=$origin};Invoke-WebRequest ($ApiBase+'/api/admin/events/upload') -Method Post -UseDefaultCredentials -AllowUnencryptedAuthentication -SkipHttpErrorCheck -Headers $h -Form @{file=Get-Item -LiteralPath $file;payload=($payload|ConvertTo-Json)}}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
$marker='Event upload test '+[guid]::NewGuid().ToString('N');$ids=[Collections.Generic.List[int]]::new();$paths=[Collections.Generic.List[string]]::new()
$badFile=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N')+'.pdf');[IO.File]::WriteAllText($badFile,'not a PDF')
try{
 $c.Open();$catalog=(Call '/api/admin/events/files').Content|ConvertFrom-Json
 Assert ((Call '/api/admin/events/file-options').StatusCode -eq 200) 'Folder hints unavailable.'
 foreach($kind in @(0,2)){
  $sample=$catalog.files|Where-Object {$_.eventType -eq $kind -and $_.name -ne 'invalid.pdf'}|Select-Object -First 1;Assert ($null -ne $sample) 'Missing local fixture.'
  $body=@{title=$marker;eventType=$kind;eventTarget='';startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');endAt=[DateTimeOffset]::UtcNow.AddDays(1).ToString('O');isDisplayed=$true}
  Assert ((Upload $sample.path $body $false).StatusCode -eq 400) 'Upload missing header accepted.'
  Assert ((Upload $sample.path $body $true 'https://not-allowed.example').StatusCode -eq 403) 'Upload wrong origin accepted.'
  $r=Upload $sample.path $body;Assert ($r.StatusCode -eq 201) "Upload failed: $($r.Content)";$id=($r.Content|ConvertFrom-Json).eventId;$ids.Add($id)
  $row=((Call '/api/admin/events').Content|ConvertFrom-Json)|Where-Object eventId -eq $id;$paths.Add($row.eventTarget)
  Assert ($row.eventTarget -match 'EventUploads[\\/][0-9a-f]{32}\.(pdf|mp4)$') 'Unsafe upload filename.'
  Assert (Test-Path -LiteralPath $row.eventTarget) 'Uploaded file not saved.'
  $read=Call "/api/header-events/$id/file";Assert ($read.StatusCode -eq 200) 'Uploaded file not served.'
  $body.eventTarget='C:\NotAllowed\event.pdf';$body.eventType=0
  $invalid=Call '/api/admin/events' 'POST' $body;Assert ($invalid.StatusCode -eq 400 -and (Json $invalid).code -eq 'OUTSIDE_ALLOWED_ROOT') 'Path error is unclear.'
 }
 $body=@{title=$marker;eventType=0;startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');endAt=[DateTimeOffset]::UtcNow.AddDays(1).ToString('O');isDisplayed=$true}
 $invalid=Upload $badFile $body;Assert ($invalid.StatusCode -eq 400 -and (Json $invalid).code -eq 'INVALID_FILE') 'Invalid PDF signature accepted or unclear.'
 $body.title='';$invalid=Upload $badFile $body;Assert ($invalid.StatusCode -eq 400 -and (Json $invalid).errors.Title) 'Metadata validation missing.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed with upload endpoint.'
 'PASS: PDF/MP4 uploads and serving, safe names, auth/header/origin checks, clear outside-root/signature/field errors, folder hints and Swagger.'
}finally{
 foreach($id in $ids){$cmd=$c.CreateCommand();$cmd.CommandText="DELETE Mng.Events WHERE EventId=@id AND Title=@title; DELETE Portal.AdminChanges WHERE Section='events' AND ItemType='event' AND ItemId=CONVERT(nvarchar(100),@id) AND ItemTitle=@title";[void]$cmd.Parameters.AddWithValue('@id',$id);[void]$cmd.Parameters.AddWithValue('@title',$marker);[void]$cmd.ExecuteNonQuery()};$c.Dispose()
 foreach($path in $paths){$full=[IO.Path]::GetFullPath($path);if($full.StartsWith('E:\GatePortal\',[StringComparison]::OrdinalIgnoreCase) -and $full -match '\\EventUploads\\[0-9a-f]{32}\.(pdf|mp4)$'){Remove-Item -LiteralPath $full -Force}}
 Remove-Item -LiteralPath $badFile -Force
}
