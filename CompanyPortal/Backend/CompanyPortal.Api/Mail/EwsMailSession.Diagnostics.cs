using System.Xml.Linq;

namespace CompanyPortal.Api.Mail;

public sealed partial class EwsMailSession
{
    // Temporary setup probes: folder metadata only, no item contents or subscriptions.
    public async Task ProbeInboxAsync(CancellationToken token) { _ = await FolderAsync(token); }
    public async Task ProbeTasksAsync(CancellationToken token)
    {
        var document = await CallAsync(new XElement(M + "GetFolder",
            new XElement(M + "FolderShape", new XElement(T + "BaseShape", "IdOnly"),
                new XElement(T + "AdditionalProperties", Field("folder:EffectiveRights"))),
            new XElement(M + "FolderIds", new XElement(T + "DistinguishedFolderId", new XAttribute("Id", "tasks")))), token);
        var rights = document.Descendants(T + "EffectiveRights").FirstOrDefault();
        if (rights?.Element(T + "Read")?.Value is not ("true" or "1")) throw new EwsResponseException("ErrorAccessDenied");
    }
}
