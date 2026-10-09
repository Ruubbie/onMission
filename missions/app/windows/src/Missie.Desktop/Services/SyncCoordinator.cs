using System.Windows;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Missie.Core;
using Missie.Desktop.Theme;

namespace Missie.Desktop.Services;

/// <summary>Runs sync in the background (on start, every 5 minutes, on window activate) and exposes the
/// state for the sync pill. Never blocks the UI.</summary>
public sealed partial class SyncCoordinator : ObservableObject
{
    private readonly IMissionStore _store;
    private readonly DispatcherTimer _timer;
    private readonly DispatcherTimer _ticker;
    private DateTimeOffset _lastAttempt = DateTimeOffset.MinValue;
    private bool _running;

    [ObservableProperty] private string _stateText = "Not set up";
    [ObservableProperty] private string _detailText = "";
    [ObservableProperty] private System.Windows.Media.Brush _dot = Look.Grey;
    [ObservableProperty] private bool _isSyncing;
    [ObservableProperty] private string? _lastError;
    [ObservableProperty] private string? _lastResult;

    public SyncCoordinator(IMissionStore store)
    {
        _store = store;
        _store.SyncStatusChanged += (_, _) => Application.Current?.Dispatcher.BeginInvoke(Refresh);
        _timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromMinutes(5) };
        _timer.Tick += (_, _) => _ = AutoSyncAsync();
        _ticker = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromSeconds(30) };
        _ticker.Tick += (_, _) => Refresh();
    }

    public void Start()
    {
        Refresh();
        _timer.Start();
        _ticker.Start();
        _ = AutoSyncAsync();
    }

    /// <summary>Called on window activate; throttled to once a minute.</summary>
    public void OnActivated()
    {
        if (DateTimeOffset.Now - _lastAttempt > TimeSpan.FromMinutes(1)) _ = AutoSyncAsync();
    }

    public Task AutoSyncAsync()
    {
        if (!_store.LocalSettings.AutoSync || !_store.IsLoggedIn) { Refresh(); return Task.CompletedTask; }
        return SyncNowAsync();
    }

    [RelayCommand]
    public async Task SyncNowAsync()
    {
        if (_running) return;
        if (!_store.IsLoggedIn)
        {
            Refresh();
            AppServices.Navigator.Go(Pages.Settings);
            return;
        }
        _running = true;
        IsSyncing = true;
        _lastAttempt = DateTimeOffset.Now;
        Refresh();
        try
        {
            var result = await Task.Run(() => _store.SyncAsync());
            LastError = result.Error;
            LastResult = result.Ok
                ? $"↑ {result.Pushed} ↓ {result.Pulled}" + (result.FilesUploaded + result.FilesDownloaded > 0 ? $" · files ↑ {result.FilesUploaded} ↓ {result.FilesDownloaded}" : "")
                  + (result.Rejected > 0 ? $" · {result.Rejected} rejected" : "")
                : result.Error;
            if (!result.Ok) AppLog.Write("Sync failed: " + result.Error);
        }
        catch (Exception ex)
        {
            LastError = ex.Message;
            AppLog.Write("Sync crashed", ex);
        }
        finally
        {
            _running = false;
            IsSyncing = false;
            Refresh();
        }
    }

    public void Refresh()
    {
        SyncState state;
        int pending;
        DateTimeOffset? last;
        try
        {
            state = _store.SyncState;
            pending = _store.PendingChanges;
            last = _store.LastSync;
            LastError ??= _store.LastSyncError;
        }
        catch (Exception ex)
        {
            AppLog.Write("Sync status read failed", ex);
            return;
        }

        if (_running) state = SyncState.Syncing;
        (StateText, Dot) = state switch
        {
            SyncState.NotConfigured => ("Not set up", Look.Grey),
            SyncState.Syncing => ("Syncing…", Look.Yellow),
            SyncState.Offline => ("Offline", Look.Sand),
            SyncState.Error => ("Sync error", Look.Pink),
            _ => pending > 0 ? ($"{pending} pending", Look.Yellow) : ("Synced", Look.Green),
        };
        var parts = new List<string>();
        if (state != SyncState.NotConfigured && pending > 0 && state != SyncState.Idle) parts.Add($"{pending} pending");
        if (last is not null) parts.Add(Ago(last.Value));
        DetailText = string.Join(" · ", parts);
    }

    public static string Ago(DateTimeOffset t)
    {
        var d = DateTimeOffset.Now - t;
        if (d < TimeSpan.FromMinutes(1)) return "just now";
        if (d < TimeSpan.FromHours(1)) return $"{(int)d.TotalMinutes} min ago";
        if (d < TimeSpan.FromDays(1)) return $"{(int)d.TotalHours} h ago";
        return t.LocalDateTime.ToString("d MMM HH:mm", CentsToEuroConverter.Nl);
    }
}
