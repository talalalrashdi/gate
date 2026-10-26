using System.Text.Json;
namespace CompanyPortal.Api.Data;
public sealed class MagazineFiles(FolderPathsStore folders,NewsFiles files)
{
 public sealed record Page(string File,double Width,double Height);
 private sealed record Document(Page[] Pages);
 public sealed record Manifest(string Directory,Page[] Pages);
 private static bool SafeName(string name)=>!string.IsNullOrWhiteSpace(name)&&name==Path.GetFileName(name)&&name.IndexOfAny(Path.GetInvalidFileNameChars())<0&&name is not ("." or "..");
 private static bool SafePdf(string name)=>SafeName(name)&&name.EndsWith(".pdf",StringComparison.OrdinalIgnoreCase)&&Path.GetFileNameWithoutExtension(name).Length>0;
 public async Task<(FileStream Stream,string ContentType)?> PdfAsync(string name,CancellationToken token)
 {
  if(!SafePdf(name))return null;
  foreach(var root in await folders.GetAsync("Magazines",token))
  {var opened=await files.OpenAsync(Path.Combine(root,name),true,token,"Magazines");if(opened is not null)return opened;}
  return null;
 }
 public async Task<Manifest?> PagesAsync(string name,CancellationToken token)
 {
  if(!SafePdf(name))return null;
  foreach(var root in await folders.GetAsync("Magazines",token))
  {
   var directory=Path.Combine(root,Path.GetFileNameWithoutExtension(name)+"-pages");var path=Path.Combine(directory,"manifest.json");
   try
   {
    for(string? node=path;node is not null;node=Path.GetDirectoryName(node))if((File.GetAttributes(node)&FileAttributes.ReparsePoint)!=0)return null;
    await using var stream=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read,4096,FileOptions.Asynchronous);
    if(stream.Length>262144)throw new InvalidDataException("Magazine manifest too large.");
    var document=await JsonSerializer.DeserializeAsync<Document>(stream,new JsonSerializerOptions{PropertyNameCaseInsensitive=true,MaxDepth=8},token);
    if(document?.Pages is not {Length:>0 and <=2000} pages||pages.Any(p=>p is null||!SafeName(p.File)||!double.IsFinite(p.Width)||!double.IsFinite(p.Height)||p.Width<=0||p.Height<=0||p.Width>20000||p.Height>20000||Path.GetExtension(p.File).ToLowerInvariant() is not (".webp" or ".jpg" or ".jpeg" or ".png")))throw new InvalidDataException("Invalid magazine manifest.");
    return new(directory,pages);
   }
   catch(FileNotFoundException){}catch(DirectoryNotFoundException){}
  }
  return null;
 }
 public Task<(FileStream Stream,string ContentType)?> PageAsync(Manifest manifest,int page,CancellationToken token)=>files.OpenAsync(Path.Combine(manifest.Directory,manifest.Pages[page-1].File),false,token,"Magazines");
}
