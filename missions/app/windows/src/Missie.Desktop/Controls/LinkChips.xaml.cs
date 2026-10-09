using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Missie.Core;
using Missie.Desktop.Services;
using Missie.Desktop.Theme;

namespace Missie.Desktop.Controls;

/// <summary>One chip in a LinkChips row.</summary>
public sealed class LinkChipItem
{
    public string Id { get; init; } = "";
    public string Collection { get; init; } = "";
    public string Title { get; init; } = "";
    public string Glyph => Look.Glyph(Collection);
    public Brush Accent => Look.Accent(Collection);
    public string Tooltip => $"{Look.CollectionLabel(Collection)}: {Title}";
    public bool IsAddButton { get; init; }
    /// <summary>False for backlinks shown via typed fields (can't be removed from here).</summary>
    public bool CanUnlink { get; init; } = true;
}

/// <summary>Smart links of an entity as clickable chips + a "+ Link" button.
/// Usage: &lt;c:LinkChips Entity="{Binding Model}" /&gt; (any Missie.Core.Entity). Clicking a chip opens it via INavigator.Open.</summary>
public partial class LinkChips : UserControl
{
    public static readonly DependencyProperty EntityProperty = DependencyProperty.Register(
        nameof(Entity), typeof(Entity), typeof(LinkChips), new FrameworkPropertyMetadata(null, (d, _) => ((LinkChips)d).Reload()));
    public Entity? Entity { get => (Entity?)GetValue(EntityProperty); set => SetValue(EntityProperty, value); }

    /// <summary>Hide the "+ Link" button (read-only views).</summary>
    public static readonly DependencyProperty CanAddProperty = DependencyProperty.Register(
        nameof(CanAdd), typeof(bool), typeof(LinkChips), new FrameworkPropertyMetadata(true, (d, _) => ((LinkChips)d).Reload()));
    public bool CanAdd { get => (bool)GetValue(CanAddProperty); set => SetValue(CanAddProperty, value); }

    private readonly ObservableCollection<LinkChipItem> _items = [];

    public LinkChips()
    {
        InitializeComponent();
        ChipList.ItemsSource = _items;
        Loaded += (_, _) => { AppServices.StoreChanged += OnStoreChanged; Reload(); };
        Unloaded += (_, _) => AppServices.StoreChanged -= OnStoreChanged;
    }

    private void OnStoreChanged(object? sender, string? collection) => Reload();

    private void Reload()
    {
        _items.Clear();
        var e = Entity;
        if (e is null) return;
        try
        {
            var store = AppServices.Store;
            // Use the freshest copy (links may have been added through the other side).
            var fresh = store.Get(e.Id) ?? e;
            foreach (var linked in store.Linked(fresh))
                _items.Add(new LinkChipItem { Id = linked.Id, Collection = linked.Collection, Title = linked.DisplayTitle });
        }
        catch (Exception ex)
        {
            AppLog.Write("LinkChips reload failed", ex);
        }
        if (CanAdd) _items.Add(new LinkChipItem { IsAddButton = true });
    }

    private void OnChipClick(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is LinkChipItem { IsAddButton: false } item)
            AppServices.Navigator.Open(item.Id);
    }

    private void OnUnlinkClick(object sender, RoutedEventArgs e)
    {
        e.Handled = true;
        if ((sender as FrameworkElement)?.DataContext is not LinkChipItem item || Entity is null) return;
        var store = AppServices.Store;
        // Mutate the page's own instance so a later save of it keeps the change.
        var b = store.Get(item.Id);
        if (b is null) return;
        store.Unlink(Entity, b);
        Reload();
    }

    private void OnAddClick(object sender, RoutedEventArgs e)
    {
        if (Entity is null) return;
        var hit = BrutalDialog.PickEntity($"Link “{Entity.DisplayTitle}” to…", Entity.Id);
        if (hit is null) return;
        var store = AppServices.Store;
        var b = store.Get(hit.Id);
        if (b is null) return;
        store.Link(Entity, b);
        Reload();
    }
}
