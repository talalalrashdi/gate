param([string]$BaseUrl = 'http://localhost:5081')
$ErrorActionPreference = 'Stop'

function Request([string]$Method = 'GET', [string]$Body = '', [hashtable]$Headers = @{}, [bool]$Authenticated = $true, [string]$Path = '/api/user-settings/card-order') {
    $parameters = @{ Uri=($BaseUrl.TrimEnd('/')+$Path); Method=$Method; Headers=$Headers; UseDefaultCredentials=$Authenticated; UseBasicParsing=$true; ErrorAction='Stop' }
    if ($Body) { $parameters.Body=$Body; $parameters.ContentType='application/json' }
    try {
        $response=Invoke-WebRequest @parameters
        return @{ Status=[int]$response.StatusCode; Content=$response.Content }
    }
    catch {
        $response=$_.Exception.Response
        if (-not $response) { throw }
        $reader=[IO.StreamReader]::new($response.GetResponseStream())
        try { $content=$reader.ReadToEnd() } finally { $reader.Dispose() }
        return @{ Status=[int]$response.StatusCode; Content=$content }
    }
}
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

$initial=Request
Assert ($initial.Status -eq 200) 'Card-order read failed; configure the registered Windows account and migration 008.'
$saved=$initial.Content | ConvertFrom-Json
$original=@($saved.cardKeys)
Assert ($original.Count -ge 2) 'Expected at least two card definitions.'
$header=@{ 'X-CompanyPortal-Request'='card-order' }
try {
    Assert ((Request 'GET' '' @{} $false).Status -eq 401) 'Anonymous read was accepted.'
    $movable=@($saved.cards | Where-Object { -not $_.isFixed } | ForEach-Object { $_.cardKey })
    Assert ($movable.Count -ge 2) 'At least two movable cards are needed for this test.'
    $a=[Array]::IndexOf($original,$movable[0]); $b=[Array]::IndexOf($original,$movable[1])
    $target=@($original); $first=$target[$a]; $target[$a]=$target[$b]; $target[$b]=$first
    $body=@{cardKeys=$target} | ConvertTo-Json -Compress
    Start-Sleep -Milliseconds 50
    Assert ((Request 'PUT' $body $header).Status -eq 204) 'Card-order save failed.'
    $result=(Request).Content | ConvertFrom-Json
    Assert (($result.cardKeys -join ',') -eq ($target -join ',') -and $result.isSaved) 'Order was not persisted.'
    Assert ($null -ne $result.lastChangeAt) 'Missing change timestamp.'
    if ($saved.lastChangeAt) { Assert ([datetime]$result.lastChangeAt -gt [datetime]$saved.lastChangeAt) 'Timestamp did not advance.' }
    Assert ((Request 'PUT' $body $header).Status -eq 204) 'Repeated save failed.'
    $unchanged=(Request).Content | ConvertFrom-Json
    Assert ($unchanged.lastChangeAt -eq $result.lastChangeAt) 'No-op save changed LastChangeAt.'
    $fixed=@($saved.cards | Where-Object isFixed)
    if ($fixed.Count -gt 0) {
        $bad=@($target); $index=[Array]::IndexOf($bad,$fixed[0].cardKey)
        $other=($index+1)%$bad.Count; $value=$bad[$index]; $bad[$index]=$bad[$other]; $bad[$other]=$value
        Assert ((Request 'PUT' (@{cardKeys=$bad} | ConvertTo-Json -Compress) $header).Status -eq 400) 'Fixed position was bypassed.'
    }
    $invalid=@($target); $invalid[0]='unknown-card'
    Assert ((Request 'PUT' (@{cardKeys=$invalid} | ConvertTo-Json -Compress) $header).Status -eq 400) 'Unknown card accepted.'
    $duplicate=@($target); $duplicate[0]=$duplicate[1]
    Assert ((Request 'PUT' (@{cardKeys=$duplicate} | ConvertTo-Json -Compress) $header).Status -eq 400) 'Duplicate card accepted.'
    Assert ((Request 'PUT' (@{cardKeys=@($target[0])} | ConvertTo-Json -Compress) $header).Status -eq 400) 'Incomplete order accepted.'
    Assert ((Request 'PUT' '{"cardKeys":[]}' $header).Status -eq 400) 'Empty order accepted.'
    Assert ((Request 'PUT' '{"cardKeys":null}' $header).Status -eq 400) 'Null order accepted.'
    Assert ((Request 'PUT' (@{cardKeys=$target;userId=123} | ConvertTo-Json -Compress) $header).Status -eq 400) 'Client-selected identity accepted.'
    Assert ((Request 'PUT' $body).Status -eq 400) 'Missing header accepted.'
    Assert ((Request 'PUT' $body @{'X-CompanyPortal-Request'='card-order';Origin='https://untrusted.invalid'}).Status -eq 403) 'Untrusted origin accepted.'
    $final=(Request).Content | ConvertFrom-Json
    Assert (($final.cardKeys -join ',') -eq ($target -join ',') -and $final.lastChangeAt -eq $result.lastChangeAt) 'Rejected requests changed the saved order.'
    Write-Output 'Card-order API checks passed: Windows authentication, save/read, timestamp/no-op, invalid/duplicate/incomplete keys, identity and write protection.'
}
finally {
    Assert ((Request 'PUT' (@{cardKeys=$original} | ConvertTo-Json -Compress) $header).Status -eq 204) 'Could not restore original order.'
    $restored=(Request).Content | ConvertFrom-Json
    Assert (($restored.cardKeys -join ',') -eq ($original -join ',')) 'Restored order differs.'
}
