param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local media fixture tests only.'}
function Assert($value,[string]$text){if(-not $value){throw $text}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
 try{$c.Open();$q=$c.CreateCommand();$q.CommandText=$query;foreach($key in $parameters.Keys){$v=$parameters[$key];if($null-eq $v){$v=[DBNull]::Value};[void]$q.Parameters.AddWithValue($key,$v)};$q.ExecuteScalar()}finally{$c.Dispose()}
}
function Request([string]$path,[string]$method='GET',$body=$null,[hashtable]$headers=@{},[bool]$authenticated=$true,[bool]$range=$false){
 $r=[Net.HttpWebRequest]::Create($BaseUrl+$path);$r.Method=$method;$r.UseDefaultCredentials=$authenticated;$r.Timeout=15000
 foreach($key in $headers.Keys){$r.Headers[$key]=$headers[$key]};if($range){$r.AddRange(0,31)}
 if($null-ne $body){$bytes=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 8 -Compress));$r.ContentType='application/json';$r.ContentLength=$bytes.Length;$s=$r.GetRequestStream();try{$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 try{$response=$r.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$m=[IO.MemoryStream]::new();$response.GetResponseStream().CopyTo($m);@{status=[int]$response.StatusCode;content=[Text.Encoding]::UTF8.GetString($m.ToArray());bytes=$m.ToArray();type=$response.ContentType;cache=$response.Headers['Cache-Control'];disposition=$response.Headers['Content-Disposition'];range=$response.Headers['Content-Range'];nosniff=$response.Headers['X-Content-Type-Options']}}finally{$response.Close()}
}
function ReadJson($path){$r=Request $path;Assert ($r.status-eq 200) "GET $path failed: $($r.status) $($r.content)";ConvertFrom-Json -InputObject $r.content}
$header=@{'X-CompanyPortal-Request'='media'};$ids=[Collections.Generic.List[int]]::new();$groupId=$null;$role=$null
Assert ((Sql "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalMediaFixture'")-eq 1) 'Requires marked local media fixture.'
$before=Sql 'SELECT (SELECT * FROM Portal.Media ORDER BY MediaID FOR JSON PATH) AS Media,(SELECT * FROM Portal.MediaGroups ORDER BY MediaGroupID FOR JSON PATH) AS Groups FOR JSON PATH,WITHOUT_ARRAY_WRAPPER'
$root=Sql "SELECT strVal FROM Mstr.Utls WHERE [Key]=N'PortalMedia' AND Active=1"
Assert ([IO.Path]::GetFullPath($root).TrimEnd('\')-eq [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../artifacts/media-fixture')).TrimEnd('\')) 'Unexpected local fixture root.'
$bad=Join-Path $root 'test-invalid.png';$unicode=Join-Path $root 'صورة اختبار.png'
Assert (-not(Test-Path -LiteralPath $bad) -and -not(Test-Path -LiteralPath $unicode)) 'Temporary file collision.'
[IO.File]::WriteAllText($bad,'not a PNG');Copy-Item -LiteralPath (Join-Path $root 'fort.png') -Destination $unicode
$tag='MediaTest-'+[guid]::NewGuid().ToString('N')
try{
 Assert ((Request '/api/media' 'GET' $null @{} $false).status-eq 401) 'Anonymous catalog allowed.'
 Assert ((Request '/api/media/1005/file' 'GET' $null @{} $false).status-eq 401) 'Anonymous file allowed.'
 Assert ((Request '/api/admin/media' 'GET' $null @{} $false).status-eq 401) 'Anonymous administration allowed.'
 $c=ReadJson '/api/media';Assert ($c.items.Count-eq 8 -and $c.groups.Count-eq 1 -and $c.groups[0].coverMediaId-eq 1001) 'Initial publication/group filtering incorrect.'
 Assert ((Request '/api/media').content-notmatch 'mediaPath|LastChangeAt|media-fixture|[A-Z]:\\') 'Physical paths/internal metadata leaked.'
 foreach($id in @(1007,1008,1009)){Assert ((Request "/api/media/$id/file").status-eq 404) 'Hidden media or album direct link allowed.'}
 $image=Request '/api/media/1001/file';Assert ($image.status-eq 200 -and $image.type-eq 'image/png' -and $image.nosniff-eq 'nosniff' -and $image.cache-match 'no-store') 'Image stream response failed.'
 $video=Request '/api/media/1005/file' 'GET' $null @{} $true $true;Assert ($video.status-eq 206 -and $video.bytes.Length-eq 32 -and $video.type-eq 'video/mp4' -and $video.range-match '^bytes 0-31/') 'Video seeking/range failed.'
 $g=@{groupName=$tag;coverMediaId=$null;displayOrder=99;active=$true}
 Assert ((Request '/api/admin/media/groups' 'POST' $g).status-eq 400) 'Missing header allowed.'
 Assert ((Request '/api/admin/media/groups' 'POST' $g @{'X-CompanyPortal-Request'='media';Origin='https://untrusted.invalid'}).status-eq 403) 'Foreign origin accepted.'
 $r=Request '/api/admin/media/groups' 'POST' $g $header;Assert ($r.status-eq 200) "Create group failed: $($r.content)";$groupId=($r.content|ConvertFrom-Json).mediaGroupId
 $groupStamp=Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.MediaGroups WHERE MediaGroupID=@Id' @{'@Id'=$groupId}
 Assert ((Request "/api/admin/media/groups/$groupId" 'PUT' $g $header).status-eq 200) 'Group no-op failed.'
 Assert ((Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.MediaGroups WHERE MediaGroupID=@Id' @{'@Id'=$groupId})-eq $groupStamp) 'Group no-op changed timestamp.'
 $body=@{mediaName=$tag+' photo';mediaPath='صورة اختبار.png';mediaType='image';mediaGroupId=$groupId;displayOrder=10;active=$true}
 $r=Request '/api/admin/media/items' 'POST' $body $header;Assert ($r.status-eq 200) "Create media failed: $($r.content)";$id=($r.content|ConvertFrom-Json).mediaId;$ids.Add($id)
 $file=Request "/api/media/$id/file";Assert ($file.status-eq 200 -and $file.disposition-match "filename\*=UTF-8''") 'Arabic inline filename failed.'
 $snapshot=Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.Media WHERE MediaID=@Id' @{'@Id'=$id}
 Assert ((Request "/api/admin/media/items/$id" 'PUT' $body $header).status-eq 200) 'No-op save failed.'
 Assert ((Sql 'SELECT CONVERT(nvarchar(30),LastChangeAt,121) FROM Portal.Media WHERE MediaID=@Id' @{'@Id'=$id})-eq $snapshot) 'No-op changed timestamp.'
 $body.mediaName=$tag+' second';$body.mediaPath='mosque.png';$body.displayOrder=20
 $r=Request '/api/admin/media/items' 'POST' $body $header;Assert ($r.status-eq 200) 'Second photo failed.';$second=($r.content|ConvertFrom-Json).mediaId;$ids.Add($second)
 $g.coverMediaId=$id;Assert ((Request "/api/admin/media/groups/$groupId" 'PUT' $g $header).status-eq 200) 'Cover selection failed.'
 $body.mediaName=$tag+' photo';$body.mediaPath='صورة اختبار.png';$body.displayOrder=10;$body.active=$false
 Assert ((Request "/api/admin/media/items/$id" 'PUT' $body $header).status-eq 200) 'Photo hide failed.'
 $published=(ReadJson '/api/media').groups|Where-Object mediaGroupId -eq $groupId;Assert ($published.coverMediaId-eq $second) 'Hidden cover did not fall back to visible photo.'
 Assert ((Request "/api/media/$id/file").status-eq 404) 'Hidden photo direct URL allowed.'
 $g.active=$false;Assert ((Request "/api/admin/media/groups/$groupId" 'PUT' $g $header).status-eq 200) 'Album hide failed.'
 Assert ((Request "/api/media/$second/file").status-eq 404) 'Hidden album child file allowed.'
 $g.active=$true;$g.coverMediaId=1001;Assert ((Request "/api/admin/media/groups/$groupId" 'PUT' $g $header).status-eq 400) 'Cover from another album accepted.'
 $body.mediaType='video';$body.active=$true;Assert ((Request '/api/admin/media/items' 'POST' $body $header).status-eq 400) 'Video accepted into photo group.';$body.mediaType='image'
 foreach($test in @(@('..\fort.png','INVALID_PATH'),@((Join-Path ($root+'-outside') 'file.png'),'OUTSIDE_ALLOWED_ROOT'),@('no-such-file.png','FILE_NOT_FOUND'),@('test-invalid.png','INVALID_FILE'),@('file.html','UNSUPPORTED_TYPE'),@('fort.png:stream','INVALID_PATH'))){
  $r=Request '/api/admin/media/preview' 'POST' @{mediaPath=$test[0];mediaType='image'} $header
  Assert ($r.status-in 400,404 -and ($r.content|ConvertFrom-Json).code-eq $test[1]) "Path check failed: $($test[1]) $($r.content)"
 }
 $body.mediaGroupId=$null;$body.mediaType='image';$body.active=$true
 Assert ((Request "/api/admin/media/items/$id" 'PUT' $body $header).status-eq 200) 'Moving photo out of album failed.'
 Assert ((Sql 'SELECT COUNT(*) FROM Portal.MediaGroups WHERE MediaGroupID=@Id AND CoverMediaID IS NULL' @{'@Id'=$groupId})-eq 1) 'Moving the cover did not clear the album cover.'
 Assert ((Request "/api/media/$id/file").status-eq 200) 'Standalone moved photo unavailable.'
 $count=Sql 'SELECT COUNT(*) FROM Portal.Media'
 $r=Request '/api/admin/media/preview' 'POST' @{mediaPath='team.mp4';mediaType='video'} $header;Assert ($r.status-eq 200) "Preview failed: $($r.content)";$ticket=($r.content|ConvertFrom-Json).token
 Assert ((Sql 'SELECT COUNT(*) FROM Portal.Media')-eq $count) 'Preview wrote business data.'
 Assert ((Request ('/api/admin/media/preview/'+$ticket) 'GET' $null @{} $true $true).status-eq 206) 'Preview did not support video ranges.'
 Assert ((Request ('/api/admin/media/preview/'+$ticket+'tampered')).status-eq 404) 'Tampered preview allowed.'
 $role=(Sql "SELECT ur.UserRoleId,ur.Active,ur.LastChangeAt FROM SecurityDB.dbo.UserRoles ur JOIN SecurityDB.dbo.Users u ON u.UserId=ur.UserId JOIN SecurityDB.dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER")|ConvertFrom-Json
 Assert ($role) 'Requires local sample admin.'
 [void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=0 WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId})
 Assert ((Request '/api/admin/media').status-eq 403 -and (Request ('/api/admin/media/preview/'+$ticket)).status-eq 403 -and (Request "/api/admin/media/items/$id" 'PUT' $body $header).status-eq 403) 'Revoked admin retained read/preview/write access.'
 Assert ((Request '/api/media').status-eq 200) 'Admin revocation broke employee media access.'
 $swagger=ReadJson '/swagger/v1/swagger.json';Assert ($null-ne $swagger.paths.'/api/admin/media/preview'.post) 'Swagger failed.'
 'PASS: media publication/direct links, album/cover hiding, CRUD/no-op, Unicode names, safe roots/signatures, MP4/range preview, current admin revocation, header/origin, preview no-write and Swagger.'
}finally{
 if($role){[void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=@Active,LastChangeAt=@At WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId;'@Active'=$role.Active;'@At'=[datetime]$role.LastChangeAt})}
 if($groupId){[void](Sql 'UPDATE Portal.MediaGroups SET CoverMediaID=NULL WHERE MediaGroupID=@Id' @{'@Id'=$groupId})}
 foreach($id in $ids){[void](Sql 'DELETE Portal.Media WHERE MediaID=@Id AND MediaName LIKE @Tag' @{'@Id'=$id;'@Tag'=$tag+'%'})}
 if($groupId){[void](Sql 'DELETE Portal.MediaGroups WHERE MediaGroupID=@Id AND GroupName=@Tag' @{'@Id'=$groupId;'@Tag'=$tag})}
 Remove-Item -LiteralPath $bad,$unicode -ErrorAction SilentlyContinue
 $after=Sql 'SELECT (SELECT * FROM Portal.Media ORDER BY MediaID FOR JSON PATH) AS Media,(SELECT * FROM Portal.MediaGroups ORDER BY MediaGroupID FOR JSON PATH) AS Groups FOR JSON PATH,WITHOUT_ARRAY_WRAPPER'
 Assert ($before-ceq $after) 'Original sample metadata/timestamps changed or test records remained.'
}
