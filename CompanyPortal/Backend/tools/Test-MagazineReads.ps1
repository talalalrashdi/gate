param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host-notin @('localhost','127.0.0.1')){throw 'Local test API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path,$method='GET',$headers=@{}){Invoke-WebRequest ($ApiBase+$path) -Method $method -Headers $headers -UseDefaultCredentials -AllowUnencryptedAuthentication}
function Code($path,$method,$headers,$code){try{$r=Call $path $method $headers;Assert ($r.StatusCode-eq $code) 'Unexpected success code'}catch{Assert ($_.Exception.Response.StatusCode.value__-eq $code) "Wrong expected status $code"}}
$c=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
function Run($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;[void]$cmd.ExecuteNonQuery()}
try{
 $c.Open();Assert ((Scalar "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalMagazineFixture'")-eq 1) 'Marked local fixture required.'
 $id=[int](Scalar "SELECT MIN(MagazineID) FROM Portal.Magazines WHERE FileName=N'39.pdf'")
 $cmd=$c.CreateCommand();$cmd.CommandText='Security.User_getByUsername';$cmd.CommandType=[Data.CommandType]::StoredProcedure;[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar()
 Assert ($id-gt 0 -and $user-gt 0) 'Test employee/issue missing.'
 $originalId=Scalar "SELECT UserMagazineReadID FROM Portal.UserMagazineReads WHERE UserId=$user AND MagazineID=$id"
 $originalAt=Scalar "SELECT ReadAt FROM Portal.UserMagazineReads WHERE UserId=$user AND MagazineID=$id"
 $originalActive=Scalar "SELECT CONVERT(int,Active) FROM Portal.UserMagazineReads WHERE UserId=$user AND MagazineID=$id"
 $headers=@{'X-CompanyPortal-Request'='magazine-read';Origin='http://localhost:5082'}
 try{
  if($originalId){Run "UPDATE Portal.UserMagazineReads SET Active=0 WHERE UserId=$user AND MagazineID=$id"}
  $catalog=(Call '/api/magazines').Content|ConvertFrom-Json;Assert (($catalog|Where-Object magazineId -eq $id).hasRead-eq $false) 'Unread status failed.'
  Code "/api/magazines/$id/read" 'POST' @{} 400
  Code "/api/magazines/$id/read" 'POST' @{'X-CompanyPortal-Request'='magazine-read';Origin='https://untrusted.invalid'} 403
  try{Invoke-WebRequest ($ApiBase+"/api/magazines/$id/read") -Method POST -Headers $headers|Out-Null;throw 'Anonymous success'}catch{Assert ($_.Exception.Response.StatusCode.value__-eq 401) 'Anonymous write not denied.'}
  Assert ((Call "/api/magazines/$id/read?userId=2147483000" 'POST' $headers).StatusCode-eq 204) 'Mark read failed.'
  Run "UPDATE Portal.UserMagazineReads SET ReadAt='20200101' WHERE UserId=$user AND MagazineID=$id"
  [void](Call "/api/magazines/$id/read" 'POST' $headers);[void](Call "/api/magazines/$id/read" 'POST' $headers)
  Assert ((Scalar "SELECT COUNT(*) FROM Portal.UserMagazineReads WHERE UserId=$user AND MagazineID=$id")-eq 1) 'Duplicate read rows.'
  Assert ((Scalar "SELECT CONVERT(nvarchar(8),ReadAt,112) FROM Portal.UserMagazineReads WHERE UserId=$user AND MagazineID=$id")-eq '20200101') 'Duplicate mark changed ReadAt.'
  $catalog=(Call '/api/magazines').Content|ConvertFrom-Json;Assert (($catalog|Where-Object magazineId -eq $id).hasRead-eq $true) 'Read status not returned in catalog.'
  Code '/api/magazines/2147483000/read' 'POST' $headers 404
  $active=Scalar "SELECT CONVERT(int,Active) FROM Portal.Magazines WHERE MagazineID=$id"
  try{Run "UPDATE Portal.Magazines SET Active=0 WHERE MagazineID=$id";Code "/api/magazines/$id/read" 'POST' $headers 404}finally{Run "UPDATE Portal.Magazines SET Active=$active WHERE MagazineID=$id"}
 }finally{
  if($originalId){$cmd=$c.CreateCommand();$cmd.CommandText='UPDATE Portal.UserMagazineReads SET ReadAt=@At,Active=@Active WHERE UserMagazineReadID=@ID';[void]$cmd.Parameters.AddWithValue('@At',$originalAt);[void]$cmd.Parameters.AddWithValue('@Active',$originalActive);[void]$cmd.Parameters.AddWithValue('@ID',$originalId);[void]$cmd.ExecuteNonQuery()}
  else{Run "DELETE Portal.UserMagazineReads WHERE UserId=$user AND MagazineID=$id"}
 }
 Write-Output 'Magazine read checks passed: unread/read catalog, current-user scope, auth/header/origin checks, one row and unchanged timestamp on duplicates, hidden/unknown issue rejection. Original read state restored.'
}finally{$c.Dispose()}
