# LOCAL DEVELOPMENT ONLY. Does not replace the existing permission procedure or root.
$ErrorActionPreference='Stop'
$backend=Split-Path $PSScriptRoot -Parent
& sqlcmd -S localhost -E -b -I -f 65001 -i (Join-Path $backend 'Database\Development\012_CreateSampleSafetyBooklets.sql')
if($LASTEXITCODE-ne 0){throw 'Safety booklet fixture seed failed.'}
$connection=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
try{
 $connection.Open();$command=$connection.CreateCommand()
 $command.CommandText="SELECT strVal FROM Mstr.Utls WHERE [Key]=N'docs' AND Active=1"
 $root=[string]$command.ExecuteScalar()
 if(-not $root){throw 'Configure an active docs root first.'}
 $expected=[IO.Path]::GetFullPath((Join-Path $backend 'artifacts\document-fixture'))
 if([IO.Path]::GetFullPath($root).TrimEnd('\') -ne $expected.TrimEnd('\')){throw 'Refusing to write samples outside the local fixture root.'}
 $source=Join-Path $root 'الموارد البشرية\دليل شؤون الموظفين.pdf'
 if(-not(Test-Path -LiteralPath $source)){throw 'Run Initialize-DocumentFixture.ps1 once before this initializer.'}
 foreach($item in @(@('تعليمات السلامة','السلامة في بيئة العمل.pdf'),@('تعليمات السلامة','سلامة الأجهزة والكهرباء.pdf'),@('تعليمات السلامة','الاستعداد للطوارئ.pdf'),@('تعليمات السلامة','الإخلاء الآمن.pdf'),@('تعليمات السلامة','الإبلاغ عن المخاطر.pdf'),@('تعليمات السلامة','الراحة أثناء العمل.pdf'))){
  $folder=Join-Path $root $item[0];[void][IO.Directory]::CreateDirectory($folder)
  $target=Join-Path $folder $item[1]
  if(-not(Test-Path -LiteralPath $target)){Copy-Item -LiteralPath $source -Destination $target}
 }
}finally{$connection.Dispose()}
'Six development-only safety PDFs and booklet entries are ready. Existing permissions and files were preserved.'
