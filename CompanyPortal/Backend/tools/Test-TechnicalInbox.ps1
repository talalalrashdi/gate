param([string]$ApiBase='http://localhost:5877')
$ErrorActionPreference='Stop'
if(([uri]$ApiBase).Host -notin @('localhost','127.0.0.1')){throw 'Local fixture only'}
function Assert($ok,$msg){if(-not $ok){throw $msg}}
function Get($path){Invoke-RestMethod ($ApiBase+$path) -UseDefaultCredentials -AllowUnencryptedAuthentication}
$c=[Data.SqlClient.SqlConnection]::new('Server=localhost;Database=CompanyPortal;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$ids=[Collections.Generic.List[long]]::new();$marker='Technical test '+[guid]::NewGuid()
function Scalar($sql){$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.ExecuteScalar()}
try{
 $c.Open();Assert ((Scalar "SELECT COUNT(*) FROM IsnadDB.sys.extended_properties WHERE class=0 AND name=N'CompanyPortalDevelopmentFixture' AND CONVERT(int,value)=1") -eq 1) 'Marked source required'
 $cmd=$c.CreateCommand();$cmd.CommandType='StoredProcedure';$cmd.CommandText='Security.User_getByUsername';[void]$cmd.Parameters.AddWithValue('@Username',[Security.Principal.WindowsIdentity]::GetCurrent().Name);$user=[int]$cmd.ExecuteScalar();Assert ($user -gt 0) 'Registered user required'
 $before=Get '/api/technical-inbox';Assert ($before.items.Count -ge 7) 'Seven samples missing'
 $id=[long](Scalar "INSERT IsnadDB.dbo.TechnicalInbox(UserId,RequestType,Details,HasAttachment) OUTPUT inserted.TechnicalInboxId VALUES($user,N'Test',N'$marker',1)");$ids.Add($id)
 $other=[long](Scalar "INSERT IsnadDB.dbo.TechnicalInbox(UserId,RequestType,Details) OUTPUT inserted.TechnicalInboxId VALUES(2147483000,N'Test',N'$marker')");$ids.Add($other)
 $full=Get '/api/technical-inbox';$count=Get '/api/technical-inbox/count';$row=$full.items|Where-Object inboxId -eq "$id"
 Assert ($row.hasAttachment -and $null -eq $row.documentNumber -and $null -eq $row.officeNumber -and -not $row.isOpened) 'Optional fields/attachment/read contract'
 Assert (-not ($full.items|Where-Object inboxId -eq "$other")) 'Other employee data exposed'
 Assert ($full.unreadCount -eq $before.unreadCount+1 -and $count.unreadCount -eq $full.unreadCount) 'Unread count mismatch'
 Assert (-not ($count.PSObject.Properties.Name -contains 'items')) 'Count returned inbox rows'
 [void](Scalar "UPDATE IsnadDB.dbo.TechnicalInbox SET IsOpened=1 WHERE TechnicalInboxId=$id")
 $full=Get '/api/technical-inbox';Assert (($full.items|Where-Object inboxId -eq "$id").isOpened -and $full.unreadCount -eq $before.unreadCount) 'Source read acknowledgement not reflected'
 [void](Scalar "UPDATE IsnadDB.dbo.TechnicalInbox SET Active=0 WHERE TechnicalInboxId=$id")
 Assert (-not ((Get '/api/technical-inbox').items|Where-Object inboxId -eq "$id")) 'Inactive item exposed'
 $cards=Get '/api/admin/cards';Assert ($cards|Where-Object cardKey -eq 'technical-inbox') 'New card missing in administration'
 $order=Get '/api/user-settings/card-order';Assert ($order.cards|Where-Object cardKey -eq 'technical-inbox') 'New card missing in employee catalog'
 foreach($path in '/api/technical-inbox','/api/technical-inbox/count'){Assert ((Invoke-WebRequest ($ApiBase+$path) -SkipHttpErrorCheck).StatusCode -eq 401) 'Anonymous allowed'}
 Assert ((Invoke-WebRequest ($ApiBase+'/swagger/v1/swagger.json') -UseDefaultCredentials -AllowUnencryptedAuthentication).StatusCode -eq 200) 'Swagger failed'
 Write-Output 'PASS technical inbox: samples, optional fields/attachments, per-user isolation, source read/count, inactive filtering, admin/employee catalogs, anonymous 401, Swagger.'
}finally{if($c.State -eq 'Open'){foreach($id in $ids){[void](Scalar "DELETE IsnadDB.dbo.TechnicalInbox WHERE TechnicalInboxId=$id AND Details=N'$marker'")}};$c.Dispose()}
