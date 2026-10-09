using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Missie.Core;
using Missie.Desktop.Controls;
using Missie.Desktop.Services;
using Missie.Desktop.Views;

namespace Missie.Desktop;

public partial class MainWindow : Window, INavigator
{
    /// <summary>Sidebar order; Ctrl+1..9 and Ctrl+0 follow it.</summary>
    private static readonly string[] NavOrder =
        [Pages.Home, Pages.Checklists, Pages.Partners, Pages.Budget, Pages.Selling, Pages.Packing, Pages.Documents, Pages.Notes, Pages.Newsletter, Pages.Contacts];

    /// <summary>Page key → class name for pages built by reflection (other worker's files).</summary>
    private static readonly Dictionary<string, string> ReflectedPages = new()
    {
        [Pages.Partners] = "Partners", [Pages.Budget] = "Budget", [Pages.Selling] = "Selling", [Pages.Packing] = "Packing",
        [Pages.Documents] = "Documents", [Pages.Notes] = "Notes", [Pages.Newsletter] = "Newsletter", [Pages.Contacts] = "Contacts",
    };

    private readonly Dictionary<string, (object Page, FrameworkElement Host)> _pages = new();
    private string? _current;
    private bool _syncingNav;

    public SyncCoordinator Sync => AppServices.Sync;

    public MainWindow()
    {
        AppServices.Navigator = this;
        InitializeComponent();
        VersionText.Text = $"v{AppServices.Version} · %LOCALAPPDATA%\\Missie";
        WindowPlacement.Restore(this);
        PreviewKeyDown += OnPreviewKeyDown;
        Activated += (_, _) => AppServices.Sync?.OnActivated();
        Closing += (_, _) => WindowPlacement.Save(this, _current);
        Loaded += (_, _) => Go(Pages.Home);
        UpdateTagline();
        AppServices.StoreChanged += (_, c) => { if (c is null or Collections.Settings) UpdateTagline(); };
    }

    private void UpdateTagline()
    {
        try
        {
            var dep = AppServices.Store.SharedSettings.DepartureDate;
            TaglineText.Text = dep is { } d ? $"Queenstown · {d.ToString("d MMM yyyy", Theme.CentsToEuroConverter.Nl)}" : "Queenstown";
        }
        catch (Exception ex) { AppLog.Write("Tagline failed", ex); }
    }

    // ===== INavigator =====

    public void Go(string pageKey)
    {
        var entry = GetOrCreate(pageKey);
        _current = pageKey;
        if (!ReferenceEquals(PageHost.Content, entry.Host)) PageHost.Content = entry.Host;
        SelectNav(pageKey);
    }

    public void Open(string entityId)
    {
        Entity? e;
        try { e = AppServices.Store.Get(entityId); }
        catch (Exception ex) { AppLog.Write("Open failed", ex); return; }
        if (e is null)
        {
            BrutalDialog.Alert("Not found", "That item no longer exists (it may have been deleted on another device).");
            return;
        }

        var selectId = e.Id;
        string key;
        switch (e)
        {
            case Gift g:
                key = Pages.Partners;
                if (g.PartnerId is not null) selectId = g.PartnerId;
                break;
            default:
                key = e.Collection switch
                {
                    Collections.Tasks or Collections.Checklists => Pages.Checklists,
                    Collections.Partners or Collections.Gifts => Pages.Partners,
                    Collections.Budget => Pages.Budget,
                    Collections.SellItems => Pages.Selling,
                    Collections.Packing => Pages.Packing,
                    Collections.Notes => Pages.Notes,
                    Collections.Newsletters => Pages.Newsletter,
                    Collections.Documents => Pages.Documents,
                    Collections.Contacts => Pages.Contacts,
                    _ => Pages.Settings,
                };
                break;
        }

        Go(key);
        if (_pages.TryGetValue(key, out var entry) && entry.Page is ISelectsEntity sel)
        {
            // Let the page finish loading first.
            Dispatcher.BeginInvoke(() =>
            {
                try { sel.Select(selectId); }
                catch (Exception ex) { AppLog.Write($"Select {selectId} on {key} failed", ex); }
            }, System.Windows.Threading.DispatcherPriority.Loaded);
        }
    }

