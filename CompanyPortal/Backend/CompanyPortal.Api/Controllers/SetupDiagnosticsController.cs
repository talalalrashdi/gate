using System.Data;
using System.Net;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Principal;
using CompanyPortal.Api.Data;
using CompanyPortal.Api.Mail;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace CompanyPortal.Api.Controllers;

// TEMPORARY: disable Diagnostics:Enabled after internal acceptance.
[ApiController, Authorize, Route("api/admin/diagnostics")]
public sealed class SetupDiagnosticsController(IConfiguration config, AdministrationStore admins,
    MailSessionFactory sessions, ILogger<SetupDiagnosticsController> logger) : ControllerBase
{
    public sealed record Check(string Code, string Status, string Title, string Detail, string NextStep);

    [HttpPost("run")]
    public async Task<IActionResult> Run(CancellationToken token)
    {
        Response.Headers.CacheControl = "private, no-store";
        if (!config.GetValue<bool>("Diagnostics:Enabled")) return NotFound();
        if (Request.Headers["X-CompanyPortal-Request"] != "diagnostics") return BadRequest();
        var origin = Request.Headers.Origin.ToString();
        if (origin.Length > 0 && origin != $"{Request.Scheme}://{Request.Host}" &&
            !(config.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? []).Contains(origin, StringComparer.Ordinal)) return Forbid();
        var account = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(account)) return Unauthorized();
        using var lifetime = CancellationTokenSource.CreateLinkedTokenSource(token);
        lifetime.CancelAfter(TimeSpan.FromSeconds(55));
        var allowed = (config.GetSection("Diagnostics:BootstrapAccounts").Get<string[]>() ?? [])
            .Contains(account, StringComparer.OrdinalIgnoreCase);
        if (!allowed)
        {
            try
            {
                using var authorization = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
                authorization.CancelAfter(TimeSpan.FromSeconds(8));
                if (!await admins.IsAdminAsync(account, authorization.Token)) return Forbid();
            }
            catch (Exception error) when (error is SqlException or InvalidOperationException or ArgumentException or OperationCanceledException)
            {
                logger.LogWarning(error, "Diagnostics authorization failed. Reference {Reference}", HttpContext.TraceIdentifier);
                return Problem(statusCode: 503, title: "تعذر التحقق من صلاحية التشخيص عبر قاعدة البيانات.",
                    detail: "أضف حساب Windows المعتمد إلى Diagnostics:BootstrapAccounts في إعدادات API مؤقتًا، ثم أعد تشغيل التطبيق.");
            }
        }

        var checks = new List<Check>();
        void Add(string code, string status, string title, string detail, string next = "") => checks.Add(new(code, status, title, detail, next));
        async Task<bool> Probe(string code, string title, Func<CancellationToken, Task<string>> action)
        {
            try
            {
                using var step = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
                step.CancelAfter(TimeSpan.FromSeconds(8));
                var start = checks.Count;
                var detail = await action(step.Token);
                if (checks.Skip(start).Any(x => x.Status is "fail" or "warn")) return false;
                Add(code, "pass", title, detail); return true;
            }
            catch (Exception error) when (error is not OutOfMemoryException && !token.IsCancellationRequested)
            {
                var (kind, detail, next) = Failure(error);
                if (kind == "CONFIG") next = code switch {
                    "SQL" => "اضبط ConnectionStrings:CompanyPortal باسم مثيل SQL Express والقاعدة والشهادة الصحيحة.",
                    "MAILBOX_MAPPING" => "أضف الحساب الحالي حرفيًا إلى Exchange:MailboxAddresses بقيمة عنوان SMTP. اكتب \\ مرتين في JSON.",
                    "OWA_INBOX" => "اضبط OutlookWebInboxUrl برابط HTTPS على نفس أصل OutlookWebUrl.",
                    "EXCHANGE_CONFIG" => "اضبط Exchange:EwsUrl وOutlookWebUrl بعنواني HTTPS، وAccessMode بقيمة ScopedServiceAccountImpersonation، وScheduleTimeZone بمنطقة صحيحة مثل Asia/Muscat.",
                    _ => next };
                Add(code + ":" + kind, "fail", title, detail, next);
                logger.LogWarning(error, "Diagnostics step {Step} failed. Reference {Reference}", code, HttpContext.TraceIdentifier);
                return false;
            }
        }
        var processName = Environment.UserName;
        if (OperatingSystem.IsWindows()) { using var processIdentity = WindowsIdentity.GetCurrent(); processName = processIdentity.Name; }
        Add("IDENTITY", "pass", "هوية Windows", $"المستخدم: {account} · تشغيل API: {processName}");
        string? connectionString = null;
        int? compatibility = null;
        var databaseOk = await Probe("SQL", "الاتصال بقاعدة CompanyPortal", async ct =>
        {
            var source = config.GetConnectionString("CompanyPortal");
            if (string.IsNullOrWhiteSpace(source)) throw new InvalidOperationException();
            var builder = new SqlConnectionStringBuilder(source) { ConnectTimeout = 5 };
            connectionString = builder.ConnectionString;
            await using var connection = new SqlConnection(connectionString); await connection.OpenAsync(ct);
            var database = await connection.QuerySingleAsync<DatabaseStatus>(new CommandDefinition("SELECT name Name,CONVERT(int,compatibility_level) CompatibilityLevel FROM sys.databases WHERE name=DB_NAME()", cancellationToken: ct));
            compatibility = database.CompatibilityLevel;
            return $"تم الاتصال بقاعدة {database.Name} · compatibility_level = {compatibility}";
        });
        int? userId = null;
        if (databaseOk)
        {
            if (compatibility < 130) Add("SQL_COMPATIBILITY", "fail", "مستوى توافق SQL منخفض", $"المستوى الحالي {compatibility}؛ OPENJSON المستخدم في صلاحيات الثيمات يحتاج 130 أو أعلى.", "على SQL Server 2017 اضبط CompanyPortal على COMPATIBILITY_LEVEL = 140 من SSMS. لا تُعد استيراد البيانات لحل ذلك.");
            await Probe("SCHEMA", "الإجراءات الأساسية المطلوبة", async ct =>
            {
                await using var c = new SqlConnection(connectionString);
                // Runtime identities may execute procedures without seeing underlying
                // table metadata. Do not misreport those tables as absent.
                var required = new[] { "Security.User_getByUsername", "Security.UserRoles_get", "Security.Apps_getForUser", "Portal.UserSettings_getTheme", "Master.Themes_getAll", "News.Items_get", "Mstr.Utls_GetFolderPaths" };
                var missing = new List<string>();
                foreach (var name in required)
                    if (await c.ExecuteScalarAsync<int?>(new CommandDefinition("SELECT OBJECT_ID(@name)", new { name }, cancellationToken: ct)) is null) missing.Add(name);
                if (missing.Count > 0) { Add("SCHEMA_MISSING", "fail", "عناصر SQL مفقودة", string.Join("، ", missing), "استورد الملف الصحيح بالكامل؛ لا تُعد تشغيل ملف الإنشاء على قاعدة موجودة."); return "اكتمل حصر العناصر؛ راجع النواقص أعلاه."; }
                return "الإجراءات الأساسية مرئية لهوية API؛ هذا ليس فحصًا شاملًا لكل الجداول والميزات.";
            });
            await Probe("USER_LOOKUP", "ربط NTName بمعرّف المستخدم", async ct =>
            {
                await using var c = new SqlConnection(connectionString);
                userId = await c.QuerySingleOrDefaultAsync<int?>(new CommandDefinition("Security.User_getByUsername", new { Username = account }, commandType: CommandType.StoredProcedure, cancellationToken: ct));
                if (userId is null) Add("USER_UNREGISTERED", "fail", "الحساب غير مسجل أو غير نشط", account, "صحّح NTName وActive في مصدر المستخدمين. احتفظ بـ UserId لاستعادة إعداداته وبطاقاته.");
                return userId is null ? "لم يُرجع مصدر المستخدمين UserId." : $"UserId = {userId}";
            });
            if (userId is not null)
                await Probe("ROLE_LOOKUP", "مصدر الأدوار", async ct =>
                {
                    await using var c = new SqlConnection(connectionString);
                    var roles = await c.QueryAsync<string>(new CommandDefinition("Security.UserRoles_get", new { UserId = userId.Value }, commandType: CommandType.StoredProcedure, cancellationToken: ct));
                    return roles.Contains("CompanyPortal.Admin", StringComparer.Ordinal) ? "الحساب مدير بوابة." : "الحساب ليس مدير بوابة؛ الوصول الحالي للتشخيص فقط من قائمة الإعداد المؤقتة.";
                });
            await Probe("NEWS_QUERY", "ربط View الأخبار بقاعدة المصدر", async ct =>
            {
                await using var c = new SqlConnection(connectionString);
                using var reader = await c.QueryMultipleAsync(new CommandDefinition("News.Items_get", commandType: CommandType.StoredProcedure, cancellationToken: ct));
                _ = await reader.ReadAsync(); _ = await reader.ReadAsync();
                return "نجح استعلام الأخبار وView المصدر. لم تُعرض بيانات الأخبار في التقرير.";
            });
            await Probe("NEWS_ROOTS", "إعداد مجلدات الأخبار", async ct =>
            {
                await using var c = new SqlConnection(connectionString);
                var roots = await c.QueryAsync<FolderPath>(new CommandDefinition("Mstr.Utls_GetFolderPaths", commandType: CommandType.StoredProcedure, cancellationToken: ct));
                var news = roots.Where(x => x.Key == "PubsInfo").ToArray();
                if (news.Length == 0) Add("NEWS_ROOT_MISSING", "warn", "لا يوجد مجلد PubsInfo", "لن تعمل مرفقات الأخبار.", "أضف مسارًا مطلقًا نشطًا في Mstr.Utls وأعطِ هوية API صلاحية القراءة.");
                foreach (var root in news)
                    if (!Path.IsPathFullyQualified(root.Path)) Add("NEWS_ROOT_INVALID", "warn", "مسار أخبار غير مطلق", "لن يُسمح بفتح ملفات من هذا المسار.", "صحّح المسار في Mstr.Utls.");
                    else if (root.Path.StartsWith(@"\\", StringComparison.Ordinal)) Add("NEWS_SHARE", "manual", "صلاحية مشاركة الأخبار", "المسار شبكة UNC؛ لم يُفحص وجوده لتجنب تعليق الفحص عند انقطاع المشاركة.", "افتح مرفق خبر للتحقق من صلاحيات المشاركة وNTFS بهوية API.");
                    else if (!Directory.Exists(root.Path)) Add("NEWS_ROOT_UNAVAILABLE", "warn", "مجلد أخبار غير متاح", "المجلد غير موجود أو لا يمكن لهوية API الوصول إليه.", "صحّح المسار وصلاحيات المجلد في الشبكة الداخلية.");
                return $"عدد مسارات PubsInfo: {news.Length}. وجود المجلد لا يثبت صلاحية قراءة كل ملف.";
            });
        }
        else Add("SQL_DEPENDENTS", "skip", "هوية المستخدم والأدوار والأخبار", "لم تُفحص بسبب فشل الاتصال بقاعدة البيانات.");

        var options = config.GetSection("Exchange").Get<MailOptions>() ?? new();
        Add("EXCHANGE_ENABLED", options.Enabled ? "pass" : "warn", "تشغيل Exchange", $"Enabled = {options.Enabled} · ScheduleEnabled = {options.ScheduleEnabled}", options.Enabled && options.ScheduleEnabled ? "" : "فعّل Enabled وScheduleEnabled بعد تجهيز حساب الخدمة وصلاحيات Exchange.");
        var validOptions = await Probe("EXCHANGE_CONFIG", "عناوين Exchange وطريقة الوصول", ct =>
        {
            _ = MailOptions.HttpsAddress(options.EwsUrl); _ = MailOptions.HttpsAddress(options.OutlookWebUrl); _ = options.ScheduleZone();
            if (options.AccessMode != "ScopedServiceAccountImpersonation") throw new InvalidOperationException();
            return Task.FromResult("عناوين HTTPS وصيغة طريقة الوصول والمنطقة الزمنية صحيحة. لم يُختبر اتصال Outlook Web أو اختيار الرسالة.");
        });
        if (string.IsNullOrWhiteSpace(options.OutlookWebInboxUrl)) Add("OWA_INBOX", "warn", "رابط فتح البريد", "OutlookWebInboxUrl فارغ.", "ضع رابط صندوق الوارد الداخلي المجرّب حتى يعمل زر فتح البريد.");
        else await Probe("OWA_INBOX", "رابط فتح البريد", ct => { _ = options.InboxLink(); return Task.FromResult("صيغة الرابط والأصل صحيحتان؛ افتحه في المتصفح لاختبار تسجيل الدخول الفعلي."); });
        string? mailbox = null;
        var mapped = await Probe("MAILBOX_MAPPING", "ربط الحساب بصندوق البريد", ct =>
        {
            mailbox = options.MailboxFor(account);
            if (mailbox is null) throw new InvalidOperationException();
            return Task.FromResult("يوجد عنوان SMTP صالح للحساب الحالي.");
        });
        if (options.Enabled && validOptions && mapped && userId is not null)
        {
            await Probe("EWS_INBOX", "وصول EWS إلى صندوق الوارد", async ct =>
            {
                await using var session = sessions.Create(mailbox!); await session.ProbeInboxAsync(ct);
                return "نجح GetFolder بهوية خدمة API وانتحال المستخدم المحدد. لم تُقرأ عناوين الرسائل.";
            });
            if (options.ScheduleEnabled)
            {
                await Probe("EWS_CALENDAR", "وصول EWS إلى التقويم", async ct =>
                {
                    await using var session = sessions.Create(mailbox!); var rights = await session.CalendarAccessAsync(mailbox!, ct);
                    if (!rights.Read) throw new EwsResponseException("ErrorAccessDenied");
                    return "نجحت قراءة صلاحيات التقويم. الأحداث والمهام والتحديثات الحية تحتاج اختبار الواجهة.";
                });
                await Probe("EWS_TASKS", "وصول EWS إلى المهام", async ct =>
                {
                    await using var session = sessions.Create(mailbox!); await session.ProbeTasksAsync(ct);
                    return "نجحت قراءة صلاحية مجلد المهام؛ لم تُقرأ محتويات المهام.";
                });
            }
        }
        else Add("EWS_LIVE", "skip", "الاتصال الفعلي بـ EWS", "لم يُنفّذ: راجع تشغيل Exchange والإعدادات وربط المستخدم والبريد أعلاه.");
        Add("LIVE_ACCEPTANCE", "manual", "التحديثات الحية والتفويض", "هذا الفحص لا ينشئ اشتراكات ولا يرسل بريدًا ولا يغيّر بيانات.", "اختبر وصول بريد جديد وتعديل تقويم/مهمة من Outlook؛ اختبر صلاحيات التفويض والخصوصية عند توفر حسابين.");
        return Ok(new { reference = HttpContext.TraceIdentifier, checkedAt = DateTimeOffset.UtcNow, checks });
    }
    private sealed record FolderPath(string Key, string Path);
    private sealed record DatabaseStatus(string Name, int CompatibilityLevel);
    private static (string, string, string) Failure(Exception error)
    {
        if (error is SqlException sql) return ($"SQL_{sql.Number}", "فشل اتصال SQL أو تنفيذ الاستعلام.", sql.Number switch {
            18456 => "تحقق من تسجيل دخول هوية API وصلاحياتها في SQL Server.",
            4060 => "تحقق من اسم قاعدة البيانات وإتاحتها لهوية API.",
            229 => "امنح هوية API صلاحيات EXECUTE والقراءة المطلوبة في قواعد المصادر.",
            208 or 2812 => "جدول أو View أو إجراء مفقود. استورد SQL ثم راجع ربط قواعد المصادر.",
            _ => "راجع اسم مثيل SQL Express، الخدمة، الشبكة، شهادة SQL وصلاحيات هوية API؛ راجع السجل بالرقم المرجعي." });
        if (error is EwsResponseException ews) return (ews.Code, "رفض Exchange طلب EWS.", ews.Code switch {
            "ErrorImpersonateUserDenied" or "ErrorImpersonationDenied" or "ErrorAccessDenied" => "تحقق من صلاحية ApplicationImpersonation ونطاقها للحساب الذي يشغّل API. عند التشغيل من localhost فهذا حساب Windows الذي شغّل dotnet، وليس حساب خدمة IIS. لا تغيّر طريقة الوصول قبل التحقق من الصلاحية.",
            "ErrorInvalidServerVersion" or "ErrorInvalidRequest" or "ErrorSchemaValidation" => "رفض Exchange إصدار أو صيغة طلب SOAP. راجع رمز الخطأ وسجل EWS؛ لا تغيّر صلاحيات الحساب اعتمادًا على هذا الخطأ وحده.",
            "ErrorUnknownSoapFault" => "أعاد Exchange خطأ SOAP دون رمز EWS معروف. أعطِ مسؤول Exchange وقت الفحص والرقم المرجعي لمراجعة سجل EWS؛ لا يتضمن التقرير نص XML الخام.",
            "ErrorNonExistentMailbox" or "ErrorInvalidUserInfo" => "تحقق من SMTP وربط NTName وصندوق البريد الفعلي.",
            _ => "راجع رمز EWS وصلاحيات الخدمة وصندوق البريد وسجل API بالرقم المرجعي." });
        if (error is HttpRequestException http && http.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            return ($"HTTP_{(int)http.StatusCode}", "رفض Exchange مصادقة HTTP أو الوصول.", "تحقق من هوية API ومصادقة Windows في EWS؛ تسجيل دخول الموظف للبوابة لا يمنح الخدمة صلاحية Exchange.");
        if (error is HttpRequestException server && server.StatusCode is not null)
            return ($"HTTP_{(int)server.StatusCode}", "أعاد خادم EWS خطأ HTTP دون رمز SOAP قابل للاستخراج.", "تحقق من عنوان /EWS/Exchange.asmx وراجع سجل EWS/HTTP Proxy لدى مسؤول Exchange بوقت الفحص. HTTP500 وحده لا يحدد إن كان السبب صلاحيات أو مشكلة خادم أو وكيل.");
        if (error is AuthenticationException || error.InnerException is AuthenticationException)
            return ("TLS", "فشل التحقق من شهادة HTTPS.", "ثبّت سلسلة شهادات الجهة الداخلية وتحقق من الاسم والصلاحية؛ لا تعطّل التحقق من الشهادة.");
        if (error is SocketException || error.InnerException is SocketException)
            return ("NETWORK", "تعذر الوصول إلى الخادم.", "تحقق من DNS والمنافذ والجدار الناري وعنوان الخادم من جهاز API.");
        if (error is OperationCanceledException) return ("TIMEOUT", "انتهت مهلة الفحص.", "تحقق من وصول جهاز API إلى SQL أو EWS ثم أعد الفحص.");
        if (error is InvalidOperationException or ArgumentException or TimeZoneNotFoundException)
            return ("CONFIG", "إعداد ناقص أو غير صالح لهذه الخطوة.", "راجع ConnectionStrings:CompanyPortal أو Exchange:EwsUrl وOutlookWebUrl وAccessMode وScheduleTimeZone وMailboxAddresses حسب اسم الخطوة.");
        return ("FAILED", "تعذر إكمال الخطوة.", "راجع سجل API باستخدام الرقم المرجعي. لا تُعرض رسائل الخادم الخام أو الأسرار في الصفحة.");
    }
}
