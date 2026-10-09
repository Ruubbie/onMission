using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Missie.Core;
using Missie.Desktop.Services;
using Missie.Desktop.Theme;

namespace Missie.Desktop.Controls;

/// <summary>Small borderless dialogs in the Brutal style.
/// BrutalDialog.Confirm("Delete?", "This can't be undone.", "Delete", danger: true)
/// BrutalDialog.Prompt("New checklist", "Name", "")  → string or null
/// BrutalDialog.Alert("Saved", "Backup written.")
/// BrutalDialog.PickEntity("Link to…", excludeId) → SearchHit or null</summary>
public sealed class BrutalDialog : Window
{
    private readonly StackPanel _body = new();
    private readonly StackPanel _buttons = new() { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 18, 0, 0) };

    private BrutalDialog(string title, double width = 460)
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        SizeToContent = SizeToContent.Height;
        Width = width;
        Title = title;
        FontFamily = (FontFamily)Application.Current.FindResource("BrandFont");
        var owner = Application.Current.Windows.OfType<Window>().FirstOrDefault(w => w.IsActive) ?? Application.Current.MainWindow;
        if (owner is not null && owner != this && owner.IsVisible)
        {
            Owner = owner;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
        }
        else WindowStartupLocation = WindowStartupLocation.CenterScreen;

        var head = new TextBlock { Text = title, Style = (Style)Application.Current.FindResource("H2"), Margin = new Thickness(0, 0, 0, 12) };
        var stack = new StackPanel();
        stack.Children.Add(head);
        stack.Children.Add(_body);
        stack.Children.Add(_buttons);
        Content = new BrutalCard { Content = stack, Padding = new Thickness(24), Margin = new Thickness(12), Accent = Look.Yellow, FolderTab = true };
        MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed) try { DragMove(); } catch { } };
        PreviewKeyDown += (_, e) => { if (e.Key == Key.Escape) { DialogResult = false; e.Handled = true; } };
    }

    private Button AddButton(string text, bool primary, bool danger, bool? result, bool isDefault = false, bool isCancel = false)
    {
        var b = new Button
        {
            Content = text,
            Margin = new Thickness(10, 0, 0, 0),
            MinWidth = 96,
            IsDefault = isDefault,
            IsCancel = isCancel,
            Style = (Style)Application.Current.FindResource(danger ? "DangerButton" : primary ? "PrimaryButton" : "BrutalButton"),
        };
        b.Click += (_, _) => DialogResult = result;
        _buttons.Children.Add(b);
        return b;
    }

    private static TextBlock BodyText(string text) =>
        new() { Text = text, Style = (Style)Application.Current.FindResource("Body"), Margin = new Thickness(0, 0, 0, 4) };

    public static bool Confirm(string title, string message, string okText = "OK", bool danger = false)
    {
        var d = new BrutalDialog(title);
        d._body.Children.Add(BodyText(message));
        d.AddButton("Cancel", false, false, false, isCancel: true);
        d.AddButton(okText, !danger, danger, true, isDefault: true);
        return d.ShowDialog() == true;
    }

    public static void Alert(string title, string message)
    {
        var d = new BrutalDialog(title);
        d._body.Children.Add(BodyText(message));
        d.AddButton("OK", true, false, true, isDefault: true, isCancel: true);
        d.ShowDialog();
    }

    /// <summary>Asks for one line of text. Returns null when cancelled or empty.</summary>
    public static string? Prompt(string title, string label, string initial = "", string okText = "Save")
    {
        var d = new BrutalDialog(title);
        d._body.Children.Add(new TextBlock { Text = label, Style = (Style)Application.Current.FindResource("Label") });
        var box = new TextBox { Text = initial };
        d._body.Children.Add(box);
        d.AddButton("Cancel", false, false, false, isCancel: true);
        d.AddButton(okText, true, false, true, isDefault: true);
        d.Loaded += (_, _) => { box.Focus(); box.SelectAll(); };
        return d.ShowDialog() == true && !string.IsNullOrWhiteSpace(box.Text) ? box.Text.Trim() : null;
    }

    /// <summary>Search-as-you-type picker over store.Search. Returns the chosen hit or null.</summary>
    public static SearchHit? PickEntity(string title = "Link to…", string? excludeId = null)
    {
        var d = new BrutalDialog(title, 560);
        var box = new TextBox();
        Brutal.SetPlaceholder(box, "Search tasks, partners, documents…");
        Brutal.SetGlyph(box, Look.GSearch);
        var list = new ListBox { Height = 320, Margin = new Thickness(0, 14, 0, 0) };
        list.ItemTemplate = HitTemplate();
        d._body.Children.Add(box);
        d._body.Children.Add(list);
        d.AddButton("Cancel", false, false, false, isCancel: true);
        var ok = d.AddButton("Link", true, false, true);

        void Refresh()
        {
            try
            {
                var q = box.Text.Trim();
                var hits = q.Length == 0 ? [] : AppServices.Store.Search(q, 40).Where(h => h.Id != excludeId).ToList();
                list.ItemsSource = hits;
                if (hits.Count > 0) list.SelectedIndex = 0;
            }
            catch (Exception ex) { AppLog.Write("Search failed", ex); }
        }
        box.TextChanged += (_, _) => Refresh();
        box.PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Down && list.Items.Count > 0) { list.SelectedIndex = Math.Min(list.SelectedIndex + 1, list.Items.Count - 1); e.Handled = true; }
            else if (e.Key == Key.Up && list.Items.Count > 0) { list.SelectedIndex = Math.Max(list.SelectedIndex - 1, 0); e.Handled = true; }
            else if (e.Key == Key.Enter && list.SelectedItem is not null) { d.DialogResult = true; e.Handled = true; }
        };
        list.MouseDoubleClick += (_, _) => { if (list.SelectedItem is not null) d.DialogResult = true; };
        ok.SetBinding(IsEnabledProperty, new System.Windows.Data.Binding("SelectedItem") { Source = list, Converter = new NotNullConverter() });
        d.Loaded += (_, _) => box.Focus();
        return d.ShowDialog() == true ? list.SelectedItem as SearchHit : null;
    }

    /// <summary>Row template for a SearchHit: coloured icon square + title + collection/snippet.</summary>
    internal static DataTemplate HitTemplate()
    {
        var t = new DataTemplate(typeof(SearchHit));
        var grid = new FrameworkElementFactory(typeof(DockPanel));
        var icon = new FrameworkElementFactory(typeof(Border));
        icon.SetValue(WidthProperty, 32.0);
        icon.SetValue(HeightProperty, 32.0);
        icon.SetValue(Border.CornerRadiusProperty, new CornerRadius(6));
        icon.SetValue(Border.BorderBrushProperty, Look.Ink);
        icon.SetValue(Border.BorderThicknessProperty, new Thickness(2));
        icon.SetBinding(Border.BackgroundProperty, new System.Windows.Data.Binding("Collection") { Converter = new AccentFromKeyConverter() });
        icon.SetValue(DockPanel.DockProperty, Dock.Left);
        var glyph = new FrameworkElementFactory(typeof(TextBlock));
        glyph.SetValue(TextBlock.FontFamilyProperty, Application.Current.FindResource("IconFont"));
        glyph.SetValue(TextBlock.FontSizeProperty, 14.0);
        glyph.SetValue(HorizontalAlignmentProperty, HorizontalAlignment.Center);
        glyph.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        glyph.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding("Collection") { Converter = new GlyphFromKeyConverter() });
        icon.AppendChild(glyph);
        var texts = new FrameworkElementFactory(typeof(StackPanel));
        texts.SetValue(MarginProperty, new Thickness(10, 0, 0, 0));
        texts.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        var title = new FrameworkElementFactory(typeof(TextBlock));
        title.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding("Title"));
        title.SetValue(TextBlock.FontWeightProperty, FontWeights.Bold);
        title.SetValue(TextBlock.TextTrimmingProperty, TextTrimming.CharacterEllipsis);
        var sub = new FrameworkElementFactory(typeof(TextBlock));
        sub.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding("Snippet"));
        sub.SetValue(TextBlock.ForegroundProperty, Application.Current.FindResource("Muted"));
        sub.SetValue(TextBlock.FontSizeProperty, 12.0);
        sub.SetValue(TextBlock.TextTrimmingProperty, TextTrimming.CharacterEllipsis);
        texts.AppendChild(title);
        texts.AppendChild(sub);
        grid.AppendChild(icon);
        grid.AppendChild(texts);
        t.VisualTree = grid;
        return t;
    }

    private sealed class NotNullConverter : System.Windows.Data.IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, System.Globalization.CultureInfo culture) => value is not null;
        public object ConvertBack(object? value, Type targetType, object? parameter, System.Globalization.CultureInfo culture) => System.Windows.Data.Binding.DoNothing;
    }
}
