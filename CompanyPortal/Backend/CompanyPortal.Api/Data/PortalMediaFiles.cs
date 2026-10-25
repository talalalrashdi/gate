using System.Buffers.Binary;
namespace CompanyPortal.Api.Data;

public sealed class MediaFileException(string code,int status):Exception(code)
{public string Code {get;}=code;public int Status {get;}=status;}

public sealed class PortalMediaFiles(FolderPathsStore folders)
{
 public sealed record Opened(FileStream Stream,string ContentType,string FileName);
 public async Task<Opened> OpenAsync(string path,string type,CancellationToken token)
 {
  if(string.IsNullOrWhiteSpace(path))throw new MediaFileException("INVALID_PATH",400);
  if(type is not ("image" or "video"))throw new MediaFileException("UNSUPPORTED_TYPE",400);
  IReadOnlyList<string> roots;
  try{roots=await folders.GetAsync("PortalMedia",token);}
  catch(InvalidOperationException){throw new MediaFileException("ROOT_NOT_CONFIGURED",503);}
  try
  {
   path=path.Trim();if(path.Length==0||path.Any(char.IsControl)||path.Split(['\\','/']).Any(p=>p=="..")
    ||(Path.IsPathRooted(path)&&!Path.IsPathFullyQualified(path)))throw new MediaFileException("INVALID_PATH",400);
   var comparison=OperatingSystem.IsWindows()?StringComparison.OrdinalIgnoreCase:StringComparison.Ordinal;
   var absolute=Path.IsPathFullyQualified(path);var candidates=absolute?new[]{Path.GetFullPath(path)}:roots.Select(root=>Path.GetFullPath(Path.Combine(root,path))).Distinct().ToArray();
   foreach(var full in candidates)
   {
    if(!roots.Any(root=>full.StartsWith(Path.TrimEndingDirectorySeparator(Path.GetFullPath(root))+Path.DirectorySeparatorChar,comparison)))
     throw new MediaFileException("OUTSIDE_ALLOWED_ROOT",400);
    if(OperatingSystem.IsWindows()&&(full.StartsWith(@"\\?\",StringComparison.Ordinal)||full.StartsWith(@"\\.\",StringComparison.Ordinal)||full[Path.GetPathRoot(full)!.Length..].Contains(':')))
     throw new MediaFileException("INVALID_PATH",400);
    var extension=Path.GetExtension(full).ToLowerInvariant();
    if(type=="video"?extension!=".mp4":extension is not (".png" or ".jpg" or ".jpeg" or ".gif" or ".webp"))throw new MediaFileException("UNSUPPORTED_TYPE",400);
    try
    {
     for(string? node=full;node is not null;node=Path.GetDirectoryName(node))
      if((File.GetAttributes(node)&FileAttributes.ReparsePoint)!=0)throw new MediaFileException("INVALID_PATH",400);
     var stream=new FileStream(full,FileMode.Open,FileAccess.Read,FileShare.Read,65536,FileOptions.Asynchronous|FileOptions.RandomAccess);
     try
     {
      var header=new byte[32];var count=await stream.ReadAtLeastAsync(header,header.Length,false,token);string? mime=null;
      if(type=="video"&&count>=16&&header.AsSpan(4,4).SequenceEqual("ftyp"u8)&&BinaryPrimitives.ReadUInt32BigEndian(header)>=16&&BinaryPrimitives.ReadUInt32BigEndian(header)<=stream.Length)mime="video/mp4";
      if(type=="image")
      {
       if(extension==".png"&&count>=8&&header.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10}))mime="image/png";
       if(extension is ".jpg" or ".jpeg"&&count>=3&&header[0]==255&&header[1]==216&&header[2]==255)mime="image/jpeg";
       if(extension==".gif"&&count>=6&&(header.AsSpan(0,6).SequenceEqual("GIF87a"u8)||header.AsSpan(0,6).SequenceEqual("GIF89a"u8)))mime="image/gif";
       if(extension==".webp"&&count>=12&&header.AsSpan(0,4).SequenceEqual("RIFF"u8)&&header.AsSpan(8,4).SequenceEqual("WEBP"u8))mime="image/webp";
      }
      if(mime is null)throw new MediaFileException("INVALID_FILE",400);
      stream.Position=0;return new(stream,mime,Path.GetFileName(full));
     }catch{await stream.DisposeAsync();throw;}
    }
    catch(FileNotFoundException){if(absolute)break;}
    catch(DirectoryNotFoundException){if(absolute)break;}
   }
   throw new MediaFileException("FILE_NOT_FOUND",404);
  }
  catch(UnauthorizedAccessException){throw new MediaFileException("FILE_ACCESS_DENIED",503);}
  catch(Exception e) when(e is ArgumentException or NotSupportedException){throw new MediaFileException("INVALID_PATH",400);}
 }
}
