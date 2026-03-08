// Refresh Windows thumbnail cache for the current folder context or globally.
// When invoked from Explorer context menu, the folder path is passed as the first argument.
// Windows does not support per-folder central cache invalidation; we clear the global cache
// and optionally remove legacy thumbs.db in the target folder.

using System.Diagnostics;
using System.IO;

string? folderPath = args.Length > 0 ? args[0].Trim('"') : null;

// Validate folder path when provided (context menu on a folder)
if (!string.IsNullOrEmpty(folderPath) && !Directory.Exists(folderPath))
{
    folderPath = null;
}

bool cleared = false;
string explorerCachePath = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
    "Microsoft",
    "Windows",
    "Explorer");

if (Directory.Exists(explorerCachePath))
{
    foreach (string pattern in new[] { "thumbcache_*.db", "iconcache_*.db" })
    {
        foreach (string file in Directory.EnumerateFiles(explorerCachePath, pattern))
        {
            try
            {
                var attrs = File.GetAttributes(file);
                if (attrs.HasFlag(FileAttributes.ReadOnly))
                {
                    File.SetAttributes(file, attrs & ~FileAttributes.ReadOnly);
                }
                File.Delete(file);
                cleared = true;
            }
            catch (IOException)
            {
                // Cache may be in use; restart Explorer and retry once below
            }
        }
    }
}

// Legacy per-folder thumbs.db (current folder only when path is provided)
if (!string.IsNullOrEmpty(folderPath))
{
    string thumbsDb = Path.Combine(folderPath, "thumbs.db");
    try
    {
        if (File.Exists(thumbsDb))
        {
            var attrs = File.GetAttributes(thumbsDb);
            if (attrs.HasFlag(FileAttributes.ReadOnly))
            {
                File.SetAttributes(thumbsDb, attrs & ~FileAttributes.ReadOnly);
            }
            File.Delete(thumbsDb);
            cleared = true;
        }
    }
    catch (IOException)
    {
        // Ignore; central cache clear is the main action
    }
}

// If we couldn't delete (files in use), restart Explorer and try again once
if (!cleared && Directory.Exists(explorerCachePath))
{
    try
    {
        foreach (Process p in Process.GetProcessesByName("explorer"))
        {
            p.Kill();
            p.WaitForExit(3000);
        }
    }
    catch
    {
        // Ignore
    }

    System.Threading.Thread.Sleep(500);

    foreach (string pattern in new[] { "thumbcache_*.db", "iconcache_*.db" })
    {
        foreach (string file in Directory.EnumerateFiles(explorerCachePath, pattern))
        {
            try
            {
                var attrs = File.GetAttributes(file);
                if (attrs.HasFlag(FileAttributes.ReadOnly))
                {
                    File.SetAttributes(file, attrs & ~FileAttributes.ReadOnly);
                }
                File.Delete(file);
                cleared = true;
            }
            catch
            {
                // Leave as-is
            }
        }
    }

    Process.Start("explorer.exe");
}
else if (cleared)
{
    // Restart Explorer so it releases cache and redraws thumbnails
    try
    {
        foreach (Process p in Process.GetProcessesByName("explorer"))
        {
            p.Kill();
            p.WaitForExit(3000);
        }
        Process.Start("explorer.exe");
    }
    catch
    {
        // Explorer will regenerate cache on next browse
    }
}
