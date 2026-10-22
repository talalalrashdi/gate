param([string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts/Airgap'))
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$target = [IO.Path]::GetFullPath($OutputDirectory)
foreach ($project in @(
 @{ Path='Frontend/CompanyPortal.Web/CompanyPortal.Web.csproj'; Folder='Frontend' },
 @{ Path='Backend/CompanyPortal.Api/CompanyPortal.Api.csproj'; Folder='Backend' }
)) {
 # Restore the current locked dependencies on the connected machine before running this.
 # Framework-dependent: target IIS machine needs the .NET 10 x64 Hosting Bundle.
 & dotnet publish (Join-Path $root $project.Path) -c Release --no-restore --self-contained false -p:UseAppHost=false -o (Join-Path $target $project.Folder)
 if ($LASTEXITCODE -ne 0) { throw "Publish failed for $($project.Folder)." }
}
foreach ($folder in 'Deployment','docs') {
 $destination=Join-Path $target $folder
 New-Item -ItemType Directory -Path $destination -Force | Out-Null
 Copy-Item (Join-Path $root "$folder/*") $destination -Recurse -Force
}
Copy-Item (Join-Path $root 'docs/AIRGAP_IIS_GUIDE.md') (Join-Path $target 'AIRGAP_IIS_GUIDE.md') -Force
$integration=Join-Path $target 'Deployment/Integration'
New-Item -ItemType Directory -Path $integration -Force | Out-Null
Copy-Item (Join-Path $root 'Backend/Database/Integration/*') $integration -Recurse -Force
Write-Output "Copy the entire $target folder and the Hosting Bundle installer to the offline network."
Write-Output 'Edit the example configuration files before installing them as appsettings.Production.json.'
