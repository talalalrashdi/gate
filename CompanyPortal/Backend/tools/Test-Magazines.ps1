param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host-notin @('localhost','127.0.0.1')){throw 'Local fixture API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Api($path,$headers=@{}){Invoke-WebRequest ($ApiBase+$path) -UseDefaultCredentials -AllowUnencryptedAuthentication -Headers $headers}
function Code($path,$expected){try{$r=Api $path;Assert ($r.StatusCode-eq $expected) "Wrong status $path"}catch{Assert ($_.Exception.Response.StatusCode.value__-eq $expected) "Wrong error $path"}}
$c=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
function Run($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;[void]$cmd.ExecuteNonQuery()}
try{
 $c.Open();Assert ((Scalar "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalMagazineFixture'")-eq 1) 'Marked local magazine fixture required.'
 $snapshot=Scalar 'SELECT * FROM Portal.Magazines ORDER BY MagazineID FOR JSON PATH'
 $catalog=Api '/api/magazines';$rows=@($catalog.Content|ConvertFrom-Json)
 Assert ($rows.Count-gt 0 -and $catalog.Headers['Cache-Control']-match 'no-store') 'Catalog unavailable/no-store missing.'
 Assert ($catalog.Content-notmatch 'fileName|39.pdf|artifacts|magazine-fixture') 'Catalog exposes physical source paths.'
 $id=[int](Scalar "SELECT MIN(MagazineID) FROM Portal.Magazines WHERE FileName=N'39.pdf'")
 Assert ($id-gt 0) 'Existing sample missing.'
 foreach($path in @('/api/magazines',"/api/magazines/$id/pdf","/api/magazines/$id/pages","/api/magazines/$id/pages/1")){
  try{Invoke-WebRequest ($ApiBase+$path)|Out-Null;throw 'Anonymous success'}catch{Assert ($_.Exception.Response.StatusCode.value__-eq 401) 'Anonymous media read was not denied.'}
 }
 $pages=(Api "/api/magazines/$id/pages").Content|ConvertFrom-Json
 Assert ($pages.pages.Count-eq 258 -and $pages.pages[0].width-gt 0) 'Wrong existing page manifest.'
 $pdf=Api "/api/magazines/$id/pdf" @{Range='bytes=0-4'}
 Assert ($pdf.StatusCode-eq 206 -and $pdf.Headers['Content-Type']-match 'application/pdf' -and $pdf.Headers['X-Content-Type-Options']-match 'nosniff') 'PDF range/MIME/header failed.'
 $image=Api "/api/magazines/$id/pages/1";Assert ($image.Headers['Content-Type']-match 'image/webp') 'Preview MIME failed.'
 Code "/api/magazines/$id/pages/259" 404
 Code '/api/magazines/2147483000/pdf' 404
 $active=Scalar "SELECT CONVERT(int,Active) FROM Portal.Magazines WHERE MagazineID=$id"
 $originalFile=[string](Scalar "SELECT FileName FROM Portal.Magazines WHERE MagazineID=$id")
 try{
  Run "UPDATE Portal.Magazines SET Active=0 WHERE MagazineID=$id"
  Assert (-not(@((Api '/api/magazines').Content|ConvertFrom-Json).magazineId-contains $id)) 'Hidden issue still listed.'
  Code "/api/magazines/$id/pdf" 404;Code "/api/magazines/$id/pages" 404;Code "/api/magazines/$id/pages/1" 404
  Run "UPDATE Portal.Magazines SET Active=$active,FileName=N'..\39.pdf' WHERE MagazineID=$id"
  Code "/api/magazines/$id/pdf" 404;Code "/api/magazines/$id/pages" 404
 }finally{
  $cmd=$c.CreateCommand();$cmd.CommandText='UPDATE Portal.Magazines SET Active=@Active,FileName=@File WHERE MagazineID=@ID';[void]$cmd.Parameters.AddWithValue('@Active',$active);[void]$cmd.Parameters.AddWithValue('@File',$originalFile);[void]$cmd.Parameters.AddWithValue('@ID',$id);[void]$cmd.ExecuteNonQuery()
 }
 Assert ($snapshot-ceq (Scalar 'SELECT * FROM Portal.Magazines ORDER BY MagazineID FOR JSON PATH')) 'Original magazine data/timestamps not restored.'
 $swagger=(Api '/swagger/v1/swagger.json').Content|ConvertFrom-Json;Assert ($swagger.paths.'/api/magazines') 'Swagger unavailable.'
 Write-Output 'Magazine checks passed: current catalog, anonymous denial, no paths, PDF ranges, preview pages, inactive direct-file denial, traversal and restoration, Swagger.'
}finally{$c.Dispose()}
