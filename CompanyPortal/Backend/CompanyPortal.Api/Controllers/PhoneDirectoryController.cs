using System.Security.Principal;
using System.Text.Json;
using System.Text.RegularExpressions;
using CompanyPortal.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

[ApiController, Authorize, Route("api/phone-directory")]
public sealed class PhoneDirectoryController(IConfiguration configuration, UserSettingsStore users,
    ILogger<PhoneDirectoryController> logger) : ControllerBase
{
    [HttpGet("more")]
    public Task<IActionResult> More([FromQuery] long id, [FromQuery] int employeeTypeId, CancellationToken token)
    {
        if(id<=0 || employeeTypeId<=0)return Task.FromResult<IActionResult>(BadRequest());
        return ReadAsset("MoreInfoPath", "api/contacts/GetMoreInfo", $"Id={id}&employeeTypeId={employeeTypeId}&contactType=1", false, token);
    }

    [HttpGet("photo/{personalId:long:min(1)}")]
    public Task<IActionResult> Photo(long personalId,CancellationToken token) =>
        ReadAsset("ThumbnailPath","api/Assest/GetEmplyeeThumb",$"PersonalID={personalId}&Res=128",true,token);

    // Signed-in employee's own photo (header avatar). 404 when no PersonalID is mapped; the page then shows a placeholder.
    [HttpGet("photo/me")]
    public async Task<IActionResult> MyPhoto(CancellationToken token)
    {
        if(string.IsNullOrWhiteSpace(User.Identity?.Name))return Unauthorized();
        long? personalId;
        try{personalId=await users.GetPersonalIdAsync(User.Identity.Name,token);}
        catch(SqlException ex){logger.LogError(ex,"PersonalID lookup failed");Response.Headers.CacheControl="private, no-store";return Problem(statusCode:503,title:"تعذر تحديد رقم الموظف.");}
        if(personalId is not > 0){Response.Headers.CacheControl="private, no-store";return NotFound();}
        return await ReadAsset("ThumbnailPath","api/Assest/GetEmplyeeThumb",$"PersonalID={personalId}&Res=256",true,token);
    }

    private async Task<IActionResult> ReadAsset(string setting,string fallback,string query,bool photo,CancellationToken token)
    {
        Response.Headers.CacheControl="private, no-store";
        Response.Headers.XContentTypeOptions="nosniff";
        try
        {
            if(string.IsNullOrWhiteSpace(User.Identity?.Name))return Unauthorized();
            if(await users.GetThemeAsync(User.Identity.Name,token) is null)return Forbid();
            var config=configuration.GetSection("PhoneDirectory");
            if(!config.GetValue<bool>("Enabled")||!Uri.TryCreate(config["BaseUrl"],UriKind.Absolute,out var root)
                ||root.Scheme is not ("http" or "https")||root.UserInfo.Length>0)
                return Problem(statusCode:503,title:"لم يتم إعداد اتصال دليل الهاتف بعد.");
            var path=config[setting]??fallback;
            var address=new Uri(new Uri(root.AbsoluteUri.TrimEnd('/')+"/"),path);
            if(address.Scheme!=root.Scheme||address.Authority!=root.Authority||address.UserInfo.Length>0)
                return Problem(statusCode:503,title:"مسار خدمة دليل الهاتف غير صالح.");
            var url=new UriBuilder(address){Query=query,Fragment=""}.Uri;
            async Task<byte[]> Fetch()
            {
                using var handler=new HttpClientHandler{UseDefaultCredentials=true,AllowAutoRedirect=false,UseCookies=false};
                using var client=new HttpClient(handler){Timeout=TimeSpan.FromSeconds(15),MaxResponseContentBufferSize=2*1024*1024};
                using var response=await client.GetAsync(url,token);response.EnsureSuccessStatusCode();
                return await response.Content.ReadAsByteArrayAsync(token);
            }
            if(!OperatingSystem.IsWindows()||User.Identity is not WindowsIdentity caller)
                return Problem(statusCode:503,title:"يتطلب دليل الهاتف هوية Windows للموظف.");
            using var process=WindowsIdentity.GetCurrent();
            var bytes=caller.User==process.User?await Fetch():await WindowsIdentity.RunImpersonatedAsync(caller.AccessToken,Fetch);
            if(photo)
            {
                // Return raster images only; never relay arbitrary HTML/SVG from upstream.
                var type=bytes.Length>=8&&bytes.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10})?"image/png":
                    bytes.Length>=3&&bytes[0]==255&&bytes[1]==216&&bytes[2]==255?"image/jpeg":
                    bytes.Length>=12&&System.Text.Encoding.ASCII.GetString(bytes,0,4)=="RIFF"&&System.Text.Encoding.ASCII.GetString(bytes,8,4)=="WEBP"?"image/webp":null;
                return type is null?NotFound():File(bytes,type);
            }
            using var data=JsonDocument.Parse(bytes);var row=data.RootElement;
            static string? Field(JsonElement value,string key)=>value.ValueKind==JsonValueKind.Object&&value.TryGetProperty(key,out var field)
                &&field.ValueKind is JsonValueKind.String or JsonValueKind.Number?field.ToString():null;
            if(!row.TryGetProperty("phoneNumbers",out var phones)||phones.ValueKind!=JsonValueKind.Array)throw new JsonException();
            row.TryGetProperty("contactAddress",out var contactAddress);
            return Ok(new{phoneNumbers=phones.EnumerateArray().Select(p=>new{
                number=Field(p,"number"),phoneTypeName=Field(p,"phoneTypeName"),phoneStateName=Field(p,"phoneStateName"),
                note=Field(p,"note"),phonePlace=Field(p,"phonePlace"),priority=Field(p,"priority")
            }).ToArray(),contactAddress=new{currentAddress=Field(contactAddress,"currentAddress"),permanentAddress=Field(contactAddress,"permanentAddress")}});
        }
        catch(HttpRequestException ex)
        {
            logger.LogWarning(ex,"Dalil {Endpoint} request failed",setting);
            return Problem(statusCode:ex.StatusCode==System.Net.HttpStatusCode.NotFound?404:502,title:
                ex.StatusCode is System.Net.HttpStatusCode.Unauthorized or System.Net.HttpStatusCode.Forbidden?
                "رفض دليل الهاتف مصادقة Windows. تحقق من التفويض والصلاحيات.":"تعذر تحميل بيانات جهة الاتصال.");
        }
        catch(OperationCanceledException) when(!token.IsCancellationRequested){return Problem(statusCode:504,title:"انتهت مهلة الاتصال بدليل الهاتف.");}
        catch(Exception ex) when(ex is JsonException or InvalidOperationException or SqlException or System.Security.SecurityException or UriFormatException)
        {logger.LogError(ex,"Dalil {Endpoint} unavailable",setting);return Problem(statusCode:503,title:"تعذر تحميل بيانات جهة الاتصال. تحقق من إعدادات الخدمة.");}
    }

    [HttpGet]
    public async Task<IActionResult> Search([FromQuery] string query = "", [FromQuery] int pageNum = 1, CancellationToken token = default)
    {
        Response.Headers.CacheControl = "private, no-store";
        query = query.Trim();
        if (query.Length > 200 || pageNum < 1 || pageNum > 100000) return BadRequest();
        try
        {
            if (string.IsNullOrWhiteSpace(User.Identity?.Name)) return Unauthorized();
            if (await users.GetThemeAsync(User.Identity.Name, token) is null) return Forbid();
            var settings = configuration.GetSection("PhoneDirectory");
            if (!settings.GetValue<bool>("Enabled") || !Uri.TryCreate(settings["BaseUrl"], UriKind.Absolute, out var root)
                || root.Scheme is not ("https" or "http") || root.UserInfo.Length > 0)
                return Problem(statusCode:503, title:"لم يتم إعداد اتصال دليل الهاتف بعد.");
            var url = new Uri(new Uri(root.AbsoluteUri.TrimEnd('/') + "/"),
                "api/contacts/search?query=" + Uri.EscapeDataString(query) + "&contactType=1&pageNum=" + pageNum);
            async Task<JsonDocument> Fetch()
            {
                // A handler per request prevents credential/connection reuse across employees.
                using var handler = new HttpClientHandler { UseDefaultCredentials = true, AllowAutoRedirect = false, UseCookies = false };
                using var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(15), MaxResponseContentBufferSize = 2 * 1024 * 1024 };
                using var response = await client.GetAsync(url, token);
                response.EnsureSuccessStatusCode();
                return JsonDocument.Parse(await response.Content.ReadAsStringAsync(token));
            }
            if (!OperatingSystem.IsWindows() || User.Identity is not WindowsIdentity caller)
                return Problem(statusCode:503, title:"يتطلب دليل الهاتف هوية Windows للموظف.");
            using var process = WindowsIdentity.GetCurrent();
            using var data = caller.User == process.User ? await Fetch()
                : await WindowsIdentity.RunImpersonatedAsync(caller.AccessToken, Fetch);
            var json = data.RootElement;
            if (!json.TryGetProperty("contacts", out var contacts) || contacts.ValueKind != JsonValueKind.Array
                || !json.TryGetProperty("total", out var total) || !total.TryGetInt32(out var count) || count < 0)
                throw new JsonException("Unexpected directory response.");
            string? Field(JsonElement row, string key) => row.TryGetProperty(key, out var value)
                && value.ValueKind is JsonValueKind.String or JsonValueKind.Number ? value.ToString() : null;
            var domain = settings["EmailDomain"] ?? "email.com";
            var owa = settings["OutlookWebUrl"];
            if (string.IsNullOrWhiteSpace(owa)) owa = configuration["Exchange:OutlookWebUrl"];
            string? Compose(string? ntUser)
            {
                if (string.IsNullOrWhiteSpace(ntUser) || !Regex.IsMatch(ntUser, @"\A[A-Za-z0-9._-]+\z")
                    || !Regex.IsMatch(domain, @"\A[A-Za-z0-9.-]+\z")
                    || !Uri.TryCreate(owa, UriKind.Absolute, out var address) || address.Scheme is not ("http" or "https") || address.UserInfo.Length > 0) return null;
                var template = settings["ComposeQueryTemplate"] ?? "?ae=Item&a=New&t=IPM.Note&to={email}";
                if (!template.StartsWith('?') || !template.Contains("{email}")) return null;
                var target = new UriBuilder(address) { Query = template[1..].Replace("{email}", Uri.EscapeDataString(ntUser + "@" + domain)), Fragment = "" };
                return target.Uri.AbsoluteUri;
            }
            return Ok(new { contacts = contacts.EnumerateArray().Take(10).Select(row => new {
                persID = Field(row,"persID"), personalID = Field(row,"personalID"), employeeTypeID = Field(row,"employeeTypeID"),
                personalIDAssignedTo = Field(row,"personalIDAssignedTo") ?? Field(row,"personalIdAssignedTo"),
                name = Field(row,"name"), officePhoneNumber = Field(row,"officePhoneNumber"),
                jobDesignate = Field(row,"jobDesignate"), employeeSectionName = Field(row,"employeeSectionName"),
                placeOfWork = Field(row,"placeOfWork"), unit = Field(row,"unit"), unitParent = Field(row,"unitParent"),
                employeeTypeName = Field(row,"employeeTypeName"), attendanceStatus = Field(row,"attendanceStatus"),
                note = Field(row,"note"), assignedToFullName = Field(row,"assignedToFullName"),
                isRetired = row.TryGetProperty("isRetired",out var retired) && retired.ValueKind == JsonValueKind.True,
                composeUrl = Compose(Field(row,"ntUser"))
            }).ToArray(), total = count, pageNum, pageSize = 10, contactType = 1 });
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex,"Dalil request failed with status {Status}",ex.StatusCode);
            return Problem(statusCode:502,title:ex.StatusCode is System.Net.HttpStatusCode.Unauthorized or System.Net.HttpStatusCode.Forbidden
                ? "رفض دليل الهاتف مصادقة Windows. تحقق من صلاحيات الاتصال والتفويض في IIS." : "تعذر الاتصال بدليل الهاتف.");
        }
        catch (OperationCanceledException) when (!token.IsCancellationRequested)
        { return Problem(statusCode:504,title:"انتهت مهلة الاتصال بدليل الهاتف. حاول مجددًا."); }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or SqlException or System.Security.SecurityException)
        { logger.LogError(ex,"Phone directory unavailable");return Problem(statusCode:503,title:"تعذر تحميل دليل الهاتف. تحقق من إعدادات الخدمة واستجابتها."); }
    }
}
