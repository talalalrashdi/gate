param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if(-not ([uri]$BaseUrl).IsLoopback){throw 'Local development tests only.'}
function Assert($value,[string]$text){if(-not $value){throw $text}}
function Request([string]$path,[string]$method='GET',$body=$null,[hashtable]$headers=@{},[bool]$authenticated=$true){
 $r=[Net.HttpWebRequest]::Create($BaseUrl+$path);$r.Method=$method;$r.UseDefaultCredentials=$authenticated;$r.AllowAutoRedirect=$false;$r.Timeout=15000
 foreach($key in $headers.Keys){$r.Headers[$key]=$headers[$key]}
 if($null-ne $body){$bytes=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 8 -Compress));$r.ContentType='application/json';$r.ContentLength=$bytes.Length;$s=$r.GetRequestStream();try{$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 try{$response=$r.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content;location=$response.Headers['Location'];cache=$response.Headers['Cache-Control']}}finally{$response.Close()}
}
function ReadJson([string]$path){$r=Request $path;Assert ($r.status-eq 200) "GET $path failed: $($r.status) $($r.content)";($r.content|ConvertFrom-Json)|ForEach-Object {$_}}
function Sql([string]$query,[hashtable]$parameters=@{}){
 $connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5'
 try{$connection.Open();$command=$connection.CreateCommand();$command.CommandText=$query;foreach($key in $parameters.Keys){$value=$parameters[$key];if($null-eq $value){$value=[DBNull]::Value};[void]$command.Parameters.AddWithValue($key,$value)};$command.ExecuteScalar()}finally{$connection.Dispose()}
}

