param([string]$BaseUrl='http://localhost:5081',[switch]$ExpectDisabled)
$ErrorActionPreference='Stop'
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Request([string]$Path,[bool]$Authenticated=$true,[string]$Method='GET',[string]$Origin='') {
    $request=[Net.HttpWebRequest]::Create($BaseUrl.TrimEnd('/')+$Path)
    $request.UseDefaultCredentials=$Authenticated; $request.Method=$Method; $request.AllowAutoRedirect=$false; $request.Timeout=15000
    if ($Origin) { $request.Headers['Origin']=$Origin }
    try { $response=$request.GetResponse() } catch { $response=$_.Exception.GetBaseException().Response; if (-not $response) { throw } }
    try { $reader=[IO.StreamReader]::new($response.GetResponseStream()); try { $content=$reader.ReadToEnd() } finally { $reader.Dispose() }; return @{Status=[int]$response.StatusCode;Content=$content;Cache=$response.Headers['Cache-Control']} } finally { $response.Close() }
}
foreach($path in @('/api/mail/inbox','/api/mail/stream','/api/mail/open?itemId=x','/api/mail/inbox/open')) {
    Assert ((Request $path $false).Status -eq 401) "Anonymous mail endpoint accepted: $path"
}
Assert ((Request '/api/mail/open').Status -eq 400) 'Missing item ID accepted.'
Assert ((Request '/api/mail/stream' $true 'GET' 'https://untrusted.invalid').Status -eq 403) 'Foreign-origin mail stream accepted.'
Assert ((Request '/api/mail/inbox' $true 'POST').Status -eq 405) 'Mail write endpoint exists.'
if($ExpectDisabled) {
    foreach($path in @('/api/mail/inbox','/api/mail/stream','/api/mail/open?itemId=x','/api/mail/inbox/open')) {
        $result=Request $path
        Assert ($result.Status -eq 503) "Disabled Exchange did not fail closed: $path"
        Assert ($result.Cache -match 'no-store') 'Mail response cached.'
        Assert ($result.Content -notmatch 'SmtpAddress|MailboxAddresses|alice@example|StackTrace') 'Internal mail details leaked.'
    }
} else {
    $result=Request '/api/mail/inbox'; Assert ($result.Status -eq 200) 'Connected inbox failed.'
    $snapshot=$result.Content|ConvertFrom-Json
    Assert ($snapshot.unreadCount -ge 0 -and @($snapshot.items).Count -le 20) 'Invalid inbox snapshot.'
}
'PASS: mail authentication, origin protection, missing-ID validation, no write endpoint and expected disabled/connected behavior.'
