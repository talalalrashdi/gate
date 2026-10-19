param([string]$BaseUrl='http://localhost:5081',[switch]$TestSampleData)
$ErrorActionPreference='Stop'
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Request([string]$Path,[bool]$Authenticated=$true,[bool]$Range=$false) {
    $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$Path)
    $request.UseDefaultCredentials=$Authenticated; $request.AllowAutoRedirect=$false; $request.Timeout=15000
    if($Range) { $request.AddRange(0,4) }
    try { $response=$request.GetResponse() } catch { $response=$_.Exception.GetBaseException().Response; if (-not $response) { throw } }
    try {
        $bytes=[IO.MemoryStream]::new(); $response.GetResponseStream().CopyTo($bytes)
        return @{Status=[int]$response.StatusCode;Content=[Text.Encoding]::UTF8.GetString($bytes.ToArray());Type=$response.ContentType;Disposition=$response.Headers['Content-Disposition'];Cache=$response.Headers['Cache-Control'];NoSniff=$response.Headers['X-Content-Type-Options']}
    } finally { $response.Close() }
}
Assert ((Request '/api/news' $false).Status -eq 401) 'Anonymous news accepted.'
Assert ((Request '/api/news/1/pdf' $false).Status -eq 401) 'Anonymous PDF accepted.'
Assert ((Request '/api/news/1/picture' $false).Status -eq 401) 'Anonymous image accepted.'
foreach($query in @('?page=0','?pageSize=0','?pageSize=51','?page=1000001')) {
    Assert ((Request ('/api/news'+$query)).Status -eq 400) 'Invalid pagination accepted.'
}
$all=Request '/api/news?page=1&pageSize=50'
Assert ($all.Status -eq 200) 'News list failed.'
Assert ($all.Cache -match 'no-store') 'News response cached.'
Assert ($all.Content -notmatch 'pdfPath|picturePath|ATT_File_Path|PIN_PicturePath|[A-Z]:\\') 'Physical path exposed.'
$page=$all.Content|ConvertFrom-Json
Assert (@($page.items|Group-Object newsId|Where-Object Count -gt 1).Count -eq 0) 'Duplicate news items.'
Assert ((Request '/api/news/2147483647/pdf').Status -eq 404) 'Unknown PDF accepted.'
if ($TestSampleData) {
    Assert (([uri]$BaseUrl).IsLoopback) 'Sample-data checks are local-only.'
    & sqlcmd -S localhost -E -b -d Pubs_Info_V4 -Q "IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1) THROW 50012,'Not a development news fixture.',1;"
    if($LASTEXITCODE -ne 0) { throw 'Fixture guard failed.' }
    Assert ($page.totalCount -eq 9) 'Publication filters or fixture count differ.'
    Assert ($page.items[0].newsId -eq 1) 'News is not ordered newest first.'
    Assert (@($page.items|Where-Object newsId -eq 1).Count -eq 1) 'Repeated join rows duplicated item 1.'
    Assert ($page.items[0].hasPdf -and $page.items[0].hasPicture -and $page.items[0].isImportant) 'PDF/image/important flags missing.'
    Assert (-not ($page.items|Where-Object newsId -eq 3).hasPdf) 'Inactive attachment returned.'
    $second=(Request '/api/news?page=2&pageSize=8').Content|ConvertFrom-Json
    Assert (@($second.items).Count -eq 1 -and $second.totalCount -eq 9) 'Pagination count differs.'
    $pdf=Request '/api/news/1/pdf'
    Assert ($pdf.Status -eq 200 -and $pdf.Type -eq 'application/pdf' -and $pdf.Content.StartsWith('%PDF-')) 'Existing PDF stream failed.'
    Assert ($pdf.Disposition -match '^inline;' -and $pdf.NoSniff -eq 'nosniff' -and $pdf.Cache -match 'no-store') 'PDF headers incorrect.'
    $range=Request '/api/news/1/pdf' $true $true
    Assert ($range.Status -eq 206 -and $range.Content -eq '%PDF-') 'PDF range requests failed.'
    $picture=Request '/api/news/1/picture'
    Assert ($picture.Status -eq 200 -and $picture.Type -eq 'image/png') 'Picture stream failed.'
    foreach($id in @(2,3,4,5,6,8,9,11)) { Assert ((Request "/api/news/$id/pdf").Status -eq 404) "Unavailable/unpublished/unsafe PDF $id accepted." }
    Assert ((Request '/api/news/7/pdf').Status -eq 409) 'Conflicting active PDFs were silently selected.'
    Assert (($page.items|Where-Object newsId -eq 7).attachmentConflict) 'PDF conflict flag missing.'
    $unpublished=$false
    try {
        $unpublished=$true
        & sqlcmd -S localhost -E -b -d Pubs_Info_V4 -Q "UPDATE dbo.Public_info_News SET PIN_Publish=0 WHERE PIN_ID=1;"
        if($LASTEXITCODE -ne 0) { throw 'Temporary unpublish failed.' }
        Assert ((Request '/api/news/1/pdf').Status -eq 404) 'Previously listed PDF bypassed publication recheck.'
        Assert ((Request '/api/news/1/picture').Status -eq 404) 'Previously listed picture bypassed publication recheck.'
    } finally {
        if($unpublished) { & sqlcmd -S localhost -E -b -d Pubs_Info_V4 -Q "UPDATE dbo.Public_info_News SET PIN_Publish=1 WHERE PIN_ID=1;"; if($LASTEXITCODE -ne 0) { throw 'Restore sample publication failed.' } }
    }
}
'PASS: authenticated news, pagination, hidden physical paths, and optional sample filters/deduplication/files/ranges/conflicts/publication rechecks.'
