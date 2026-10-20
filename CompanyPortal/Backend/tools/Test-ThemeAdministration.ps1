param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Use an isolated local development API/database.'}
Add-Type -AssemblyName System.Net.Http
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true
$client=[Net.Http.HttpClient]::new($handler)
function Assert($value,[string]$message){if(-not $value){throw $message}}
function Send([string]$method,[string]$path,$body=$null,[string]$header='admin-themes',[string]$origin=''){
 $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method),$BaseUrl+$path)
 if($header){$request.Headers.Add('X-CompanyPortal-Request',$header)}
 if($origin){$request.Headers.Add('Origin',$origin)}
 if($null -ne $body){$request.Content=[Net.Http.StringContent]::new(($body|ConvertTo-Json -Depth 8 -Compress),[Text.Encoding]::UTF8,'application/json')}
 try{$response=$client.SendAsync($request).GetAwaiter().GetResult();try{return @{Status=[int]$response.StatusCode;Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()}}finally{$response.Dispose()}}finally{$request.Dispose()}
}
function Catalog { $r=Send GET '/api/admin/themes';Assert ($r.Status -eq 200) 'Admin catalog failed.';$parsed=$r.Body|ConvertFrom-Json;$parsed|ForEach-Object{$_} }
function Payload($theme){$body=@{};foreach($key in 'themeName','layoutKey','displayOrder','active','isDefault','primaryColor','accentColor','backgroundColor','overlayOpacity','foregroundPreset','imagePresentation','imageGroupId','visibility','previewRoles'){$body[$key]=$theme.$key};$body}
function Save([int]$id,$body){Send PUT "/api/admin/themes/$id" $body}
$ids=[Collections.Generic.List[int]]::new();$groupId=0;$originalDefault=$null;$originalSetting=$null;$settingChanged=$false;$allSettings=$null
try{
 $snapshotConnection=[System.Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=False')
 $snapshotAdapter=[System.Data.SqlClient.SqlDataAdapter]::new('SELECT UserSettingId,ThemeId,Active,LastChangeAt FROM Portal.UserSettings',$snapshotConnection);$allSettings=[System.Data.DataTable]::new()
 try{[void]$snapshotAdapter.Fill($allSettings)}finally{$snapshotAdapter.Dispose();$snapshotConnection.Dispose()}
 $before=@(Catalog);$originalDefault=$before|Where-Object isDefault|Select-Object -First 1
 $originalSetting=(Send GET '/api/user-settings/theme').Body|ConvertFrom-Json
 $templates=Send GET '/api/admin/themes/templates';$templateRows=$templates.Body|ConvertFrom-Json;Assert ($templates.Status -eq 200 -and $templateRows.Count -eq 3) 'Template metadata missing.'
 Assert ((Send GET '/swagger/v1/swagger.json').Status -eq 200) 'Swagger failed.'
 $imageCatalog=(Send GET '/api/admin/images').Body|ConvertFrom-Json
 $image=$imageCatalog.images|Where-Object contentType -eq 'image/svg+xml'|Select-Object -First 1
 if(-not $image){$image=$imageCatalog.images|Select-Object -First 1};Assert ($null -ne $image) 'Import frontend artwork before running this test.'
 $group=Send POST '/api/admin/images/groups' @{groupName='Theme administration fixture';rotateImages=$false;rotationSeconds=8;defaultImageId=$image.imageId;active=$true;items=@(@{imageId=$image.imageId;displayOrder=1;active=$true})} 'admin-images'
 Assert ($group.Status -eq 200) 'Fixture group creation failed.';$groupId=[int](($group.Body|ConvertFrom-Json).imageGroupId)
 $body=@{themeName='Theme test A';layoutKey='official';displayOrder=99;active=$true;isDefault=$false;primaryColor='#234e40';accentColor='#A3333B';backgroundColor='#F5F9F3';overlayOpacity=20;foregroundPreset='dark';imagePresentation='artwork';imageGroupId=$groupId}
 Assert ((Send POST '/api/admin/themes' $body '').Status -eq 400) 'Missing write header accepted.'
 Assert ((Send POST '/api/admin/themes' $body 'admin-themes' 'https://untrusted.invalid').Status -eq 403) 'Untrusted origin accepted.'
 $invalid=$body.Clone();$invalid.userId=1;Assert ((Send POST '/api/admin/themes' $invalid).Status -eq 400) 'Unknown field accepted.'
 foreach($change in @(@{primaryColor='red'},@{primaryColor=''},@{foregroundPreset=''},@{primaryColor='#123456;'},@{layoutKey='custom-js'},@{overlayOpacity=86},@{imagePresentation='html'},@{imageGroupId=2147483647},@{themeName=' '})){
  $invalid=$body.Clone();foreach($key in $change.Keys){$invalid[$key]=$change[$key]};Assert ((Send POST '/api/admin/themes' $invalid).Status -eq 400) 'Invalid appearance accepted.'
 }
 $created=Send POST '/api/admin/themes' $body;Assert ($created.Status -eq 200) "Create A failed: $($created.Body)";$a=[int](($created.Body|ConvertFrom-Json).themeId);$ids.Add($a)
 $body.themeName='Theme test B';$body.primaryColor='#002147';$created=Send POST '/api/admin/themes' $body;Assert ($created.Status -eq 200) 'Create B failed.';$b=[int](($created.Body|ConvertFrom-Json).themeId);$ids.Add($b)
 $all=@(Catalog);$rowA=$all|Where-Object themeId -eq $a;$rowB=$all|Where-Object themeId -eq $b
 Assert ($rowA.primaryColor -eq '#234E40' -and $rowB.primaryColor -eq '#002147' -and $rowA.layoutKey -eq $rowB.layoutKey) 'Shared-layout overrides did not roundtrip independently.'
 $noOp=Save $a (Payload $rowA);Assert ($noOp.Status -eq 200) 'No-op failed.';$same=@(Catalog)|Where-Object themeId -eq $a;Assert ($same.lastChangeAt -eq $rowA.lastChangeAt) 'No-op changed timestamp.'
 $makeDefault=Payload $rowA;$makeDefault.isDefault=$true;Assert ((Save $a $makeDefault).Status -eq 200) 'Set default failed.'
 $disable=$makeDefault.Clone();$disable.active=$false;Assert ((Save $a $disable).Status -eq 400) 'Inactive default accepted.'
 $disable=$makeDefault.Clone();$disable.isDefault=$false;Assert ((Save $a $disable).Status -eq 400) 'Default removed without replacement.'
 if($originalSetting.isSaved){
  $settingChanged=$true;Assert ((Send PUT '/api/user-settings/theme' @{themeId=$b} 'theme').Status -eq 204) 'Employee theme selection failed.'
  $inactive=Payload $rowB;$inactive.active=$false;Assert ((Save $b $inactive).Status -eq 200) 'Deactivate B failed.'
  Assert (((Send GET '/api/user-settings/theme').Body|ConvertFrom-Json).themeId -eq $a) 'Inactive saved theme did not fall back.'
  $inactive.active=$true;Assert ((Save $b $inactive).Status -eq 200) 'Reactivate B failed.'
  Assert (((Send GET '/api/user-settings/theme').Body|ConvertFrom-Json).themeId -eq $b) 'Fallback overwrote saved employee preference.'
 }
 $active=(Send GET '/api/themes').Body|ConvertFrom-Json;Assert (@($active|Where-Object isDefault).Count -eq 1) 'Employee catalog has invalid default count.'
 Assert (($active|Where-Object themeId -eq $a).imagePresentation -eq 'artwork') 'Employee catalog omitted appearance.'
 $anonymous=[Net.Http.HttpClient]::new();try{foreach($path in '/api/admin/themes','/api/admin/themes/templates'){$r=$anonymous.GetAsync($BaseUrl+$path).GetAwaiter().GetResult();try{Assert ([int]$r.StatusCode -eq 401) 'Anonymous admin access accepted.'}finally{$r.Dispose()}}}finally{$anonymous.Dispose()}
 Write-Output 'PASS: Swagger/templates, strict fields/header/origin, independent shared-layout themes, full appearance roundtrip, no-op timestamps, active default enforcement, employee fallback and anonymous denial.'
}
finally{
 if($originalDefault){Assert ((Save $originalDefault.themeId (Payload $originalDefault)).Status -eq 200) 'Original default restoration failed.'}
 if($settingChanged){Assert ((Send PUT '/api/user-settings/theme' @{themeId=$originalSetting.themeId} 'theme').Status -eq 204) 'Original employee preference restoration failed.'}
 if($allSettings){
  $restoreConnection=[System.Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=False');$restoreConnection.Open();$restoreTransaction=$restoreConnection.BeginTransaction()
  try{
   foreach($row in $allSettings.Rows){$command=$restoreConnection.CreateCommand();$command.Transaction=$restoreTransaction;$command.CommandText='SET QUOTED_IDENTIFIER ON; UPDATE Portal.UserSettings SET ThemeId=@ThemeId,Active=@Active,LastChangeAt=@Stamp WHERE UserSettingId=@Id;'
    [void]$command.Parameters.AddWithValue('@ThemeId',$row.ThemeId);[void]$command.Parameters.AddWithValue('@Active',$row.Active);[void]$command.Parameters.AddWithValue('@Stamp',$row.LastChangeAt);[void]$command.Parameters.AddWithValue('@Id',$row.UserSettingId);[void]$command.ExecuteNonQuery();$command.Dispose()}
   $restoreTransaction.Commit()
  }catch{$restoreTransaction.Rollback();throw}finally{$restoreTransaction.Dispose();$restoreConnection.Dispose();$allSettings.Dispose()}
 }
 if($ids.Count -gt 0 -or $groupId -gt 0){
  $list=(@(0)+@($ids)) -join ','
  $sql="SET QUOTED_IDENTIFIER ON; SET XACT_ABORT ON; BEGIN TRAN; DELETE FROM Master.Themes WHERE ThemeId IN($list) AND IsDefault=0 AND NOT EXISTS(SELECT 1 FROM Portal.UserSettings s WHERE s.ThemeId=Master.Themes.ThemeId); DELETE FROM Master.ImageGroupItems WHERE ImageGroupId=$groupId AND NOT EXISTS(SELECT 1 FROM Master.Themes t WHERE t.ImageGroupId=$groupId); DELETE FROM Master.ImageGroups WHERE ImageGroupId=$groupId AND NOT EXISTS(SELECT 1 FROM Master.Themes t WHERE t.ImageGroupId=$groupId); COMMIT;"
  & sqlcmd -S localhost -E -b -d CompanyPortal -Q $sql;Assert ($LASTEXITCODE -eq 0) 'Theme test cleanup failed.'
 }
 $client.Dispose()
}
