# LOCAL DEVELOPMENT ONLY. Creates inferred views and fictional files, never real internal records.
$ErrorActionPreference='Stop'
$backend=Split-Path $PSScriptRoot -Parent
$root=Join-Path $backend 'artifacts\document-fixture'
& sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\010_CreateSampleDocuments.sql')
if($LASTEXITCODE-ne 0){throw 'Document fixture schema/seed failed.'}
$connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
try{
 $connection.Open();$command=$connection.CreateCommand()
 $command.CommandText='SELECT j.ID FROM Mng.DocumentSampleJobs j JOIN SecurityDB.dbo.Users u ON u.UserID=j.UserID WHERE u.NTName=ORIGINAL_LOGIN() AND u.Active=1 AND j.Active=1'
 $jobId=$command.ExecuteScalar();if(-not $jobId){throw 'No active local sample employee/job mapping.'}
 [void][IO.Directory]::CreateDirectory($root)
 $lookup=[IO.File]::ReadAllText((Join-Path $backend 'Database\Integration\ConfigureDocumentLookup.sql'))
 $lookup=$lookup.Replace('-- DOCUMENT_FULL_ACCESS_IDS',('INSERT @FullAccessIds(ID) VALUES('+[int]$jobId+'); -- explicit local test grant'))
 $lookupPath=Join-Path $root 'ConfigureSampleDocumentLookup.sql'
 [IO.File]::WriteAllText($lookupPath,$lookup,[Text.UTF8Encoding]::new($true))
 & sqlcmd -S localhost -E -b -I -f 65001 -i $lookupPath
 if($LASTEXITCODE-ne 0){throw 'Document lookup installation failed.'}
 $command.CommandText="IF NOT EXISTS(SELECT 1 FROM Mstr.Utls WHERE [Key]=N'docs') INSERT Mstr.Utls([Key],strVal) VALUES(N'docs',@Root)"
 [void]$command.Parameters.AddWithValue('@Root',$root);[void]$command.ExecuteNonQuery()
}finally{$connection.Dispose()}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$items=@(
 @('الموارد البشرية\الاستمارات','طلب إجازة.docx'),@('الموارد البشرية','دليل شؤون الموظفين.pdf'),
 @('تقنية المعلومات','طلب صلاحيات نظام.docx'),@('تقنية المعلومات','دليل أمن المعلومات.pdf'),
 @('الوثائق المخصصة','وثيقة مخصصة.pdf'),@('الوثائق المخصصة\الاستمارات المخصصة','استمارة مخصصة.docx'),
 @('مجلد مخفي','وثيقة مخفية.pdf')
)
foreach($item in $items){
 $folder=Join-Path $root $item[0];[void][IO.Directory]::CreateDirectory($folder);$path=Join-Path $folder $item[1]
 if(Test-Path -LiteralPath $path){continue}
 if([IO.Path]::GetExtension($path)-eq '.pdf'){
  $objects=@('<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
  $text="BT /F1 20 Tf 50 700 Td (CompanyPortal sample document) Tj ET`n"
  $objects+=('<< /Length '+[Text.Encoding]::ASCII.GetByteCount($text)+" >>`nstream`n"+$text+'endstream')
  $pdf="%PDF-1.4`n";$offsets=@(0)
  for($i=0;$i-lt $objects.Count;$i++){$offsets += [Text.Encoding]::ASCII.GetByteCount($pdf);$pdf+=($i+1).ToString()+" 0 obj`n"+$objects[$i]+"`nendobj`n"}
  $xref=[Text.Encoding]::ASCII.GetByteCount($pdf);$pdf+="xref`n0 6`n0000000000 65535 f `n"
  foreach($offset in $offsets[1..5]){$pdf+=$offset.ToString('0000000000')+" 00000 n `n"}
  $pdf+="trailer`n<< /Size 6 /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n"
  [IO.File]::WriteAllText($path,$pdf,[Text.Encoding]::ASCII)
 }else{
  $zip=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Create)
  try{
   $parts=@{
    '[Content_Types].xml'='<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
    '_rels/.rels'='<?xml version="1.0" encoding="utf-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
    'word/document.xml'=('<?xml version="1.0" encoding="utf-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:bidi/></w:pPr><w:r><w:t>'+[Security.SecurityElement]::Escape($item[1])+'</w:t></w:r></w:p><w:p><w:r><w:t>CompanyPortal development sample.</w:t></w:r></w:p></w:body></w:document>')
   }
   foreach($name in $parts.Keys){$entry=$zip.CreateEntry($name);$writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false));try{$writer.Write($parts[$name])}finally{$writer.Dispose()}}
  }finally{$zip.Dispose()}
 }
}
"Local document files: $root"
"Explicit sample VJobMainPeriod.ID access entry: $jobId"
