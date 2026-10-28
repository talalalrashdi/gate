param([string]$BaseUrl='http://localhost:5095',[switch]$KeepFixtures)
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local development fixtures only.'}
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true;$client=[Net.Http.HttpClient]::new($handler)
$created=[Collections.Generic.List[int]]::new();$tag='FocalTest-'+[guid]::NewGuid().ToString('N');$passed=$false
function Assert($condition,$message){if(-not $condition){throw $message}}
function Call($path,$method='GET',$body=$null){
 $request=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method),$BaseUrl+$path)
 if($null -ne $body){$request.Headers.Add('X-CompanyPortal-Request','admin-themes');$request.Content=[Net.Http.StringContent]::new(($body|ConvertTo-Json -Depth 8 -Compress),[Text.Encoding]::UTF8,'application/json')}
 try{$r=$client.SendAsync($request).GetAwaiter().GetResult();try{@{status=[int]$r.StatusCode;text=$r.Content.ReadAsStringAsync().GetAwaiter().GetResult()}}finally{$r.Dispose()}}finally{$request.Dispose()}
}
function Read($path){$r=Call $path;Assert ($r.status -eq 200) "$path : $($r.status) $($r.text)";$r.text|ConvertFrom-Json}
try{
 $library=Read '/api/admin/images';$group=$null;$members=@()
 foreach($g in @($library.groups|Where-Object active|Sort-Object imageGroupId -Descending)){
  $candidate=@($library.items|Where-Object {$_.imageGroupId -eq $g.imageGroupId -and $_.active -and $_.imageId -in $library.images.imageId})
  if($candidate.Count -ge 2){$group=$g;$members=$candidate;break}
 }
 Assert ($null -ne $group) 'Need an existing active group with two images.'
 $points=@(@{imageId=$members[0].imageId;focalX=12.5;focalY=88.25},@{imageId=$members[1].imageId;focalX=95;focalY=5})
 $body=@{themeName=$tag+' A';layoutKey='official';displayOrder=999;active=$false;isDefault=$false;visibility='hidden';previewRoles=@();imagePresentation='background';imageGroupId=$group.imageGroupId;imagePositions=$points}
 $r=Call '/api/admin/themes' 'POST' $body;Assert ($r.status -eq 200) $r.text;$id=($r.text|ConvertFrom-Json).themeId;$created.Add($id)
 $bodyB=$body.Clone();$bodyB.themeName=$tag+' B';$bodyB.imagePositions=@(@{imageId=$members[0].imageId;focalX=80;focalY=20})
 $r=Call '/api/admin/themes' 'POST' $bodyB;Assert ($r.status -eq 200) $r.text;$idB=($r.text|ConvertFrom-Json).themeId;$created.Add($idB)
 $rows=@(Read '/api/admin/themes');$a=$rows|Where-Object themeId -eq $id;$b=$rows|Where-Object themeId -eq $idB
 Assert ($a.imagePositions.Count -eq 2 -and ($a.imagePositions|Where-Object imageId -eq $members[0].imageId).focalY -eq 88.25) 'Position reload failed.'
 Assert ($b.imagePositions[0].focalX -eq 80) 'Themes share the same image position.'
 $at=$a.lastChangeAt
 Assert ((Call "/api/admin/themes/$id" 'PUT' $body).status -eq 200) 'No-op failed.'
 Assert (((Read '/api/admin/themes'|Where-Object themeId -eq $id).lastChangeAt) -eq $at) 'No-op changed timestamp.'
 $bad=$body.Clone();$bad.imagePositions=@(@{imageId=$members[0].imageId;focalX=101;focalY=50});Assert ((Call "/api/admin/themes/$id" 'PUT' $bad).status -eq 400) 'Out-of-range coordinate accepted.'
 $bad.imagePositions=@($points[0],$points[0]);Assert ((Call "/api/admin/themes/$id" 'PUT' $bad).status -eq 400) 'Duplicate position accepted.'
 $bad.imagePositions=@(@{imageId=$members[0].imageId});Assert ((Call "/api/admin/themes/$id" 'PUT' $bad).status -eq 400) 'Missing coordinates accepted.'
 $bad.imagePositions=@(@{imageId=2147483647;focalX=50;focalY=50});$bad.themeName='Must roll back';Assert ((Call "/api/admin/themes/$id" 'PUT' $bad).status -eq 400) 'Unknown image accepted.'
 Assert ((Read '/api/admin/themes'|Where-Object themeId -eq $id).themeName -eq $body.themeName) 'Rejected positions partly saved the theme.'
 $body.active=$true;$body.visibility='public'
 Assert ((Call "/api/admin/themes/$id" 'PUT' $body).status -eq 200) 'Publish fixture failed.'
 $employee=Read "/api/themes/$id/images";$first=$employee.images|Where-Object imageId -eq $members[0].imageId
 Assert ($first.focalX -eq 12.5 -and $first.focalY -eq 88.25) 'Employee image API lost positions.'
 $legacy=$body.Clone();$legacy.Remove('imagePositions')
 Assert ((Call "/api/admin/themes/$id" 'PUT' $legacy).status -eq 200) 'Legacy save failed.'
 Assert ((Read '/api/admin/themes'|Where-Object themeId -eq $id).imagePositions.Count -eq 2) 'Legacy save erased positions.'
 $body.imagePositions=@();Assert ((Call "/api/admin/themes/$id" 'PUT' $body).status -eq 200) 'Reset failed.'
 Assert ((Read '/api/admin/themes'|Where-Object themeId -eq $id).imagePositions.Count -eq 0) 'Clear did not remove overrides.'
 $body.imagePositions=$points;Assert ((Call "/api/admin/themes/$id" 'PUT' $body).status -eq 200) 'Restore fixture positions failed.'
 $swagger=Read '/swagger/v1/swagger.json';Assert ($null -ne $swagger.components.schemas.SaveAdminTheme.properties.imagePositions) 'Swagger missing positions.'
 'PASS: per-theme/per-image persistence, employee DTO, no-op timestamp, atomic invalid-input rollback, bounds/duplicates/missing coordinates, legacy omission, clear/reset and Swagger.'
 $passed=$true
 if($KeepFixtures){$folder=Join-Path $PSScriptRoot '../../../.local/theme-focus';New-Item -ItemType Directory -Path $folder -Force|Out-Null;@{themeId=$id;secondThemeId=$idB;tag=$tag;groupId=$group.imageGroupId;imageId=$members[0].imageId}|ConvertTo-Json|Set-Content (Join-Path $folder 'fixture.json');Write-Output "Kept $id and $idB for browser checks."}
}finally{
 if(-not ($KeepFixtures -and $passed) -and $created.Count){
  $c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$c.Open()
  try{foreach($id in $created){$cmd=$c.CreateCommand();$cmd.CommandText='IF EXISTS(SELECT 1 FROM Master.Themes WHERE ThemeId=@Id AND ThemeName LIKE @Tag AND IsDefault=0) BEGIN DELETE Master.ThemeImagePositions WHERE ThemeId=@Id; DELETE Master.ThemePreviewRoles WHERE ThemeId=@Id; DELETE Master.Themes WHERE ThemeId=@Id; END';[void]$cmd.Parameters.AddWithValue('@Id',$id);[void]$cmd.Parameters.AddWithValue('@Tag',$tag+'%');[void]$cmd.ExecuteNonQuery()}}finally{$c.Dispose()}
 }
 $client.Dispose()
}
