using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Missie.Desktop.Controls;

/// <summary>Paper card with thick ink outline and a hard offset shadow.
/// Accent: optional colour (shown as a top strip, or as the folder tab when FolderTab=True).</summary>
public class BrutalCard : ContentControl
{
    static BrutalCard() =>
        DefaultStyleKeyProperty.OverrideMetadata(typeof(BrutalCard), new FrameworkPropertyMetadata(typeof(BrutalCard)));

    public static readonly DependencyProperty AccentProperty = DependencyProperty.Register(
        nameof(Accent), typeof(Brush), typeof(BrutalCard),
        new FrameworkPropertyMetadata(null, (d, e) => d.SetValue(HasAccentPropertyKey, e.NewValue is not null)));
    public Brush? Accent { get => (Brush?)GetValue(AccentProperty); set => SetValue(AccentProperty, value); }

    public static readonly DependencyProperty FolderTabProperty = DependencyProperty.Register(
        nameof(FolderTab), typeof(bool), typeof(BrutalCard), new FrameworkPropertyMetadata(false));
    public bool FolderTab { get => (bool)GetValue(FolderTabProperty); set => SetValue(FolderTabProperty, value); }

    private static readonly DependencyPropertyKey HasAccentPropertyKey = DependencyProperty.RegisterReadOnly(
        nameof(HasAccent), typeof(bool), typeof(BrutalCard), new FrameworkPropertyMetadata(false));
    public static readonly DependencyProperty HasAccentProperty = HasAccentPropertyKey.DependencyProperty;
    public bool HasAccent => (bool)GetValue(HasAccentProperty);
}
