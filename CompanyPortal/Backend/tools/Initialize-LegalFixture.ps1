# Local development only. Never run against the real internal legal database.
$ErrorActionPreference='Stop'
$backend=Split-Path $PSScriptRoot -Parent
$legalRoot=Join-Path $backend 'artifacts\legal-fixture'
[void][IO.Directory]::CreateDirectory($legalRoot)
foreach($number in 1..6){
 $objects=@('<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
 $text="BT /F1 20 Tf 50 700 Td (CompanyPortal sample decision $number) Tj ET`n"
 $objects+=('<< /Length '+[Text.Encoding]::ASCII.GetByteCount($text)+" >>`nstream`n"+$text+'endstream')
 $pdf="%PDF-1.4`n";$offsets=@(0)
 for($index=0;$index-lt $objects.Count;$index++){$offsets += [Text.Encoding]::ASCII.GetByteCount($pdf);$pdf+=($index+1).ToString()+" 0 obj`n"+$objects[$index]+"`nendobj`n"}
 $xref=[Text.Encoding]::ASCII.GetByteCount($pdf);$pdf+="xref`n0 6`n0000000000 65535 f `n"
 foreach($offset in $offsets[1..5]){$pdf+=$offset.ToString('0000000000')+" 00000 n `n"}
 $pdf+="trailer`n<< /Size 6 /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n"
 $file=Join-Path $legalRoot "decision-$number.pdf"
 if(-not (Test-Path -LiteralPath $file)){[IO.File]::WriteAllText($file,$pdf,[Text.Encoding]::ASCII)}
}
& sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\008_CreateSampleLegalAffairs.sql')
if($LASTEXITCODE-ne 0){throw 'Legal fixture SQL setup failed.'}
$env:LegalRoot=$legalRoot.Replace("'","''")
try{
 & sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\009_ConfigureSampleLegalFolder.sql')
 if($LASTEXITCODE-ne 0){throw 'Legal fixture folder setup failed.'}
}finally{Remove-Item Env:LegalRoot}
"Local legal fixture files: $legalRoot"
