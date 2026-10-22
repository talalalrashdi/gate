param([string]$BaseUrl='http://localhost:5081',[switch]$TestSampleRevocation)
$ErrorActionPreference='Stop'
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Request([string]$Method,[string]$Path,[string]$Body='',[hashtable]$Headers=@{},[bool]$Authenticated=$true) {
    $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$Path)
    $request.Method=$Method; $request.UseDefaultCredentials=$Authenticated; $request.AllowAutoRedirect=$false; $request.Timeout=10000
    foreach($key in $Headers.Keys) { $request.Headers[$key]=$Headers[$key] }
    if ($Body) { $bytes=[Text.Encoding]::UTF8.GetBytes($Body); $request.ContentType='application/json'; $request.ContentLength=$bytes.Length; $stream=$request.GetRequestStream(); try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() } }
    try { $response=$request.GetResponse() } catch { $response=$_.Exception.GetBaseException().Response; if (-not $response) { throw } }
    try { $reader=[IO.StreamReader]::new($response.GetResponseStream()); try { $content=$reader.ReadToEnd() } finally { $reader.Dispose() }; return @{Status=[int]$response.StatusCode;Content=$content} } finally { $response.Close() }
}
function SampleRole([bool]$Active) {
    Assert (([uri]$BaseUrl).IsLoopback) 'Sample role tests are local-only.'
    $value=if($Active){1}else{0}
    $query="SET NOCOUNT ON; UPDATE ur SET Active=$value,LastChangeAt=GETDATE() FROM dbo.UserRoles ur JOIN dbo.Users u ON u.UserId=ur.UserId JOIN dbo.Roles r ON r.RoleId=ur.RoleId WHERE u.NTName=ORIGINAL_LOGIN() AND r.RoleName=N'CompanyPortal.Admin'; IF @@ROWCOUNT<>1 THROW 50010,'Expected one local sample role grant.',1;"
    & sqlcmd -S localhost -E -b -I -d SecurityDB -Q $query
    if ($LASTEXITCODE -ne 0) { throw 'Sample role update failed.' }
}
$header=@{'X-CompanyPortal-Request'='admin-cards'}
function Save($Card,[string]$Name,[bool]$Fixed,[int]$Order) {
    Request 'PUT' "/api/admin/cards/$($Card.cardId)" (@{cardName=$Name;isFixed=$Fixed;displayOrder=$Order;active=$Card.active;audience=$Card.audience;appIds=@($Card.appIds);roleNames=@($Card.roleNames)}|ConvertTo-Json -Compress) $header
}
function Cards {
    $response=Request 'GET' '/api/admin/cards'; Assert ($response.Status -eq 200) 'Admin catalog failed.'
    ($response.Content|ConvertFrom-Json)|ForEach-Object { $_ }
}
Assert ((Request 'GET' '/api/admin/cards' '' @{} $false).Status -eq 401) 'Anonymous admin read accepted.'
Assert ((Request 'GET' '/api/access' '' @{} $false).Status -eq 401) 'Anonymous access lookup accepted.'
Assert (((Request 'GET' '/api/access').Content|ConvertFrom-Json).isAdmin) 'Current account needs an explicit development admin grant.'
$before=@(Cards); Assert ($before.Count -ge 2) 'Need two master cards.'
$first=$before[0]; $second=$before[1]; $revoked=$false
$body=@{cardName=$first.cardName;isFixed=$first.isFixed;displayOrder=$first.displayOrder;active=$first.active;audience=$first.audience;appIds=@($first.appIds);roleNames=@($first.roleNames)}|ConvertTo-Json -Compress
try {
    Assert ((Request 'PUT' "/api/admin/cards/$($first.cardId)" $body).Status -eq 400) 'Missing write header accepted.'
    Assert ((Request 'PUT' "/api/admin/cards/$($first.cardId)" $body @{'X-CompanyPortal-Request'='admin-cards';Origin='https://untrusted.invalid'}).Status -eq 403) 'Untrusted origin accepted.'
    Assert ((Request 'PUT' "/api/admin/cards/$($first.cardId)" '{"cardName":"x","isFixed":false,"displayOrder":1,"userId":1}' $header).Status -eq 400) 'Unexpected owner accepted.'
    Assert ((Request 'PUT' "/api/admin/cards/$($first.cardId)" '{"cardName":"x","displayOrder":1}' $header).Status -eq 400) 'Missing fixed flag accepted.'
    Assert ((Save $first ' ' $false 1).Status -eq 400) 'Blank name accepted.'
    Assert ((Save $first 'x' $false ($before.Count+1)).Status -eq 400) 'Out-of-range position accepted.'
    Assert ((Request 'PUT' '/api/admin/cards/2147483647' $body $header).Status -eq 400) 'Missing card accepted.'
    Assert ((Save $first $first.cardName $first.isFixed $first.displayOrder).Status -eq 204) 'No-op failed.'
    $same=@(Cards)|Where-Object cardId -eq $first.cardId
    Assert ($same.lastChangeAt -eq $first.lastChangeAt) 'No-op advanced timestamp.'
    Start-Sleep -Milliseconds 50
    Assert ((Save $first 'Admin test <b>literal</b>' $false $first.displayOrder).Status -eq 204) 'Rename failed.'
    $changed=@(Cards)|Where-Object cardId -eq $first.cardId
    Assert ($changed.cardName -ceq 'Admin test <b>literal</b>') 'Name differs.'
    Assert ([datetime]$changed.lastChangeAt -gt [datetime]$first.lastChangeAt) 'Rename timestamp did not advance.'
    $workspace=(Request 'GET' '/api/user-settings/card-order').Content|ConvertFrom-Json
    Assert (@($workspace.cards|Where-Object cardKey -eq $first.cardKey)[0].cardName -ceq $changed.cardName) 'Employee catalog did not receive renamed card.'
    Assert ((Save $first 'admin test <b>literal</b>' $false $first.displayOrder).Status -eq 204) 'Case-only rename failed.'
    Assert ((@(Cards)|Where-Object cardId -eq $first.cardId).cardName -ceq 'admin test <b>literal</b>') 'Case-only rename lost.'
    # Uses the original positions; temporary policy is always restored below.
    Assert ((Save $second $second.cardName $true $second.displayOrder).Status -eq 204) 'Set fixed failed.'
    Assert ((Save $first 'Must not persist' $true $second.displayOrder).Status -eq 400) 'Fixed-slot conflict accepted.'
    Assert ((@(Cards)|Where-Object cardId -eq $first.cardId).cardName -cne 'Must not persist') 'Failed save changed name.'
    Assert ((Save $first $first.cardName $first.isFixed $first.displayOrder).Status -eq 204) 'Restore first failed.'
    Assert ((Save $second $second.cardName $second.isFixed $second.displayOrder).Status -eq 204) 'Restore second failed.'
    if ($TestSampleRevocation) {
        $revoked=$true; SampleRole $false
        Assert (-not ((Request 'GET' '/api/access').Content|ConvertFrom-Json).isAdmin) 'Revoked admin still reported.'
        Assert ((Request 'GET' '/api/admin/cards').Status -eq 403) 'Revoked admin could read catalog.'
        Assert ((Request 'PUT' "/api/admin/cards/$($first.cardId)" $body $header).Status -eq 403) 'Revoked admin could save.'
        Assert ((Request 'GET' '/api/applications').Status -eq 200) 'Admin revocation broke employee app access.'
        SampleRole $true; $revoked=$false
    }
    'PASS: admin authorization, CRUD validation, origin/header checks, names, timestamps, fixed conflicts, employee catalog and optional role revocation.'
} finally {
    if ($revoked) { SampleRole $true }
    # Unfix test cards before restoring, avoiding transient fixed-slot conflicts.
    foreach($card in @($first,$second)) { Assert ((Save $card $card.cardName $false $card.displayOrder).Status -eq 204) 'Cleanup unfix failed.' }
    foreach($card in @($first,$second)) { Assert ((Save $card $card.cardName $card.isFixed $card.displayOrder).Status -eq 204) 'Cleanup restore failed.' }
}
