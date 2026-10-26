param([string]$ApiBase='http://localhost:5091')
# Magazine tracking is now part of the shared tracker. This includes the magazine regression.
& (Join-Path $PSScriptRoot 'Test-SharedReads.ps1') -ApiBase $ApiBase
