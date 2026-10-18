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
    Assert ((Request 'PUT' '{"theme":"formal"}' $header).Status -eq 204) 'Theme save failed.'
    $result=(Request).Content | ConvertFrom-Json
    Assert ($result.theme -eq 'formal' -and $result.isSaved) 'Theme was not persisted.'
    Assert ((Request 'PUT' '{"theme":"invalid"}' $header).Status -eq 400) 'Invalid theme was accepted.'
    Assert ((Request 'PUT' '{"theme":"formal","userId":123}' $header).Status -eq 400) 'Client-selected UserId was accepted.'
    Assert ((Request 'PUT' '{"theme":"formal"}').Status -eq 400) 'Missing request header was accepted.'
    Assert ((Request 'PUT' '{"theme":"formal"}' @{'X-CompanyPortal-Request'='theme';Origin='https://untrusted.invalid'}).Status -eq 403) 'Untrusted write origin was accepted.'
    Write-Output 'Theme API checks passed: authentication, persistence, validation, identity protection and write-origin/header checks.'
}
finally {
    $restored=Request 'PUT' (@{theme=$saved.theme} | ConvertTo-Json -Compress) $header
    Assert ($restored.Status -eq 204) 'Could not restore the original theme.'
}
