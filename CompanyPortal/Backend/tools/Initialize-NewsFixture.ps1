# Local development only. Never run against the internal news database.
$ErrorActionPreference='Stop'
$backend=Split-Path $PSScriptRoot -Parent
$newsRoot=Join-Path $backend 'artifacts\news-fixture'
[IO.Directory]::CreateDirectory($newsRoot) | Out-Null
# Minimal standalone test PDF. It represents an already-created source attachment;
# the application never generates PDFs at runtime.
$objects=@('<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
$text="BT /F1 20 Tf 50 700 Td (CompanyPortal sample news PDF) Tj ET`n"
$objects+=('<< /Length '+[Text.Encoding]::ASCII.GetByteCount($text)+" >>`nstream`n"+$text+'endstream')
$pdf="%PDF-1.4`n"; $offsets=@(0)
for($index=0;$index -lt $objects.Count;$index++) { $offsets += [Text.Encoding]::ASCII.GetByteCount($pdf); $pdf+=($index+1).ToString()+" 0 obj`n"+$objects[$index]+"`nendobj`n" }
$xref=[Text.Encoding]::ASCII.GetByteCount($pdf)
$pdf+="xref`n0 6`n0000000000 65535 f `n"
foreach($offset in $offsets[1..5]) { $pdf+=$offset.ToString('0000000000')+" 00000 n `n" }
$pdf+="trailer`n<< /Size 6 /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n"
[IO.File]::WriteAllText((Join-Path $newsRoot 'sample.pdf'),$pdf,[Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $newsRoot 'other.pdf'),$pdf,[Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path (Split-Path $newsRoot -Parent) 'outside.pdf'),$pdf,[Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $newsRoot 'invalid.pdf'),'This is not a PDF.',[Text.Encoding]::ASCII)
Copy-Item -LiteralPath (Join-Path $backend '..\Frontend\CompanyPortal.Web\wwwroot\assets\hero-oman-fort.png') -Destination (Join-Path $newsRoot 'sample.png')
$sqlRoot=$newsRoot.Replace("'","''")
$env:NewsRoot=$sqlRoot
& sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\004_CreateSampleNews.sql')
if ($LASTEXITCODE -ne 0) { throw 'News fixture SQL setup failed.' }
& sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\005_ConfigureSampleNewsFolder.sql')
if ($LASTEXITCODE -ne 0) { throw 'News fixture folder setup failed. Apply migration014 first.' }
Write-Output "Local fixture files: $newsRoot"
