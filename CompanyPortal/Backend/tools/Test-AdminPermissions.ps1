param([string]$ApiDll=(Join-Path $PSScriptRoot '../../../.local/roles-api/CompanyPortal.Api.dll'),[int]$Port=5879)
$ErrorActionPreference='Stop'
$fixtureDb='CompanyPortal_RoleTest_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$account=[Security.Principal.WindowsIdentity]::GetCurrent().Name.Replace("'","''")
$admin=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$test=$null;$process=$null
function Sql($connection,$sql){$c=$connection.CreateCommand();$c.CommandText=$sql;$c.CommandTimeout=30;[void]$c.ExecuteNonQuery()}
function Assert($ok,$message){if(-not $ok){throw $message}}
$base="http://localhost:$Port"
function Call($path,$method='GET',$body=$null,$headers=@{}){$args=@{Uri=$base+$path;Method=$method;Headers=$headers;UseDefaultCredentials=$true;AllowUnencryptedAuthentication=$true;SkipHttpErrorCheck=$true};if($null -ne $body){$args.Body=$body|ConvertTo-Json -Depth 5 -Compress;$args.ContentType='application/json'};Invoke-WebRequest @args}
try{
 $admin.Open();Sql $admin "CREATE DATABASE [$fixtureDb]";$test=[Data.SqlClient.SqlConnection]::new("Server=localhost;Database=$fixtureDb;Integrated Security=True;Encrypt=True;TrustServerCertificate=True");$test.Open()
 foreach($schema in 'Portal','Security','Mng'){Sql $test "CREATE SCHEMA $schema"}
 Sql $test "CREATE TABLE dbo.SourceRoles(RoleName nvarchar(200) NOT NULL PRIMARY KEY,Assigned bit NOT NULL DEFAULT(0),Active bit NOT NULL DEFAULT(1));INSERT dbo.SourceRoles(RoleName,Assigned) VALUES(N'CompanyPortal.Admin',1),(N'CompanyPortal.Directory',0),(N'CompanyPortal.Status',0),(N'CompanyPortal.Content',0);"
 Sql $test "CREATE TABLE Portal.AdminSectionRoles(AdminSectionRoleId int IDENTITY PRIMARY KEY,RoleName nvarchar(200) COLLATE Latin1_General_100_BIN2 NOT NULL,SectionKey nvarchar(40) NOT NULL,Active bit NOT NULL DEFAULT(1),LastChangeAt datetime NOT NULL DEFAULT(GETDATE()),UNIQUE(SectionKey,RoleName));INSERT Portal.AdminSectionRoles(RoleName,SectionKey) VALUES(N'CompanyPortal.Directory',N'important-numbers'),(N'CompanyPortal.Status',N'institution-status');SELECT TOP(0) * INTO Portal.AdminChanges FROM CompanyPortal.Portal.AdminChanges;"
 Sql $test "CREATE PROCEDURE Security.User_getByUsername @Username nvarchar(512) AS SELECT 1 UserId WHERE @Username=N'$account';"
 Sql $test 'CREATE PROCEDURE Security.UserRoles_get @UserId int AS SELECT RoleName FROM dbo.SourceRoles WHERE Active=1 AND Assigned=1 AND @UserId=1;'
 Sql $test 'CREATE PROCEDURE Security.Roles_getForAdministration AS SELECT RoleName FROM dbo.SourceRoles WHERE Active=1;'
 foreach($proc in 'Portal.AdminAccess_get','Portal.AdminSectionRoles_Get','Portal.AdminSectionRoles_Save'){$cmd=$admin.CreateCommand();$cmd.CommandText="SELECT definition FROM CompanyPortal.sys.sql_modules WHERE object_id=OBJECT_ID(N'CompanyPortal.$proc')";$definition=[string]$cmd.ExecuteScalar();Assert ($definition.Length -gt 50) "Missing source proc $proc";Sql $test $definition}
 Sql $test 'CREATE TABLE Mng.CurrentStatus(Id int IDENTITY PRIMARY KEY);ALTER TABLE Portal.AdminChanges ADD CONSTRAINT DF_TestChangedAt DEFAULT(GETDATE()) FOR ChangedAt;'
 $migration=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../Database/Scripts/065_RolesWorkstationsPopups.sql')).Replace('USE CompanyPortal;',"USE [$fixtureDb];")
 foreach($batch in [regex]::Split($migration,'(?im)^GO\s*$')){if($batch.Trim()){Sql $test $batch}}
 Sql $test 'ALTER TABLE Portal.AdminChanges ADD CONSTRAINT DF_TestWorkstation DEFAULT(HOST_NAME()) FOR WorkStation;'
 Sql $test "CREATE OR ALTER PROCEDURE Security.Role_Create @RoleName nvarchar(200) AS BEGIN IF EXISTS(SELECT 1 FROM dbo.SourceRoles WHERE RoleName=@RoleName) THROW 50006,'Duplicate role.',1;INSERT dbo.SourceRoles(RoleName) VALUES(@RoleName);END;"
 Sql $test "CREATE OR ALTER PROCEDURE Security.Role_Deactivate @RoleName nvarchar(200) AS UPDATE dbo.SourceRoles SET Active=0 WHERE RoleName=@RoleName;"
 $cmd=$admin.CreateCommand();$cmd.CommandText="SELECT definition FROM CompanyPortal.sys.sql_modules WHERE object_id=OBJECT_ID(N'CompanyPortal.Portal.AdminChanges_Add')";Sql $test ([string]$cmd.ExecuteScalar())
 Sql $test "CREATE PROCEDURE Mng.ImportantNumbers_GetAll AS SELECT 1 Id,N'Test number' Title,N'1000' Number,1 SortOrder,CAST(1 AS bit) Active,GETDATE() LastChangeAt;"
 Sql $test "CREATE PROCEDURE Mng.StatusLevels_GetAll AS SELECT CAST(1 AS tinyint) ColorValue,N'Normal' Title,N'Green' ColorName,N'Summary' Summary,CAST(NULL AS nvarchar(300)) GuideText,CAST(NULL AS nvarchar(1500)) Actions,GETDATE() LastChangeAt;"
 Sql $test "CREATE PROCEDURE Mng.CurrentStatus_AdminGet AS BEGIN SELECT 1 Id,CAST(1 AS tinyint) ColorValue,GETDATE() LastUpdated,CAST(NULL AS nvarchar(512)) ChangedBy,CAST(NULL AS int) UserId;SELECT CAST(1 AS bigint) AdminChangeId,GETDATE() ChangedAt,N'' ChangedBy,CAST(NULL AS int) StatusId,CAST(NULL AS int) FromColorValue,CAST(NULL AS nvarchar(100)) FromTitle,CAST(NULL AS int) ToColorValue,CAST(NULL AS nvarchar(100)) ToTitle WHERE 1=0;END;"
 Sql $test "CREATE PROCEDURE Portal.AdminAuthors_Get @NamesJson nvarchar(max) AS SELECT CAST(NULL AS nvarchar(512)) ChangedBy,CAST(NULL AS nvarchar(1000)) DisplayName WHERE 1=0;"
 $env:ASPNETCORE_ENVIRONMENT='Development';$env:ConnectionStrings__CompanyPortal="Server=localhost;Database=$fixtureDb;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5;"
 $ApiDll=[IO.Path]::GetFullPath($ApiDll);$apiRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../CompanyPortal.Api'));$logRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../.local'))
 $process=Start-Process -FilePath dotnet -ArgumentList @($ApiDll,'--urls',$base,'--contentRoot',$apiRoot) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'permission-test-api.log') -RedirectStandardError (Join-Path $logRoot 'permission-test-api.err')
 for($i=0;$i -lt 30;$i++){try{$ready=Call '/api/access';if($ready.StatusCode -eq 200){break}}catch{};Start-Sleep -Milliseconds 300}
 Assert ($ready.StatusCode -eq 200) 'Fixture API did not start'
 Assert ((Call '/api/admin/permissions').StatusCode -eq 200) 'Super-admin catalog failed'
 $head=@{'X-CompanyPortal-Request'='admin-permissions'}
 Assert ((Call '/api/admin/permissions' 'POST' @{roleName='CompanyPortal.TestCreated';sections=@('notices')} $head).StatusCode -eq 201) 'Create role failed'
 Assert ((Call '/api/admin/permissions' 'POST' @{roleName='CompanyPortal.TestCreated';sections=@()} $head).StatusCode -eq 400) 'Duplicate role accepted'
 Assert ((Call '/api/admin/permissions' 'DELETE' @{roleName='CompanyPortal.Admin'} $head).StatusCode -eq 400) 'Super role deleted'
 Assert ((Call '/api/admin/permissions' 'DELETE' @{roleName='CompanyPortal.TestCreated'} $head).StatusCode -eq 204) 'Role soft delete failed'
 $check=$test.CreateCommand();$check.CommandText="SELECT COUNT(*) FROM dbo.SourceRoles WHERE RoleName=N'CompanyPortal.TestCreated' AND Active=0";Assert ($check.ExecuteScalar() -eq 1) 'Role physically deleted or still active'
 $check.CommandText='SELECT COUNT(*) FROM Portal.AdminChanges';Assert ($check.ExecuteScalar() -eq 0) 'Role changes created audit entries'
 $popupHeaders=@{'X-CompanyPortal-Request'='custom-popups'}
 $popup=@{popupType='Custom type';details='Plain text <script> stays text';startAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('o');endAt=[DateTimeOffset]::UtcNow.AddHours(1).ToString('o');isDisplayed=$true}
 Assert ((Call '/api/admin/custom-popups' 'POST' $popup $popupHeaders).StatusCode -eq 201) 'Create popup failed'
 $popupRows=(Call '/api/custom-popups').Content|ConvertFrom-Json;$pidValue=@($popupRows)[0].popupId
 Assert (@($popupRows).Count -eq 1) 'Popup not visible'
 Assert ((Call "/api/custom-popups/$pidValue/dismiss" 'POST' $null @{'X-CompanyPortal-Request'='popup-dismiss'}).StatusCode -eq 204) 'Dismiss popup failed'
 Assert (@((Call '/api/custom-popups').Content|ConvertFrom-Json).Count -eq 0) 'Dismissed popup returned'
 Assert ((Call "/api/custom-popups/$pidValue/dismiss" 'POST' $null @{'X-CompanyPortal-Request'='popup-dismiss'}).StatusCode -eq 204) 'Repeated dismissal failed'
 $check.CommandText="SELECT COUNT(*) FROM Portal.UserPopupDismissals";Assert ($check.ExecuteScalar() -eq 1) 'Duplicate dismissal'
 $check.CommandText="SELECT COUNT(*) FROM Portal.AdminChanges WHERE WorkStation IS NOT NULL AND WorkStation<>N''";Assert ($check.ExecuteScalar() -eq 1) 'Missing workstation in popup history'

 Sql $test "CREATE OR ALTER PROCEDURE Security.User_getByUsername @Username nvarchar(512) AS SELECT 2 UserId WHERE @Username=N'$account';"
 Assert (@((Call '/api/custom-popups').Content|ConvertFrom-Json).Count -eq 1) 'Dismissal leaked to another employee'
 Sql $test "CREATE OR ALTER PROCEDURE Security.User_getByUsername @Username nvarchar(512) AS SELECT 1 UserId WHERE @Username=N'$account';"
 $popup.endAt=$popup.startAt;Assert ((Call '/api/admin/custom-popups' 'POST' $popup $popupHeaders).StatusCode -eq 400) 'Invalid popup date accepted'
 $popup.endAt=[DateTimeOffset]::UtcNow.AddHours(1).ToString('o');$popup.isDisplayed=$false
 Assert ((Call '/api/admin/custom-popups' 'POST' $popup $popupHeaders).StatusCode -eq 201) 'Hidden draft creation failed'
 Assert (@((Call '/api/custom-popups').Content|ConvertFrom-Json).Count -eq 0) 'Hidden popup visible'
 Assert ((Call "/api/admin/custom-popups/$pidValue" 'DELETE' $null $popupHeaders).StatusCode -eq 204) 'Popup deletion failed'
 Sql $test 'DELETE Portal.AdminChanges;'

 $write=@{'X-CompanyPortal-Request'='admin-permissions'}
 $r=Call '/api/admin/permissions' 'PUT' @{roleName='CompanyPortal.Content';sections=@('media','events')} $write;Assert ($r.StatusCode -eq 204) 'Permission save failed'
 $catalog=(Call '/api/admin/permissions').Content|ConvertFrom-Json;Assert ((($catalog.roles|Where-Object roleName -eq 'CompanyPortal.Content').sections -join ',') -eq 'events,media' -or (($catalog.roles|Where-Object roleName -eq 'CompanyPortal.Content').sections -join ',') -eq 'media,events') 'Saved permissions not returned'
 foreach($body in @(@{roleName='CompanyPortal.Admin';sections=@()},@{roleName='missing-role';sections=@('media')},@{roleName='CompanyPortal.Content';sections=@('permissions')},@{roleName='CompanyPortal.Content';sections=@('header-content')})){Assert ((Call '/api/admin/permissions' 'PUT' $body $write).StatusCode -eq 400) 'Invalid/fixed role or section accepted'}
 Assert ((Call '/api/admin/permissions' 'PUT' @{roleName='CompanyPortal.Content';sections=@('media')}).StatusCode -eq 400) 'Missing header accepted'
 Assert ((Call '/api/admin/permissions' 'PUT' @{roleName='CompanyPortal.Content';sections=@('media')} @{'X-CompanyPortal-Request'='admin-permissions';Origin='https://wrong.test'}).StatusCode -eq 403) 'Foreign origin accepted'
 $cmd=$test.CreateCommand();$cmd.CommandText='SELECT COUNT(*) FROM Portal.AdminChanges';Assert ($cmd.ExecuteScalar() -eq 0) 'Permission changes were audited'
 Sql $test "UPDATE dbo.SourceRoles SET Assigned=CASE WHEN RoleName=N'CompanyPortal.Directory' THEN 1 ELSE 0 END;"
 $r=Call '/api/admin/header-content';Assert ($r.StatusCode -eq 200) 'Directory read failed';$d=$r.Content|ConvertFrom-Json;Assert ($d.numbers.Count -eq 1 -and $d.levels.Count -eq 0) 'Directory received status admin data'
 Assert ((Call '/api/admin/header-content/current-status').StatusCode -eq 403) 'Directory can read status history'
 Assert ((Call '/api/admin/header-content/current-status' 'PUT' @{colorValue=1} @{'X-CompanyPortal-Request'='header-content'}).StatusCode -eq 403) 'Directory can write current status'
 Assert ((Call '/api/admin/permissions').StatusCode -eq 403) 'Limited role can manage permissions'
 Assert ((Call '/api/admin/changes').StatusCode -eq 403) 'Limited role can read full history'
 Assert ((Call '/api/admin/health').StatusCode -eq 403) 'Limited role can run health checks'
 Sql $test "UPDATE dbo.SourceRoles SET Assigned=CASE WHEN RoleName=N'CompanyPortal.Status' THEN 1 ELSE 0 END;"
 $r=Call '/api/admin/header-content';Assert ($r.StatusCode -eq 200) 'Status read failed';$d=$r.Content|ConvertFrom-Json;Assert ($d.numbers.Count -eq 0 -and $d.levels.Count -eq 1) 'Status received numbers admin data'
 Assert ((Call '/api/admin/header-content/current-status').StatusCode -eq 200) 'Status cannot read its history'
 Assert ((Call '/api/admin/header-content/important-numbers' 'POST' @{} @{'X-CompanyPortal-Request'='header-content'}).StatusCode -eq 403) 'Status can write numbers'
 Sql $test "UPDATE dbo.SourceRoles SET Assigned=1 WHERE RoleName=N'CompanyPortal.Directory';"
 $access=(Call '/api/access').Content|ConvertFrom-Json;Assert ($access.sections -contains 'important-numbers' -and $access.sections -contains 'institution-status') 'Multiple roles did not combine'
 Sql $test "UPDATE Portal.AdminSectionRoles SET Active=0 WHERE SectionKey=N'important-numbers';"
 $access=(Call '/api/access').Content|ConvertFrom-Json;Assert ($access.sections -notcontains 'important-numbers') 'Revocation not effective on next request'
 Assert ((Invoke-WebRequest ($base+'/api/admin/permissions') -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous permissions access'
 Assert ((Call '/swagger/v1/swagger.json').StatusCode -eq 200) 'Swagger failed'
 Write-Output 'PASS isolated API: role creation/duplicate/soft-delete, custom popup display/dismiss/idempotency/per-user/hidden/date validation, workstation history, super-only permissions, save/reload, invalid role/section, immutable super role, headers/origin, no audit, Directory/Status read-write separation, combined roles, immediate revocation, 401/403, Swagger.'
}finally{
 if($process -and -not $process.HasExited){Stop-Process -Id $process.Id -Force}
 if($test){$test.Dispose()}
 if($admin.State -eq 'Open' -and $fixtureDb -match '^CompanyPortal_RoleTest_[a-f0-9]{12}$'){Sql $admin "IF DB_ID(N'$fixtureDb') IS NOT NULL BEGIN ALTER DATABASE [$fixtureDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [$fixtureDb];END;"}
 $admin.Dispose()
}
