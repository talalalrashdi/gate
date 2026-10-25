param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local document-fixture tests only.'}
function Assert($value,[string]$message){if(-not $value){throw $message}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
 try{$connection.Open();$command=$connection.CreateCommand();$command.CommandText=$query;foreach($key in $parameters.Keys){[void]$command.Parameters.AddWithValue($key,$parameters[$key])};$command.ExecuteScalar()}finally{$connection.Dispose()}
}
function Request([string]$path,[bool]$authenticated=$true,[bool]$range=$false){
 $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$path);$request.UseDefaultCredentials=$authenticated;$request.Timeout=15000
 if($range){$request.AddRange(0,4)}
 try{$response=$request.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$bytes=[IO.MemoryStream]::new();$response.GetResponseStream().CopyTo($bytes);@{status=[int]$response.StatusCode;bytes=$bytes.ToArray();content=[Text.Encoding]::UTF8.GetString($bytes.ToArray());type=$response.ContentType;cache=$response.Headers['Cache-Control'];disposition=$response.Headers['Content-Disposition'];nosniff=$response.Headers['X-Content-Type-Options']}}finally{$response.Close()}
}
function FileUrl([int]$number){'/api/documents/d0250000-0000-0000-0000-'+$number.ToString('000000000000')+'/file'}
Assert ((Sql "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDocumentFixture' AND CONVERT(int,value)=1")-eq 1) 'Not a document fixture database.'
$user=ConvertFrom-Json -InputObject (Sql 'SELECT UserId,Active FROM SecurityDB.dbo.Users WHERE NTName=ORIGINAL_LOGIN() FOR JSON PATH,WITHOUT_ARRAY_WRAPPER')
$job=ConvertFrom-Json -InputObject (Sql 'SELECT ID,Active FROM Mng.DocumentSampleJobs WHERE UserID=@UserId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER' @{'@UserId'=$user.UserId})
$doc=ConvertFrom-Json -InputObject (Sql "SELECT DocumentID,DocumentPath,Active FROM Mng.Document WHERE DocumentID='d0250000-0000-0000-0000-000000000004' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER")
$root=ConvertFrom-Json -InputObject (Sql "SELECT UtlsId,Active,strVal FROM Mstr.Utls WHERE [Key]=N'docs' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER")
$folder=ConvertFrom-Json -InputObject (Sql 'SELECT FolderID,ParentID,Active FROM Mng.Folder WHERE FolderID=11 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER')
Assert ($user.Active -and $job.Active -and $root.Active -and $folder.ParentID-eq 10) 'Expected unchanged local fixtures.'
$invalid=Join-Path (Join-Path $root.strVal ([string](Sql 'SELECT FolderName FROM Mng.Folder WHERE FolderID=20'))) 'test-invalid.pdf'
Assert (-not (Test-Path -LiteralPath $invalid)) 'Temporary file already exists.'
try{
 Assert ((Request '/api/documents' $false).status-eq 401) 'Anonymous list allowed.'
 Assert ((Request (FileUrl 1) $false).status-eq 401) 'Anonymous file allowed.'
 $list=Request '/api/documents';Assert ($list.status-eq 200 -and $list.cache-match 'no-store') 'List/cache failed.'
 $rows=ConvertFrom-Json -InputObject $list.content;Assert (@($rows|Where-Object documentId -match '^d0250000-0000-0000-0000-00000000000[1-7]$').Count-eq 6) 'Allowed fixture count wrong.'
 Assert ($list.content-notmatch '[A-Z]:\\|document-fixture') 'Physical root exposed.'
 Assert (@($rows|Where-Object folderId -eq 90).Count-eq 0) 'Hidden folder leaked.'
 $pdf=Request (FileUrl 4);Assert ($pdf.status-eq 200 -and $pdf.content.StartsWith('%PDF-') -and $pdf.type-eq 'application/pdf' -and $pdf.disposition-match '^inline;' -and $pdf.nosniff-eq 'nosniff' -and $pdf.cache-match 'no-store') 'PDF display response wrong.'
 Assert ((Request (FileUrl 4) $true $true).status-eq 206) 'PDF range failed.'
 $download=Request (FileUrl 1);Assert ($download.status-eq 200 -and $download.type-eq 'application/octet-stream' -and $download.content.StartsWith('PK') -and $download.disposition-match '^attachment;' -and $download.disposition-match "filename\*=UTF-8''") 'DOCX attachment/Unicode header failed.'
 $decoded=[uri]::UnescapeDataString(($download.disposition -split "filename\*=UTF-8''")[1].Trim('"'))
 $expected=(Sql "SELECT DocumentPath FROM Mng.Document WHERE DocumentID='d0250000-0000-0000-0000-000000000001'")
 Assert ($decoded-eq $expected) 'Original Arabic download filename changed.'
 Assert ((Request '/api/documents/00000000-0000-0000-0000-000000000000/file').status-eq 404) 'Unknown GUID accepted.'
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=0 WHERE ID=@Id' @{'@Id'=$job.ID})
 $limited=ConvertFrom-Json -InputObject (Request '/api/documents').content
 Assert (@($limited|Where-Object documentId -match '^d0250000-0000-0000-0000-00000000000[1-7]$').Count-eq 4 -and @($limited|Where-Object {$_.folderId-in 74,75}).Count-eq 0) 'Restricted folder or child leaked.'
 Assert ((Request (FileUrl 5)).status-eq 404 -and (Request (FileUrl 6)).status-eq 404) 'Restricted direct link allowed.'
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=1 WHERE ID=@Id' @{'@Id'=$job.ID})
 foreach($parent in @(11,999999)){
  [void](Sql 'UPDATE Mng.Folder SET ParentID=@Parent WHERE FolderID=11' @{'@Parent'=$parent})
  Assert ((Request (FileUrl 1)).status-eq 404) 'Cycle or missing parent did not fail closed.'
 }
 [void](Sql 'UPDATE Mng.Folder SET ParentID=10 WHERE FolderID=11')
 [void](Sql 'UPDATE Mng.Document SET Active=0 WHERE DocumentID=@Id' @{'@Id'=[guid]$doc.DocumentID})
 Assert ((Request (FileUrl 4)).status-eq 404) 'Inactive document allowed.'
 [void](Sql 'UPDATE Mng.Document SET Active=1 WHERE DocumentID=@Id' @{'@Id'=[guid]$doc.DocumentID})
 foreach($path in @('missing.pdf','..\outside.pdf','C:\outside.pdf','file.pdf:stream','\\server\share\file.pdf')){
  [void](Sql 'UPDATE Mng.Document SET DocumentPath=@Path WHERE DocumentID=@Id' @{'@Id'=[guid]$doc.DocumentID;'@Path'=$path})
  Assert ((Request (FileUrl 4)).status-eq 404) 'Unsafe filename allowed.'
 }
 [IO.File]::WriteAllText($invalid,'Not a PDF.')
 [void](Sql 'UPDATE Mng.Document SET DocumentPath=@Path WHERE DocumentID=@Id' @{'@Id'=[guid]$doc.DocumentID;'@Path'='test-invalid.pdf'})
 Assert ((Request (FileUrl 4)).status-eq 404) 'Invalid PDF signature allowed.'
 [void](Sql 'UPDATE Mng.Document SET DocumentPath=@Path WHERE DocumentID=@Id' @{'@Id'=[guid]$doc.DocumentID;'@Path'=$doc.DocumentPath})
 [void](Sql 'UPDATE Mstr.Utls SET Active=0 WHERE UtlsId=@Id' @{'@Id'=$root.UtlsId})
 Assert ((Request (FileUrl 4)).status-eq 503) 'Missing folder root did not fail closed.'
 Assert ((Request '/api/documents').status-eq 200) 'Root setting broke authorized list.'
 [void](Sql 'UPDATE SecurityDB.dbo.Users SET Active=0 WHERE UserID=@Id' @{'@Id'=$user.UserId})
 Assert ((Request '/api/documents').status-eq 403 -and (Request (FileUrl 4)).status-eq 403) 'Inactive employee allowed.'
 Assert ((Request '/swagger/v1/swagger.json').content.Contains('/api/documents/{id}/file')) 'Swagger route missing.'
 $defaults=Sql "SET XACT_ABORT ON; BEGIN TRANSACTION; INSERT Mng.Document(DocumentName,DocumentPath,FolderID) OUTPUT inserted.DocumentID VALUES(N'Default check',N'check.txt',10); ROLLBACK TRANSACTION;"
 Assert ($defaults-is [guid] -and $defaults-ne [guid]::Empty) 'NEWID default failed.'
 'PASS: document list/permissions, folder74 descendants, cycles/orphans, PDF display/range/signature, DOCX/Arabic filename download, unsafe paths, inactive users/documents, missing root, GUID default and Swagger.'
}finally{
 [void](Sql 'UPDATE SecurityDB.dbo.Users SET Active=@Active WHERE UserID=@Id' @{'@Id'=$user.UserId;'@Active'=$user.Active})
 [void](Sql 'UPDATE Mng.DocumentSampleJobs SET Active=@Active WHERE ID=@Id' @{'@Id'=$job.ID;'@Active'=$job.Active})
 [void](Sql 'UPDATE Mng.Document SET DocumentPath=@Path,Active=@Active WHERE DocumentID=@Id' @{'@Id'=[guid]$doc.DocumentID;'@Path'=$doc.DocumentPath;'@Active'=$doc.Active})
 [void](Sql 'UPDATE Mng.Folder SET ParentID=@Parent,Active=@Active WHERE FolderID=11' @{'@Parent'=$folder.ParentID;'@Active'=$folder.Active})
 [void](Sql 'UPDATE Mstr.Utls SET Active=@Active WHERE UtlsId=@Id' @{'@Id'=$root.UtlsId;'@Active'=$root.Active})
 if(Test-Path -LiteralPath $invalid){Remove-Item -LiteralPath $invalid}
}
