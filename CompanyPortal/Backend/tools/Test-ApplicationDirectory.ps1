param([string]$BaseUrl='http://localhost:5091',[switch]$TestSampleRevocation)
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local sample test only.'}
function Assert($value,[string]$text){if(-not $value){throw $text}}
function Request([string]$path,[string]$method='GET',$body=$null,[hashtable]$headers=@{},[bool]$authenticated=$true){
 $r=[Net.HttpWebRequest]::Create($BaseUrl+$path);$r.Method=$method;$r.UseDefaultCredentials=$authenticated;$r.AllowAutoRedirect=$false;$r.Timeout=15000
 foreach($key in $headers.Keys){$r.Headers[$key]=$headers[$key]}
 if($null-ne $body){$bytes=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 8 -Compress));$r.ContentType='application/json';$r.ContentLength=$bytes.Length;$s=$r.GetRequestStream();try{$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 try{$response=$r.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content;location=$response.Headers['Location'];cache=$response.Headers['Cache-Control']}}finally{$response.Close()}
}
function ReadJson([string]$path){$r=Request $path;Assert ($r.status-eq 200) "GET $path failed: $($r.status) $($r.content)";($r.content|ConvertFrom-Json)|ForEach-Object {$_}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5'
 try{$connection.Open();$command=$connection.CreateCommand();$command.CommandText=$query;foreach($key in $parameters.Keys){$value=$parameters[$key];if($null-eq $value){$value=[DBNull]::Value};[void]$command.Parameters.AddWithValue($key,$value)};$command.ExecuteScalar()}finally{$connection.Dispose()}
}
$header=@{'X-CompanyPortal-Request'='application-directory'}
$initial=@(ReadJson '/api/applications');Assert ($initial.Count-gt 0) 'Need a permitted sample app.'
$appId=$initial[0].appId
$snapshot=Sql 'SELECT AppId,ApplicationCategoryId,AppDescription,Active,LastChangeAt FROM Master.ApplicationDetails WHERE AppId=@Id FOR JSON PATH,WITHOUT_ARRAY_WRAPPER' @{'@Id'=$appId}
Assert ($snapshot) 'Expected seeded local metadata.';$original=$snapshot|ConvertFrom-Json
$catId=$null;$grant=$null;$role=$null
$tag='DirectoryTest-'+[guid]::NewGuid().ToString('N')
try{
 Assert ((Request '/api/applications' 'GET' $null @{} $false).status-eq 401) 'Anonymous employee catalog accepted.'
 Assert ((Request '/api/admin/application-directory' 'GET' $null @{} $false).status-eq 401) 'Anonymous administration accepted.'
 $response=Request '/api/applications';Assert ($response.cache-match 'no-store') 'Catalog cache policy missing.'
 Assert ($response.content-notmatch 'launchUrl|AppDescription|ntName|userId') 'Private/internal fields exposed.'
 $admin=ReadJson '/api/admin/application-directory';$allowedIds=@($initial|ForEach-Object appId)
 $forbidden=@($admin.applications|Where-Object {$allowedIds-notcontains $_.appId});Assert ($forbidden.Count-gt 0) 'Need an ungranted sample app.'
 foreach($app in $forbidden){Assert ((Request "/api/applications/$($app.appId)/launch").status-eq 404) 'Ungranted app launch accepted.';Assert (-not ($response.content.Contains($app.appName))) 'Ungranted name exposed.'}
 $cat=@{categoryName=$tag;displayOrder=0;active=$true}
 Assert ((Request '/api/admin/application-directory/categories' 'POST' $cat).status-eq 400) 'Missing header accepted.'
 Assert ((Request '/api/admin/application-directory/categories' 'POST' $cat @{'X-CompanyPortal-Request'='application-directory';Origin='https://untrusted.invalid'}).status-eq 403) 'Foreign origin accepted.'
 $r=Request '/api/admin/application-directory/categories' 'POST' $cat $header;Assert ($r.status-eq 201) "Category create failed $($r.content)";$catId=($r.content|ConvertFrom-Json).categoryId
 $saved=(ReadJson '/api/admin/application-directory').categories|Where-Object categoryId -eq $catId
 Assert ((Request "/api/admin/application-directory/categories/$catId" 'PUT' $cat $header).status-eq 204) 'Category no-op save failed.'
 Assert (((ReadJson '/api/admin/application-directory').categories|Where-Object categoryId -eq $catId).lastChangeAt-eq $saved.lastChangeAt) 'Category no-op timestamp changed.'
 Assert ((Request '/api/admin/application-directory/categories' 'POST' $cat $header).status-eq 400) 'Duplicate category accepted.'
 $body=@{description='Description <b>literal</b> / test';categoryId=$catId}
 Assert ((Request "/api/admin/application-directory/applications/$appId" 'PUT' $body $header).status-eq 204) 'App metadata save failed.'
 $visible=@(ReadJson '/api/applications')|Where-Object appId -eq $appId
 Assert ($visible.description-ceq $body.description -and $visible.categoryId-eq $catId -and $visible.categoryName-eq $tag) 'Employee metadata did not round trip.'
 $saved=(ReadJson '/api/admin/application-directory').applications|Where-Object appId -eq $appId
 Assert ((Request "/api/admin/application-directory/applications/$appId" 'PUT' $body $header).status-eq 204) 'App no-op failed.'
 Assert (((ReadJson '/api/admin/application-directory').applications|Where-Object appId -eq $appId).lastChangeAt-eq $saved.lastChangeAt) 'App no-op timestamp changed.'
 $cat.active=$false
 Assert ((Request "/api/admin/application-directory/categories/$catId" 'PUT' $cat $header).status-eq 204) 'Category deactivation failed.'
 $visible=@(ReadJson '/api/applications')|Where-Object appId -eq $appId
 Assert ($null-eq $visible.categoryId -and $visible.description-ceq $body.description) 'Inactive category removed app or lost description instead of falling back.'
 Assert ((Request "/api/applications/$appId/launch").status-eq 302) 'Permitted launch failed.'
 Assert ((Request "/api/admin/application-directory/applications/$appId" 'PUT' @{description=('x'*2001);categoryId=$catId} $header).status-eq 400) 'Long description accepted.'
 Assert ((Request "/api/admin/application-directory/applications/$appId" 'PUT' @{description='x';categoryId=2147483647} $header).status-eq 400) 'Unknown category accepted.'
 Assert ((Request "/api/admin/application-directory/applications/$appId" 'PUT' @{description='x';categoryId=$catId;launchUrl='https://untrusted.invalid'} $header).status-eq 400) 'Launch address override accepted.'
 Assert ((Request '/api/admin/application-directory/applications/2147483647' 'PUT' $body $header).status-eq 404) 'Unknown application accepted.'
 if($TestSampleRevocation){
  $grantJson=Sql "SELECT g.UserApplicationAccessId,g.Active,g.LastChangeAt FROM SecurityDB.dbo.UserApplicationAccess g JOIN SecurityDB.dbo.Users u ON u.UserId=g.UserId JOIN SecurityDB.dbo.Applications a ON a.AppId=g.AppId WHERE u.NTName=ORIGINAL_LOGIN() AND a.AppId=@Id AND a.AppKey IN(N'people-demo',N'support-demo',N'projects-demo') FOR JSON PATH,WITHOUT_ARRAY_WRAPPER" @{'@Id'=$appId}
  Assert ($grantJson) 'Expected an explicit local sample grant.';$grant=$grantJson|ConvertFrom-Json
  [void](Sql 'UPDATE SecurityDB.dbo.UserApplicationAccess SET Active=0 WHERE UserApplicationAccessId=@Id' @{'@Id'=$grant.UserApplicationAccessId})
  Assert (-not (@(ReadJson '/api/applications').appId-contains $appId)) 'Revoked app remained in catalog.'
  Assert ((Request "/api/applications/$appId/launch").status-eq 404) 'Revoked app still launched.'
  [void](Sql 'UPDATE SecurityDB.dbo.UserApplicationAccess SET Active=@Active,LastChangeAt=@At WHERE UserApplicationAccessId=@Id' @{'@Id'=$grant.UserApplicationAccessId;'@Active'=$grant.Active;'@At'=[datetime]$grant.LastChangeAt});$grant=$null
  $roleJson=Sql "SELECT ur.UserRoleId,ur.Active,ur.LastChangeAt FROM SecurityDB.dbo.UserRoles ur JOIN SecurityDB.dbo.Users u ON u.UserId=ur.UserId JOIN SecurityDB.dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER"
  Assert ($roleJson) 'Expected sample admin role.';$role=$roleJson|ConvertFrom-Json
  [void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=0 WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId})
  Assert ((Request '/api/admin/application-directory').status-eq 403) 'Revoked administrator could read metadata.'
  Assert ((Request "/api/admin/application-directory/applications/$appId" 'PUT' $body $header).status-eq 403) 'Revoked administrator could write metadata.'
  Assert ((Request '/api/applications').status-eq 200) 'Admin revocation broke ordinary app access.'
 }
 $swagger=ReadJson '/swagger/v1/swagger.json';Assert ($null-ne $swagger.paths.'/api/admin/application-directory/categories'.post) 'Swagger generation/routes missing.'
 'PASS: directory metadata, permission/URL isolation, launch checks, categories, inactive fallback, no-op timestamps, validation, Swagger and optional sample grant/role revocation.'
}finally{
 if($grant){[void](Sql 'UPDATE SecurityDB.dbo.UserApplicationAccess SET Active=@Active,LastChangeAt=@At WHERE UserApplicationAccessId=@Id' @{'@Id'=$grant.UserApplicationAccessId;'@Active'=$grant.Active;'@At'=[datetime]$grant.LastChangeAt})}
 if($role){[void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=@Active,LastChangeAt=@At WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId;'@Active'=$role.Active;'@At'=[datetime]$role.LastChangeAt})}
 [void](Sql 'UPDATE Master.ApplicationDetails SET ApplicationCategoryId=@Category,AppDescription=@Description,Active=@Active,LastChangeAt=@At WHERE AppId=@Id' @{'@Id'=$original.AppId;'@Category'=$original.ApplicationCategoryId;'@Description'=$original.AppDescription;'@Active'=$original.Active;'@At'=[datetime]$original.LastChangeAt})
 if($catId){[void](Sql 'DELETE Master.ApplicationCategories WHERE ApplicationCategoryId=@Id AND CategoryName=@Name' @{'@Id'=$catId;'@Name'=$tag})}
}
