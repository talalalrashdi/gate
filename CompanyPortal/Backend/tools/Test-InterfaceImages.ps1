param([string]$BaseUrl='http://localhost:5081', [switch]$KeepFixtures)
$ErrorActionPreference='Stop'
if (-not ([uri]$BaseUrl).IsLoopback) { throw 'Run only against the local development API.' }
Add-Type -AssemblyName System.Net.Http
function Assert($value,[string]$message) { if(-not $value){throw $message} }
$handler=[Net.Http.HttpClientHandler]::new(); $handler.UseDefaultCredentials=$true
$client=[Net.Http.HttpClient]::new($handler); $client.Timeout=[timespan]::FromSeconds(30)
$client.DefaultRequestHeaders.Add('X-CompanyPortal-Request','admin-images')
function Send([string]$method,[string]$path,$body=$null,[bool]$header=$true,[string]$origin='') {
    $req=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($method),$BaseUrl.TrimEnd('/')+$path)
    if($null -ne $body){$req.Content=[Net.Http.StringContent]::new(($body|ConvertTo-Json -Depth 8 -Compress),[Text.Encoding]::UTF8,'application/json')}
    if($origin){$req.Headers.Add('Origin',$origin)}
    if(-not $header){$req.Headers.Add('X-CompanyPortal-Request','wrong-header')}
    try{$res=$client.SendAsync($req).GetAwaiter().GetResult();try{return @{Status=[int]$res.StatusCode;Body=$res.Content.ReadAsStringAsync().GetAwaiter().GetResult()}}finally{$res.Dispose()}}finally{$req.Dispose()}
}
function Upload([string]$name,[byte[]]$bytes,[string]$mime='image/svg+xml') {
    $body=[Net.Http.MultipartFormDataContent]::new();$file=[Net.Http.ByteArrayContent]::new($bytes)
    $file.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::new($mime);$body.Add($file,'file',$name)
    try{$res=$client.PostAsync($BaseUrl.TrimEnd('/')+'/api/admin/images',$body).GetAwaiter().GetResult();try{return @{Status=[int]$res.StatusCode;Body=$res.Content.ReadAsStringAsync().GetAwaiter().GetResult()}}finally{$res.Dispose()}}finally{$body.Dispose()}
}
$imageIds=[Collections.Generic.List[int]]::new();$groupIds=[Collections.Generic.List[int]]::new();$original=$null;$themeId=0
try {
    $swagger=Send GET '/swagger/v1/swagger.json';Assert ($swagger.Status -eq 200) 'Swagger document generation failed.'
    $document=$swagger.Body|ConvertFrom-Json
    Assert ($null -ne $document.paths.'/api/admin/images'.post.requestBody.content.'multipart/form-data') 'Swagger upload form is missing.'
    $before=Send GET '/api/admin/images';Assert ($before.Status -eq 200) 'Admin catalog failed.'
    $catalog=$before.Body|ConvertFrom-Json;$theme=$catalog.themes|Where-Object layoutKey -eq 'official'|Select-Object -First 1
    $themeId=[int]$theme.themeId;$original=$theme.imageGroupId
    $svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="700" viewBox="0 0 1200 700"><rect width="1200" height="700" fill="#234e40"/><circle cx="900" cy="180" r="90" fill="#d4bb7c"/><path d="M0 700L350 220L800 700Z" fill="#638970"/></svg>'
    foreach($suffix in 1,2){$upload=Upload "interface-test-$suffix.svg" ([Text.Encoding]::UTF8.GetBytes($svg.Replace('#234e40',$(if($suffix -eq 1){'#234e40'}else{'#6b433f'}))));Assert ($upload.Status -eq 200) "SVG upload failed: $($upload.Body)";$imageIds.Add([int](($upload.Body|ConvertFrom-Json).imageId))}
    $deletable=Upload 'interface-delete-test.svg' ([Text.Encoding]::UTF8.GetBytes($svg))
    Assert ($deletable.Status -eq 200) 'Delete fixture upload failed.'
    $deleteId=[int](($deletable.Body|ConvertFrom-Json).imageId)
    Assert ((Send DELETE "/api/admin/images/$deleteId" $null $false).Status -eq 400) 'Delete accepted incorrect request header.'
    Assert ((Send DELETE "/api/admin/images/$deleteId" $null $true 'https://untrusted.invalid').Status -eq 403) 'Delete accepted untrusted origin.'
    Assert ((Send DELETE "/api/admin/images/$deleteId").Status -eq 204) 'Unused image deletion failed.'
    Assert ((Send DELETE "/api/admin/images/$deleteId").Status -eq 404) 'Repeated deletion should be not found.'
    Assert ((Send GET "/api/images/$deleteId/content").Status -eq 404) 'Deleted content is still accessible.'
    Assert (-not @(((Send GET '/api/admin/images').Body|ConvertFrom-Json).images|Where-Object imageId -eq $deleteId).Count) 'Deleted image remains in library.'
    $pngPath=Join-Path $PSScriptRoot '../../Frontend/CompanyPortal.Web/wwwroot/assets/hero-oman-fort.png'
    $png=Upload 'interface-test.png' ([IO.File]::ReadAllBytes([IO.Path]::GetFullPath($pngPath))) 'text/plain'
    Assert ($png.Status -eq 200) 'PNG signature detection failed.';$imageIds.Add([int](($png.Body|ConvertFrom-Json).imageId))
    $formats=@(
        @{name='interface-test.jpg';data='/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDgqKKKzPEP/9k='},
        @{name='interface-test-lossy.webp';data='UklGRjAAAABXRUJQVlA4ICQAAABwAQCdASoCAAIAAUAmJZgCdAF1AAD+9bf6v/+Fa/la/lat8AA='},
        @{name='interface-test-lossless.webp';data='UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAAAdQrWaUp/+BiOh/AAA='},
        @{name='interface-test-alpha.webp';data='UklGRlIAAABXRUJQVlA4WAoAAAAQAAAAAQAAAQAAQUxQSAUAAAAAeHh4eABWUDggJgAAAHABAJ0BKgIAAgABQCYlmAJ0AXUAAP71t/vd/+Fa/la/lat8AAAA'}
    )
    foreach($format in $formats){$r=Upload $format.name ([Convert]::FromBase64String($format.data));Assert ($r.Status -eq 200) "Raster upload failed: $($format.name) $($r.Body)";$imageIds.Add([int](($r.Body|ConvertFrom-Json).imageId))}
    $artworkPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Frontend/CompanyPortal.Web/wwwroot/assets/national-day-complete.svg'))
    $artwork=[IO.File]::ReadAllBytes($artworkPath)
    $animated=Upload 'interface-test-animated.svg' $artwork
    Assert ($animated.Status -eq 200) "Bundled animated SVG failed: $($animated.Body)"
    $animatedId=[int](($animated.Body|ConvertFrom-Json).imageId);$imageIds.Add($animatedId)
    $animatedResponse=$client.GetAsync($BaseUrl+"/api/images/$animatedId/content").GetAwaiter().GetResult()
    try{Assert (($animatedResponse.Headers.GetValues('Content-Security-Policy') -join ';').Contains("img-src data:")) 'Bundled SVG image policy missing.'}finally{$animatedResponse.Dispose()}
    $tampered=[Text.Encoding]::UTF8.GetBytes([Text.Encoding]::UTF8.GetString($artwork).Replace('</svg>','<script>alert(1)</script></svg>'))
    Assert ((Upload 'national-day-complete.svg' $tampered).Status -eq 400) 'Modified bundled artwork was trusted by filename.'
    foreach($bad in @(
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><script>alert(1)</script></svg>',
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" onload="alert(1)"/>',
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://external.invalid/x"/></svg>',
        '<!DOCTYPE svg [<!ENTITY x SYSTEM "file:///c:/windows/win.ini">]><svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">&x;</svg>',
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect style="fill:red"/></svg>'
    )){Assert ((Upload 'unsafe.svg' ([Text.Encoding]::UTF8.GetBytes($bad))).Status -eq 400) 'Unsafe SVG accepted.'}
    Assert ((Upload 'fake.png' ([Text.Encoding]::UTF8.GetBytes('This is not a PNG image.'))).Status -eq 400) 'Fake PNG accepted.'
    $members=@(@{imageId=$imageIds[0];displayOrder=1;active=$true},@{imageId=$imageIds[1];displayOrder=2;active=$true})
    $group=@{groupName='Interface test group';rotateImages=$true;rotationSeconds=3;defaultImageId=$imageIds[1];active=$true;items=$members}
    Assert ((Send POST '/api/admin/images/groups' $group $false).Status -eq 400) 'Missing write header accepted.'
    Assert ((Send POST '/api/admin/images/groups' $group $true 'https://untrusted.invalid').Status -eq 403) 'Untrusted write origin accepted.'
    $invalid=$group.Clone();$invalid.userId=1;Assert ((Send POST '/api/admin/images/groups' $invalid).Status -eq 400) 'Unknown JSON field accepted.'
    $invalid=$group.Clone();$invalid.items=@($null);Assert ((Send POST '/api/admin/images/groups' $invalid).Status -eq 400) 'Null image member accepted.'
    $created=Send POST '/api/admin/images/groups' $group;Assert ($created.Status -eq 200) "Group create failed: $($created.Body)"
    $id=[int](($created.Body|ConvertFrom-Json).imageGroupId);$groupIds.Add($id)
    Assert ((Send DELETE "/api/admin/images/$($imageIds[0])").Status -eq 409) 'Linked image deletion was not blocked.'
    $snapshot=((Send GET '/api/admin/images').Body|ConvertFrom-Json).groups|Where-Object imageGroupId -eq $id
    Assert ((Send PUT "/api/admin/images/groups/$id" $group).Status -eq 200) 'No-op group save failed.'
    $same=((Send GET '/api/admin/images').Body|ConvertFrom-Json).groups|Where-Object imageGroupId -eq $id
    Assert ($same.lastChangeAt -eq $snapshot.lastChangeAt) 'No-op changed group timestamp.'
    Assert ((Send PUT "/api/admin/images/themes/$themeId/group" @{imageGroupId=$id}).Status -eq 204) 'Theme assignment failed.'
    $settings=(Send GET "/api/themes/$themeId/images").Body|ConvertFrom-Json
    Assert ($settings.images.Count -eq 2 -and $settings.settings.defaultImageId -eq $imageIds[1] -and $settings.settings.rotateImages) 'Published group differs.'
    $content=Send GET "/api/images/$($imageIds[0])/content";Assert ($content.Status -eq 200 -and $content.Body.Contains('<svg')) 'SVG content failed.'
    $group.defaultImageId=$imageIds[2];Assert ((Send PUT "/api/admin/images/groups/$id" $group).Status -eq 400) 'Nonmember default accepted.';$group.defaultImageId=$imageIds[1]
    $group.rotateImages=$false;Assert ((Send PUT "/api/admin/images/groups/$id" $group).Status -eq 200) 'Static setting failed.'
    Assert (-not (((Send GET "/api/themes/$themeId/images").Body|ConvertFrom-Json).settings.rotateImages)) 'Static setting not persisted.'
    $group.items=@(@{imageId=$imageIds[1];displayOrder=1;active=$true});Assert ((Send PUT "/api/admin/images/groups/$id" $group).Status -eq 200) 'Remove/reorder failed.'
    $settings=(Send GET "/api/themes/$themeId/images").Body|ConvertFrom-Json;Assert ($settings.images.Count -eq 1 -and $settings.images[0].imageId -eq $imageIds[1]) 'Removed member is still published.'
    $group.active=$false;Assert ((Send PUT "/api/admin/images/groups/$id" $group).Status -eq 200) 'Group deactivation failed.'
    Assert ($null -eq (((Send GET "/api/themes/$themeId/images").Body|ConvertFrom-Json).settings)) 'Inactive group published.'
    $group.active=$true;$group.rotateImages=$true;$group.items=$members
    Assert ((Send PUT "/api/admin/images/groups/$id" $group).Status -eq 200) 'Restore fixture group failed.'
    $anonymous=[Net.Http.HttpClient]::new()
    try{foreach($route in '/api/admin/images',"/api/themes/$themeId/images","/api/images/$($imageIds[0])/content"){$r=$anonymous.GetAsync($BaseUrl+$route).GetAwaiter().GetResult();try{Assert ([int]$r.StatusCode -eq 401) 'Anonymous image access accepted.'}finally{$r.Dispose()}}}finally{$anonymous.Dispose()}
    Write-Output "PASS: protected image deletion, linked-image conflict, uploads, passive SVG checks, signature checks, group save/order/removal/default/rotation/active state, theme assignment, content and anonymous denial."
    if($KeepFixtures){Write-Output ("Fixtures kept for browser verification: group {0}; image IDs {1}; original theme group {2}." -f $id,($imageIds -join ','),$original)}
}
finally {
    if($themeId -gt 0){$restore=Send PUT "/api/admin/images/themes/$themeId/group" @{imageGroupId=$original};Assert ($restore.Status -eq 204) 'Original theme image group could not be restored.'}
    if(-not $KeepFixtures -and $imageIds.Count -gt 0){
        $groups=(@(0)+@($groupIds)) -join ',';$images=(@($imageIds)+@($deleteId)) -join ','
        $sql="SET XACT_ABORT ON; BEGIN TRAN; DELETE FROM Master.ImageGroupItems WHERE ImageGroupId IN ($groups); DELETE FROM Master.ImageGroups WHERE ImageGroupId IN ($groups) AND NOT EXISTS(SELECT 1 FROM Master.Themes t WHERE t.ImageGroupId=Master.ImageGroups.ImageGroupId); DELETE FROM Master.Images WHERE ImageId IN ($images) AND NOT EXISTS(SELECT 1 FROM Master.ImageGroupItems m WHERE m.ImageId=Master.Images.ImageId) AND NOT EXISTS(SELECT 1 FROM Master.ImageGroups g WHERE g.DefaultImageId=Master.Images.ImageId); COMMIT;"
        & sqlcmd -S localhost -E -b -d CompanyPortal -Q $sql
        Assert ($LASTEXITCODE -eq 0) 'Fixture cleanup failed.'
    }
    $client.Dispose()
}
