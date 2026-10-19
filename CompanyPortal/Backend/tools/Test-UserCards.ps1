param([string]$BaseUrl='http://localhost:5081',[switch]$TestSampleRevocation)
$ErrorActionPreference='Stop'
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Request([string]$Method,[string]$Path,[string]$Body='',[hashtable]$Headers=@{},[bool]$Authenticated=$true) {
    $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$Path)
    $request.Method=$Method; $request.UseDefaultCredentials=$Authenticated; $request.AllowAutoRedirect=$false; $request.Timeout=10000
    foreach($key in $Headers.Keys) { $request.Headers[$key]=$Headers[$key] }
    if ($Body) { $bytes=[Text.Encoding]::UTF8.GetBytes($Body); $request.ContentType='application/json'; $request.ContentLength=$bytes.Length; $stream=$request.GetRequestStream(); try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() } }
    try { $response=$request.GetResponse() } catch { $response=$_.Exception.GetBaseException().Response; if (-not $response) { throw } }
    try { $reader=[IO.StreamReader]::new($response.GetResponseStream()); try { $content=$reader.ReadToEnd() } finally { $reader.Dispose() }; return @{Status=[int]$response.StatusCode;Content=$content;Location=$response.Headers['Location']} } finally { $response.Close() }
}
function SampleGrant([int]$AppId,[bool]$Active) {
    Assert (([uri]$BaseUrl).IsLoopback) 'Sample permission tests are local-only.'
    $value=if($Active){1}else{0}
    $query="SET NOCOUNT ON; IF NOT EXISTS(SELECT 1 FROM dbo.Applications WHERE AppId=$AppId AND AppKey IN(N'people-demo',N'support-demo',N'projects-demo')) THROW 50010,'Expected a sample application.',1; UPDATE g SET Active=$value,LastChangeAt=GETDATE() FROM dbo.UserApplicationAccess g JOIN dbo.Users u ON u.UserId=g.UserId WHERE u.NTName=ORIGINAL_LOGIN() AND g.AppId=$AppId; IF @@ROWCOUNT<>1 THROW 50010,'Expected exactly one sample grant.',1;"
    & sqlcmd -S localhost -E -b -I -d SecurityDB -Q $query
    if ($LASTEXITCODE -ne 0) { throw 'Sample grant change failed.' }
}
$header=@{'X-CompanyPortal-Request'='custom-cards'}
$allowed=Request 'GET' '/api/applications'
Assert ($allowed.Status -eq 200) 'Authorized app lookup unavailable.'
$apps=@(($allowed.Content | ConvertFrom-Json) | ForEach-Object { $_ })
Assert ($apps.Count -ge 2) 'Two authorized sample applications are required.'
$before=(Request 'GET' '/api/user-settings/card-order').Content | ConvertFrom-Json
$id=$null; $revoked=$false; $revokeId=[int]$apps[1].appId
try {
    Assert ((Request 'GET' '/api/user-cards' '' @{} $false).Status -eq 401) 'Anonymous read accepted.'
    $body=@{cardName='Custom card API test';appIds=@([int]$apps[0].appId)} | ConvertTo-Json -Compress
    $created=Request 'POST' '/api/user-cards' $body $header
    Assert ($created.Status -eq 201) 'Card creation failed.'
    $id=[int](($created.Content | ConvertFrom-Json).userCardId)
    $card=(Request 'GET' "/api/user-cards/$id").Content | ConvertFrom-Json
    Assert ($card.cardName -eq 'Custom card API test' -and @($card.applications).Count -eq 1) 'Created card differs.'
    $updated=@{cardName='Updated custom card API test';appIds=@($revokeId)} | ConvertTo-Json -Compress
    Start-Sleep -Milliseconds 50
    Assert ((Request 'PUT' "/api/user-cards/$id" $updated $header).Status -eq 204) 'Update failed.'
    $changed=(Request 'GET' "/api/user-cards/$id").Content | ConvertFrom-Json
    Assert ([datetime]$changed.lastChangeAt -gt [datetime]$card.lastChangeAt) 'Change timestamp did not advance.'
    Assert ((Request 'PUT' "/api/user-cards/$id" $updated $header).Status -eq 204) 'No-op update failed.'
    $unchanged=(Request 'GET' "/api/user-cards/$id").Content | ConvertFrom-Json
    Assert ($changed.lastChangeAt -eq $unchanged.lastChangeAt) 'No-op update changed timestamp.'
    Start-Sleep -Milliseconds 50
    $updated=@{cardName=$changed.cardName.ToLowerInvariant();appIds=@($revokeId)} | ConvertTo-Json -Compress
    Assert ((Request 'PUT' "/api/user-cards/$id" $updated $header).Status -eq 204) 'Case-only rename failed.'
    $caseChanged=(Request 'GET' "/api/user-cards/$id").Content | ConvertFrom-Json
    Assert ($caseChanged.cardName -ceq $changed.cardName.ToLowerInvariant()) 'Case-only rename was lost.'
    Assert ([datetime]$caseChanged.lastChangeAt -gt [datetime]$changed.lastChangeAt) 'Case-only rename did not update timestamp.'
    Assert ((Request 'POST' '/api/user-cards' $body).Status -eq 400) 'Missing header accepted.'
    Assert ((Request 'POST' '/api/user-cards' $body @{'X-CompanyPortal-Request'='custom-cards';Origin='https://untrusted.invalid'}).Status -eq 403) 'Untrusted write origin accepted.'
    Assert ((Request 'POST' '/api/user-cards' '{"cardName":"x","appIds":[2147483647]}' $header).Status -eq 400) 'Unauthorized app accepted.'
    Assert ((Request 'POST' '/api/user-cards' '{"cardName":"x","appIds":[]}' $header).Status -eq 400) 'Empty apps accepted.'
    $duplicate=@{cardName='x';appIds=@($revokeId,$revokeId)} | ConvertTo-Json -Compress
    Assert ((Request 'POST' '/api/user-cards' $duplicate $header).Status -eq 400) 'Duplicate apps accepted.'
    $forged=@{cardName='x';appIds=@($revokeId);userId=123} | ConvertTo-Json -Compress
    Assert ((Request 'POST' '/api/user-cards' $forged $header).Status -eq 400) 'Client-selected owner accepted.'
    Assert ((Request 'GET' '/api/user-cards/2147483647').Status -eq 404) 'Missing card read was not 404.'
    Assert ((Request 'PUT' '/api/user-cards/2147483647' $body $header).Status -eq 404) 'Missing card update was not 404.'
    Assert ((Request 'DELETE' '/api/user-cards/2147483647' '' $header).Status -eq 404) 'Missing card delete was not 404.'
    $order=(Request 'GET' '/api/user-settings/card-order').Content | ConvertFrom-Json
    Assert ($order.cardKeys -contains "custom-$id") 'Custom card absent from workspace order.'
    $target=@($order.cardKeys); $source=[Array]::IndexOf($target,"custom-$id")
    $movable=@($order.cards | Where-Object { -not $_.isFixed })[0].cardKey; $destination=[Array]::IndexOf($target,$movable)
    $temp=$target[$destination]; $target[$destination]=$target[$source]; $target[$source]=$temp
    Assert ((Request 'PUT' '/api/user-settings/card-order' (@{cardKeys=$target} | ConvertTo-Json -Compress) @{'X-CompanyPortal-Request'='card-order'}).Status -eq 204) 'Combined order save failed.'
    $read=(Request 'GET' '/api/user-settings/card-order').Content | ConvertFrom-Json
    Assert (($read.cardKeys -join ',') -eq ($target -join ',')) 'Combined order differs.'
    Assert ((Request 'GET' "/api/applications/$revokeId/launch").Status -eq 302) 'Authorized launch did not redirect.'
    Assert ((Request 'GET' '/api/applications/2147483647/launch').Status -eq 404) 'Unauthorized launch accepted.'
    if ($TestSampleRevocation) {
        SampleGrant $revokeId $false; $revoked=$true
        $filtered=(Request 'GET' '/api/applications').Content | ConvertFrom-Json
        Assert (-not ($filtered.appId -contains $revokeId)) 'Revoked app stayed in allowed list.'
        $filteredCard=(Request 'GET' "/api/user-cards/$id").Content | ConvertFrom-Json
        Assert (@($filteredCard.applications).Count -eq 0) 'Revoked app stayed in card read.'
        Assert ((Request 'PUT' "/api/user-cards/$id" $updated $header).Status -eq 400) 'Revoked app save accepted.'
        Assert ((Request 'GET' "/api/applications/$revokeId/launch").Status -eq 404) 'Revoked app launch accepted.'
        SampleGrant $revokeId $true; $revoked=$false
        $restoredCard=(Request 'GET' "/api/user-cards/$id").Content | ConvertFrom-Json
        Assert (@($restoredCard.applications).Count -eq 1) 'Restored grant did not restore authorized card content.'
    }
    Assert ((Request 'DELETE' "/api/user-cards/$id" '' $header).Status -eq 204) 'Card deletion failed.'
    Assert ((Request 'GET' "/api/user-cards/$id").Status -eq 404) 'Deleted card remained readable.'
    $id=$null
    Write-Output 'Custom-card API checks passed: CRUD, owner-input rejection, app authorization/revocation, launch checks, combined order, timestamps and write protection.'
}
finally {
    if ($revoked) { SampleGrant $revokeId $true }
    if ($null -ne $id) { Assert ((Request 'DELETE' "/api/user-cards/$id" '' $header).Status -eq 204) 'Failed to remove the API test card.' }
    Assert ((Request 'PUT' '/api/user-settings/card-order' (@{cardKeys=@($before.cardKeys)} | ConvertTo-Json -Compress) @{'X-CompanyPortal-Request'='card-order'}).Status -eq 204) 'Failed to restore original workspace order.'
}
