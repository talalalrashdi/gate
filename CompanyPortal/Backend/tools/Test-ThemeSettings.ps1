param([string]$BaseUrl = 'http://localhost:5081')
$ErrorActionPreference = 'Stop'

function Request([string]$Method = 'GET', [string]$Body = '', [hashtable]$Headers = @{}, [bool]$Authenticated = $true, [string]$Path = '/api/user-settings/theme') {
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
Assert ($initial.Status -eq 200) 'Register/activate the current Windows account in the security database before testing.'
$saved=$initial.Content | ConvertFrom-Json
$catalogResponse=Request 'GET' '' @{} $true '/api/themes'
Assert ($catalogResponse.Status -eq 200) 'Theme catalog unavailable.'
$catalog=@(($catalogResponse.Content | ConvertFrom-Json) | ForEach-Object { $_ })
Assert (@($catalog | Where-Object isDefault).Count -eq 1) 'Expected one default theme.'
$header=@{ 'X-CompanyPortal-Request'='theme' }
try {
    Assert ((Request 'GET' '' @{} $false).Status -eq 401) 'Anonymous requests must be rejected.'
    $target = $catalog | Where-Object { $_.themeId -ne $saved.themeId } | Select-Object -First 1
    Assert ($null -ne $target) 'At least two active test themes are required.'
    $body = @{themeId=$target.themeId} | ConvertTo-Json -Compress
    Start-Sleep -Milliseconds 50
    Assert ((Request 'PUT' $body $header).Status -eq 204) 'Theme save failed.'
    $result=(Request).Content | ConvertFrom-Json
    Assert ($result.themeId -eq $target.themeId -and $result.isSaved) 'ThemeId was not persisted.'
    Assert ($null -ne $result.lastChangeAt) 'LastChangeAt was not returned.'
    if ($saved.lastChangeAt) {
        Assert ([datetime]$result.lastChangeAt -gt [datetime]$saved.lastChangeAt) 'LastChangeAt did not advance when the theme changed.'
    }
    Assert ((Request 'PUT' $body $header).Status -eq 204) 'Repeated theme save failed.'
    $unchanged=(Request).Content | ConvertFrom-Json
    Assert ($unchanged.lastChangeAt -eq $result.lastChangeAt) 'A no-op save changed LastChangeAt.'
    Assert ((Request 'PUT' '{"themeId":-1}' $header).Status -eq 400) 'Invalid ThemeId was accepted.'
    Assert ((Request 'PUT' '{"themeId":2147483647}' $header).Status -eq 400) 'Missing catalog theme was accepted.'
    Assert ((Request 'PUT' '{"themeName":"work"}' $header).Status -eq 400) 'ThemeName must not select a theme.'
    Assert ((Request 'PUT' (@{themeId=$target.themeId;userId=123} | ConvertTo-Json -Compress) $header).Status -eq 400) 'Client-selected UserId was accepted.'
    Assert ((Request 'PUT' $body).Status -eq 400) 'Missing request header was accepted.'
    Assert ((Request 'PUT' $body @{'X-CompanyPortal-Request'='theme';Origin='https://untrusted.invalid'}).Status -eq 403) 'Untrusted write origin was accepted.'
    Write-Output 'Theme API checks passed: authentication, persistence, LastChangeAt changes/no-op stability, validation, identity protection and write-origin/header checks.'
}
finally {
    $restored=Request 'PUT' (@{themeId=$saved.themeId} | ConvertTo-Json -Compress) $header
    Assert ($restored.Status -eq 204) 'Could not restore the original theme.'
}