    private (object Page, FrameworkElement Host) GetOrCreate(string key)
    {
        if (_pages.TryGetValue(key, out var existing)) return existing;
        object page;
        try
        {
            page = key switch
            {
                Pages.Home => new HomePage(),
                Pages.Checklists => new ChecklistsPage(),
                Pages.Settings => new SettingsPage(),
                _ => CreateByReflection(key) ?? ComingSoon(key),
            };
        }
        catch (Exception ex)
        {
            AppLog.Write($"Creating page '{key}' failed", ex);
            page = Problem(key, ex);
        }

        FrameworkElement host = page switch
        {
            Page p => new Frame { Content = p, NavigationUIVisibility = System.Windows.Navigation.NavigationUIVisibility.Hidden, Focusable = false },
            FrameworkElement fe => fe,
            _ => new ContentControl { Content = page },
        };
        var entry = (page, host);
        _pages[key] = entry;
        return entry;
    }

    private static object? CreateByReflection(string key)
    {
        if (!ReflectedPages.TryGetValue(key, out var name)) return null;
        var type = typeof(MainWindow).Assembly.GetType($"Missie.Desktop.Views.{name}Page");
        if (type is null || type.GetConstructor(Type.EmptyTypes) is null) return null;
        return Activator.CreateInstance(type);
    }

    private static FrameworkElement ComingSoon(string key) =>
        Placeholder(char.ToUpperInvariant(key[0]) + key[1..], "This page is coming soon.");

    private static FrameworkElement Problem(string key, Exception ex) =>
        Placeholder(char.ToUpperInvariant(key[0]) + key[1..], "This page could not be opened: " + ex.GetBaseException().Message);

    private static FrameworkElement Placeholder(string title, string text)
    {
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock { Text = title, Style = (Style)Application.Current.FindResource("H1") });
        stack.Children.Add(new TextBlock { Text = text, Style = (Style)Application.Current.FindResource("MutedText"), FontSize = 16, Margin = new Thickness(0, 10, 0, 0) });
        return new BrutalCard
        {
            Content = stack, Accent = Theme.Look.Sand, FolderTab = true, Padding = new Thickness(32),
            VerticalAlignment = VerticalAlignment.Top, HorizontalAlignment = HorizontalAlignment.Left, MinWidth = 520, Margin = new Thickness(0, 10, 0, 0),
        };
    }

    // ===== Sidebar =====

    private void OnNavChecked(object sender, RoutedEventArgs e)
    {
        if (_syncingNav) return;
        if (sender is RadioButton { CommandParameter: string key }) Go(key);
    }

    private void SelectNav(string key)
    {
        _syncingNav = true;
        try
        {
            foreach (var rb in NavPanel.Children.OfType<RadioButton>().Append(NavSettings))
                rb.IsChecked = (rb.CommandParameter as string) == key;
        }
        finally { _syncingNav = false; }
    }

    // ===== Top bar =====

    private void OnSearchClick(object sender, RoutedEventArgs e) => OpenSearch();

    private void OnNewClick(object sender, RoutedEventArgs e) => CreateNewOnCurrentPage();

    public void OpenSearch(string initial = "")
    {
        var w = new SearchWindow(initial) { Owner = this };
        w.Show();
    }

    private void CreateNewOnCurrentPage()
    {
        if (_current is not null && _pages.TryGetValue(_current, out var entry) && entry.Page is ICreatesItems creator)
        {
            creator.CreateNew();
            return;
        }
        // Pages without "new": add a task from Home.
        Go(Pages.Home);
        if (_pages[Pages.Home].Page is ICreatesItems home) home.CreateNew();
    }

    // ===== Keyboard =====

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (Keyboard.Modifiers == ModifierKeys.Control)
        {
            switch (e.Key)
            {
                case Key.K:
                    OpenSearch();
                    e.Handled = true;
                    return;
                case Key.N:
                    CreateNewOnCurrentPage();
                    e.Handled = true;
                    return;
                case Key.OemComma:
                    Go(Pages.Settings);
                    e.Handled = true;
                    return;
            }
            var index = e.Key switch
            {
                >= Key.D1 and <= Key.D9 => e.Key - Key.D1,
                >= Key.NumPad1 and <= Key.NumPad9 => e.Key - Key.NumPad1,
                Key.D0 or Key.NumPad0 => 9,
                _ => -1,
            };
            if (index >= 0 && index < NavOrder.Length)
            {
                Go(NavOrder[index]);
                e.Handled = true;
            }
        }
        else if (e.Key == Key.F5 && Keyboard.Modifiers == ModifierKeys.None)
        {
            _ = AppServices.Sync.SyncNowAsync();
            e.Handled = true;
        }
    }
}
