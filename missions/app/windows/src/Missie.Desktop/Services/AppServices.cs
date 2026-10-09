using System.IO;
using System.Windows;
using Missie.Core;

namespace Missie.Desktop.Services;

/// <summary>App-wide services. Pages have parameterless constructors and use these.</summary>
public static class AppServices
{
    /// <summary>%LOCALAPPDATA%\Missie</summary>
    public static string DataDir { get; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Missie");

    private static IMissionStore? _store;
    private static INavigator? _navigator;

    public static IMissionStore Store
    {
        get => _store ?? throw new InvalidOperationException("Store not initialised yet.");
        set
        {
            if (_store is not null) _store.Changed -= OnStoreChanged;
            _store = value;
            _store.Changed += OnStoreChanged;
        }
    }

    public static INavigator Navigator
    {
        get => _navigator ?? throw new InvalidOperationException("Navigator not initialised yet.");
        set => _navigator = value;
    }

    public static SyncCoordinator Sync { get; set; } = null!;

    /// <summary>Same as Store.Changed but always raised on the UI thread (a sync can raise Store.Changed from a
    /// background thread). Pages should prefer this one. Arg = collection or null for "many".</summary>
    public static event EventHandler<string?>? StoreChanged;

    private static void OnStoreChanged(object? sender, string? collection)
    {
        var d = Application.Current?.Dispatcher;
        if (d is null) return;
        if (d.CheckAccess()) StoreChanged?.Invoke(sender, collection);
        else d.BeginInvoke(() => StoreChanged?.Invoke(sender, collection));
    }

    public static string Version =>
        typeof(AppServices).Assembly.GetName().Version?.ToString(3) ?? "0.1.0";
}
