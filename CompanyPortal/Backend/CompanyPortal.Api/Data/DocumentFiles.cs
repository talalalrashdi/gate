namespace CompanyPortal.Api.Data;

public sealed class DocumentFiles(FolderPathsStore folders)
{
    // DocumentPath is a filename only. FolderPath is the logical hierarchy from the SP.
    private static bool SafeSegment(string value)=>!string.IsNullOrWhiteSpace(value)&&value is not ("." or "..")
        &&!value.EndsWith('.')&&!value.EndsWith(' ')&&!value.Any(c=>c<32||"<>:\"/\\|?*".Contains(c));

    private static string? RelativePath(DocumentsStore.Row row)
    {
        if(!SafeSegment(row.DocumentPath)||string.IsNullOrWhiteSpace(row.FolderPath))return null;
        var segments=row.FolderPath.Split('\\').Select(segment=>segment.Trim()).ToArray();
        return segments.Any(segment=>!SafeSegment(segment))?null:Path.Combine(segments.Append(row.DocumentPath).ToArray());
    }
    // Administration only: candidates under the same configured roots used by the protected reader.
    public static string[] SourcePaths(DocumentsStore.Row row,IReadOnlyList<string> roots)
    {
        var relative=RelativePath(row);
        return relative is null?[]:roots.Select(root=>Path.GetFullPath(Path.Combine(root,relative))).ToArray();
    }
    public async Task<FileStream?> OpenAsync(DocumentsStore.Row row,bool pdf,CancellationToken token)
    {
        var relative=RelativePath(row);if(relative is null)return null;
        var roots=await folders.GetAsync("docs",token);
        foreach(var root in roots)
        {
            var fullPath=Path.GetFullPath(Path.Combine(root,relative));
            var comparison=OperatingSystem.IsWindows()?StringComparison.OrdinalIgnoreCase:StringComparison.Ordinal;
            if(!fullPath.StartsWith(Path.TrimEndingDirectorySeparator(Path.GetFullPath(root))+Path.DirectorySeparatorChar,comparison))continue;
            if(OperatingSystem.IsWindows()&&(fullPath.StartsWith(@"\\?\",StringComparison.Ordinal)
                ||fullPath.StartsWith(@"\\.\",StringComparison.Ordinal)||fullPath[Path.GetPathRoot(fullPath)!.Length..].Contains(':')))continue;
            try
            {
                var reparse=false;
                for(string? node=fullPath;node is not null;node=Path.GetDirectoryName(node))
                    if((File.GetAttributes(node)&FileAttributes.ReparsePoint)!=0){reparse=true;break;}
                if(reparse)continue;
                var stream=new FileStream(fullPath,FileMode.Open,FileAccess.Read,FileShare.Read,4096,FileOptions.Asynchronous|FileOptions.RandomAccess);
                try
                {
                    if(pdf)
                    {
                        var header=new byte[5];
                        var count=await stream.ReadAtLeastAsync(header,5,throwOnEndOfStream:false,cancellationToken:token);
                        if(count!=5||!header.AsSpan().SequenceEqual("%PDF-"u8)){await stream.DisposeAsync();continue;}
                        stream.Position=0;
                    }
                    return stream;
                }
                catch{await stream.DisposeAsync();throw;}
            }
            catch(FileNotFoundException){}
            catch(DirectoryNotFoundException){}
        }
        return null;
    }
}
