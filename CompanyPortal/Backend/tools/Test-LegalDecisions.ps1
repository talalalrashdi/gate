param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Fixture mutation tests are local-only.'}
function Assert($value,[string]$message){if(-not $value){throw $message}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
 try{$connection.Open();$command=$connection.CreateCommand();$command.CommandText=$query;foreach($key in $parameters.Keys){[void]$command.Parameters.AddWithValue($key,$parameters[$key])};$command.ExecuteScalar()}finally{$connection.Dispose()}
}
function Request([string]$path,[bool]$authenticated=$true,[bool]$range=$false){
 $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$path);$request.UseDefaultCredentials=$authenticated;$request.Timeout=15000
 if($range){$request.AddRange(0,4)}
 try{$response=$request.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content;type=$response.ContentType;cache=$response.Headers['Cache-Control'];disposition=$response.Headers['Content-Disposition'];nosniff=$response.Headers['X-Content-Type-Options']}}finally{$response.Close()}
}
$guard=Sql "SELECT COUNT(*) FROM LegelAffairs.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1"
Assert ($guard-eq 1) 'Not a marked legal development database.'
$user=ConvertFrom-Json -InputObject (Sql 'SELECT UserId,Active FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN() FOR JSON PATH,WITHOUT_ARRAY_WRAPPER')
$original=ConvertFrom-Json -InputObject (Sql 'SELECT DecisionId,Active,PdfFileName FROM LegelAffairs.dbo.Decisions WHERE DecisionId=1 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER')
$grant=ConvertFrom-Json -InputObject (Sql 'SELECT DecisionUserId,Active FROM LegelAffairs.dbo.DecisionUsers WHERE DecisionId=6 AND UserId=@UserId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER' @{'@UserId'=$user.UserId})
$folder=ConvertFrom-Json -InputObject (Sql "SELECT UtlsId,Active,strVal FROM Mstr.Utls WHERE [Key]=N'LegalAffairs' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER")
Assert ($user.Active -and $original -and $grant -and $folder.Active) 'Expected local fixtures missing.'
$invalid=Join-Path $folder.strVal 'test-invalid-content.pdf';Assert (-not (Test-Path -LiteralPath $invalid)) 'Temporary file already exists.'
try{
 Assert ((Request '/api/decisions' $false).status-eq 401) 'Anonymous list accepted.'
 Assert ((Request '/api/decisions/1/pdf' $false).status-eq 401) 'Anonymous PDF accepted.'
 $list=Request '/api/decisions';Assert ($list.status-eq 200 -and $list.cache-match 'no-store') 'List/cache failed.'
 $rows=ConvertFrom-Json -InputObject $list.content
 Assert ($rows.Count-ge 6 -and @($rows|Where-Object decisionId -eq '6').Count-eq 1) 'Fixture order/count incorrect.'
 Assert ($list.content-notmatch 'pdfFileName|[A-Z]:\\|decision-1.pdf') 'Physical path exposed.'
 $pdf=Request '/api/decisions/1/pdf';Assert ($pdf.status-eq 200 -and $pdf.type-eq 'application/pdf' -and $pdf.content.StartsWith('%PDF-') -and $pdf.disposition-match '^inline;' -and $pdf.nosniff-eq 'nosniff' -and $pdf.cache-match 'no-store') 'PDF response failed.'
 Assert ((Request '/api/decisions/1/pdf' $true $true).status-eq 206) 'Range failed.'
 Assert ((Request '/api/decisions/9223372036854775807/pdf').status-eq 404) 'Unknown decision accepted.'
 [void](Sql 'UPDATE LegelAffairs.dbo.DecisionUsers SET Active=0 WHERE DecisionUserId=@Id' @{'@Id'=$grant.DecisionUserId})
 $revoked=ConvertFrom-Json -InputObject (Request '/api/decisions').content
 Assert ($revoked.Count-eq ($rows.Count-1) -and @($revoked|Where-Object decisionId -eq '6').Count-eq 0) 'Restricted summary leaked.'
 Assert ((Request '/api/decisions/6/pdf').status-eq 404) 'Revoked PDF accessible.'
 [void](Sql 'UPDATE LegelAffairs.dbo.Decisions SET Active=0 WHERE DecisionId=1')
 Assert ((Request '/api/decisions/1/pdf').status-eq 404) 'Inactive PDF accessible.'
 [void](Sql 'UPDATE LegelAffairs.dbo.Decisions SET Active=1 WHERE DecisionId=1')
 foreach($path in @('missing.pdf','..\news-fixture\sample.pdf','decision-1.pdf:stream','\\?\C:\file.pdf',('\'+$folder.strVal.TrimStart('\')))){
  [void](Sql 'UPDATE LegelAffairs.dbo.Decisions SET PdfFileName=@Path WHERE DecisionId=1' @{'@Path'=$path})
  Assert ((Request '/api/decisions/1/pdf').status-eq 404) ('Unsafe/missing path accepted: '+$path)
 }
 [IO.File]::WriteAllText($invalid,'Not a PDF.')
 [void](Sql 'UPDATE LegelAffairs.dbo.Decisions SET PdfFileName=@Path WHERE DecisionId=1' @{'@Path'='test-invalid-content.pdf'})
 Assert ((Request '/api/decisions/1/pdf').status-eq 404) 'Invalid PDF content accepted.'
 [void](Sql 'UPDATE LegelAffairs.dbo.Decisions SET PdfFileName=@Path WHERE DecisionId=1' @{'@Path'=(Join-Path $folder.strVal 'decision-1.pdf')})
 Assert ((Request '/api/decisions/1/pdf').status-eq 200) 'Absolute authorized path failed.'
 [void](Sql 'UPDATE Mstr.Utls SET Active=0 WHERE UtlsId=@Id' @{'@Id'=$folder.UtlsId})
 Assert ((Request '/api/decisions/1/pdf').status-eq 503) 'Missing configured root did not fail closed.'
 Assert ((Request '/api/decisions').status-eq 200) 'Root failure broke summaries.'
 [void](Sql 'UPDATE SecurityDB.dbo.Users SET Active=0 WHERE UserId=@Id' @{'@Id'=$user.UserId})
 Assert ((Request '/api/decisions').status-eq 403 -and (Request '/api/decisions/1/pdf').status-eq 403) 'Inactive employee accepted.'
 Assert ((Request '/swagger/v1/swagger.json').content.Contains('/api/decisions/{id}/pdf')) 'Swagger route missing.'
 'PASS: public/restricted list, revocation, inactive user/item, PDF headers/range/signature, safe relative/absolute paths, missing roots and Swagger.'
}finally{
 [void](Sql 'UPDATE SecurityDB.dbo.Users SET Active=@Active WHERE UserId=@Id' @{'@Id'=$user.UserId;'@Active'=$user.Active})
 [void](Sql 'UPDATE LegelAffairs.dbo.Decisions SET Active=@Active,PdfFileName=@Path WHERE DecisionId=@Id' @{'@Id'=$original.DecisionId;'@Active'=$original.Active;'@Path'=$original.PdfFileName})
 [void](Sql 'UPDATE LegelAffairs.dbo.DecisionUsers SET Active=@Active WHERE DecisionUserId=@Id' @{'@Id'=$grant.DecisionUserId;'@Active'=$grant.Active})
 [void](Sql 'UPDATE Mstr.Utls SET Active=@Active WHERE UtlsId=@Id' @{'@Id'=$folder.UtlsId;'@Active'=$folder.Active})
 if(Test-Path -LiteralPath $invalid){Remove-Item -LiteralPath $invalid}
}
