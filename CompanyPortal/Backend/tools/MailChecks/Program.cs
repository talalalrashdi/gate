using System.Net;
using System.Text;
using System.Threading.Channels;
using System.Xml;
using System.Xml.Linq;
using CompanyPortal.Api.Mail;

static void Assert(bool value, string message) { if (!value) throw new Exception(message); }
static MailOptions Settings() => new() { Enabled = true, EwsUrl = "https://exchange.test/EWS/Exchange.asmx", OutlookWebUrl = "https://exchange.test/owa/", AccessMode = "WindowsDelegation", LatestMessageCount = 2 };
static void Reject(Action action, string message) { try { action(); } catch (InvalidOperationException) { return; } throw new Exception(message); }
static async Task Fault(string body, string expected, HttpStatusCode status = HttpStatusCode.InternalServerError)
{
    await using var mail = new EwsMailSession(new HttpClient(new FakeExchange { ErrorBody = body, ErrorStatus = status }), Settings(), "alice@example.test");
    try { await mail.ProbeInboxAsync(default); throw new Exception("SOAP fault was accepted."); }
    catch (EwsResponseException error) { Assert(error.Code == expected && !error.Message.Contains("SECRET"), "Fault code lost or private fault text exposed."); }
}
const string soap = "http://schemas.xmlsoap.org/soap/envelope/";
await Fault($"<s:Envelope xmlns:s='{soap}'><s:Body><s:Fault><faultcode>a:ErrorImpersonateUserDenied</faultcode><faultstring>SECRET server details</faultstring></s:Fault></s:Body></s:Envelope>", "ErrorImpersonateUserDenied");
await Fault($"<s:Envelope xmlns:s='{soap}'><s:Body><s:Fault><faultcode>s:Server</faultcode><detail><e:ResponseCode xmlns:e='http://schemas.microsoft.com/exchange/services/2006/errors'>ErrorNonExistentMailbox</e:ResponseCode><message>SECRET</message></detail></s:Fault></s:Body></s:Envelope>", "ErrorNonExistentMailbox");
await Fault($"<s:Envelope xmlns:s='{soap}'><s:Body><s:Fault><faultcode>s:Server</faultcode><faultstring>SECRET</faultstring></s:Fault></s:Body></s:Envelope>", "ErrorUnknownSoapFault", HttpStatusCode.OK);
await Fault($"<s:Envelope xmlns:s='{soap}'><s:Body><m:ResponseMessages xmlns:m='http://schemas.microsoft.com/exchange/services/2006/messages'><m:ResponseCode>ErrorAccessDenied</m:ResponseCode></m:ResponseMessages></s:Body></s:Envelope>", "ErrorAccessDenied");
foreach (var body in new[] { "", "<html><body>SECRET</body></html>", "<!DOCTYPE x [<!ENTITY y 'SECRET'>]><x>&y;</x>", "<broken" })
{
    await using var failed = new EwsMailSession(new HttpClient(new FakeExchange { ErrorBody = body }), Settings(), "alice@example.test");
    try { await failed.ProbeInboxAsync(default); throw new Exception("HTTP500 accepted."); }
    catch (HttpRequestException error) { Assert(error.StatusCode == HttpStatusCode.InternalServerError && !error.Message.Contains("SECRET"), "HTTP status lost or error body exposed."); }
}
var options = Settings();
Reject(() => options.InboxLink(), "Missing inbox URL silently fell back to the general Outlook URL.");
options.OutlookWebInboxUrl = "https://evil.test/inbox";
Reject(options.Validate, "Off-origin inbox URL accepted.");
options.OutlookWebInboxUrl = "https://exchange.test/owa/#verified-inbox-route";
Assert(options.InboxLink() == options.OutlookWebInboxUrl, "Explicit inbox destination was ignored.");
Reject(() => new MailOptions().Validate(), "Disabled configuration accepted.");
var legacy = Settings(); legacy.AccessMode = "ScopedServiceAccountImpersonation"; Reject(legacy.Validate, "Old service-account mode accepted.");
var invalid = Settings(); invalid.EwsUrl = "http://exchange.test/ews"; Reject(invalid.Validate, "HTTP credentials accepted.");
invalid = Settings(); invalid.AccessMode = "DefaultCredentials"; Reject(invalid.Validate, "Unapproved identity mode accepted.");
invalid = Settings(); invalid.OpenMode = "InboxSelected"; Reject(invalid.Validate, "Unverified inbox template accepted.");
invalid.InboxSelectedUrlTemplate = "https://evil.test/{itemId}"; Reject(invalid.Validate, "Off-origin Outlook link accepted.");
invalid.InboxSelectedUrlTemplate = "#verified-route/{itemId}"; invalid.Validate();
Assert(invalid.MessageLink("A+/=", "") == "https://exchange.test/owa/#verified-route/A%2B%2F%3D", "Template ID not safely encoded.");
Reject(() => options.MessageLink("x", "https://evil.test/"), "Absolute read-form URL accepted.");
options.MailboxAddresses["DOMAIN\\Alice"] = "alice@example.test";
Assert(options.MailboxFor("domain\\alice") == "alice@example.test" && options.MailboxFor("DOMAIN\\Bob") is null, "Account mapping guessed or case handling wrong.");