$header=@{'X-CompanyPortal-Request'='fixed-orders'}
$tag='DirectiveAdminTest-'+[guid]::NewGuid().ToString('N');$id=$null;$role=$null
$before=Sql 'SELECT * FROM Portal.FixedOrders ORDER BY FixedOrderID FOR JSON PATH'
try{
 Assert ((Request '/api/admin/fixed-orders' 'GET' $null @{} $false).status-eq 401) 'Anonymous admin list accepted.'
 $body=@{timestamp='2001-02-03';timestamp2='2030-04-05';contentBefor='Before <b>text</b> ss{1}se';contentAfter=$tag;contentText='Change ds{0}de to ss{1}se then ds{0}de';timestampType=-2147482999}
 Assert ((Request '/api/admin/fixed-orders' 'POST' $body @{} $false).status-eq 401) 'Anonymous create allowed.'
 Assert ((Request '/api/admin/fixed-orders' 'POST' $body).status-eq 400) 'Missing request header accepted.'
 Assert ((Request '/api/admin/fixed-orders' 'POST' $body @{'X-CompanyPortal-Request'='fixed-orders';Origin='https://untrusted.invalid'}).status-eq 403) 'Foreign origin accepted.'
 $response=Request '/api/admin/fixed-orders' 'POST' $body $header;Assert ($response.status-eq 201) "Create failed: $($response.status) $($response.content)"
 $id=($response.content|ConvertFrom-Json).fixedOrderId;Assert ($id-is [string] -and $id-match '^[1-9][0-9]{0,18}$') 'Created bigint ID was not a string.'
 $row=@(ReadJson '/api/fixed-orders')|Where-Object fixedOrderId -eq $id
 Assert ($row.contentAfter-eq $tag -and $row.contentText-eq $body.contentText -and $row.timestamp-eq '2001-02-03' -and $row.year-eq 2001 -and $row.timestamp2-eq '2030-04-05' -and $row.timestampType-eq -2147482999) 'Employee read/save mapping failed.'
 Assert ((Request '/api/admin/fixed-orders').cache-match 'no-store') 'Admin cache policy missing.'
 $snapshot=Sql 'SELECT * FROM Portal.FixedOrders WHERE FixedOrderID=@Id FOR JSON PATH' @{'@Id'=[long]$id}
 Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 204) 'No-op failed.'
 Assert ((Sql 'SELECT * FROM Portal.FixedOrders WHERE FixedOrderID=@Id FOR JSON PATH' @{'@Id'=[long]$id})-ceq $snapshot) 'No-op changed data.'
 $body.contentBefor+=' ';Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 204) 'Whitespace edit failed.'
 $row=@(ReadJson '/api/admin/fixed-orders')|Where-Object fixedOrderId -eq $id;Assert ($row.contentBefor-ceq $body.contentBefor) 'Trailing text spacing lost.'
 $body.timestamp='0001-01-01';$body.timestamp2='9999-12-31';$body.contentText='ds{0}de only';$body.contentAfter=$tag+' edited'
 Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 204) 'Full SQL date range/before-only edit failed.'
 $row=@(ReadJson '/api/admin/fixed-orders')|Where-Object fixedOrderId -eq $id
 Assert ($row.timestamp-eq '0001-01-01' -and $row.year-eq 1 -and $row.timestamp2-eq '9999-12-31' -and $row.contentAfter-eq $body.contentAfter) 'Date-only edit roundtrip failed.'
 $body.timestamp=$null;$body.timestamp2=$null
 Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 204) 'Nullable dates rejected.'
 $row=@(ReadJson '/api/fixed-orders')|Where-Object fixedOrderId -eq $id
 Assert ($null-eq $row.timestamp -and $null-eq $row.year -and $null-eq $row.timestamp2) 'Undated mapping failed.'
 $body.timestampType=$null;Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Missing TimestampType accepted.';$body.timestampType=-2147482999
 $body.contentAfter=' ';Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Blank title accepted.';$body.contentAfter=$tag
 $body.contentText=' ';Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Blank wording accepted.';$body.contentText='ds{0}de'
 $body.contentBefor=$null;Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Missing referenced previous text accepted.';$body.contentBefor='previous'
 $body.contentText='ds{1}de';Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Invalid marker accepted.';$body.contentText='ds{0}de'
 $body.contentBefor='x'*501;Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Oversized previous text accepted.';$body.contentBefor='previous'
 $body.contentAfter='x'*1001;Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Oversized title accepted.';$body.contentAfter=$tag
 $body.contentText='x'*1001;Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Oversized wording accepted.';$body.contentText='ds{0}de'
 $body.extra='ignored';Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 400) 'Unknown fields accepted.';$body.Remove('extra')
 Assert ((Request '/api/admin/fixed-orders/9223372036854775807' 'PUT' $body $header).status-eq 404) 'Missing bigint ID accepted.'
 $role=(Sql "SELECT ur.UserRoleId,ur.Active,ur.LastChangeAt FROM SecurityDB.dbo.UserRoles ur JOIN SecurityDB.dbo.Users u ON u.UserId=ur.UserId JOIN SecurityDB.dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER")|ConvertFrom-Json
 Assert ($role) 'Requires explicit local sample admin.'
 [void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=0 WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId})
 Assert ((Request '/api/admin/fixed-orders').status-eq 403) 'Revoked admin list allowed.'
 Assert ((Request '/api/admin/fixed-orders' 'POST' $body $header).status-eq 403) 'Revoked admin creation allowed.'
 Assert ((Request "/api/admin/fixed-orders/$id" 'PUT' $body $header).status-eq 403) 'Revoked admin edit allowed.'
 Assert ((Request '/api/fixed-orders').status-eq 200) 'Admin revocation broke employee reads.'
 $swagger=ReadJson '/swagger/v1/swagger.json';Assert ($null-ne $swagger.paths.'/api/admin/fixed-orders'.post) 'Swagger routes missing.'
 'PASS: fixed-order admin create/edit/read, dates/year/null/full range, string IDs, no-op, marker/length/type validation, current role and origin/header enforcement, Swagger.'
}finally{
 if($role){[void](Sql 'UPDATE SecurityDB.dbo.UserRoles SET Active=@Active,LastChangeAt=@At WHERE UserRoleId=@Id' @{'@Id'=$role.UserRoleId;'@Active'=$role.Active;'@At'=[datetime]$role.LastChangeAt})}
 if($id){[void](Sql 'DELETE Portal.FixedOrders WHERE FixedOrderID=@Id AND TimestampType=-2147482999' @{'@Id'=[long]$id})}
 $after=Sql 'SELECT * FROM Portal.FixedOrders ORDER BY FixedOrderID FOR JSON PATH'
 Assert ($before-ceq $after) 'Original directive data changed or temporary row remained.'
}
