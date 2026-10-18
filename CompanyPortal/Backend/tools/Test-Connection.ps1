param(
    [string]$ApiUrl = 'http://localhost:5081',
    [string]$FrontendUrl = 'http://localhost:5080',
    [switch]$Production,
    [switch]$ExpectDatabaseUnavailable,
    [switch]$ExpectApiUnavailable
)

$ErrorActionPreference = 'Stop'

function Read-Response([string]$Url, [bool]$WindowsCredentials) {
    try {
        $result = Invoke-WebRequest -Uri $Url -UseBasicParsing -UseDefaultCredentials:$WindowsCredentials -ErrorAction Stop
        return @{ Status = [int]$result.StatusCode; Content = $result.Content; Headers = $result.Headers }
    }
    catch {
        $result = $_.Exception.Response
        if (-not $result) { throw }
        $reader = New-Object System.IO.StreamReader($result.GetResponseStream())
        try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return @{ Status = [int]$result.StatusCode; Content = $content; Headers = $result.Headers }
    }
}

if ($Production) {
    $api = Read-Response ($ApiUrl.TrimEnd('/') + '/api/diagnostics/database') $true
    $frontend = Read-Response ($FrontendUrl.TrimEnd('/') + '/diagnostics/connection') $false
    if ($api.Status -ne 404 -or $frontend.Status -ne 404) { throw 'Diagnostic routes must be unavailable in Production.' }
    Write-Output 'Both diagnostic routes return 404 in Production.'
    exit 0
}

if (-not $ExpectApiUnavailable) {
    $anonymous = Read-Response ($ApiUrl.TrimEnd('/') + '/api/diagnostics/database') $false
    if ($anonymous.Status -ne 401) { throw 'The database check must require Windows authentication.' }
    $database = Read-Response ($ApiUrl.TrimEnd('/') + '/api/diagnostics/database') $true
    if ($ExpectDatabaseUnavailable) {
        if ($database.Status -ne 503) { throw 'Expected database failure to return 503.' }
        $problem = $database.Content | ConvertFrom-Json
        if ($problem.title -ne 'Database connection check failed.') { throw 'Unexpected database error response.' }
        if ($database.Content -match 'ConnectionString|SqlException|Server=|StackTrace') { throw 'Database diagnostics leaked internal details.' }
    }
    else {
        if ($database.Status -ne 200) { throw 'The API could not query SQL Server.' }
        $data = $database.Content | ConvertFrom-Json
        if ($data.status -ne 'Connected' -or $data.databaseName -ne 'CompanyPortal') { throw 'Unexpected database check result.' }
        $swagger = (Read-Response ($ApiUrl.TrimEnd('/') + '/swagger/v1/swagger.json') $true).Content | ConvertFrom-Json
        if (-not $swagger.paths.'/api/diagnostics/database'.get) { throw 'Database diagnostics missing from Swagger.' }
    }
}

$page = Read-Response ($FrontendUrl.TrimEnd('/') + '/diagnostics/connection') $false
if ($ExpectDatabaseUnavailable -or $ExpectApiUnavailable) {
    if ($page.Status -ne 503 -or $page.Content -notmatch 'data-connection-status="failed"') { throw 'Frontend did not show a connection failure.' }
    if ($page.Content -match 'data-database-name') { throw 'Frontend displayed a stale success result.' }
}
else {
    if ($page.Status -ne 200 -or $page.Content -notmatch 'data-connection-status="connected"') { throw 'Frontend connection check did not pass.' }
    if ($page.Content -notmatch 'data-database-name>CompanyPortal') { throw 'Frontend did not show the database returned by the API.' }
}
if ($page.Headers['Cache-Control'] -notmatch 'no-store') { throw 'Connection results must not be cached.' }

$scenario = if ($ExpectApiUnavailable) { 'API unavailable' } elseif ($ExpectDatabaseUnavailable) { 'database unavailable' } else { 'frontend -> Windows-authenticated API -> SQL connected' }
Write-Output "Connection checks passed: $scenario; expected status and no stale results."
