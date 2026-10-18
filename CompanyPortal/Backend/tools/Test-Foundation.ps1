param(
    [string]$BaseUrl = 'http://localhost:5081',
    [switch]$Production
)

$ErrorActionPreference = 'Stop'

function Request([string]$Path, [int]$ExpectedStatus, [bool]$Authenticated = $false, [string]$Method = 'GET') {
    $parameters = @{
        Uri = $BaseUrl.TrimEnd('/') + $Path
        Method = $Method
        UseBasicParsing = $true
        UseDefaultCredentials = $Authenticated
        ErrorAction = 'Stop'
    }
    try {
        $response = Invoke-WebRequest @parameters
        $status = [int]$response.StatusCode
        $content = $response.Content
        $headers = $response.Headers
    }
    catch {
        $response = $_.Exception.Response
        if (-not $response) { throw }
        $status = [int]$response.StatusCode
        $headers = $response.Headers
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    if ($status -ne $ExpectedStatus) { throw "$Method $Path expected $ExpectedStatus, received $status." }
    return @{ Content = $content; Headers = $headers }
}

# IIS can intentionally require authentication for health as well.
$health = Request '/health' 200 $Production.IsPresent
if ($health.Content.Trim() -ne 'Healthy') { throw 'Unexpected liveness response.' }
$challenge = Request '/api/me' 401
if ($challenge.Headers['WWW-Authenticate'] -notmatch 'Negotiate|NTLM') { throw 'Missing Windows authentication challenge.' }
$me = Request '/api/me' 200 $true
$identity = $me.Content | ConvertFrom-Json
if (-not $identity.accountName -or -not $identity.authenticationType) { throw 'No authenticated Windows identity returned.' }
if ($me.Headers['Cache-Control'] -notmatch 'no-store') { throw 'Identity response must not be cached.' }

if ($Production) {
    Request '/swagger/index.html' 404 $true | Out-Null
    Request '/swagger/v1/swagger.json' 404 $true | Out-Null
}
else {
    $swagger = Request '/swagger/index.html' 200 $true
    if ($swagger.Content -notmatch 'Swagger UI') { throw 'Swagger UI not served.' }
    $schema = (Request '/swagger/v1/swagger.json' 200 $true).Content | ConvertFrom-Json
    if (-not $schema.paths.'/api/me'.get) { throw 'Identity endpoint is missing from Swagger.' }
    foreach ($asset in @('/swagger/swagger-ui.css', '/swagger/swagger-ui-bundle.js', '/swagger/swagger-ui-standalone-preset.js')) {
        Request $asset 200 $true | Out-Null
    }
}

Request '/api/not-an-endpoint' 404 $true | Out-Null
$methodError = Request '/api/me' 405 $true 'POST'
$problem = $methodError.Content | ConvertFrom-Json
if ($problem.status -ne 405 -or -not $problem.title) { throw 'Expected a Problem Details error response.' }

Write-Output 'API checks passed: liveness, Windows challenge/identity, no-store, Swagger behavior, routes and Problem Details. Account details were not exported.'
