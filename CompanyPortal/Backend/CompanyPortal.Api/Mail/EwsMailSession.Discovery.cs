using System.Text;
using System.Xml.Linq;
using System.Net.Mail;
namespace CompanyPortal.Api.Mail;

public sealed record DiscoveredCalendar(string Mailbox,string Name,string FolderId);
public sealed partial class EwsMailSession
{
 private static XElement Extended(string tag)=>new(T+"ExtendedFieldURI",new XAttribute("PropertyTag",tag),new XAttribute("PropertyType","Binary"));
 private static string? BinaryProperty(XElement item,string tag)=>item.Elements(T+"ExtendedProperty").FirstOrDefault(p=>string.Equals(p.Element(T+"ExtendedFieldURI")?.Attribute("PropertyTag")?.Value,tag,StringComparison.OrdinalIgnoreCase))?.Element(T+"Value")?.Value;
 private async Task<string?> ConvertFolderId(string binary,string owner,CancellationToken token)
 {
  var bytes=Convert.FromBase64String(binary);if(bytes.Length is 0 or >8192)return null;
  var response=await CallAsync(new XElement(M+"ConvertId",new XAttribute("DestinationFormat","EwsId"),new XElement(M+"SourceIds",new XElement(T+"AlternateId",new XAttribute("Format","HexEntryId"),new XAttribute("Id",Convert.ToHexString(bytes)),new XAttribute("Mailbox",owner)))),token);
  return response.Descendants(T+"AlternateId").FirstOrDefault()?.Attribute("Id")?.Value;
 }
 // Best effort: Outlook navigation shortcuts are not an Exchange permission inventory.
 // Mailbox-wide scans and GetDelegate (which lists the wrong direction) are deliberately avoided.
 public async Task<(IReadOnlyList<DiscoveredCalendar> Calendars,string? Warning)> DiscoverCalendarsAsync(CancellationToken token)
 {
  var result=new List<DiscoveredCalendar>();const string warning="قد لا يُظهر Exchange جميع التقاويم المشتركة تلقائيًا. يمكنك فتح تقويم بإدخال بريد صاحبه.";
  try{
   var root=await CallAsync(new XElement(M+"GetFolder",new XElement(M+"FolderShape",new XElement(T+"BaseShape","IdOnly"),new XElement(T+"AdditionalProperties",Extended("0x35E6"))),new XElement(M+"FolderIds",Folder("root",mailbox))),token);
   var value=root.Descendants(T+"Folder").Select(f=>BinaryProperty(f,"0x35E6")).FirstOrDefault(v=>v is not null);if(value is null)return(result,warning);
   var common=await ConvertFolderId(value,mailbox,token);if(common is null)return(result,warning);
   var seen=new HashSet<string>(StringComparer.Ordinal);var offset=0;
   for(var page=0;page<5&&result.Count<30;page++){
    var response=await CallAsync(new XElement(M+"FindItem",new XAttribute("Traversal","Associated"),new XElement(M+"ItemShape",new XElement(T+"BaseShape","IdOnly"),new XElement(T+"AdditionalProperties",Field("item:Subject"),Extended("0x6854"),Extended("0x684C"))),new XElement(M+"IndexedPageItemView",new XAttribute("MaxEntriesReturned",100),new XAttribute("Offset",offset),new XAttribute("BasePoint","Beginning")),new XElement(M+"Restriction",new XElement(T+"IsEqualTo",Field("item:ItemClass"),new XElement(T+"FieldURIOrConstant",new XElement(T+"Constant",new XAttribute("Value","IPM.Microsoft.WunderBar.Link"))))),new XElement(M+"ParentFolderIds",new XElement(T+"FolderId",new XAttribute("Id",common)))),token);
    foreach(var item in response.Descendants(T+"Items").Elements()){
     if(result.Count>=30)break;
     try{
      var entry=BinaryProperty(item,"0x6854");var folderEntry=BinaryProperty(item,"0x684C");if(entry is null||folderEntry is null)continue;var raw=Convert.FromBase64String(entry);if(raw.Length is <29 or >8192)continue;
      var legacy=Encoding.ASCII.GetString(raw,28,raw.Length-28).Split('\0')[0];if(!legacy.StartsWith("/o=",StringComparison.OrdinalIgnoreCase)||legacy.Length>2000||!seen.Add(legacy.ToUpperInvariant()+"|"+folderEntry))continue;
      var resolved=await CallAsync(new XElement(M+"ResolveNames",new XAttribute("ReturnFullContactData",false),new XAttribute("SearchScope","ActiveDirectory"),new XElement(M+"UnresolvedEntry",legacy)),token);
      var candidate=resolved.Descendants(T+"Resolution").SingleOrDefault()?.Element(T+"Mailbox");var address=candidate?.Element(T+"EmailAddress")?.Value;
      if(!MailAddress.TryCreate(address,out var parsed)||parsed.Address!=address)continue;
      var id=await ConvertFolderId(folderEntry,address!,token);if(string.IsNullOrWhiteSpace(id)||id.Length>2048)continue;
      // Prove this shortcut really is a readable calendar as the employee.
      var rights=await CalendarAccessAsync(address!,token,id);if(rights.Read)result.Add(new(address!,candidate?.Element(T+"Name")?.Value??address!,id));
     }catch(Exception error)when(error is EwsResponseException or FormatException or InvalidOperationException){/* Stale/non-calendar shortcuts are not grants. */}
    }
    var folder=response.Descendants(M+"RootFolder").FirstOrDefault();if(folder?.Attribute("IncludesLastItemInRange")?.Value is "true" or "1")break;
    if(!int.TryParse(folder?.Attribute("IndexedPagingOffset")?.Value,out var next)||next<=offset)break;offset=next;
   }
  }catch(Exception error)when(error is EwsResponseException or FormatException or InvalidOperationException){return(result,warning);}
  return(result,warning);
 }
}
