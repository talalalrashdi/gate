# LOCAL DEVELOPMENT ONLY: copies the existing sample PDF; no network/rendering dependency (pages are rendered by PDF.js).
$ErrorActionPreference='Stop'
$backend=Split-Path $PSScriptRoot -Parent
$source=[IO.Path]::GetFullPath((Join-Path $backend '../Frontend/CompanyPortal.Web/wwwroot/assets/magazines'))
$root=Join-Path $backend 'artifacts/magazine-fixture'
$connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
try{
 $connection.Open();$cmd=$connection.CreateCommand();$cmd.CommandText="SELECT strVal FROM Mstr.Utls WHERE [Key]=N'Magazines'";$reader=$cmd.ExecuteReader();$paths=@();while($reader.Read()){$paths+=$reader.GetString(0)};$reader.Close()
 if($paths.Count -gt 0 -and ($paths.Count-ne 1 -or $paths[0]-ne $root)){throw 'Existing Magazines root differs: no fixture files or settings changed.'}
 sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database/Development/015_CreateSampleMagazine.sql')
 if($LASTEXITCODE-ne 0){throw 'Magazine seed failed'}
 [void][IO.Directory]::CreateDirectory($root)
 if(-not(Test-Path -LiteralPath (Join-Path $root '39.pdf'))){Copy-Item -LiteralPath (Join-Path $source '39.pdf') -Destination $root}
 $cmd.CommandText="IF NOT EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'Magazines') INSERT Mstr.Utls([Key],strVal) VALUES(N'Magazines',@Path)";[void]$cmd.Parameters.AddWithValue('@Path',$root);[void]$cmd.ExecuteNonQuery()
 Write-Output "Magazine fixture ready: $root"
}finally{$connection.Dispose()}
