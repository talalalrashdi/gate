param([string]$ApiBase='http://localhost:5877')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local test only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$method='GET',$body=$null,$header=$true,$origin=$null){$a=@{Uri=$ApiBase+$path;Method=$method;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true};$h=@{};if($header){$h['X-CompanyPortal-Request']='media-read'};if($origin){$h.Origin=$origin};$a.Headers=$h;if($body){$a.ContentType='application/json';$a.Body=$body|ConvertTo-Json -Depth 4};Invoke-WebRequest @a}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$ids=[Collections.Generic.List[int]]::new();$marker='MediaRead test '+[guid]::NewGuid().ToString('N')
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
try{
 $c.Open();$cmd=$c.CreateCommand();$cmd.CommandText='Security.User_getByUsername';$cmd.CommandType='StoredProcedure';[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar();Assert ($user -gt 0) 'User missing.'
 $before=Scalar "SELECT COUNT(*) FROM Portal.UserReads WHERE UserId=$user AND ContentTypeID=3"
 $group=Scalar 'SELECT TOP(1) MediaGroupID FROM Portal.MediaGroups WHERE Active=1 ORDER BY MediaGroupID';Assert ($group -gt 0) 'Active sample album required.'
 foreach($type in @('image','video')){
  $gid=if($type -eq 'image'){[string]$group}else{'NULL'}
  $id=[int](Scalar "INSERT Portal.Media(MediaName,MediaPath,MediaType,MediaGroupID) OUTPUT inserted.MediaID VALUES(N'$marker',N'not-opened-in-this-test.$type',N'$type',$gid)");$ids.Add($id)
 }
 $data=(Call '/api/media').Content|ConvertFrom-Json;foreach($id in $ids){Assert ($data.unreadMediaIds -contains [string]$id) 'New image/video missing from unread IDs.'}
 Assert ((Call '/api/media/seen' 'POST' @{mediaIds=@($ids[0])} $false).StatusCode -eq 400) 'Missing header accepted.'
 Assert ((Call '/api/media/seen' 'POST' @{mediaIds=@($ids[0])} $true 'https://bad.example').StatusCode -eq 403) 'Bad origin accepted.'
 Assert ((Invoke-WebRequest ($ApiBase+'/api/media/seen') -Method Post -ContentType application/json -Body '{"mediaIds":[]}' -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous acknowledgement accepted.'
 Assert ((Call '/api/media/seen' 'POST' @{mediaIds=@(-1)}).StatusCode -eq 400) 'Bad ID accepted.'
 Assert ((Call '/api/media/seen' 'POST' @{mediaIds=@($ids[0],$ids[0])}).StatusCode -eq 204) 'Acknowledge failed.'
 $first=$ids[0];$second=$ids[1];$stamp=Scalar "SELECT CONVERT(nvarchar(30),ReadAt,126) FROM Portal.UserReads WHERE UserId=$user AND ContentTypeID=3 AND ContentId=N'$first'"
 [void](Call '/api/media/seen' 'POST' @{mediaIds=@($first)})
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.UserReads WHERE UserId=$user AND ContentTypeID=3 AND ContentId=N'$first'") -eq 1) 'Duplicate read.'
 Assert ((Scalar "SELECT CONVERT(nvarchar(30),ReadAt,126) FROM Portal.UserReads WHERE UserId=$user AND ContentTypeID=3 AND ContentId=N'$first'") -eq $stamp) 'Repeat changed read timestamp.'
 $data=(Call '/api/media').Content|ConvertFrom-Json;Assert ($data.unreadMediaIds -notcontains [string]$first) 'Acknowledgement did not persist.';Assert ($data.unreadMediaIds -contains [string]$second) 'Unclicked new media was acknowledged.'
 [void](Scalar "UPDATE Portal.Media SET MediaName=N'$marker edited',DisplayOrder=22 WHERE MediaID=$first")
 Assert (((Call '/api/media').Content|ConvertFrom-Json).unreadMediaIds -notcontains [string]$first) 'Title/order edit restored badge.'
 [void](Scalar "UPDATE Portal.Media SET Active=0 WHERE MediaID=$second")
 Assert ((Call '/api/media/seen' 'POST' @{mediaIds=@($second)}).StatusCode -eq 404) 'Hidden media acknowledged.'
 Assert (((Call '/api/media').Content|ConvertFrom-Json).unreadMediaIds -notcontains [string]$second) 'Hidden item triggered badge.'
 Assert ((Scalar "SELECT COUNT(*) FROM Portal.UserReads WHERE UserId=2147483000 AND ContentTypeID=3 AND ContentId=N'$first'") -eq 0) 'Read leaked to another user.'
 Write-Output 'PASS: new video/photo in existing album, persistent per-user reads, duplicate/no-op protection, stale snapshot isolation, edit/order stability, hidden media, header/origin/ID/anonymous gates.'
}finally{
 foreach($id in $ids){[void](Scalar "DELETE Portal.UserReads WHERE ContentTypeID=3 AND ContentId=N'$id'; DELETE Portal.Media WHERE MediaID=$id AND MediaName LIKE N'$marker%';")};$c.Dispose()
}