var handler = new FakeExchange();
await using (var mail = new EwsMailSession(new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan }, options, "alice@example.test"))
{
    Assert(mail.InboxLink == options.OutlookWebInboxUrl, "Open-inbox action used the general Outlook URL.");
    await mail.ProbeInboxAsync(default);
    await mail.ProbeTasksAsync(default);
    Assert(handler.Calls.All(call => call == "GetFolder"), "Setup probes read items or subscribed.");
    handler.TasksReadable = false;
    try { await mail.ProbeTasksAsync(default); throw new Exception("Task probe ignored denied access."); }
    catch (EwsResponseException error) when (error.Code == "ErrorAccessDenied") { }
    handler.TasksReadable = true;
    var snapshot = await mail.SnapshotAsync(default);
    Assert(snapshot.UnreadCount == 7 && snapshot.Items.Count == 2, "Unread count was inferred from the visible rows.");
    Assert(snapshot.Items[0].Subject == "<b>Latest mail</b>" && !snapshot.Items[0].IsRead, "Message fields not parsed.");
    Assert((await mail.MessageLinkAsync("A+/=", default)) == "https://exchange.test/owa/?ItemID=A%2B%2F%3D&viewmodel=ReadMessageItem", "Read form not used.");
    handler.WrongParent = true;
    Assert(await mail.MessageLinkAsync("other-user-id", default) is null, "Another folder/mailbox's item was accepted.");
    handler.WrongParent = false;
    using var stop = new CancellationTokenSource();
    await using (var events = mail.ObserveAsync(stop.Token).GetAsyncEnumerator(stop.Token))
    {
        Assert(await events.MoveNextAsync(), "Missing initial snapshot.");
        Assert(handler.Calls.IndexOf("Subscribe") < handler.Calls.LastIndexOf("FindItem"), "Snapshot ran before subscription.");
        var pending = events.MoveNextAsync().AsTask();
        await handler.StreamStarted.Task.WaitAsync(TimeSpan.FromSeconds(2));
        var reads = handler.Calls.Count(call => call == "FindItem");
        await handler.Push("StatusEvent");
        await Task.Delay(100);
        Assert(!pending.IsCompleted && handler.Calls.Count(call => call == "FindItem") == reads, "Status/heartbeat polled the inbox.");
        handler.Unread = 8; handler.Subject = "New event-driven mail";
        await handler.Push("NewMailEvent");
        Assert(await pending.WaitAsync(TimeSpan.FromSeconds(2)), "New mail event was not delivered.");
        Assert(events.Current.UnreadCount == 8 && events.Current.Items[0].Subject == handler.Subject, "New mail did not update snapshot.");
        pending = events.MoveNextAsync().AsTask(); handler.Unread = 6; handler.IsRead = true;
        await handler.Push("ModifiedEvent");
        Assert(await pending.WaitAsync(TimeSpan.FromSeconds(2)) && events.Current.UnreadCount == 6 && events.Current.Items[0].IsRead, "Read-status changes did not update count.");
        pending = events.MoveNextAsync().AsTask(); handler.Unread = 5;
        await handler.Push("DeletedEvent");
        Assert(await pending.WaitAsync(TimeSpan.FromSeconds(2)) && events.Current.UnreadCount == 5, "Delete event did not update count.");
        stop.Cancel();
    }
    Assert(handler.Calls.Count(call => call == "Unsubscribe") == 1, "Disconnect did not unsubscribe.");
    Assert(handler.Calls.All(call => new[] { "GetFolder", "FindItem", "GetItem", "Subscribe", "GetStreamingEvents", "Unsubscribe" }.Contains(call)), "Unexpected mailbox mutation operation.");
}

var limits = new MailStreamLimits(); using var first = limits.TryEnter("DOMAIN\\Alice"); using var second = limits.TryEnter("domain\\alice");
Assert(first is not null && second is not null && limits.TryEnter("domain\\alice") is null, "Per-account stream limit not enforced.");
first!.Dispose(); first.Dispose(); using var third = limits.TryEnter("domain\\alice"); Assert(third is not null, "Lease was not released exactly once.");

try
{
    await foreach (var _ in EwsMailSession.ReadEnvelopesAsync(new MemoryStream(Encoding.UTF8.GetBytes("<s:Envelope xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>")), default)) { }
    throw new Exception("Truncated stream accepted.");
}
catch (XmlException) { }
Console.WriteLine("PASS: options, account mapping, authoritative count, read links, mailbox boundary, fragmented streaming events, no status polling, read/delete updates, unsubscribe and stream limits. No real Exchange connection was used.");

