param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local fixture API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Call($path){Invoke-WebRequest -Uri ($ApiBase+$path) -UseDefaultCredentials -AllowUnencryptedAuthentication -SkipHttpErrorCheck}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
$ids=[Collections.Generic.List[long]]::new();$title='Forms verification '+[guid]::NewGuid().ToString()
try{
 $c.Open();Assert ((Scalar "SELECT COUNT(*) FROM Formsdb.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture'") -eq 1) 'Marked local Formsdb required.'
 $cmd=$c.CreateCommand();$cmd.CommandType='StoredProcedure';$cmd.CommandText='Security.User_getByUsername';[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar();Assert ($user -gt 0) 'Registered user required.'
 $before=(Call '/api/forms').Content|ConvertFrom-Json
 $id=[long](Scalar "INSERT Formsdb.dbo.FormInbox(UserId,Title,SenderName) OUTPUT inserted.FormId VALUES($user,N'$title',N'Test sender')");$ids.Add($id)
 $other=[long](Scalar "INSERT Formsdb.dbo.FormInbox(UserId,Title,SenderName) OUTPUT inserted.FormId VALUES(2147483000,N'$title',N'Test sender')");$ids.Add($other)
 $response=Call '/api/forms';Assert ($response.StatusCode -eq 200) 'Catalog failed.';$data=$response.Content|ConvertFrom-Json
 $row=$data.items|Where-Object formId -eq "$id"
 Assert ($row -and -not $row.isOpened -and $row.isSamplePreview -and -not $row.canOpen) 'Sample contract failed.'
 Assert ($data.unreadCount -eq $before.unreadCount+1) 'Unread count mismatch.'
 Assert (-not ($data.items|Where-Object formId -eq "$other")) 'Other user exposed.'
 Assert ((Call "/api/forms/$other/open").StatusCode -eq 404) 'Other user open allowed.'
 Assert ((Call "/api/forms/$id/open").StatusCode -eq 503) 'Missing app URL should return clear error.'
 Assert ((Scalar "SELECT CONVERT(int,IsOpened) FROM Formsdb.dbo.FormInbox WHERE FormId=$id") -eq 0) 'Portal modified source opened state.'
 [void](Scalar "UPDATE Formsdb.dbo.FormInbox SET IsOpened=1 WHERE FormId=$id AND Title=N'$title'")
 $data=(Call '/api/forms').Content|ConvertFrom-Json
 Assert (($data.items|Where-Object formId -eq "$id").isOpened) 'Source opened state not reflected.'
 Assert ($data.unreadCount -eq $before.unreadCount) 'Count not reduced from source.'
 [void](Scalar "UPDATE Formsdb.dbo.FormInbox SET Active=0 WHERE FormId=$id AND Title=N'$title'")
 Assert (-not (((Call '/api/forms').Content|ConvertFrom-Json).items|Where-Object formId -eq "$id")) 'Inactive source exposed.'
 Assert ((Call "/api/forms/$id/open").StatusCode -eq 404) 'Inactive open allowed.'
 Assert ((Invoke-WebRequest ($ApiBase+'/api/forms') -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous catalog allowed.'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed.'
 Write-Output 'PASS: forms inbox, separate count, source opened status, isolation/open checks, inactive filtering, missing URL, no portal read writes, anonymous rejection and Swagger.'
}finally{
 foreach($id in $ids){[void](Scalar "DELETE Formsdb.dbo.FormInbox WHERE FormId=$id AND Title=N'$title'")}
 $c.Dispose()
}
