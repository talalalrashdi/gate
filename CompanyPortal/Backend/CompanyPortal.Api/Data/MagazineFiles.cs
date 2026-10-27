namespace CompanyPortal.Api.Data;
public sealed class MagazineFiles(FolderPathsStore folders,NewsFiles files)
{
 private static bool SafeName(string name)=>!string.IsNullOrWhiteSpace(name)&&name==Path.GetFileName(name)&&name.IndexOfAny(Path.GetInvalidFileNameChars())<0&&name is not ("." or "..");
 private static bool SafePdf(string name)=>SafeName(name)&&name.EndsWith(".pdf",StringComparison.OrdinalIgnoreCase)&&Path.GetFileNameWithoutExtension(name).Length>0;
 public async Task<(FileStream Stream,string ContentType)?> PdfAsync(string name,CancellationToken token)
 {
  if(!SafePdf(name))return null;
  foreach(var root in await folders.GetAsync("Magazines",token))
  {var opened=await files.OpenAsync(Path.Combine(root,name),true,token,"Magazines");if(opened is not null)return opened;}
  return null;
 }
}
