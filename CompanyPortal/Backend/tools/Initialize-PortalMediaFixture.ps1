param([string]$SampleVideoPath='')
# LOCAL DEVELOPMENT ONLY. Uses already generated sample video; no runtime FFmpeg dependency.
$ErrorActionPreference='Stop'
$backend=Split-Path $PSScriptRoot -Parent
$company=Split-Path $backend -Parent
$root=Join-Path $backend 'artifacts\media-fixture'
$clip=if($SampleVideoPath){[IO.Path]::GetFullPath($SampleVideoPath)}elseif(Test-Path -LiteralPath (Join-Path $root 'team.mp4')){Join-Path $root 'team.mp4'}else{Join-Path $company '..\.local\media-tools\sample.mp4'}
if(-not(Test-Path -LiteralPath $clip)){throw 'Generate the local development MP4 first; see docs/PORTAL_MEDIA.md.'}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
try{
 $c.Open();$q=$c.CreateCommand();$q.CommandText="IF NOT EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'PortalMedia') INSERT Mstr.Utls([Key],strVal) VALUES(N'PortalMedia',@Root); SELECT strVal FROM Mstr.Utls WHERE [Key]=N'PortalMedia' AND Active=1"
 [void]$q.Parameters.AddWithValue('@Root',$root);$actual=[string]$q.ExecuteScalar()
 if(-not $actual -or [IO.Path]::GetFullPath($actual).TrimEnd('\') -ne [IO.Path]::GetFullPath($root).TrimEnd('\')){throw 'Refusing to write sample files outside the expected local fixture root.'}
}finally{$c.Dispose()}
[void][IO.Directory]::CreateDirectory($root)
$assets=Join-Path $company 'Frontend\CompanyPortal.Web\wwwroot\assets'
foreach($pair in @(@('hero-oman-fort.png','fort.png'),@('hero-oman-mosque.png','mosque.png'),@('hero-oman-desert.png','desert.png'))){
 $target=Join-Path $root $pair[1];if(-not(Test-Path -LiteralPath $target)){Copy-Item -LiteralPath (Join-Path $assets $pair[0]) -Destination $target}
}
foreach($name in @('team.mp4','initiative.mp4')){$target=Join-Path $root $name;if(-not(Test-Path -LiteralPath $target)){Copy-Item -LiteralPath $clip -Destination $target}}
& sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\013_CreateSamplePortalMedia.sql')
if($LASTEXITCODE-ne 0){throw 'Media fixture seed failed.'}
"Local media fixture ready at $root. Existing records, settings and files were preserved."
