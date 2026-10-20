using System.Net.Mail;

namespace CompanyPortal.Api.Mail;

public sealed class MailOptions
{
    public bool Enabled { get; set; }
    public string EwsUrl { get; set; } = "";
    public string OutlookWebUrl { get; set; } = "";
    public string OutlookWebInboxUrl { get; set; } = "";
    public string AccessMode { get; set; } = "Unconfigured";
    public string OpenMode { get; set; } = "Message";
    public string InboxSelectedUrlTemplate { get; set; } = "";
    public int LatestMessageCount { get; set; } = 10;
    public Dictionary<string, string> MailboxAddresses { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public bool ScheduleEnabled { get; set; }
    public string ScheduleTimeZone { get; set; } = "Asia/Muscat";
    public Dictionary<string, SharedCalendarOptions[]> SharedCalendars { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public string ScheduleZoneId()=>TimeZoneInfo.TryConvertWindowsIdToIanaId(ScheduleTimeZone,out var iana)?iana:ScheduleTimeZone;
    public TimeZoneInfo ScheduleZone() => TimeZoneInfo.FindSystemTimeZoneById(ScheduleTimeZone);
    public SharedCalendarOptions[] CalendarsFor(string account)
    {
        var calendars=SharedCalendars.FirstOrDefault(p=>string.Equals(p.Key,account,StringComparison.OrdinalIgnoreCase)).Value??[];
        if(calendars.Length>10 || calendars.Any(c=>string.IsNullOrWhiteSpace(c.Name)||c.Name.Length>200
            || !System.Text.RegularExpressions.Regex.IsMatch(c.Key??"","^[a-zA-Z0-9_-]{1,40}$") || c.Key=="own"
            || !MailAddress.TryCreate(c.Mailbox,out var address)||address.Address!=c.Mailbox)
            || calendars.Select(c=>c.Key).Distinct(StringComparer.Ordinal).Count()!=calendars.Length)
            throw new InvalidOperationException("Configure valid, distinct shared calendar keys and mailbox addresses.");
        return calendars;
    }
    public void Validate()
    {
        if (!Enabled || AccessMode != "ScopedServiceAccountImpersonation")
            throw new InvalidOperationException("Configure and approve the Exchange service identity before enabling mail.");
        _ = HttpsAddress(EwsUrl); _ = HttpsAddress(OutlookWebUrl);
        if (!string.IsNullOrWhiteSpace(OutlookWebInboxUrl)) _ = InboxLink();
        if (LatestMessageCount is < 1 or > 20 || OpenMode is not ("Message" or "InboxSelected"))
            throw new InvalidOperationException("Invalid Exchange display settings.");
        if (OpenMode == "InboxSelected") _ = InboxSelectedLink("validation-id");
    }

    public string? MailboxFor(string account)
    {
        var address = MailboxAddresses.FirstOrDefault(pair => string.Equals(pair.Key, account, StringComparison.OrdinalIgnoreCase)).Value;
        if (string.IsNullOrWhiteSpace(address)) return null;
        if (!MailAddress.TryCreate(address, out var parsed) || parsed.Address != address || address.IndexOfAny(['\r', '\n']) >= 0)
            throw new InvalidOperationException("Configure an explicit SMTP address for the Windows account.");
        return address;
    }

    public string InboxLink()
    {
        var root = HttpsAddress(OutlookWebUrl);
        var inbox = HttpsAddress(OutlookWebInboxUrl);
        if (inbox.Authority != root.Authority)
            throw new InvalidOperationException("The inbox must use the configured internal Outlook Web origin.");
        return inbox.AbsoluteUri;
    }

    public string MessageLink(string itemId, string readForm)
    {
        if (OpenMode == "InboxSelected") return InboxSelectedLink(itemId);
        if (string.IsNullOrWhiteSpace(readForm) || readForm[0] is not ('?' or '#') || readForm.IndexOfAny(['\r','\n']) >= 0)
            throw new InvalidOperationException("Exchange did not provide a valid Outlook Web read-form link.");
        return new Uri(HttpsAddress(OutlookWebUrl), readForm).AbsoluteUri;
    }

    private string InboxSelectedLink(string itemId)
    {
        if (!InboxSelectedUrlTemplate.Contains("{itemId}", StringComparison.Ordinal))
            throw new InvalidOperationException("Verify and configure the Outlook Web inbox-selection template first.");
        var root = HttpsAddress(OutlookWebUrl);
        var link = new Uri(root, InboxSelectedUrlTemplate.Replace("{itemId}", Uri.EscapeDataString(itemId), StringComparison.Ordinal));
        if (link.Scheme != root.Scheme || link.Authority != root.Authority || !string.IsNullOrEmpty(link.UserInfo))
            throw new InvalidOperationException("The Outlook link must remain on the configured internal Outlook Web origin.");
        return link.AbsoluteUri;
    }

    public static Uri HttpsAddress(string address)
    {
        if (!Uri.TryCreate(address, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps || !string.IsNullOrEmpty(uri.UserInfo))
            throw new InvalidOperationException("Configure an HTTPS Exchange address without embedded credentials.");
        return uri;
    }
}

public sealed class SharedCalendarOptions
{
    public string Key {get;set;}="";
    public string Name {get;set;}="";
    public string Mailbox {get;set;}="";
    // Enable only after owner-scoped subscriptions have been approved internally.
    public bool EnableNotifications {get;set;}
}
