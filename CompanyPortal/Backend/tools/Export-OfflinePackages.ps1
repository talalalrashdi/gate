$ErrorActionPreference = 'Stop'

$backendRoot = Split-Path $PSScriptRoot -Parent
$assetsPath = Join-Path $backendRoot 'CompanyPortal.Api/obj/project.assets.json'
if (-not (Test-Path -LiteralPath $assetsPath)) {
    throw 'Restore CompanyPortal.Backend.slnx successfully before exporting packages.'
}

$assets = Get-Content -LiteralPath $assetsPath -Raw | ConvertFrom-Json
$destination = Join-Path $backendRoot 'artifacts/offline-feed'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$count = 0

foreach ($library in $assets.libraries.PSObject.Properties) {
    if ($library.Value.type -ne 'package') { continue }
    $parts = $library.Name.Split('/')
    $fileName = ('{0}.{1}.nupkg' -f $parts[0], $parts[1]).ToLowerInvariant()
    $source = $null
    foreach ($folder in $assets.packageFolders.PSObject.Properties.Name) {
        $candidate = Join-Path (Join-Path $folder $library.Value.path) $fileName
        if (Test-Path -LiteralPath $candidate) { $source = $candidate; break }
    }
    if (-not $source) { throw "Resolved package archive missing: $($library.Name)" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $destination $fileName) -Force
    $count++
}

if ($count -eq 0) { throw 'No resolved packages found; check that restore succeeded.' }
Write-Output "Exported $count resolved package archives to $destination."