sealed class FakeExchange : HttpMessageHandler
{
    private static readonly XNamespace S = "http://schemas.xmlsoap.org/soap/envelope/", M = "http://schemas.microsoft.com/exchange/services/2006/messages", T = "http://schemas.microsoft.com/exchange/services/2006/types";
    public List<string> Calls { get; } = [];
    public int Unread = 7;
    public string Subject = "<b>Latest mail</b>";
    public bool IsRead, WrongParent;
    public bool TasksReadable = true;
    public string? ErrorBody;
    public HttpStatusCode ErrorStatus = HttpStatusCode.InternalServerError;
    private readonly ChunkStream stream = new();
    public TaskCompletionSource StreamStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    public async Task Push(string eventName)
    {
        var text = "<?xml version=\"1.0\"?>" + Envelope(new XElement(M + "GetStreamingEventsResponse", new XElement(M + "ResponseMessages",
            new XElement(M + "GetStreamingEventsResponseMessage", new XAttribute("ResponseClass", "Success"), new XElement(M + "ResponseCode", "NoError"),
                new XElement(M + "Notifications", new XElement(M + "Notification", new XElement(T + eventName))))))).ToString(SaveOptions.DisableFormatting);
        // Arbitrary HTTP chunk boundaries must not affect SOAP framing.
        var bytes = Encoding.UTF8.GetBytes(text);
        for (var offset = 0; offset < bytes.Length; offset += 11) await stream.Chunks.Writer.WriteAsync(bytes.Skip(offset).Take(11).ToArray());
    }
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
    {
        var xml = XElement.Parse(await request.Content!.ReadAsStringAsync(token));
        if (request.RequestUri!.Scheme != "https" || xml.Descendants(T + "ExchangeImpersonation").Any()
            || request.Headers.GetValues("X-AnchorMailbox").Single() != "alice@example.test") throw new Exception("Wrong mailbox identity or endpoint.");
        var operation = xml.Element(S + "Body")!.Elements().Single().Name.LocalName;
        Calls.Add(operation);
        if (ErrorBody is not null) return new HttpResponseMessage(ErrorStatus) { Content = new StringContent(ErrorBody) };
        if (operation == "GetStreamingEvents")
        {
            StreamStarted.TrySetResult(); return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StreamContent(stream) };
        }
        XElement payload = operation switch
        {
            "GetFolder" => new XElement(M + "Folders", new XElement(T + "Folder", new XElement(T + "FolderId", new XAttribute("Id", "own-inbox")), new XElement(T + "UnreadCount", Unread), new XElement(T + "EffectiveRights", new XElement(T + "Read", TasksReadable)))),
            "FindItem" => new XElement(M + "RootFolder", new XElement(T + "Items", Enumerable.Range(0,2).Select(index =>
                new XElement(T + "Message", new XElement(T + "ItemId", new XAttribute("Id", index == 0 ? "A+/=" : "second")),
                    new XElement(T + "Subject", index == 0 ? Subject : "Other mail"), new XElement(T + "DateTimeReceived", "2026-10-19T08:00:00Z"),
                    new XElement(T + "Sender", new XElement(T + "Mailbox", new XElement(T + "Name", "Test sender"))), new XElement(T + "IsRead", IsRead))))),
            "GetItem" => new XElement(M + "Items", new XElement(T + "Message", new XElement(T + "ParentFolderId", new XAttribute("Id", WrongParent ? "other-inbox" : "own-inbox")),
                new XElement(T + "WebClientReadFormQueryString", "?ItemID=A%2B%2F%3D&viewmodel=ReadMessageItem"))),
            "Subscribe" => new XElement(M + "SubscriptionId", "subscription-1"),
            "Unsubscribe" => new XElement(M + "Done"),
            _ => throw new Exception("Unexpected SOAP operation: " + operation)
        };
        return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(Envelope(new XElement(M + (operation + "Response"),
            new XElement(M + "ResponseMessages", new XElement(M + (operation + "ResponseMessage"), new XAttribute("ResponseClass", "Success"), new XElement(M + "ResponseCode", "NoError"), payload)))).ToString(), Encoding.UTF8, "text/xml") };
    }
    private static XElement Envelope(XElement body) => new(S + "Envelope", new XAttribute(XNamespace.Xmlns + "s", S), new XAttribute(XNamespace.Xmlns + "t", T), new XAttribute(XNamespace.Xmlns + "m", M), new XElement(S + "Body", body));
}

sealed class ChunkStream : Stream
{
    public Channel<byte[]> Chunks { get; } = Channel.CreateUnbounded<byte[]>();
    private byte[] current = []; private int offset;
    public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken token = default)
    {
        if (offset == current.Length) { current = await Chunks.Reader.ReadAsync(token); offset = 0; }
        var count = Math.Min(buffer.Length, current.Length-offset); current.AsMemory(offset,count).CopyTo(buffer); offset += count; return count;
    }
    public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken token) => ReadAsync(buffer.AsMemory(offset,count),token).AsTask();
    public override bool CanRead => true; public override bool CanSeek => false; public override bool CanWrite => false;
    public override long Length => throw new NotSupportedException(); public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
    public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException(); public override void Flush() { }
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException(); public override void SetLength(long value) => throw new NotSupportedException(); public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}
