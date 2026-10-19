using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;
using CompanyPortal.Api.Contracts;

namespace CompanyPortal.Api.Mail;

public sealed class EwsMailSession : IAsyncDisposable
{
    private static readonly XNamespace Soap = "http://schemas.xmlsoap.org/soap/envelope/";
    private static readonly XNamespace T = "http://schemas.microsoft.com/exchange/services/2006/types";
    private static readonly XNamespace M = "http://schemas.microsoft.com/exchange/services/2006/messages";
    private static readonly HashSet<string> MailTypes = ["Message", "MeetingMessage", "MeetingRequest", "MeetingResponse", "MeetingCancellation"];
    private readonly HttpClient client;
    private readonly MailOptions options;
    private readonly string mailbox;
    public EwsMailSession(HttpClient client, MailOptions options, string mailbox)
    {
        options.Validate(); this.client = client; this.options = options; this.mailbox = mailbox;
    }
    public string InboxLink => options.InboxLink();
    private XElement InboxId() => new(T + "DistinguishedFolderId", new XAttribute("Id", "inbox"),
        new XElement(T + "Mailbox", new XElement(T + "EmailAddress", mailbox)));
    private static XElement Field(string name) => new(T + "FieldURI", new XAttribute("FieldURI", name));

    private async Task<(string Id, int Unread)> FolderAsync(CancellationToken token)
    {
        var document = await CallAsync(new XElement(M + "GetFolder",
            new XElement(M + "FolderShape", new XElement(T + "BaseShape", "IdOnly"),
                new XElement(T + "AdditionalProperties", Field("folder:UnreadCount"))),
            new XElement(M + "FolderIds", InboxId())), token);
        var folder = document.Descendants(T + "Folder").Single();
        var id = folder.Element(T + "FolderId")?.Attribute("Id")?.Value ?? throw new XmlException("Missing inbox folder ID.");
        var unread = int.Parse(folder.Element(T + "UnreadCount")?.Value ?? throw new XmlException("Missing inbox unread count."), CultureInfo.InvariantCulture);
        if (unread < 0) throw new XmlException("Invalid unread count.");
        return (id, unread);
    }

    public async Task<InboxSnapshot> SnapshotAsync(CancellationToken token)
    {
        var folder = await FolderAsync(token);
        var document = await CallAsync(new XElement(M + "FindItem", new XAttribute("Traversal", "Shallow"),
            new XElement(M + "ItemShape", new XElement(T + "BaseShape", "IdOnly"),
                new XElement(T + "AdditionalProperties", Field("item:Subject"), Field("item:DateTimeReceived"), Field("message:Sender"), Field("message:IsRead"))),
            new XElement(M + "IndexedPageItemView", new XAttribute("MaxEntriesReturned", options.LatestMessageCount), new XAttribute("Offset", 0), new XAttribute("BasePoint", "Beginning")),
            new XElement(M + "SortOrder", new XElement(T + "FieldOrder", new XAttribute("Order", "Descending"), Field("item:DateTimeReceived"))),
            new XElement(M + "ParentFolderIds", InboxId())), token);
        var items = document.Descendants(T + "Items").Elements().Where(item => item.Name.Namespace == T && MailTypes.Contains(item.Name.LocalName)).Select(item => new InboxMessage(
            item.Element(T + "ItemId")?.Attribute("Id")?.Value ?? throw new XmlException("Missing mail item ID."), item.Element(T + "Subject")?.Value ?? "",
            item.Element(T + "Sender")?.Descendants(T + "Name").FirstOrDefault()?.Value
                ?? item.Element(T + "Sender")?.Descendants(T + "EmailAddress").FirstOrDefault()?.Value ?? "",
            DateTimeOffset.Parse(item.Element(T + "DateTimeReceived")?.Value ?? throw new XmlException("Missing received date."), CultureInfo.InvariantCulture),
            XmlConvert.ToBoolean(item.Element(T + "IsRead")?.Value ?? throw new XmlException("Missing read status.")))).ToArray();
        return new InboxSnapshot(folder.Unread, items, DateTimeOffset.UtcNow);
    }

