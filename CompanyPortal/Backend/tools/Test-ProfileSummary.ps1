param([string]$ApiBase='http://localhost:5091')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Use a local test API only.'}
function Assert($ok,$message){if(-not $ok){throw $message}}
function Read-Api($path){Invoke-WebRequest ($ApiBase+$path) -UseDefaultCredentials -AllowUnencryptedAuthentication}
$connection=New-Object Data.SqlClient.SqlConnection 'Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
function Sql-Value($sql){$cmd=$connection.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
function Sql-Run($sql){$cmd=$connection.CreateCommand();$cmd.CommandText=$sql;[void]$cmd.ExecuteNonQuery()}
try{
 $connection.Open()
 Assert ((Sql-Value "SELECT COUNT(*) FROM sys.extended_properties WHERE class=0 AND name=N'CompanyPortalProfileFixture'") -eq 1) 'Local profile fixture required.'
 $cmd=$connection.CreateCommand();$cmd.CommandText='Security.User_getByUsername';$cmd.CommandType=[Data.CommandType]::StoredProcedure;[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$userId=[int]$cmd.ExecuteScalar()
 Assert ($userId -gt 0) 'Current employee not registered.'
 $attendance=Read-Api '/api/profile/attendance';$row=($attendance.Content|ConvertFrom-Json).data
 Assert ($attendance.StatusCode-eq 200 -and $attendance.Headers['Cache-Control']-match 'no-store' -and $row.displayName) 'Attendance/profile read failed.'
 Assert ($row.arrivalAt -and $row.expectedLeaveAt) 'Today fixture times missing.'
 $balance=(Read-Api '/api/profile/leave-balance').Content|ConvertFrom-Json
 Assert ($null-ne $balance.data.holidayDays -and $null-ne $balance.data.daysToBeDeleted) 'Leave balance missing.'
 $own=(Read-Api '/api/profile/leave-balance?userId=2147483000').Content|ConvertFrom-Json
 Assert (($own|ConvertTo-Json -Compress)-eq ($balance|ConvertTo-Json -Compress)) 'Caller-supplied UserId changed employee scope.'
 try{Invoke-WebRequest ($ApiBase+'/api/profile/attendance')|Out-Null;throw 'Anonymous profile access succeeded.'}catch{Assert ($_.Exception.Response.StatusCode.value__-eq 401) 'Anonymous response was not 401.'}
 $attendanceId=Sql-Value "SELECT ProfileAttendanceID FROM Development.ProfileAttendance WHERE UserId=$userId AND AttendanceDate=CONVERT(date,GETDATE())"
 $balanceId=Sql-Value "SELECT ProfileLeaveBalanceID FROM Development.ProfileLeaveBalances WHERE UserId=$userId"
 $attendanceActive=Sql-Value "SELECT CONVERT(int,Active) FROM Development.ProfileAttendance WHERE ProfileAttendanceID=$attendanceId"
 $balanceActive=Sql-Value "SELECT CONVERT(int,Active) FROM Development.ProfileLeaveBalances WHERE ProfileLeaveBalanceID=$balanceId"
 try{
  Sql-Run "UPDATE Development.ProfileAttendance SET Active=0 WHERE ProfileAttendanceID=$attendanceId"
  $missing=(Read-Api '/api/profile/attendance').Content|ConvertFrom-Json
  Assert ($missing.data.displayName -and $null-eq $missing.data.arrivalAt -and $null-eq $missing.data.expectedLeaveAt) 'Missing attendance exposed illustrative times.'
  Assert ((Read-Api '/api/profile/leave-balance').StatusCode-eq 200) 'Independent balance read failed.'
  Sql-Run "UPDATE Development.ProfileLeaveBalances SET Active=0 WHERE ProfileLeaveBalanceID=$balanceId"
  $missingBalance=(Read-Api '/api/profile/leave-balance').Content|ConvertFrom-Json
  Assert ($null-eq $missingBalance.data) 'Missing leave row did not return explicit null.'
 }finally{
  Sql-Run "UPDATE Development.ProfileAttendance SET Active=$attendanceActive WHERE ProfileAttendanceID=$attendanceId; UPDATE Development.ProfileLeaveBalances SET Active=$balanceActive WHERE ProfileLeaveBalanceID=$balanceId"
 }
 $swagger=Invoke-RestMethod ($ApiBase+'/swagger/v1/swagger.json') -UseDefaultCredentials -AllowUnencryptedAuthentication
 Assert ($swagger.paths.'/api/profile/attendance' -and $swagger.paths.'/api/profile/leave-balance') 'Swagger profile contracts missing.'
 Write-Output 'Profile checks passed: current-user scope, anonymous denial, no-store, DB times/balances, independent missing-data handling, Swagger. Fixture flags restored.'
}finally{$connection.Dispose()}


