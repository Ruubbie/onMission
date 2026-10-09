using System.Windows;

namespace Missie.Desktop.Controls;

/// <summary>Attached properties used by the Brutal theme templates.
/// TextBox: c:Brutal.Placeholder="Add a task…" shows grey hint text; c:Brutal.Glyph="&#xE721;" shows an icon on the left.</summary>
public static class Brutal
{
    public static readonly DependencyProperty PlaceholderProperty = DependencyProperty.RegisterAttached(
        "Placeholder", typeof(string), typeof(Brutal), new FrameworkPropertyMetadata(null));
    public static string? GetPlaceholder(DependencyObject o) => (string?)o.GetValue(PlaceholderProperty);
    public static void SetPlaceholder(DependencyObject o, string? v) => o.SetValue(PlaceholderProperty, v);

    public static readonly DependencyProperty GlyphProperty = DependencyProperty.RegisterAttached(
        "Glyph", typeof(string), typeof(Brutal), new FrameworkPropertyMetadata(null));
    public static string? GetGlyph(DependencyObject o) => (string?)o.GetValue(GlyphProperty);
    public static void SetGlyph(DependencyObject o, string? v) => o.SetValue(GlyphProperty, v);
}