    public async Task<string?> MessageLinkAsync(string itemId, CancellationToken token)
    {
        var folder = await FolderAsync(token);
        var document = await CallAsync(new XElement(M + "GetItem", new XElement(M + "ItemShape",
            new XElement(T + "BaseShape", "IdOnly"), new XElement(T + "AdditionalProperties", Field("item:ParentFolderId"), Field("item:WebClientReadFormQueryString"))),
            new XElement(M + "ItemIds", new XElement(T + "ItemId", new XAttribute("Id", itemId)))), token);
        var item = document.Descendants(M + "Items").Elements().SingleOrDefault(item => item.Name.Namespace == T && MailTypes.Contains(item.Name.LocalName));
        // A guessed item ID must not open mail from some other folder/mailbox to
        // which the service account happens to have rights.
        if (item?.Element(T + "ParentFolderId")?.Attribute("Id")?.Value != folder.Id) return null;
        return options.MessageLink(itemId, item.Element(T + "WebClientReadFormQueryString")?.Value ?? "");
    }

    public async IAsyncEnumerable<InboxSnapshot> ObserveAsync([EnumeratorCancellation] CancellationToken token)
    {
        var subscribed = await CallAsync(new XElement(M + "Subscribe", new XElement(M + "StreamingSubscriptionRequest",
            new XAttribute("SubscribeToAllFolders", "false"), new XElement(T + "FolderIds", InboxId()),
            new XElement(T + "EventTypes", new[] { "NewMailEvent", "CreatedEvent", "ModifiedEvent", "DeletedEvent", "MovedEvent", "CopiedEvent" }
                .Select(name => new XElement(T + "EventType", name))))), token);
        var id = subscribed.Descendants(M + "SubscriptionId").Single().Value;
        try
        {
            // Subscribe before the initial read so an arriving message cannot fall
            // between the snapshot and subscription. No timer polls the inbox.
            yield return await SnapshotAsync(token);
            while (!token.IsCancellationRequested)
            {
                var operation = new XElement(M + "GetStreamingEvents", new XElement(M + "SubscriptionIds", new XElement(T + "SubscriptionId", id)), new XElement(M + "ConnectionTimeout", 1));
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
                timeout.CancelAfter(TimeSpan.FromSeconds(90));
                using var request = Request(operation);
                using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
                response.EnsureSuccessStatusCode();
                await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
                var started = DateTime.UtcNow;
                await foreach (var envelope in ReadEnvelopesAsync(stream, timeout.Token))
                {
                    Check(envelope);
                    if (envelope.Descendants(T + "Notification").Any() || envelope.Descendants(M + "Notification").Any())
                    {
                        var changes = new HashSet<string>(["NewMailEvent", "CreatedEvent", "ModifiedEvent", "DeletedEvent", "MovedEvent", "CopiedEvent"]);
                        if (envelope.Descendants().Any(node => node.Name.Namespace == T && changes.Contains(node.Name.LocalName)))
                            yield return await SnapshotAsync(token);
                    }
                }
                if (DateTime.UtcNow - started < TimeSpan.FromSeconds(1))
                    throw new InvalidOperationException("Exchange ended its streaming connection prematurely.");
                // A normal held-connection timeout renews GetStreamingEvents on the
                // existing subscription; it does not perform an inbox read.
            }
        }
        finally
        {
            using var cleanup = new CancellationTokenSource(TimeSpan.FromSeconds(2));
            try { await CallAsync(new XElement(M + "Unsubscribe", new XElement(M + "SubscriptionId", id)), cleanup.Token); }
            catch (Exception error) when (error is HttpRequestException or OperationCanceledException or InvalidOperationException or XmlException) { /* Connection loss can already have invalidated the subscription. */ }
        }
    }

