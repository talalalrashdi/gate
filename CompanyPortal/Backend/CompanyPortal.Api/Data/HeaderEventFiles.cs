using CompanyPortal.Api.Data;
namespace CompanyPortal.Api.Data;

// Administrators may publish files from these existing, trusted portal stores.
// Add an Events row in Mstr.Utls for a dedicated event-only folder.
public sealed class HeaderEventFiles(FolderPathsStore folders,NewsFiles pdfs,PortalMediaFiles media)
{
 private static readonly string[] Keys=["Events","PubsInfo","Magazines","PortalMedia","docs"];
 public sealed record Entry(string Name,string Path,int EventType);
 public async Task<PortalMediaFiles.Opened?> Open(string path,int type,CancellationToken token)
 {
  if(type is not (0 or 2)||string.IsNullOrWhiteSpace(path)||!System.IO.Path.IsPathFullyQualified(path))return null;
  foreach(var key in Keys)
  {
   try
   {
    if(type==0){var opened=await pdfs.OpenAsync(path,true,token,key);if(opened is not null)return new(opened.Value.Stream,opened.Value.ContentType,System.IO.Path.GetFileName(path));}
    else return await media.OpenAsync(path,"video",token,key);
   }
   catch(InvalidOperationException) { /* An optional folder key is not configured. */ }
   catch(MediaFileException e) when(e.Status<500||e.Code=="ROOT_NOT_CONFIGURED") { }
  }
  return null;
 }
 public const long MaxUploadBytes=100L*1024*1024;
 public sealed class FileError(string code,int status,string message):Exception(message){public string Code=>code;public int Status=>status;}
 private async Task<List<(string Key,string Path)>> Roots(CancellationToken token){var roots=new List<(string,string)>();foreach(var key in Keys){try{roots.AddRange((await folders.GetAsync(key,token)).Select(path=>(key,path)));}catch(InvalidOperationException){}}return roots;}
 public async Task<object> Options(CancellationToken token)=>new{Roots=(await Roots(token)).Select(r=>r.Path).Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),MaxUploadBytes};
 public async Task Validate(string path,int type,CancellationToken token)
 {
  if(type==1)return;
  if(type is not (0 or 2)||string.IsNullOrWhiteSpace(path)||!Path.IsPathFullyQualified(path)||path.Any(char.IsControl))throw new FileError("INVALID_PATH",400,"أدخل المسار الكامل للملف على خادم البوابة، مثل D:\\PortalFiles\\Events\\event.pdf.");
  string full;try{full=Path.GetFullPath(path);}catch(Exception e)when(e is ArgumentException or NotSupportedException){throw new FileError("INVALID_PATH",400,"صيغة مسار الملف غير صحيحة.");}
  if(!string.Equals(Path.GetExtension(full),type==0?".pdf":".mp4",StringComparison.OrdinalIgnoreCase))throw new FileError("INVALID_EXTENSION",400,type==0?"اختر ملف PDF بامتداد .pdf.":"اختر فيديو MP4 بامتداد .mp4.");
  var roots=await Roots(token);if(roots.Count==0)throw new FileError("ROOT_NOT_CONFIGURED",503,"لم تُضبط مجلدات الفعاليات. أضف مسارًا مطلقًا تحت Events في Mstr.Utls وامنح حساب API صلاحية القراءة والكتابة.");
  if(!roots.Any(r=>full.StartsWith(Path.TrimEndingDirectorySeparator(Path.GetFullPath(r.Path))+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)))throw new FileError("OUTSIDE_ALLOWED_ROOT",400,"الملف خارج المجلدات المسموحة. استخدم أحد المسارات الموضحة أسفل الحقل، أو اختر الملف من جهازك لرفعه.");
  if(full.StartsWith(@"\\?\")||full.StartsWith(@"\\.\")||full[Path.GetPathRoot(full)!.Length..].Contains(':'))throw new FileError("INVALID_PATH",400,"لا يُسمح بمسارات الأجهزة أو تدفقات الملفات البديلة.");
  try{for(string? node=full;node is not null;node=Path.GetDirectoryName(node))if((File.GetAttributes(node)&FileAttributes.ReparsePoint)!=0)throw new FileError("INVALID_PATH",400,"لا يمكن استخدام اختصار مجلد أو رابط رمزي؛ اختر الملف الأصلي.");
   var opened=await Open(full,type,token);if(opened is null)throw new FileError("INVALID_FILE",400,type==0?"الملف ليس PDF صالحًا. تغيير الامتداد وحده لا يحوّله إلى PDF.":"الملف ليس فيديو MP4 صالحًا.");await opened.Stream.DisposeAsync();
  }catch(FileNotFoundException){throw new FileError("FILE_NOT_FOUND",400,"الملف غير موجود على خادم البوابة. تحقق من الاسم والمسار، أو اختره من جهازك لرفعه.");}
   catch(DirectoryNotFoundException){throw new FileError("FILE_NOT_FOUND",400,"المجلد غير موجود على خادم البوابة. المسار المكتوب يجب أن يكون متاحًا للخادم.");}
   catch(UnauthorizedAccessException){throw new FileError("FILE_ACCESS_DENIED",503,"حساب تشغيل API لا يملك صلاحية قراءة الملف. امنحه Read على الملف والمجلد.");}
 }
 public async Task<string> Upload(IFormFile file,int type,CancellationToken token)
 {
  if(type is not (0 or 2))throw new FileError("INVALID_TYPE",400,"رفع الملفات متاح لنوع PDF أو فيديو فقط.");
  if(file.Length==0)throw new FileError("EMPTY_FILE",400,"الملف فارغ. اختر ملفًا صالحًا.");
  if(file.Length>MaxUploadBytes)throw new FileError("FILE_TOO_LARGE",413,"حجم الملف يتجاوز 100 ميجابايت.");
  var ext=type==0?".pdf":".mp4";if(!string.Equals(Path.GetExtension(file.FileName),ext,StringComparison.OrdinalIgnoreCase))throw new FileError("INVALID_EXTENSION",400,type==0?"اختر ملف PDF بامتداد .pdf.":"اختر فيديو MP4 بامتداد .mp4.");
  var roots=await Roots(token);var root=roots.FirstOrDefault(r=>r.Key=="Events");if(root==default)root=roots.FirstOrDefault(r=>r.Key=="PortalMedia");
  if(root==default)throw new FileError("UPLOAD_ROOT_NOT_CONFIGURED",503,"تعذر الرفع: أضف مجلدًا تحت Events في Mstr.Utls وامنح حساب API صلاحية القراءة والكتابة.");
  var directory=Path.Combine(root.Path,"EventUploads");var path=Path.Combine(directory,Guid.NewGuid().ToString("N")+ext);
  try{
   // Check existing ancestors before creating anything, and never follow junctions.
   for(string? node=directory;node is not null;node=Path.GetDirectoryName(node))if(Directory.Exists(node)&&(File.GetAttributes(node)&FileAttributes.ReparsePoint)!=0)throw new FileError("INVALID_PATH",400,"مجلد الرفع لا يمكن أن يكون رابطًا رمزيًا أو اختصارًا.");
   Directory.CreateDirectory(directory);
   await using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.None,65536,FileOptions.Asynchronous)){await file.CopyToAsync(stream,token);}
   await Validate(path,type,token);return path;
  }catch(UnauthorizedAccessException){TryDeleteUpload(path);throw new FileError("UPLOAD_ACCESS_DENIED",503,"تعذر حفظ الملف: حساب تشغيل API يحتاج صلاحية Modify على مجلد الرفع.");}
   catch{TryDeleteUpload(path);throw;}
 }
 public void TryDeleteUpload(string path){try{File.Delete(path);}catch(IOException){}catch(UnauthorizedAccessException){}}
 public async Task<object> List(CancellationToken token)
 {
  var entries=new List<Entry>();var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);var truncated=false;
  foreach(var key in Keys)
  {
   IReadOnlyList<string> roots;
   try{roots=await folders.GetAsync(key,token);}catch(InvalidOperationException){continue;}
   foreach(var root in roots)
   {
    token.ThrowIfCancellationRequested();
    // Never follow junctions/symlinks. Bound traversal as well as returned files.
    var pending=new Queue<(string Path,int Depth)>();pending.Enqueue((root,0));int scanned=0;
    while(pending.Count>0)
    {
     var (dir,depth)=pending.Dequeue();
     try
     {
      if((File.GetAttributes(dir)&FileAttributes.ReparsePoint)!=0)continue;
      foreach(var file in Directory.EnumerateFileSystemEntries(dir))
      {
       token.ThrowIfCancellationRequested();if(++scanned>10000||entries.Count>=1000){truncated=true;break;}
       var attr=File.GetAttributes(file);if((attr&FileAttributes.ReparsePoint)!=0)continue;
       if((attr&FileAttributes.Directory)!=0){if(depth<8)pending.Enqueue((file,depth+1));else truncated=true;continue;}
       var ext=System.IO.Path.GetExtension(file).ToLowerInvariant();if(ext is not (".pdf" or ".mp4")||!seen.Add(file))continue;
       entries.Add(new(System.IO.Path.GetFileName(file),file,ext==".pdf"?0:2));
      }
     }catch(Exception e) when(e is IOException or UnauthorizedAccessException){continue;}
     if(truncated)break;
    }
    if(entries.Count>=1000)break;
   }
  }
  return new{Files=entries.OrderBy(e=>e.Name).ToArray(),Truncated=truncated};
 }
}
