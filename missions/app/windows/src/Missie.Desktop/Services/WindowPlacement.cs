using System.IO;
using System.Text.Json;
using System.Windows;

namespace Missie.Desktop.Services;

/// <summary>Remembers the main window size/position in %LOCALAPPDATA%\Missie\window.json.</summary>
public static class WindowPlacement
{
    private sealed record Saved(double Left, double Top, double Width, double Height, bool Maximized, string? Page);

    private static string FilePath => Path.Combine(AppServices.DataDir, "window.json");

    public static string? Restore(Window w)
    {
        try
        {
            if (!File.Exists(FilePath)) return null;
            var s = JsonSerializer.Deserialize<Saved>(File.ReadAllText(FilePath));
            if (s is null) return null;
            w.Width = Math.Max(w.MinWidth, s.Width);
            w.Height = Math.Max(w.MinHeight, s.Height);
            // Only restore position when it is on a visible screen area.
            var vl = SystemParameters.VirtualScreenLeft;
            var vt = SystemParameters.VirtualScreenTop;
            if (s.Left >= vl - 50 && s.Top >= vt - 10 &&
                s.Left + 200 <= vl + SystemParameters.VirtualScreenWidth && s.Top + 100 <= vt + SystemParameters.VirtualScreenHeight)
            {
                w.WindowStartupLocation = WindowStartupLocation.Manual;
                w.Left = s.Left;
                w.Top = s.Top;
            }
            if (s.Maximized) w.WindowState = WindowState.Maximized;
            return s.Page;
        }
        catch (Exception ex)
        {
            AppLog.Write("Window placement unreadable", ex);
            return null;
        }
    }

    public static void Save(Window w, string? page)
    {
        try
        {
            var b = w.WindowState == WindowState.Normal ? new Rect(w.Left, w.Top, w.Width, w.Height) : w.RestoreBounds;
            var s = new Saved(b.Left, b.Top, b.Width, b.Height, w.WindowState == WindowState.Maximized, page);
            Directory.CreateDirectory(AppServices.DataDir);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(s));
        }
        catch (Exception ex)
        {
            AppLog.Write("Window placement save failed", ex);
        }
    }
}