    private HttpRequestMessage Request(XElement operation)
    {
        var envelope = new XElement(Soap + "Envelope", new XAttribute(XNamespace.Xmlns + "s", Soap), new XAttribute(XNamespace.Xmlns + "t", T), new XAttribute(XNamespace.Xmlns + "m", M),
            new XElement(Soap + "Header", new XElement(T + "RequestServerVersion", new XAttribute("Version", "Exchange2013_SP1")),
                new XElement(T + "ExchangeImpersonation", new XElement(T + "ConnectingSID", new XElement(T + "SmtpAddress", mailbox)))), new XElement(Soap + "Body", operation));
        var request = new HttpRequestMessage(HttpMethod.Post, options.EwsUrl) { Content = new StringContent(envelope.ToString(SaveOptions.DisableFormatting), Encoding.UTF8, "text/xml") };
        request.Headers.Add("SOAPAction", "\"" + M.NamespaceName + "/" + operation.Name.LocalName + "\"");
        request.Headers.Add("X-AnchorMailbox", mailbox);
        request.Headers.Add("X-PreferServerAffinity", "true");
        return request;
    }

    private async Task<XElement> CallAsync(XElement operation, CancellationToken token)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token); timeout.CancelAfter(TimeSpan.FromSeconds(30));
        using var request = Request(operation); using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
        using var reader = XmlReader.Create(stream, new XmlReaderSettings { Async = true, DtdProcessing = DtdProcessing.Prohibit, MaxCharactersInDocument = 2_000_000, XmlResolver = null });
        var document = await XElement.LoadAsync(reader, LoadOptions.None, timeout.Token); Check(document); return document;
    }

    private static void Check(XElement envelope)
    {
        if (envelope.Name != Soap + "Envelope") throw new XmlException("Invalid EWS envelope.");
        if (envelope.Descendants(Soap + "Fault").Any()) throw new InvalidOperationException("Exchange SOAP fault.");
        var errors = envelope.Descendants(M + "ResponseCode").Where(node => node.Value != "NoError").Select(node => node.Value).ToArray();
        if (errors.Length > 0) throw new EwsResponseException(errors[0]);
    }

    public static async IAsyncEnumerable<XElement> ReadEnvelopesAsync(Stream stream, [EnumeratorCancellation] CancellationToken token)
    {
        // Exchange sends complete SOAP envelopes incrementally, independent of HTTP
        // chunk boundaries. Frame each envelope before strict, DTD-disabled parsing.
        using var reader = new StreamReader(stream, Encoding.UTF8, true, 4096, leaveOpen: true);
        var buffer = new StringBuilder(); var chars = new char[4096];
        var startPattern = new Regex(@"<(?<prefix>[A-Za-z_][\w.-]*:)?Envelope(?=[\s>])", RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1));
        while (true)
        {
            var count = await reader.ReadAsync(chars.AsMemory(), token); if (count == 0) break;
            buffer.Append(chars, 0, count);
            if (buffer.Length > 2_000_000) throw new XmlException("EWS streaming frame is too large.");
            while (true)
            {
                var text = buffer.ToString(); var match = startPattern.Match(text); if (!match.Success) break;
                var endTag = "</" + match.Groups["prefix"].Value + "Envelope>";
                var end = text.IndexOf(endTag, match.Index + match.Length, StringComparison.Ordinal); if (end < 0) break;
                end += endTag.Length;
                using var xml = XmlReader.Create(new StringReader(text[match.Index..end]), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 2_000_000 });
                var envelope = XElement.Load(xml); Check(envelope); buffer.Remove(0, end); yield return envelope;
            }
        }
        if (!string.IsNullOrWhiteSpace(buffer.ToString())) throw new XmlException("Truncated EWS streaming frame.");
    }
    public ValueTask DisposeAsync() { client.Dispose(); return ValueTask.CompletedTask; }
}

public sealed class EwsResponseException(string code) : InvalidOperationException("Exchange request failed: " + code)
{
    public string Code { get; } = code;
}
