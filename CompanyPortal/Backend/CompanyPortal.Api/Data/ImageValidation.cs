using System.Buffers.Binary;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;

namespace CompanyPortal.Api.Data;

public sealed record ValidatedImage(byte[] Data, string ContentType, int Width, int Height);

public static partial class ImageValidation
{
    public const int MaximumBytes = 10 * 1024 * 1024;
    public static ValidatedImage Read(byte[] data, string extension)
    {
        if (data.Length is < 12 or > MaximumBytes) throw new ArgumentException("The image must be between 12 bytes and 10 MB.");
        var span = data.AsSpan();
        string type; int width = 0, height = 0;
        switch (extension.ToLowerInvariant())
        {
            case ".svg": return Svg(data);
            case ".png" when span[..8].SequenceEqual(new byte[] { 137,80,78,71,13,10,26,10 }) && data.Length >= 33 && Encoding.ASCII.GetString(data,12,4) == "IHDR":
                type = "image/png"; width = BinaryPrimitives.ReadInt32BigEndian(span[16..]); height = BinaryPrimitives.ReadInt32BigEndian(span[20..]);
                var hasPixels = false; var hasEnd = false;
                for (var position=8; position+12<=data.Length;)
                {
                    var length=BinaryPrimitives.ReadUInt32BigEndian(span[position..]);
                    if (length > data.Length-position-12) break;
                    var name=Encoding.ASCII.GetString(data,position+4,4);
                    if(name=="IDAT" && length>0) hasPixels=true;
                    position+=12+(int)length;
                    if(name=="IEND") {hasEnd=length==0 && position==data.Length;break;}
                }
                if(!hasPixels || !hasEnd) throw new ArgumentException("The PNG container is incomplete.");
                break;
            case ".jpg" or ".jpeg" when span[0] == 255 && span[1] == 216:
                if(span[^2]!=255 || span[^1]!=217) throw new ArgumentException("The JPEG container is incomplete.");
                type = "image/jpeg";
                for (var offset = 2; offset + 8 < data.Length;)
                {
                    if (data[offset++] != 255) break;
                    while (offset < data.Length && data[offset] == 255) offset++;
                    if (offset >= data.Length) break;
                    var marker = data[offset++];
                    if (marker is 0xDA or 0xD9) break;
                    if (marker is 0x01 or >= 0xD0 and <= 0xD8) continue;
                    if (offset + 2 > data.Length) break;
                    var length = BinaryPrimitives.ReadUInt16BigEndian(span[offset..]);
                    if (length < 2 || offset + length > data.Length) break;
                    if (length >= 7 && marker is (0xC0 or 0xC1 or 0xC2)) { height = BinaryPrimitives.ReadUInt16BigEndian(span[(offset+3)..]); width = BinaryPrimitives.ReadUInt16BigEndian(span[(offset+5)..]); break; }
                    offset += length;
                }
                break;
            case ".webp" when Encoding.ASCII.GetString(data,0,4) == "RIFF" && Encoding.ASCII.GetString(data,8,4) == "WEBP" && data.Length >= 30:
                type = "image/webp";
                if(BinaryPrimitives.ReadUInt32LittleEndian(span[4..])!=data.Length-8) throw new ArgumentException("The WebP container is incomplete.");
                var chunk = Encoding.ASCII.GetString(data,12,4);
                if (chunk == "VP8X") { width = 1 + data[24] + (data[25]<<8) + (data[26]<<16); height = 1 + data[27] + (data[28]<<8) + (data[29]<<16); }
                else if (chunk == "VP8 " && data[23]==0x9d && data[24]==1 && data[25]==0x2a) { width = BinaryPrimitives.ReadUInt16LittleEndian(span[26..]) & 0x3fff; height = BinaryPrimitives.ReadUInt16LittleEndian(span[28..]) & 0x3fff; }
                else if (chunk == "VP8L" && data[20] == 0x2f) { var bits = BinaryPrimitives.ReadUInt32LittleEndian(span[21..]); width = (int)(bits & 0x3fff)+1; height = (int)((bits>>14)&0x3fff)+1; }
                break;
            default: throw new ArgumentException("Upload a JPEG, PNG, WebP or SVG image matching its file extension.");
        }
        Dimensions(width,height);
        return new(data,type,width,height);
    }
    private static void Dimensions(int width, int height)
    {
        if (width is < 1 or > 12000 || height is < 1 or > 12000 || (long)width*height > 40_000_000)
            throw new ArgumentException("Image dimensions must be at most 12000 pixels per side and 40 megapixels.");
    }
    private static ValidatedImage Svg(byte[] data)
    {
        // Only this exact bundled artwork may contain animation/embedded PNGs.
        if (BundledArtwork.IsNationalDay(data)) return new(data, "image/svg+xml", 2560, 1440);
        if (data.Length > 1024*1024) throw new ArgumentException("SVG images must be at most 1 MB.");
        try
        {
            using var input = new MemoryStream(data);
            using var reader = XmlReader.Create(input, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 1024*1024 });
            var document = XDocument.Load(reader);
            XNamespace ns = "http://www.w3.org/2000/svg";
            if (document.Root?.Name != ns+"svg") throw new ArgumentException("A valid SVG root is required.");
            var elements = new HashSet<string>("svg g defs title desc path rect circle ellipse line polyline polygon text tspan linearGradient radialGradient stop clipPath mask".Split(' '),StringComparer.Ordinal);
            var attributes = new HashSet<string>("id version width height viewBox preserveAspectRatio x y x1 y1 x2 y2 cx cy r rx ry d points fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin stroke-miterlimit stroke-dasharray stroke-dashoffset opacity transform gradientUnits gradientTransform offset stop-color stop-opacity clip-path clip-rule mask maskUnits maskContentUnits font-family font-size font-weight text-anchor dominant-baseline dx dy spreadMethod fx fy fr color".Split(' '),StringComparer.Ordinal);
            var count = 0;
            foreach (var node in document.Descendants())
            {
                if (++count > 10000 || node.Ancestors().Count() > 64 || node.Name.Namespace != ns || !elements.Contains(node.Name.LocalName))
                    throw new ArgumentException("SVG contains unsupported elements or excessive complexity.");
                foreach (var attribute in node.Attributes())
                {
                    if (attribute.IsNamespaceDeclaration) { if (attribute.Value != ns.NamespaceName) throw new ArgumentException("External SVG namespaces are not supported."); continue; }
                    if (attribute.Name.Namespace != XNamespace.None || !attributes.Contains(attribute.Name.LocalName)
                        || UnsafeValue().IsMatch(attribute.Value)) throw new ArgumentException("SVG contains unsupported attributes or external content. Export as a plain SVG without scripts or styles.");
                    if (attribute.Value.Contains("url",StringComparison.OrdinalIgnoreCase) && !LocalReference().IsMatch(attribute.Value))
                        throw new ArgumentException("SVG references must point to an ID inside the same image.");
                }
            }
            if (document.Nodes().OfType<XProcessingInstruction>().Any() || document.DescendantNodes().OfType<XProcessingInstruction>().Any())
                throw new ArgumentException("SVG processing instructions are not supported.");
            var root = document.Root;
            var viewBox = ((string?)root.Attribute("viewBox"))?.Split(new[] { ' ', ',', '\t', '\r', '\n' },StringSplitOptions.RemoveEmptyEntries);
            double Parse(string? value) => double.TryParse(value?.Replace("px","",StringComparison.Ordinal), NumberStyles.Float, CultureInfo.InvariantCulture, out var number) && double.IsFinite(number) ? number : 0;
            var w = Parse((string?)root.Attribute("width")); var h = Parse((string?)root.Attribute("height"));
            if (w<=0 && viewBox?.Length==4) w=Parse(viewBox[2]); if (h<=0 && viewBox?.Length==4) h=Parse(viewBox[3]);
            if (w > 12000 || h > 12000) throw new ArgumentException("SVG dimensions are too large.");
            var width=(int)Math.Ceiling(w); var height=(int)Math.Ceiling(h); Dimensions(width,height);
            // Serialize the parsed passive document; never store the original XML declaration/DTD.
            return new(Encoding.UTF8.GetBytes(root.ToString(SaveOptions.DisableFormatting)),"image/svg+xml",width,height);
        }
        catch (XmlException) { throw new ArgumentException("The SVG is not valid safe XML."); }
    }
    [GeneratedRegex(@"[\\\p{Cc}]|javascript|data:|https?:|//|@|expression|[<>]", RegexOptions.IgnoreCase)] private static partial Regex UnsafeValue();
    [GeneratedRegex(@"^url\(#[A-Za-z_][A-Za-z0-9_.:-]*\)$", RegexOptions.IgnoreCase)] private static partial Regex LocalReference();
}
