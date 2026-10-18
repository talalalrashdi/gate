param([string]$BaseUrl = 'http://localhost:5081')
$ErrorActionPreference = 'Stop'
$endpoint = $BaseUrl.TrimEnd('/') + '/api/user-settings/theme'

function Request([string]$Method = 'GET', [string]$Body = '', [hashtable]$Headers = @{}, [bool]$Authenticated = $true) {
    $parameters = @{ Uri=$endpoint; Method=$Method; Headers=$Headers; UseDefaultCredentials=$Authenticated; UseBasicParsing=$true; ErrorAction='Stop' }
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
Assert ($initial.Status -eq 200) 'Register/activate the current Windows account in the security database before testing.'
$saved=$initial.Content | ConvertFrom-Json
$header=@{ 'X-CompanyPortal-Request'='theme' }
try {
    Assert ((Request 'GET' '' @{} $false).Status -eq 401) 'Anonymous requests must be rejected.'
    $target = if ($saved.themeName -eq 'work') { 'national-day' } else { 'work' }
    $body = @{themeName=$target} | ConvertTo-Json -Compress
    Start-Sleep -Milliseconds 50
    Assert ((Request 'PUT' $body $header).Status -eq 204) 'Theme save failed.'
    $result=(Request).Content | ConvertFrom-Json
    Assert ($result.themeName -eq $target -and $result.isSaved) 'Theme was not persisted.'
    Assert ($null -ne $result.lastChangeAt) 'LastChangeAt was not returned.'
    if ($saved.lastChangeAt) {
        Assert ([datetime]$result.lastChangeAt -gt [datetime]$saved.lastChangeAt) 'LastChangeAt did not advance when the theme changed.'
    }
    Assert ((Request 'PUT' $body $header).Status -eq 204) 'Repeated theme save failed.'
    $unchanged=(Request).Content | ConvertFrom-Json
    Assert ($unchanged.lastChangeAt -eq $result.lastChangeAt) 'A no-op save changed LastChangeAt.'
    Assert ((Request 'PUT' '{"themeName":"invalid"}' $header).Status -eq 400) 'Invalid theme was accepted.'
    foreach ($legacyName in @('majestic', 'formal')) {
        Assert ((Request 'PUT' (@{themeName=$legacyName} | ConvertTo-Json -Compress) $header).Status -eq 400) 'A retired theme name was accepted.'
    }
    Assert ((Request 'PUT' '{"themeName":"work","userId":123}' $header).Status -eq 400) 'Client-selected UserId was accepted.'
    Assert ((Request 'PUT' '{"themeName":"work"}').Status -eq 400) 'Missing request header was accepted.'
    Assert ((Request 'PUT' '{"themeName":"work"}' @{'X-CompanyPortal-Request'='theme';Origin='https://untrusted.invalid'}).Status -eq 403) 'Untrusted write origin was accepted.'
    Write-Output 'Theme API checks passed: authentication, persistence, LastChangeAt changes/no-op stability, validation, identity protection and write-origin/header checks.'
}
finally {
    $restored=Request 'PUT' (@{themeName=$saved.themeName} | ConvertTo-Json -Compress) $header
    Assert ($restored.Status -eq 204) 'Could not restore the original theme.'
}
