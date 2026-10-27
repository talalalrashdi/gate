param([string]$BaseUrl='http://localhost:5091',[switch]$TestLocalSampleRoles)
$ErrorActionPreference='Stop'
function Assert($value,$message){if(!$value){throw $message}}
function Request($path,[bool]$auth=$true){
 $r=Invoke-WebRequest ($BaseUrl+$path) -UseDefaultCredentials:$auth -AllowUnencryptedAuthentication -SkipHttpErrorCheck
 return @{Status=[int]$r.StatusCode;Data=if($r.StatusCode -eq 200){$r.Content|ConvertFrom-Json}else{$null};Text=$r.Content}
}
Assert ((Request '/api/admin/overview' $false).Status -eq 401) 'Anonymous overview must be 401.'
Assert ((Request '/api/admin/changes/latest?section=media' $false).Status -eq 401) 'Anonymous history must be 401.'
$access=(Request '/api/access').Data
Assert $access.isSuperAdmin 'Run as the local sample super admin.'
$all=Request '/api/admin/overview';Assert ($all.Status -eq 200) 'Overview unavailable.'
Assert ($all.Data.cards.Count -eq 5) 'Expected status/magazine/notices/alerts/media.'
Assert ($all.Data.changes.Count -le 10) 'History must be bounded.'
Assert ($all.Text -notmatch 'oldJson|newJson|mediaPath|fileName|pdfFileName') 'Private snapshots/paths leaked.'
foreach($s in $access.sections){$r=Request ('/api/admin/changes/latest?section='+$s);Assert ($r.Status -eq 200) "Latest $s failed.";Assert (@($r.Data|Where-Object section -ne $s).Count -eq 0) 'History section mismatch.'}
Assert ((Request '/api/admin/changes/latest?section=unknown').Status -eq 400) 'Invalid section accepted.'
Assert ((Request '/swagger/v1/swagger.json').Status -eq 200) 'Swagger failed.'
if($TestLocalSampleRoles){
 Assert (([uri]$BaseUrl).IsLoopback) 'Temporary role tests must use localhost.'
 Add-Type -AssemblyName System.Data
 $c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=SecurityDB;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;')
 $c.Open();$role='CompanyPortal.Phase4.'+[guid]::NewGuid().ToString('N');$saved=$null
 function Sql($text){$cmd=$c.CreateCommand();$cmd.CommandText=$text;$cmd.CommandTimeout=15;return $cmd}
 try{
  $cmd=Sql "SELECT ur.UserRoleId,ur.Active,ur.LastChangeAt,ur.UserId FROM dbo.UserRoles ur JOIN dbo.Users u ON u.UserId=ur.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin'"
  $table=[Data.DataTable]::new();$table.Load($cmd.ExecuteReader());Assert ($table.Rows.Count -eq 1) 'Expected one sample grant.';$saved=$table.Rows[0];Assert $saved.Active 'Super grant must start active.'
  $cmd=Sql "SET XACT_ABORT ON; BEGIN TRAN; INSERT dbo.Roles(RoleName) VALUES(@role); DECLARE @id int=SCOPE_IDENTITY(); INSERT dbo.UserRoles(UserId,RoleId) VALUES(@user,@id); INSERT CompanyPortal.Portal.AdminSectionRoles(SectionKey,RoleName) VALUES('media',@role); UPDATE dbo.UserRoles SET Active=0 WHERE UserRoleId=@grant; COMMIT;"
  [void]$cmd.Parameters.AddWithValue('@role',$role);[void]$cmd.Parameters.AddWithValue('@user',[int]$saved.UserId);[void]$cmd.Parameters.AddWithValue('@grant',[int]$saved.UserRoleId);[void]$cmd.ExecuteNonQuery()
  $limited=(Request '/api/access').Data;Assert (!$limited.isSuperAdmin -and @($limited.sections).Count -eq 1 -and $limited.sections[0] -eq 'media') 'Limited grant not applied.'
  $r=Request '/api/admin/overview';Assert ($r.Status -eq 200) 'Limited overview failed.'
  Assert (@($r.Data.cards).Count -eq 2) 'Limited overview must contain only magazine and media.'
  Assert (@($r.Data.cards|Where-Object { $_.section -and $_.section -ne 'media' }).Count -eq 0) 'Unpermitted card leaked.'
  Assert (@($r.Data.changes|Where-Object section -ne 'media').Count -eq 0) 'Unpermitted history leaked.'
  Assert ((Request '/api/admin/changes/latest?section=header-content').Status -eq 403) 'Unpermitted latest must be 403.'
  Assert ((Request '/api/admin/changes/latest?section=media').Status -eq 200) 'Permitted latest failed.'
  $cmd=Sql 'DELETE CompanyPortal.Portal.AdminSectionRoles WHERE RoleName=@role';[void]$cmd.Parameters.AddWithValue('@role',$role);[void]$cmd.ExecuteNonQuery()
  Assert ((Request '/api/admin/overview').Status -eq 403) 'Employee overview must be 403.'
  Assert ((Request '/api/admin/changes/latest?section=media').Status -eq 403) 'Employee latest must be 403.'
 }finally{
  if($null -ne $saved){
   $cmd=Sql 'SET XACT_ABORT ON; BEGIN TRAN; UPDATE dbo.UserRoles SET Active=@active,LastChangeAt=@at WHERE UserRoleId=@id; DELETE CompanyPortal.Portal.AdminSectionRoles WHERE RoleName=@role; DELETE ur FROM dbo.UserRoles ur JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE r.RoleName=@role; DELETE dbo.Roles WHERE RoleName=@role; COMMIT;'
   [void]$cmd.Parameters.AddWithValue('@active',[bool]$saved.Active);[void]$cmd.Parameters.AddWithValue('@at',[datetime]$saved.LastChangeAt);[void]$cmd.Parameters.AddWithValue('@id',[int]$saved.UserRoleId);[void]$cmd.Parameters.AddWithValue('@role',$role);[void]$cmd.ExecuteNonQuery()
  };$c.Dispose()
 }
 Assert ((Request '/api/access').Data.isSuperAdmin) 'Original grant was not restored.'
}
Write-Host 'PASS: overview/latest authorization, section filters, summary-only data, Swagger; temporary sample grants restored when requested.'
