using System.Net;

namespace CompanyPortal.Api.Mail;

public sealed class MailSessionFactory(IConfiguration configuration)
{
    public EwsMailSession Create(string mailbox)
    {
        var options = configuration.GetSection("Exchange").Get<MailOptions>() ?? new();
        options.Validate();
        // Each session has its own Exchange affinity cookies. No visitor impersonation
        // or passwords: Exchange must explicitly authorize the scoped IIS identity.
        var client = new HttpClient(new HttpClientHandler
        {
            UseDefaultCredentials = true,
            AllowAutoRedirect = false,
            CookieContainer = new CookieContainer(),
            UseCookies = true
        }) { Timeout = Timeout.InfiniteTimeSpan };
        return new EwsMailSession(client, options, mailbox);
    }
}
