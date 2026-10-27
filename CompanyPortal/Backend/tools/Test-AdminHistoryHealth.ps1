param([string]$BaseUrl='http://localhost:5091',[switch]$TestLocalSampleRoles)
$ErrorActionPreference='Stop'
function Assert($value,$message){if(!$value){throw $message}}
function Request($path,[bool]$auth=$true){$r=Invoke-WebRequest ($BaseUrl+$path) -UseDefaultCredentials:$auth -AllowUnencryptedAuthentication -SkipHttpErrorCheck -TimeoutSec 75;return @{Status=[int]$r.StatusCode;Data=if($r.StatusCode -eq 200){$r.Content|ConvertFrom-Json}else{$null};Text=$r.Content;Cache=$r.Headers['Cache-Control']}}
Assert ((Request '/api/admin/changes' $false).Status -eq 401) 'Anonymous history accepted.'
Assert ((Request '/api/admin/changes/1' $false).Status -eq 401) 'Anonymous detail accepted.'
Assert ((Request '/api/admin/health' $false).Status -eq 401) 'Anonymous health accepted.'
$all=Request '/api/admin/changes';Assert ($all.Status -eq 200) 'History unavailable.';Assert ($all.Data.pageSize -eq 25) 'Unexpected page size.';Assert ($all.Cache -match 'no-store') 'History cache protection missing.'
Assert ($all.Text -notmatch 'oldJson|newJson') 'List returned snapshots.'
$empty=Request '/api/admin/changes?page=1000000';Assert ($empty.Status -eq 200 -and $empty.Data.total -eq $all.Data.total -and @($empty.Data.items).Count -eq 0) 'Empty page lost total.'
foreach($row in $all.Data.items){
 $d=Request ('/api/admin/changes/'+$row.changeId);Assert ($d.Status -eq 200 -and $d.Data.changeId -eq $row.changeId) 'Detail lookup mismatch.'
 $s=Request ('/api/admin/changes?section='+$row.section);Assert (@($s.Data.items|Where-Object section -ne $row.section).Count -eq 0) 'Section filter failed.'
 $p=Request ('/api/admin/changes?person='+[uri]::EscapeDataString($row.changedBy));Assert (@($p.Data.items|Where-Object changedBy -ne $row.changedBy).Count -eq 0) 'Person filter failed.'
 $date=([datetime]$row.changedAt).ToString('yyyy-MM-dd');$dates=Request "/api/admin/changes?from=$date&to=$date";Assert (@($dates.Data.items|Where-Object {([datetime]$_.changedAt).ToString('yyyy-MM-dd') -ne $date}).Count -eq 0) 'Date range failed.'
}
foreach($q in '?section=unknown','?page=0','?from=2026-10-28&to=2026-10-01',('?person='+('a'*513))){Assert ((Request ('/api/admin/changes'+$q)).Status -eq 400) "Invalid filter accepted: $q"}
Assert ((Request '/api/admin/changes/9223372036854775807').Status -eq 404) 'Missing history detail accepted.'
$health=Request '/api/admin/health';Assert ($health.Status -eq 200) 'Health unavailable.';Assert ($health.Cache -match 'no-store') 'Health cache protection missing.'
foreach($check in $health.Data.checks){Assert ($check.status -in 'ok','warning','failed') 'Unexpected status.';Assert ($check.reference -and $check.detail -and $check.title) 'Incomplete health check.';if($check.status -ne 'ok'){Assert (@($check.steps).Count -gt 0) 'Failure/warning has no steps.'}}
Assert ($health.Text -notmatch '[\u0600-\u06ff]|Password=|StackTrace|ConnectionString=') 'Health report exposed raw settings or non-English diagnostics.'
Assert ((Request '/swagger/v1/swagger.json').Status -eq 200) 'Swagger failed.'
if($TestLocalSampleRoles){
 Assert (([uri]$BaseUrl).IsLoopback) 'Role tests are localhost-only.'
 $c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=SecurityDB;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;');$c.Open();$role='CompanyPortal.Phase5.'+[guid]::NewGuid().ToString('N');$saved=$null
 function Sql($text){$cmd=$c.CreateCommand();$cmd.CommandText=$text;return $cmd}
 try{
  $cmd=Sql "SELECT ur.UserRoleId,ur.Active,ur.LastChangeAt,ur.UserId FROM dbo.UserRoles ur JOIN dbo.Users u ON u.UserId=ur.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin'";$t=[Data.DataTable]::new();$t.Load($cmd.ExecuteReader());Assert ($t.Rows.Count -eq 1) 'Expected one sample grant.';$saved=$t.Rows[0];Assert $saved.Active 'Expected active super grant.'
  $cmd=Sql "SET XACT_ABORT ON; BEGIN TRAN; INSERT dbo.Roles(RoleName) VALUES(@role); DECLARE @id int=SCOPE_IDENTITY(); INSERT dbo.UserRoles(UserId,RoleId) VALUES(@user,@id); INSERT CompanyPortal.Portal.AdminSectionRoles(SectionKey,RoleName) VALUES('media',@role); UPDATE dbo.UserRoles SET Active=0 WHERE UserRoleId=@grant; COMMIT;";[void]$cmd.Parameters.AddWithValue('@role',$role);[void]$cmd.Parameters.AddWithValue('@user',[int]$saved.UserId);[void]$cmd.Parameters.AddWithValue('@grant',[int]$saved.UserRoleId);[void]$cmd.ExecuteNonQuery()
  Assert ((Request '/api/admin/overview').Status -eq 200) 'Limited admin lost permitted overview.'
  foreach($path in '/api/admin/changes','/api/admin/changes/1','/api/admin/health'){Assert ((Request $path).Status -eq 403) "Limited admin accepted: $path"}
  Assert ((Request '/api/admin/changes/latest?section=media').Status -eq 200) 'Section-specific last-change labels regressed.'
 }finally{
  if($null -ne $saved){$cmd=Sql 'SET XACT_ABORT ON; BEGIN TRAN; UPDATE dbo.UserRoles SET Active=@active,LastChangeAt=@at WHERE UserRoleId=@id; DELETE CompanyPortal.Portal.AdminSectionRoles WHERE RoleName=@role; DELETE ur FROM dbo.UserRoles ur JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE r.RoleName=@role; DELETE dbo.Roles WHERE RoleName=@role; COMMIT;';[void]$cmd.Parameters.AddWithValue('@active',[bool]$saved.Active);[void]$cmd.Parameters.AddWithValue('@at',[datetime]$saved.LastChangeAt);[void]$cmd.Parameters.AddWithValue('@id',[int]$saved.UserRoleId);[void]$cmd.Parameters.AddWithValue('@role',$role);[void]$cmd.ExecuteNonQuery()};$c.Dispose()
 }
 Assert ((Request '/api/access').Data.isSuperAdmin) 'Original grant was not restored.'
}
Write-Host 'PASS: full super-admin history, filters/pages/details,401/403, read labels, health references/English/steps, no-store and Swagger. Temporary sample grants restored.'
