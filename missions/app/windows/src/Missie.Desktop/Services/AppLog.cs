using System.IO;

namespace Missie.Desktop.Services;

/// <summary>Plain text log at %LOCALAPPDATA%\Missie\log.txt (trimmed when it gets big).</summary>
public static class AppLog
{
    private static readonly object Gate = new();
    public static string PathOnDisk => System.IO.Path.Combine(AppServices.DataDir, "log.txt");

    public static void Write(string message, Exception? ex = null)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(AppServices.DataDir);
                var fi = new FileInfo(PathOnDisk);
                if (fi.Exists && fi.Length > 2_000_000)
                    File.Move(PathOnDisk, PathOnDisk + ".old", overwrite: true);
                File.AppendAllText(PathOnDisk,
                    $"{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss} {message}{(ex is null ? "" : Environment.NewLine + ex)}{Environment.NewLine}");
            }
        }
        catch
        {
            // Logging must never crash the app.
        }
    }
}
