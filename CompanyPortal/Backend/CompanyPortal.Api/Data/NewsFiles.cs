namespace CompanyPortal.Api.Data;

// File roots must be trusted, read-only for portal employees, and readable by the API identity.
public sealed class NewsFiles(IConfiguration configuration, IHostEnvironment environment)
{
    public async Task<(FileStream Stream, string ContentType)?> OpenAsync(string path, bool pdf, CancellationToken token)
    {
        var roots = configuration.GetSection("News:AllowedRoots").Get<string[]>() ?? [];
        if (roots.Length == 0) throw new InvalidOperationException("Configure News:AllowedRoots before serving news files.");
        if (!Path.IsPathFullyQualified(path)) return null;
        var fullPath = Path.GetFullPath(path);
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        if (!roots.Any(root => !string.IsNullOrWhiteSpace(root)
            && fullPath.StartsWith(Path.TrimEndingDirectorySeparator(Path.GetFullPath(root, environment.ContentRootPath)) + Path.DirectorySeparatorChar, comparison))) return null;
        // Reject alternate data streams, device paths and reparse points (including parent directories).
        if (OperatingSystem.IsWindows() && (fullPath.StartsWith(@"\\?\", StringComparison.Ordinal)
            || fullPath.StartsWith(@"\\.\", StringComparison.Ordinal)
            || fullPath[Path.GetPathRoot(fullPath)!.Length..].Contains(':'))) return null;
        var extension = Path.GetExtension(fullPath).ToLowerInvariant();
        if (pdf ? extension != ".pdf" : extension is not (".png" or ".jpg" or ".jpeg" or ".gif" or ".webp")) return null;
        try
        {
            for (string? node = fullPath; node is not null; node = Path.GetDirectoryName(node))
                if ((File.GetAttributes(node) & FileAttributes.ReparsePoint) != 0) return null;
            var stream = new FileStream(fullPath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.Asynchronous | FileOptions.RandomAccess);
            try
            {
                var header = new byte[12];
                var count = await stream.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken: token);
                string? type = null;
                if (pdf && count >= 5 && header.AsSpan(0,5).SequenceEqual("%PDF-"u8)) type = "application/pdf";
                if (!pdf && extension == ".png" && count >= 8 && header.AsSpan(0,8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10})) type = "image/png";
                if (!pdf && extension is ".jpg" or ".jpeg" && count >= 3 && header[0] == 255 && header[1] == 216 && header[2] == 255) type = "image/jpeg";
                if (!pdf && extension == ".gif" && count >= 6 && (header.AsSpan(0,6).SequenceEqual("GIF87a"u8) || header.AsSpan(0,6).SequenceEqual("GIF89a"u8))) type = "image/gif";
                if (!pdf && extension == ".webp" && count >= 12 && header.AsSpan(0,4).SequenceEqual("RIFF"u8) && header.AsSpan(8,4).SequenceEqual("WEBP"u8)) type = "image/webp";
                if (type is null) { await stream.DisposeAsync(); return null; }
                stream.Position = 0;
                return (stream, type);
            }
            catch { await stream.DisposeAsync(); throw; }
        }
        catch (FileNotFoundException) { return null; }
        catch (DirectoryNotFoundException) { return null; }
    }
}
