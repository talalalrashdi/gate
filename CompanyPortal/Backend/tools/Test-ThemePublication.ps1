param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local development only.'}
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true
$client=[Net.Http.HttpClient]::new($handler)
function Assert($ok,$message){if(-not $ok){throw $message}}
function Send($method,$path,$body=$null,$header='admin-themes',$origin=''){
 $req=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method),$BaseUrl+$path)
 if($header){$req.Headers.Add('X-CompanyPortal-Request',$header)}
 if($origin){$req.Headers.Add('Origin',$origin)}
 if($null -ne $body){$req.Content=[Net.Http.StringContent]::new(($body|ConvertTo-Json -Depth 8 -Compress),[Text.Encoding]::UTF8,'application/json')}
 try{$res=$client.SendAsync($req).GetAwaiter().GetResult();try{@{Status=[int]$res.StatusCode;Body=$res.Content.ReadAsStringAsync().GetAwaiter().GetResult()}}finally{$res.Dispose()}}finally{$req.Dispose()}
}
function Row { ((Send GET '/api/admin/themes').Body|ConvertFrom-Json)|ForEach-Object{$_}|Where-Object themeId -eq $script:id }
function CatalogHas { ((Send GET '/api/themes').Body|ConvertFrom-Json)|ForEach-Object{$_}|Where-Object themeId -eq $script:id }
$id=0;$imageId=0;$groupId=0
try{
 $admin=Send GET '/api/admin/themes';Assert ($admin.Status -eq 200) "Catalog failed: $($admin.Body)"
 $default=($admin.Body|ConvertFrom-Json)|ForEach-Object{$_}|Where-Object isDefault|Select-Object -First 1
 Assert ((Send GET '/swagger/v1/swagger.json').Status -eq 200) 'Swagger failed.'
 Assert ((Send DELETE "/api/admin/themes/$($default.themeId)").Status -eq 400) 'Default deletion accepted.'
 # A unique image makes hidden/preview byte-access tests independent of public groups.
 $svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="600"><rect width="1200" height="600" fill="#145642"/></svg>'
 $multipart=[Net.Http.MultipartFormDataContent]::new();$file=[Net.Http.ByteArrayContent]::new([Text.Encoding]::UTF8.GetBytes($svg));$multipart.Add($file,'file','publication-fixture.svg')
 $client.DefaultRequestHeaders.Add('X-CompanyPortal-Request','admin-images')
 try{$res=$client.PostAsync($BaseUrl+'/api/admin/images',$multipart).GetAwaiter().GetResult();try{Assert ([int]$res.StatusCode -eq 200) 'Upload failed.';$imageId=[int](($res.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json).imageId)}finally{$res.Dispose()}}finally{$multipart.Dispose();$client.DefaultRequestHeaders.Remove('X-CompanyPortal-Request')|Out-Null}
 $group=Send POST '/api/admin/images/groups' @{groupName='Publication test fixture';rotateImages=$false;rotationSeconds=8;active=$true;defaultImageId=$imageId;items=@(@{imageId=$imageId;displayOrder=1;active=$true})} 'admin-images'
 Assert ($group.Status -eq 200) 'Group failed.';$groupId=[int](($group.Body|ConvertFrom-Json).imageGroupId)
 $body=@{themeName='Publication fixture';layoutKey='official';displayOrder=99;active=$false;isDefault=$false;visibility='hidden';previewRoles=@();imagePresentation='artwork';imageGroupId=$groupId}
 $res=Send POST '/api/admin/themes' $body;Assert ($res.Status -eq 200) "Create failed: $($res.Body)";$id=[int](($res.Body|ConvertFrom-Json).themeId)
 Assert (-not (CatalogHas)) 'Hidden theme leaked to employee catalog.'
 $body.active=$true;$body.visibility='preview'
 Assert ((Send PUT "/api/admin/themes/$id" $body).Status -eq 400) 'Preview without roles accepted.'
 $body.previewRoles=@('CompanyPortal.NoGrant.'+[guid]::NewGuid().ToString('N'))
 Assert ((Send PUT "/api/admin/themes/$id" $body).Status -eq 200) 'Preview save failed.'
 Assert (-not (CatalogHas)) 'Restricted preview leaked.'
 Assert ((Send PUT '/api/user-settings/theme' @{themeId=$id} 'theme').Status -eq 400) 'Unauthorized preview selection accepted.'
 Assert ($null -eq (((Send GET "/api/themes/$id/images").Body|ConvertFrom-Json).settings)) 'Restricted image metadata leaked.'
 $body.previewRoles=@('CompanyPortal.Admin')
 Assert ((Send PUT "/api/admin/themes/$id" $body).Status -eq 200) 'Allowed-role save failed.'
 Assert ([bool](CatalogHas)) 'Allowed preview missing.'
 Assert ((Row).previewRoles[0] -eq 'CompanyPortal.Admin') 'Role persistence failed.'
 Assert ($null -ne (((Send GET "/api/themes/$id/images").Body|ConvertFrom-Json).settings)) 'Allowed image metadata missing.'
 $stamp=(Row).lastChangeAt
 Assert ((Send PUT "/api/admin/themes/$id" $body).Status -eq 200) 'No-op save failed.'
 Assert ((Row).lastChangeAt -eq $stamp) 'No-op timestamp changed.'
 Assert ((Send POST "/api/admin/themes/$id/apply-to-all").Status -eq 400) 'Preview applied globally.'
 $body.visibility='public';$body.previewRoles=@()
 Assert ((Send PUT "/api/admin/themes/$id" $body).Status -eq 200) 'Public save failed.'
 Assert ([bool](CatalogHas)) 'Public theme missing.'
 Assert ((Send POST "/api/admin/themes/$id/apply-to-all" $null '').Status -eq 400) 'Apply accepted missing header.'
 Assert ((Send DELETE "/api/admin/themes/$id" $null 'admin-themes' 'https://untrusted.invalid').Status -eq 403) 'Delete accepted untrusted origin.'
 # Roll back every global/default/preference test. No real employee choices are overwritten.
 $sql=@"
SET QUOTED_IDENTIFIER ON; SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Username nvarchar(512)=ORIGINAL_LOGIN(),@UserId int;
DECLARE @Users TABLE(UserId int); INSERT @Users EXEC Security.User_getByUsername @Username; SELECT @UserId=UserId FROM @Users;
BEGIN TRANSACTION;
EXEC Master.Themes_applyToAll @ThemeId=$id;
IF EXISTS(SELECT 1 FROM Portal.UserSettings WHERE Active=1 AND ThemeId<>$id) THROW 51000,'Apply did not change all saved users.',1;
IF NOT EXISTS(SELECT 1 FROM Master.Themes WHERE ThemeId=$id AND IsDefault=1) THROW 51000,'Default not changed.',1;
EXEC Portal.UserSettings_setTheme @UserId=@UserId,@ThemeId=$($default.themeId);
IF NOT EXISTS(SELECT 1 FROM Portal.UserSettings WHERE UserId=@UserId AND ThemeId=$($default.themeId)) THROW 51000,'User could not choose another theme.',1;
ROLLBACK;
BEGIN TRANSACTION;
EXEC Master.Themes_save @ThemeId=$id,@ThemeName=N'Publication fixture',@LayoutKey=N'official',@DisplayOrder=99,@Active=1,@IsDefault=1,@ImagePresentation=N'artwork',@ImageGroupId=$groupId,@Visibility=N'public';
IF EXISTS(SELECT 1 FROM Portal.UserSettings WHERE Active=1 AND ThemeId<>$id) THROW 51000,'Default save did not apply to all.',1;
ROLLBACK;
BEGIN TRANSACTION;
UPDATE Master.Themes SET Visibility=N'preview' WHERE ThemeId=$id;
INSERT Master.ThemePreviewRoles(ThemeId,RoleName) VALUES($id,N'CompanyPortal.NoGrant');
EXEC Master.Images_getContent @ImageId=$imageId,@IsAdmin=0,@UserId=@UserId;

EXEC Portal.UserSettings_setTheme @UserId=@UserId,@ThemeId=$($default.themeId);
UPDATE Portal.UserSettings SET ThemeId=$id WHERE UserId=@UserId;
EXEC Portal.UserSettings_getTheme @UserId=@UserId;

ROLLBACK;
"@
 $connection=[System.Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=False')
 $adapter=[System.Data.SqlClient.SqlDataAdapter]::new($sql,$connection);$adapter.SelectCommand.CommandTimeout=30;$results=[System.Data.DataSet]::new()
 try{[void]$adapter.Fill($results);Assert ($results.Tables.Count -eq 3) 'Unexpected SQL test results.';Assert ($results.Tables[1].Rows.Count -eq 0) 'Unauthorized image bytes leaked.';Assert ($results.Tables[2].Rows[0].ThemeId -eq $default.themeId) 'Revoked role did not fall back.'}finally{$adapter.Dispose();$connection.Dispose();$results.Dispose()}
 $body.active=$false;$body.visibility='hidden'
 Assert ((Send PUT "/api/admin/themes/$id" $body).Status -eq 200) 'Hide failed.'
 Assert (-not (CatalogHas)) 'Hidden catalog persisted.'
 Assert ((Send DELETE "/api/admin/themes/$id").Status -eq 204) 'Delete failed.'
 Assert (-not (Row)) 'Deleted theme remains in admin catalog.'
 Assert ((Send DELETE "/api/admin/themes/$id").Status -eq 404) 'Repeated delete was not 404.'
 Write-Output 'PASS: Swagger, hidden/role/public catalog, allowed/revoked access, metadata, no-op timestamp, protected deletion, rollback-only global/default application.'
}
finally{
 if($id -gt 0){& sqlcmd -S localhost -E -b -d CompanyPortal -Q "SET QUOTED_IDENTIFIER ON; DELETE Master.ThemePreviewRoles WHERE ThemeId=$id; DELETE Master.Themes WHERE ThemeId=$id AND IsDefault=0 AND NOT EXISTS(SELECT 1 FROM Portal.UserSettings WHERE ThemeId=$id);"}
 if($groupId -gt 0){& sqlcmd -S localhost -E -b -d CompanyPortal -Q "DELETE Master.ImageGroupItems WHERE ImageGroupId=$groupId; DELETE Master.ImageGroups WHERE ImageGroupId=$groupId AND NOT EXISTS(SELECT 1 FROM Master.Themes WHERE ImageGroupId=$groupId);"}
 if($imageId -gt 0){& sqlcmd -S localhost -E -b -d CompanyPortal -Q "DELETE Master.Images WHERE ImageId=$imageId AND NOT EXISTS(SELECT 1 FROM Master.ImageGroupItems WHERE ImageId=$imageId);"}
 $client.Dispose()
}
