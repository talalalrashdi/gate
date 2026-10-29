using System.Net;
using System.Security.Principal;
using System.Runtime.Versioning;
namespace CompanyPortal.Api.Mail;

public sealed class MailSessionFactory(IConfiguration configuration,IHttpContextAccessor context)
{
 public EwsMailSession Create(string mailbox)
 {
  var options=configuration.GetSection("Exchange").Get<MailOptions>()??new();options.Validate();
  if(!OperatingSystem.IsWindows()||context.HttpContext?.User.Identity is not WindowsIdentity {IsAuthenticated:true} caller)
   throw new InvalidOperationException("Exchange requires the employee's authenticated Windows identity. Enable IIS Windows Authentication and verify Kerberos delegation.");
  var transport=new HttpClientHandler{UseDefaultCredentials=true,AllowAutoRedirect=false,CookieContainer=new CookieContainer(),UseCookies=true};
  try{return new EwsMailSession(new HttpClient(new CallerWindowsHandler(caller,transport)){Timeout=Timeout.InfiniteTimeSpan},options,mailbox);}
  catch{transport.Dispose();throw;}
 }
}

// One token and connection pool per session. All EWS sends, including streaming
// subscriptions/reconnect/unsubscribe, use the caller; there is no process-account fallback.
[SupportedOSPlatform("windows")]
public sealed class CallerWindowsHandler : DelegatingHandler
{
 private readonly WindowsIdentity identity;
 public CallerWindowsHandler(WindowsIdentity caller,HttpMessageHandler inner):base(inner)
 {identity=WindowsIdentity.RunImpersonated(caller.AccessToken,()=>WindowsIdentity.GetCurrent());}
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token)
  =>WindowsIdentity.RunImpersonatedAsync(identity.AccessToken,()=>base.SendAsync(request,token));
 protected override void Dispose(bool disposing){try{base.Dispose(disposing);}finally{if(disposing)identity.Dispose();}}
}
