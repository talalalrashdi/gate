param([string]$BaseUrl='http://localhost:5091')
$ErrorActionPreference='Stop'
if (-not ([uri]$BaseUrl).IsLoopback) { throw 'This test creates/removes a disposable local card. Loopback only.' }
function Assert($value,[string]$message){if(-not $value){throw $message}}
function Request([string]$path,[string]$method='GET',$body=$null,[hashtable]$headers=@{},[bool]$authenticated=$true){
 $r=[Net.HttpWebRequest]::Create($BaseUrl+$path);$r.Method=$method;$r.UseDefaultCredentials=$authenticated;$r.AllowAutoRedirect=$false;$r.Timeout=15000
 foreach($key in $headers.Keys){$r.Headers[$key]=$headers[$key]}
 if($null-ne $body){$bytes=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 8 -Compress));$r.ContentType='application/json';$r.ContentLength=$bytes.Length;$s=$r.GetRequestStream();try{$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 try{$response=$r.GetResponse()}catch{$response=$_.Exception.GetBaseException().Response;if(-not $response){throw}}
 try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()};@{status=[int]$response.StatusCode;content=$content}}finally{$response.Close()}
}
function ReadJson([string]$path){$r=Request $path;Assert ($r.status-eq 200) "GET $path failed: $($r.status) $($r.content)";($r.content|ConvertFrom-Json)|ForEach-Object {$_}}
$header=@{'X-CompanyPortal-Request'='admin-cards'}
$id=$null;$key=$null
$tag='MasterCardTest-'+[guid]::NewGuid().ToString('N')
$before=@(ReadJson '/api/admin/cards')
$catalog=@(ReadJson '/api/admin/cards/applications');Assert ($catalog.Count-ge 1) 'Need local sample apps.'
$allowed=@(ReadJson '/api/applications');$allowedIds=@($allowed|ForEach-Object appId)
$selected=@($catalog|Select-Object -First 100|ForEach-Object appId)
$body=@{cardName=$tag;displayOrder=(@($before|Where-Object active).Count+1);isFixed=$false;active=$false;audience='everyone';appIds=$selected;roleNames=@()}
try{
 Assert ((Request '/api/admin/cards' 'POST' $body @{}).status-eq 400) 'Missing header accepted.'
 $foreign=Request '/api/admin/cards' 'POST' $body @{'X-CompanyPortal-Request'='admin-cards';Origin='https://untrusted.invalid'}
 Assert ($foreign.status-eq 403) "Foreign origin check returned $($foreign.status): $($foreign.content)"
 Assert ((Request '/api/admin/cards/applications' 'GET' $null @{} $false).status-eq 401) 'Anonymous admin app catalog accepted.'
 $r=Request '/api/admin/cards' 'POST' $body $header;Assert ($r.status-eq 201) "Create failed $($r.content)";$id=($r.content|ConvertFrom-Json).cardId
 $saved=@(ReadJson '/api/admin/cards')|Where-Object cardId -eq $id;$key=$saved.cardKey
 Assert ($saved.cardType-eq 'applications' -and -not $saved.active) 'Hidden creation lost.'
 Assert (-not ((ReadJson '/api/user-settings/card-order').cardKeys-contains $key)) 'Hidden card exposed.'
 Assert ((Request "/api/admin/cards/$id" 'PUT' $body $header).status-eq 204) 'No-op save failed.'
 $same=@(ReadJson '/api/admin/cards')|Where-Object cardId -eq $id;Assert ($same.lastChangeAt-eq $saved.lastChangeAt) 'No-op changed timestamp.'
 $body.active=$true;$body.cardName=$tag+' <b>literal</b>'
 Assert ((Request "/api/admin/cards/$id" 'PUT' $body $header).status-eq 204) 'Activation failed.'
 $employee=ReadJson '/api/user-settings/card-order';$card=@($employee.cards|Where-Object cardKey -eq $key)[0]
 Assert ($null-ne $card -and $card.cardName-ceq $body.cardName) 'Employee master app card missing/name modified.'
 $expected=@($selected|Where-Object {$allowedIds-contains $_}|Sort-Object)
 Assert ((@($card.applications|ForEach-Object appId|Sort-Object)-join ',')-eq ($expected-join ',')) 'Employee app grants bypassed.'
 Assert ((Request '/api/user-settings/card-order' 'PUT' @{cardKeys=@($employee.cardKeys)} @{'X-CompanyPortal-Request'='card-order'}).status-eq 204) 'Valid dynamic-card order rejected.'
 foreach($app in @($catalog|Where-Object {$allowedIds-notcontains $_.appId})) {Assert ((Request "/api/applications/$($app.appId)/launch").status-eq 404) 'Unpermitted app launch accepted.'}
 $body.audience='roles';$body.roleNames=@('CompanyPortal.Test.Unassigned.'+$tag)
 Assert ((Request "/api/admin/cards/$id" 'PUT' $body $header).status-eq 204) 'Role restriction failed.'
 Assert (-not ((ReadJson '/api/user-settings/card-order').cardKeys-contains $key)) 'Unassigned role leaked card.'
 $body.roleNames=@('CompanyPortal.Admin')
 Assert ((Request "/api/admin/cards/$id" 'PUT' $body $header).status-eq 204) 'Matching role save failed.'
 Assert ((ReadJson '/api/user-settings/card-order').cardKeys-contains $key) 'Matching role lost.'
 $body.isFixed=$true;$body.displayOrder=2
 Assert ((Request "/api/admin/cards/$id" 'PUT' $body $header).status-eq 204) 'Fixed save failed.'
 $employee=ReadJson '/api/user-settings/card-order';Assert ($employee.cardKeys[1]-eq $key) 'Fixed slot not applied.'
 $bad=@($employee.cardKeys);$bad[1]=$bad[0];$bad[0]=$key
 Assert ((Request '/api/user-settings/card-order' 'PUT' @{cardKeys=$bad} @{'X-CompanyPortal-Request'='card-order'}).status-eq 400) 'Fixed card moved.'
 $invalid=$body.Clone();$invalid.appIds=@(2147483647)
 Assert ((Request "/api/admin/cards/$id" 'PUT' $invalid $header).status-eq 400) 'Unknown app accepted.'
 $invalid=$body.Clone();$invalid.userId=1
 Assert ((Request "/api/admin/cards/$id" 'PUT' $invalid $header).status-eq 400) 'Client identity accepted.'
 $invalid=$body.Clone();$invalid.roleNames=@()
 Assert ((Request "/api/admin/cards/$id" 'PUT' $invalid $header).status-eq 400) 'Empty role audience accepted.'
 $body.active=$false
 Assert ((Request "/api/admin/cards/$id" 'PUT' $body $header).status-eq 204) 'Hide failed.'
 Assert (-not ((ReadJson '/api/user-settings/card-order').cardKeys-contains $key)) 'Hidden fixed card exposed.'
 $swagger=ReadJson '/swagger/v1/swagger.json';Assert ($null-ne $swagger.paths.'/api/admin/cards'.post) 'Swagger create missing.'
 'PASS: create/no-op/activate/hide, role audience, fixed slots, app filtering/launch, validation, header/origin/anonymous checks and Swagger.'
}finally{
 if($id){
  # Only the uniquely named fixture created by this invocation is removed.
  $query="SET XACT_ABORT ON; BEGIN TRAN; DECLARE @Id int=$id; IF EXISTS(SELECT 1 FROM Master.Cards WHERE CardId=@Id AND CardType=N'applications' AND CardName LIKE N'$tag%') BEGIN DELETE FROM Master.CardApplications WHERE CardId=@Id; DELETE FROM Master.CardRoles WHERE CardId=@Id; DELETE FROM Portal.UserWorkspaceOrder WHERE CardKey=(SELECT CardKey FROM Master.Cards WHERE CardId=@Id); DELETE FROM Master.Cards WHERE CardId=@Id; END; COMMIT;"
  & sqlcmd -S localhost -E -b -I -d CompanyPortal -Q $query
  if($LASTEXITCODE-ne 0){throw 'Fixture cleanup failed.'}
 }
}
