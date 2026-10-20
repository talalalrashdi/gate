param([string]$BaseUrl='http://localhost:5081')
# Uses the current Windows account's existing admin permission; requires migration015.
# Imports shared theme artwork, without creating groups or assigning themes.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Net.Http
$assets=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Frontend/CompanyPortal.Web/wwwroot/assets'))
$manifest=@(
    @{File='hero-oman-fort.png';Name='قلعة عُمانية.png'},
    @{File='hero-oman-mosque.png';Name='جامع عُماني.png'},
    @{File='hero-oman-desert.png';Name='كثبان عُمان.png'},
    @{File='sultan-haitham-cutout.png';Name='السلطان هيثم بن طارق.png'},
    @{File='oman-national-silk-v2.png';Name='زخرفة العلم العُماني.png'},
    @{File='national-day-complete.jpg';Name='اليوم الوطني - التصميم الكامل.jpg'},
    @{File='national-day-complete.svg';Name='اليوم الوطني - التصميم المتحرك.svg'}
)
$root=[uri]($BaseUrl.TrimEnd('/')+'/')
if($root.Scheme -ne 'https' -and -not $root.IsLoopback){throw 'Use HTTPS for a non-local API.'}
$handler=[Net.Http.HttpClientHandler]::new();$handler.UseDefaultCredentials=$true
$client=[Net.Http.HttpClient]::new($handler);$client.Timeout=[timespan]::FromSeconds(60)
$client.DefaultRequestHeaders.Add('X-CompanyPortal-Request','admin-images')
function GetBytes([string]$Path){
    $response=$client.GetAsync([uri]::new($root,$Path)).GetAwaiter().GetResult()
    try{[void]$response.EnsureSuccessStatusCode();return ,($response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult())}finally{$response.Dispose()}
}
function Hash([byte[]]$Bytes){
    $sha=[Security.Cryptography.SHA256]::Create()
    try{[Convert]::ToBase64String($sha.ComputeHash($Bytes))}finally{$sha.Dispose()}
}
try {
    $catalog=([Text.Encoding]::UTF8.GetString((GetBytes 'api/admin/images')))|ConvertFrom-Json
    $existing=@($catalog.images)
    foreach($entry in $manifest){
        $bytes=[IO.File]::ReadAllBytes((Join-Path $assets $entry.File));$hash=Hash $bytes
        $mime=switch([IO.Path]::GetExtension($entry.File)){'.jpg'{'image/jpeg'} '.svg'{'image/svg+xml'} default{'image/png'}}
        $found=$null
        foreach($image in $existing){
            if($image.contentType -eq $mime -and $image.byteLength -eq $bytes.Length){
                if((Hash (GetBytes "api/images/$($image.imageId)/content")) -eq $hash){$found=$image;break}
            }
        }
        if($found){Write-Output "Already available: $($entry.Name) [ID $($found.imageId)]";continue}
        $body=[Net.Http.MultipartFormDataContent]::new();$file=[Net.Http.ByteArrayContent]::new($bytes)
        $file.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::new($mime);$body.Add($file,'file',$entry.Name)
        try{
            $response=$client.PostAsync([uri]::new($root,'api/admin/images'),$body).GetAwaiter().GetResult()
            try{[void]$response.EnsureSuccessStatusCode();$result=($response.Content.ReadAsStringAsync().GetAwaiter().GetResult())|ConvertFrom-Json}
            finally{$response.Dispose()}
        }finally{$body.Dispose()}
        $existing+= [pscustomobject]@{imageId=$result.imageId;contentType=$mime;byteLength=$bytes.Length}
        Write-Output "Imported: $($entry.Name) [ID $($result.imageId)]"
    }
    Write-Output 'Complete. No groups, theme assignments or existing image metadata were changed.'
}
finally{$client.Dispose()}
