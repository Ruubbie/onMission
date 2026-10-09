using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Missie.Desktop.Controls;

/// <summary>The folder-tab card from the design: coloured tab, coloured icon square, grey count text, bold title.
/// It is a Button, so use Command/CommandParameter or Click. Style="{StaticResource FolderRow}" gives a compact list row.</summary>
public class FolderCard : Button
{
    static FolderCard() =>
        DefaultStyleKeyProperty.OverrideMetadata(typeof(FolderCard), new FrameworkPropertyMetadata(typeof(FolderCard)));

    public static readonly DependencyProperty TitleProperty = DependencyProperty.Register(nameof(Title), typeof(string), typeof(FolderCard));
    public string? Title { get => (string?)GetValue(TitleProperty); set => SetValue(TitleProperty, value); }

    /// <summary>Grey count text, e.g. "4 open · 12 total".</summary>
    public static readonly DependencyProperty SubtitleProperty = DependencyProperty.Register(nameof(Subtitle), typeof(string), typeof(FolderCard));
    public string? Subtitle { get => (string?)GetValue(SubtitleProperty); set => SetValue(SubtitleProperty, value); }

    /// <summary>Optional second grey line.</summary>
    public static readonly DependencyProperty DetailProperty = DependencyProperty.Register(nameof(Detail), typeof(string), typeof(FolderCard));
    public string? Detail { get => (string?)GetValue(DetailProperty); set => SetValue(DetailProperty, value); }

    public static readonly DependencyProperty GlyphProperty = DependencyProperty.Register(nameof(Glyph), typeof(string), typeof(FolderCard));
    public string? Glyph { get => (string?)GetValue(GlyphProperty); set => SetValue(GlyphProperty, value); }

    public static readonly DependencyProperty AccentProperty = DependencyProperty.Register(nameof(Accent), typeof(Brush), typeof(FolderCard));
    public Brush? Accent { get => (Brush?)GetValue(AccentProperty); set => SetValue(AccentProperty, value); }

    /// <summary>Small pink badge like "NEW" or "3 late".</summary>
    public static readonly DependencyProperty BadgeProperty = DependencyProperty.Register(nameof(Badge), typeof(string), typeof(FolderCard),
        new FrameworkPropertyMetadata(null, (d, e) => d.SetValue(HasBadgePropertyKey, !string.IsNullOrEmpty(e.NewValue as string))));
    public string? Badge { get => (string?)GetValue(BadgeProperty); set => SetValue(BadgeProperty, value); }

    private static readonly DependencyPropertyKey HasBadgePropertyKey = DependencyProperty.RegisterReadOnly(
        nameof(HasBadge), typeof(bool), typeof(FolderCard), new FrameworkPropertyMetadata(false));
    public static readonly DependencyProperty HasBadgeProperty = HasBadgePropertyKey.DependencyProperty;
    public bool HasBadge => (bool)GetValue(HasBadgeProperty);

    public static readonly DependencyProperty IsSelectedProperty = DependencyProperty.Register(nameof(IsSelected), typeof(bool), typeof(FolderCard));
    public bool IsSelected { get => (bool)GetValue(IsSelectedProperty); set => SetValue(IsSelectedProperty, value); }

    /// <summary>0..1 shows a thin progress bar; null hides it.</summary>
    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(nameof(Progress), typeof(double?), typeof(FolderCard));
    public double? Progress { get => (double?)GetValue(ProgressProperty); set => SetValue(ProgressProperty, value); }
}
