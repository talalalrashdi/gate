using System.Data;
using System.Net;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Principal;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Infrastructure;
using CompanyPortal.Api.Mail;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController,Authorize,Route("api/admin/health")]
public sealed class AdminHealthController(IConfiguration config,AdministrationStore admins,UserSettingsStore users,
    MailSessionFactory sessions,IWebHostEnvironment environment,ILogger<AdminHealthController> logger):ControllerBase
{
    public sealed record Check(string Code,string Status,string Title,string Detail,string[] Steps,string Reference);
    private sealed record Folder(string Key,string Path);
    private sealed record Database(string Name,int Compatibility,int Major);
    [HttpGet]
    public async Task<IActionResult> Run(CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        var account=User.Identity?.Name;if(string.IsNullOrWhiteSpace(account))return Unauthorized();
        // Explicit bootstrap accounts can diagnose a missing/unreachable security adapter only.
        // They never override a successful authorization result denying super-admin access.
        try{using var authorization=CancellationTokenSource.CreateLinkedTokenSource(token);authorization.CancelAfter(TimeSpan.FromSeconds(8));if(!(await admins.GetAccessAsync(account,authorization.Token)).IsSuperAdmin)return Forbid();}
        catch(Exception e)when(!token.IsCancellationRequested&&(e is SqlException or InvalidOperationException or ArgumentException or OperationCanceledException))
        {
            if(!(config.GetSection("Diagnostics:BootstrapAccounts").Get<string[]>()??[]).Contains(account,StringComparer.OrdinalIgnoreCase))
                return Problem(statusCode:503,title:"Cannot verify super-admin access.",detail:"The database/security adapter could not be reached. No health checks were run.",extensions:new Dictionary<string,object?>{{"reference",HttpContext.TraceIdentifier},{"steps",new[]{"Check the API database connection and Security.UserRoles_get/Portal.AdminAccess_get permissions.","During first-time setup only, add the approved Windows account to Diagnostics:BootstrapAccounts on the API host and restart the API.","Remove that bootstrap entry after the database and super-admin role are configured."}}});
            logger.LogWarning("Health bootstrap access for {Account}. Reference {Reference}",account,HttpContext.TraceIdentifier);
        }
        using var lifetime=CancellationTokenSource.CreateLinkedTokenSource(token);lifetime.CancelAfter(TimeSpan.FromSeconds(55));
        var checks=new List<Check>();
        string process=Environment.UserName;if(OperatingSystem.IsWindows()){using var identity=WindowsIdentity.GetCurrent();process=identity.Name;}
        var sqlTarget="configured server";
        void Add(string code,string status,string title,string detail,params string[] steps)
        {
            var reference=HttpContext.TraceIdentifier+":"+code;
            checks.Add(new(code,status,title,detail,steps,reference));
            logger.LogInformation("Health {Code}: {Status}. Reference {Reference}",code,status,reference);
        }
        async Task<bool> Probe(string code,string title,Func<CancellationToken,Task<string>> action,string[] steps)
        {
            try{using var step=CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);step.CancelAfter(TimeSpan.FromSeconds(8));
                var detail=await action(step.Token);Add(code,"ok",title,detail);return true;}
            catch(Exception e)when(e is not OutOfMemoryException&&!token.IsCancellationRequested)
            {
                var failure=Failure(e);var detail=code=="SQL_CONNECTION"?$"Cannot connect to SQL Server '{sqlTarget}' using API process account '{process}'. {failure.Detail}":failure.Detail;
                Add(code,"failed",title,detail, failure.Steps.Length>0?failure.Steps:steps);
                logger.LogWarning("Health failure {Code}, {Type}. Reference {Reference}",code,e.GetType().Name,HttpContext.TraceIdentifier+":"+code);return false;
            }
        }
        Add("API_IDENTITY","ok","Windows identity",$"Browser account: {account}. API process account: {process}. SQL and EWS use the API process identity unless their integration explicitly impersonates a caller.");
        Add("VERSIONS","ok","Versions and server time",$"API {typeof(AdminHealthController).Assembly.GetName().Version}; build UTC {System.IO.File.GetLastWriteTimeUtc(typeof(AdminHealthController).Assembly.Location):O}; .NET {Environment.Version}; environment {environment.EnvironmentName}; UTC {DateTimeOffset.UtcNow:O}.");
        string? connectionString=null;Database? database=null;
        var dbOk=await Probe("SQL_CONNECTION","Database connection",async ct=>
        {
            var b=new SqlConnectionStringBuilder(config.GetConnectionString("CompanyPortal")){ConnectTimeout=5};connectionString=b.ConnectionString;sqlTarget=SafeHost(b.DataSource);
            await using var c=new SqlConnection(connectionString);await c.OpenAsync(ct);
            database=await c.QuerySingleAsync<Database>(new CommandDefinition("SELECT DB_NAME() Name,CONVERT(int,compatibility_level) Compatibility,CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) Major FROM sys.databases WHERE name=DB_NAME()",cancellationToken:ct));
            return $"Connected to SQL Server '{SafeHost(b.DataSource)}', database '{SafeHost(database.Name)}', using '{process}' (or the configured SQL login).";
        },["Open SQL Server Configuration Manager and confirm the configured SQL instance is running.","Check ConnectionStrings:CompanyPortal on the API host; do not share its password.",$"In SSMS, add the API identity '{process}' as a login/database user and grant the required EXECUTE permissions."]);
        int? userId=null;
        var schemaSteps=new[]{"Open SSMS and connect to the configured CompanyPortal database.","Apply the missing numbered migrations in order, through 049. Do not rerun the fresh-install Setup.sql on an existing database.","Grant the API identity EXECUTE on required procedures. If metadata is hidden, grant VIEW DEFINITION on the affected objects and rerun checks."};
        if(dbOk)
        {
            Add("SQL_COMPATIBILITY",database!.Compatibility>=130&&database.Major>=14?"ok":"failed","SQL compatibility",
                $"Server major version {database.Major}; compatibility level {database.Compatibility}. The portal requires SQL Server 2017+ and compatibility 130+ (OPENJSON and STRING_AGG).",
                database.Compatibility>=130&&database.Major>=14?[]:["Use SQL Server 2017 or later.","In SSMS, open CompanyPortal properties > Options and choose a supported compatibility level of at least 130 (140 on SQL Server 2017).","Do not lower compatibility to 100; JSON procedures will fail."]);
            await Probe("REQUIRED_PROCEDURES","Required procedures",async ct=>
            {
                var names=System.Text.Json.JsonSerializer.Deserialize<string[]>(await System.IO.File.ReadAllTextAsync(Path.Combine(environment.ContentRootPath,"HealthProcedures.json"),ct))??[];
                await using var c=new SqlConnection(connectionString);
                var found=(await c.QueryAsync<string>(new CommandDefinition("SELECT SCHEMA_NAME(schema_id)+'.'+name FROM sys.procedures",cancellationToken:ct))).ToHashSet(StringComparer.OrdinalIgnoreCase);
                var missing=names.Where(n=>!found.Contains(n)).ToArray();
                if(missing.Length>0){Add("MIGRATIONS","failed","Migration coverage","Missing or invisible procedures: "+string.Join(", ",missing),schemaSteps);throw new HealthCheckException("Required procedures are missing or invisible to the API identity.");}
                Add("MIGRATIONS","ok","Migration coverage","Required procedure names through migration 049 are present. There is no migration ledger; this verifies current objects, not historical execution order.");
                return $"All {names.Length} required procedures are visible. Execution permissions are checked for the identity/source probes below; visibility alone does not prove every feature works.";
            },schemaSteps);
            await Probe("USER_LOOKUP","Windows account to user",async ct=>
            {await using var c=new SqlConnection(connectionString);userId=await c.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername",new{Username=account},commandType:CommandType.StoredProcedure,cancellationToken:ct));if(userId is null)throw new HealthCheckException($"Windows account '{account}' did not resolve to an active UserId.");return $"'{account}' resolves to UserId {userId}.";},["Open the configured employee/security database.","Check the exact DOMAIN\\username and Active flag.","Correct Security.User_getByUsername to query the real employee source; keep existing UserId values."]);
            if(userId is not null)await Probe("USER_ROLES","User roles",async ct=>
            {await using var c=new SqlConnection(connectionString);var roles=(await c.QueryAsync<string>(new CommandDefinition("Security.UserRoles_get",new{UserId=userId.Value},commandType:CommandType.StoredProcedure,cancellationToken:ct))).ToArray();if(!roles.Contains("CompanyPortal.Admin",StringComparer.Ordinal))throw new HealthCheckException("The employee role source did not return CompanyPortal.Admin.");return "Role lookup succeeded; the current user is a super admin.";},["Check effective direct/group grants in the security database.","Correct Security.UserRoles_get; it must return active RoleName values."]);
            else Add("USER_ROLES","warning","User roles","Not checked because no active UserId was resolved.","Fix USER_LOOKUP, then run checks again.");
            var roots=new List<Folder>();var rootsOk=await Probe("FOLDER_SETTINGS","Folder settings",async ct=>
            {await using var c=new SqlConnection(connectionString);roots=(await c.QueryAsync<Folder>(new CommandDefinition("Mstr.Utls_GetFolderPaths",commandType:CommandType.StoredProcedure,cancellationToken:ct))).ToList();return "Folder paths loaded from Mstr.Utls_GetFolderPaths; no configuration fallback was used.";},["Grant EXECUTE on Mstr.Utls_GetFolderPaths.","Confirm it returns Key and Path for active Mstr.Utls rows."]);
            foreach(var (key,title) in new[]{("PubsInfo","News folder"),("Magazines","Magazine folder"),("docs","Documents folder"),("PortalMedia","Media folder")})
            {
                var selected=roots.Where(r=>r.Key.Equals(key,StringComparison.OrdinalIgnoreCase)).ToArray();
                if(!rootsOk||selected.Length==0){Add("FOLDER_"+key,"warning",title,$"No usable '{key}' folder setting was returned.","In CompanyPortal.Mstr.Utls, add the correct active key and an absolute strVal path.",$"Give '{process}' Read/List access (and share permissions for UNC paths).","Run checks again.");continue;}
                await Probe("FOLDER_"+key,title,async ct=>
                {
                    foreach(var folder in selected)await Task.Run(()=>
                    {
                        if(!Path.IsPathFullyQualified(folder.Path))throw new HealthCheckException($"The '{key}' path is not absolute.");
                        // Enumeration throws on missing or unreadable directories; Directory.Exists hides that distinction.
                        using var entries=Directory.EnumerateFileSystemEntries(folder.Path).GetEnumerator();_ = entries.MoveNext();
                    },ct).WaitAsync(ct);
                    return $"All {selected.Length} '{key}' folders exist and can be listed by '{process}'. Individual file permissions may differ.";
                },[$"In SSMS, correct the '{key}' path in Mstr.Utls.","On the file server, open folder Properties > Security and grant the API process identity Read/List.","For a UNC path, also check Sharing > Advanced Sharing > Permissions and network/DNS access from the API host."]);
            }
        }
        else foreach(var code in new[]{"SQL_COMPATIBILITY","REQUIRED_PROCEDURES","MIGRATIONS","USER_LOOKUP","USER_ROLES","FOLDER_SETTINGS","FOLDER_PubsInfo","FOLDER_Magazines","FOLDER_docs","FOLDER_PortalMedia"})Add(code,"warning",code.Replace('_',' '),"Not checked because the database connection failed.","Fix SQL_CONNECTION and run checks again.");
        var mail=new MailOptions();var mailBound=true;
        try{mail=config.GetSection("Exchange").Get<MailOptions>()??new();}
        catch(Exception e)when(e is InvalidOperationException or ArgumentException){mailBound=false;Add("EXCHANGE_SETTINGS","failed","Exchange settings","Exchange settings cannot be parsed.","Check the Exchange section in API appsettings.json; Enabled and ScheduleEnabled must be true/false and numeric settings must contain numbers.","Restart the API after correcting configuration.");}
        bool mailReady=false;string? mailbox=null;
        if(mailBound&&!mail.Enabled)Add("EXCHANGE_SETTINGS","warning","Exchange settings","Exchange integration is disabled.","Configure the internal EWS/OWA HTTPS addresses and approved mailbox-access method.","Enable Exchange:Enabled after the Exchange administrator has approved and configured access.");
        else if(mailBound)mailReady=await Probe("EXCHANGE_SETTINGS","Exchange settings",ct=>
        {mail.Validate();_=mail.ScheduleZone();_=mail.CalendarsFor(account);mailbox=mail.MailboxFor(account);if(mailbox is null)throw new HealthCheckException("The current Windows account has no valid mailbox mapping.");return Task.FromResult("EWS/OWA addresses, access mode, time zone, shared-calendar settings and the current account's mailbox mapping are valid. This is not an OWA sign-in or shared-mailbox permission test.");},["Set Exchange:EwsUrl and OutlookWebUrl to the verified internal HTTPS addresses.","Set AccessMode to ScopedServiceAccountImpersonation and configure MailboxAddresses for the current Windows account.","Check OpenMode, inbox-link templates, ScheduleTimeZone and SharedCalendars against the approved configuration.","Use an approved, scoped Exchange service identity; do not grant impersonation to every employee."]);
        foreach(var code in new[]{"EWS_INBOX","EWS_CALENDAR","EWS_TASKS"})
        {
            var title=code=="EWS_INBOX"?"Exchange inbox":code=="EWS_CALENDAR"?"Exchange calendar":"Exchange tasks";
            if(!mailReady||userId is null||code!="EWS_INBOX"&&!mail.ScheduleEnabled){Add(code,"warning",title,"Live access was not checked: Exchange is disabled/unconfigured, the user is unresolved, or scheduling is disabled.","Fix the Exchange/user checks above.",code=="EWS_INBOX"?"Enable Exchange:Enabled after access is approved, then run checks again.":"Set Exchange:ScheduleEnabled=true to test calendars and tasks.");continue;}
            await Probe(code,title,async ct=>
            {await using var session=sessions.Create(mailbox!);if(code=="EWS_INBOX")await session.ProbeInboxAsync(ct);else if(code=="EWS_TASKS")await session.ProbeTasksAsync(ct);else if(!(await session.CalendarAccessAsync(mailbox!,ct)).Read)throw new EwsResponseException("ErrorAccessDenied");return "The live EWS folder access check succeeded. No item contents were included and nothing was changed.";},["Check the EWS HTTPS address and network access from the API host.","Ask the Exchange administrator to check EWS authentication and the API identity's scoped ApplicationImpersonation assignment.","Use the reference ID and check time to match API and Exchange logs."]);
        }
        var photoSetting=config["PhoneDirectory:Enabled"]??"false";
        if(!bool.TryParse(photoSetting,out var photoEnabled))Add("PHOTO_SERVICE","failed","Employee photo service","PhoneDirectory:Enabled must be true or false.","Correct the boolean setting in API appsettings.json and restart the API.");
        else if(!photoEnabled)Add("PHOTO_SERVICE","warning","Employee photo service","PhoneDirectory integration is disabled.","Configure PhoneDirectory:BaseUrl and ThumbnailPath for the internal service.","Enable PhoneDirectory:Enabled and rerun checks.");
        else await Probe("PHOTO_SERVICE","Employee photo service",async ct=>
        {
            var personalId=await users.GetPersonalIdAsync(account,ct);if(personalId is not >0)throw new HealthCheckException("No PersonalID is mapped for the current Windows account.");
            if(!Uri.TryCreate(config["PhoneDirectory:BaseUrl"],UriKind.Absolute,out var root)||root.Scheme is not ("http" or "https")||root.UserInfo.Length>0)throw new HealthCheckException("PhoneDirectory:BaseUrl is missing or invalid.");
            var address=new Uri(new Uri(root.AbsoluteUri.TrimEnd('/')+"/"),config["PhoneDirectory:ThumbnailPath"]??"api/Assest/GetEmplyeeThumb");
            if(address.Authority!=root.Authority||address.Scheme!=root.Scheme||address.UserInfo.Length>0)throw new HealthCheckException("The thumbnail endpoint must use the configured service origin.");
            using var handler=new HttpClientHandler{UseDefaultCredentials=true,AllowAutoRedirect=false,UseCookies=false};using var client=new HttpClient(handler){Timeout=TimeSpan.FromSeconds(7),MaxResponseContentBufferSize=2*1024*1024};
            async Task CheckPhoto(){using var response=await client.GetAsync(new UriBuilder(address){Query=$"PersonalID={personalId}&Res=128",Fragment=""}.Uri,ct);response.EnsureSuccessStatusCode();var bytes=await response.Content.ReadAsByteArrayAsync(ct);var valid=bytes.Length>=8&&bytes.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10})||bytes.Length>=3&&bytes[0]==255&&bytes[1]==216&&bytes[2]==255||bytes.Length>=12&&System.Text.Encoding.ASCII.GetString(bytes,0,4)=="RIFF"&&System.Text.Encoding.ASCII.GetString(bytes,8,4)=="WEBP";if(!valid)throw new HealthCheckException("The photo service did not return a supported PNG, JPEG or WebP image.");}
            if(OperatingSystem.IsWindows()&&User.Identity is WindowsIdentity caller){using var current=WindowsIdentity.GetCurrent();if(current.User!=caller.User)await WindowsIdentity.RunImpersonatedAsync(caller.AccessToken,CheckPhoto);else await CheckPhoto();}else throw new HealthCheckException("The photo service requires a Windows caller identity.");
            return "The configured photo endpoint returned a valid image using the same Windows-credential flow as the portal. The image is not included in this report.";
        },["Check Security.User_getPersonalId and the employee PersonalID mapping.","Check PhoneDirectory:BaseUrl/ThumbnailPath and the service's Windows authentication.","For IIS-to-service access, check the approved Kerberos/delegation configuration and TLS trust."]);
        return Ok(new{Reference=HttpContext.TraceIdentifier,CheckedAt=DateTimeOffset.UtcNow,Checks=checks});
    }
    private sealed class HealthCheckException(string message):Exception(message);
    private static string SafeHost(string value)=>System.Text.RegularExpressions.Regex.IsMatch(value,@"^[\w.\\,: -]{1,200}$")?value:"configured server";
    private static (string Detail,string[] Steps) Failure(Exception e)
    {
        if(e is HealthCheckException)return(e.Message,[]);
        if(e is SqlException sql)return(sql.Number switch{18456=>"SQL Server rejected the API login (SQL 18456).",4060=>"SQL Server cannot open the configured database (SQL 4060).",229=>"The API identity does not have the required SQL permission (SQL 229).",208 or 2812=>"A required SQL table, view or procedure is missing (SQL "+sql.Number+").",_=>"SQL Server connection or command failed (SQL "+sql.Number+")."},[]);
        if(e is EwsResponseException ews)return("Exchange rejected the EWS request ("+System.Text.RegularExpressions.Regex.Replace(ews.Code,@"[^A-Za-z0-9_]","")+").",ews.Code is "ErrorImpersonateUserDenied" or "ErrorImpersonationDenied" or "ErrorAccessDenied"?["Identify the account shown in API_IDENTITY, not just the browser user.","Ask the Exchange administrator to verify that account's scoped ApplicationImpersonation role and target mailbox scope.","Do not grant impersonation to all employees; rerun after the approved service assignment is fixed."]:[]);
        if(e is HttpRequestException http&&http.StatusCode is not null)return($"The remote service returned HTTP {(int)http.StatusCode}. No response content was exposed.",[]);
        if(e is AuthenticationException||e.InnerException is AuthenticationException)return("TLS certificate validation failed.",["Check the certificate name, expiry and internal issuing CA.","Install the approved CA chain in the API host's trusted certificate store.","Do not disable certificate validation."]);
        if(e is SocketException||e.InnerException is SocketException)return("The remote server could not be reached (DNS or network error).",[]);
        if(e is OperationCanceledException)return("The check timed out. No successful result could be confirmed.",[]);
        if(e is UnauthorizedAccessException)return("The API process identity cannot read/list the configured folder.",[]);
        if(e is DirectoryNotFoundException)return("The configured folder does not exist or the share cannot be reached.",[]);
        if(e is IOException)return("A file or network share could not be read.",[]);
        if(e is ArgumentException or InvalidOperationException or TimeZoneNotFoundException)return("A required setting is missing or invalid. No setting values or secrets were exposed.",[]);
        return("The check could not complete. Use the reference ID to inspect the server log.",[]);
    }
}
