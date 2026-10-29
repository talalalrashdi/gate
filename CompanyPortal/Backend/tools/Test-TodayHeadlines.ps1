param([string]$ApiBase='http://localhost:5877')
$ErrorActionPreference='Stop';if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local test only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path){Invoke-WebRequest ($ApiBase+$path) -UseDefaultCredentials -AllowUnencryptedAuthentication -SkipHttpErrorCheck}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=Pubs_Info_V4;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$marker='Headlines test '+[guid]::NewGuid().ToString('N');$ids=[Collections.Generic.List[int]]::new()
function Scalar($text){$cmd=$c.CreateCommand();$cmd.CommandText=$text;$cmd.ExecuteScalar()}
try{
 $c.Open();Assert ((Scalar "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1") -eq 1) 'Marked local source required.'
 $before=(Call '/api/news?pageSize=50&includeHeadlines=true').Content|ConvertFrom-Json
 $today=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(4)).ToString('yyyy-MM-dd')
 foreach($i in 1..14){$date=if($i -eq 13){([datetime]$today).AddDays(-1)}elseif($i -eq 14){([datetime]$today).AddDays(1)}else{([datetime]$today).AddMinutes($i)};$stamp=$date.ToString('yyyy-MM-ddTHH:mm:ss');$id=[int](Scalar "INSERT dbo.Public_info_News(PIN_Subject,PIN_Date) OUTPUT inserted.PIN_ID VALUES(N'$marker $i','$stamp')");$ids.Add($id);[void](Scalar "INSERT dbo.Public_info_News_Prodc(News_ID) VALUES($id)")}
 $response=Call '/api/news?pageSize=8&includeHeadlines=true';Assert ($response.StatusCode -eq 200) 'Combined catalog failed.';$data=$response.Content|ConvertFrom-Json
 Assert ($data.headlines.Count -eq 5) 'Hero should contain5 items.'
 Assert (@($data.headlines|Where-Object {([datetime]$_.publishedAt).ToString('yyyy-MM-dd') -ne $today}).Count -eq 0) 'Hero includes older/future dates.'
 Assert (@($data.items|Where-Object {([datetime]$_.publishedAt).ToString('yyyy-MM-dd') -ne $today}).Count -eq 0) 'More-news includes older/future dates.'
 for($i=1;$i -lt $data.headlines.Count;$i++){Assert ([datetime]$data.headlines[$i-1].publishedAt -ge [datetime]$data.headlines[$i].publishedAt) 'Headlines not newest first.'}
 Assert ($data.items.Count -eq 8 -and $data.totalCount -eq $before.totalCount+12) 'Today-list pagination/total mismatch.'
 $archive=(Call '/api/news?pageSize=50').Content|ConvertFrom-Json;Assert ($null -eq $archive.headlines) 'Ordinary pages should not query/return headline data.'
 Assert (@($archive.items|Where-Object newsId -eq $ids[12]).Count -eq 0) 'Yesterday appeared in today-only more-news.'
 # A page refresh must put the newly arrived item first; IDs break equal-time ties.
 $stamp=([datetime]$today).AddHours(23).AddMinutes(59).AddSeconds(59).ToString('yyyy-MM-ddTHH:mm:ss')
 foreach($n in 1..2){
  $new=[int](Scalar "INSERT dbo.Public_info_News(PIN_Subject,PIN_Date) OUTPUT inserted.PIN_ID VALUES(N'$marker arrival$n','$stamp')");$ids.Add($new);[void](Scalar "INSERT dbo.Public_info_News_Prodc(News_ID) VALUES($new)")
  $refresh=(Call '/api/news?includeHeadlines=true').Content|ConvertFrom-Json
  Assert ($refresh.headlines.Count -eq 5 -and $refresh.headlines[0].newsId -eq $new) 'Refresh did not put newest/tied latest ID first in hero.'
  Assert ($refresh.items[0].newsId -eq $new) 'More-news order differs from hero.'
 }
 Assert ((Invoke-WebRequest ($ApiBase+'/api/news?includeHeadlines=true') -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous access allowed.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed.'
 Write-Output 'PASS: latest5 today/newest-first, new arrivals/tie order on refresh, more-news today-only with correct pagination, opt-in combined response, anonymous protection and Swagger.'
}finally{
 foreach($id in $ids){[void](Scalar "DELETE dbo.Public_info_News_Prodc WHERE News_ID=$id; DELETE dbo.Public_info_News WHERE PIN_ID=$id AND PIN_Subject LIKE N'$marker%';")};$c.Dispose()
}
$after=(Call '/api/news?includeHeadlines=true').Content|ConvertFrom-Json
Assert ($after.headlines.Count -eq $before.headlines.Count) 'Cleanup did not restore original headline count.'
Assert ($after.totalCount -eq $before.totalCount) 'Cleanup did not restore today count.'
if($before.totalCount -eq 0){Assert ($after.items.Count -eq 0 -and $after.headlines.Count -eq 0) 'No-today day must be empty in both views.';Write-Output 'PASS: no news today leaves both hero and More empty; fixtures removed.'}
