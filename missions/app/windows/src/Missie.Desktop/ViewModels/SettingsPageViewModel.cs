using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Windows.Controls;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using Missie.Core;
using Missie.Desktop.Controls;
using Missie.Desktop.Services;
using Missie.Desktop.Theme;

namespace Missie.Desktop.ViewModels;

public sealed partial class SettingsPageViewModel : ObservableObject
{
    private readonly IMissionStore _store = AppServices.Store;
    private bool _loading;

    public SyncCoordinator Sync => AppServices.Sync;
    public string DataDir => AppServices.DataDir;
    public string Version => $"Missie {AppServices.Version} for Windows";

    // Account
    [ObservableProperty] private string _apiUrl = "";
    [ObservableProperty] private string _email = "";
    [ObservableProperty] private string _setupSecret = "";
    [ObservableProperty] private string _name = "Ruben";
    [ObservableProperty] private bool _showSetup;
    [ObservableProperty] private bool _isLoggedIn;
    [ObservableProperty] private string _accountText = "";
    [ObservableProperty] private bool _busy;
    [ObservableProperty] private string? _accountError;

    // Device
    [ObservableProperty] private string _deviceName = "";
    [ObservableProperty] private bool _autoSync;

    // Shared
    [ObservableProperty] private DateTime? _departureDate;
    [ObservableProperty] private string _supportMinimum = "";
    [ObservableProperty] private string _supportTarget = "";
    [ObservableProperty] private string _nzdPerEur = "";
    [ObservableProperty] private string? _sharedMessage;

    public void Load()
    {
        _loading = true;
        try
        {
            var local = _store.LocalSettings;
            ApiUrl = local.ApiUrl;
            Email = local.Email ?? "";
            DeviceName = local.DeviceName;
            AutoSync = local.AutoSync;
            IsLoggedIn = _store.IsLoggedIn;
            AccountText = IsLoggedIn ? $"Logged in as {local.Email} on {local.DeviceName}" : "Not logged in. The app works offline; log in to sync with your iPhone and the server.";

            var shared = _store.SharedSettings;
            DepartureDate = shared.DepartureDate?.ToDateTime(TimeOnly.MinValue);
            SupportMinimum = shared.SupportMinimumMonthlyCents is { } m ? Money.Plain(m) : "";
            SupportTarget = shared.SupportTargetMonthlyCents is { } t ? Money.Plain(t) : "";
            NzdPerEur = shared.NzdPerEur?.ToString("0.####", CentsToEuroConverter.Nl) ?? "";
            SharedMessage = null;
        }
        catch (Exception ex)
        {
            AppLog.Write("Settings load failed", ex);
        }
        finally { _loading = false; }
    }

    private void SaveLocal(Action<LocalSettings> change)
    {
        if (_loading) return;
        var local = _store.LocalSettings;
        change(local);
        _store.SaveLocalSettings(local);
    }

    partial void OnDeviceNameChanged(string value)
    {
        if (!string.IsNullOrWhiteSpace(value)) SaveLocal(l => l.DeviceName = value.Trim());
    }

    partial void OnAutoSyncChanged(bool value)
    {
        SaveLocal(l => l.AutoSync = value);
        if (value && !_loading) _ = Sync.AutoSyncAsync();
    }

    partial void OnApiUrlChanged(string value)
    {
        if (!string.IsNullOrWhiteSpace(value)) SaveLocal(l => l.ApiUrl = value.Trim().TrimEnd('/'));
    }

    [RelayCommand]
    private async Task LoginAsync(object? passwordBox)
    {
        var password = (passwordBox as PasswordBox)?.Password ?? "";
        AccountError = null;
        if (string.IsNullOrWhiteSpace(Email) || password.Length == 0) { AccountError = "Fill in email and password."; return; }
        Busy = true;
        try
        {
            if (ShowSetup)
            {
                if (string.IsNullOrWhiteSpace(SetupSecret)) { AccountError = "The setup secret is needed for the first account."; return; }
                await _store.SetupAsync(ApiUrl.Trim().TrimEnd('/'), SetupSecret.Trim(), Email.Trim(), password, string.IsNullOrWhiteSpace(Name) ? "Ruben" : Name.Trim());
            }
            else
            {
                await _store.LoginAsync(ApiUrl.Trim().TrimEnd('/'), Email.Trim(), password);
            }
            if (passwordBox is PasswordBox pb) pb.Clear();
            SetupSecret = "";
            ShowSetup = false;
            Load();
            _ = Sync.SyncNowAsync();
        }
        catch (ApiException ex)
        {
            AccountError = ex.Message;
        }
        catch (Exception ex)
        {
            AppLog.Write("Login failed", ex);
            AccountError = "Could not reach the server: " + ex.GetBaseException().Message;
        }
        finally
        {
            Busy = false;
            Sync.Refresh();
        }
    }

    [RelayCommand]
    private async Task LogoutAsync()
    {
        if (!BrutalDialog.Confirm("Log out?", "Your data stays on this PC. Changes made while logged out are synced when you log in again.", "Log out")) return;
        Busy = true;
        try { await _store.LogoutAsync(); }
        catch (Exception ex) { AppLog.Write("Logout failed", ex); AccountError = ex.Message; }
        finally
        {
            Busy = false;
            Load();
            Sync.Refresh();
        }
    }

    [RelayCommand]
    private void ToggleSetup() => ShowSetup = !ShowSetup;

    [RelayCommand]
    private void SaveShared()
    {
        var min = Money.TryParseCents(SupportMinimum);
        var target = Money.TryParseCents(SupportTarget);
        double? rate = null;
        if (!string.IsNullOrWhiteSpace(NzdPerEur))
        {
            var t = NzdPerEur.Trim().Replace(',', '.');
            if (!double.TryParse(t, NumberStyles.Float, CultureInfo.InvariantCulture, out var r) || r <= 0)
            {
                SharedMessage = "NZD per EUR must be a number like 1,85.";
                return;
            }
            rate = r;
        }
        if ((!string.IsNullOrWhiteSpace(SupportMinimum) && min is null) || (!string.IsNullOrWhiteSpace(SupportTarget) && target is null))
        {
            SharedMessage = "Amounts must be numbers like 750 or 1.000,00.";
            return;
        }
        var s = _store.SharedSettings;
        s.DepartureDate = DepartureDate is { } d ? DateOnly.FromDateTime(d) : null;
        s.SupportMinimumMonthlyCents = min;
        s.SupportTargetMonthlyCents = target;
        s.NzdPerEur = rate;
        _store.Save(s);
        Load();
        SharedMessage = "Saved. Synced to your other devices on the next sync.";
    }

    [RelayCommand]
    private void OpenDataFolder()
    {
        Directory.CreateDirectory(DataDir);
        try { Process.Start(new ProcessStartInfo("explorer.exe", $"\"{DataDir}\"") { UseShellExecute = true }); }
        catch (Exception ex) { AppLog.Write("Open data folder failed", ex); }
    }

    [RelayCommand]
    private void ExportBackup()
    {
        var dlg = new SaveFileDialog
        {
            Title = "Export backup",
            FileName = $"missie-backup-{DateTime.Now:yyyy-MM-dd}.json",
            Filter = "JSON backup (*.json)|*.json",
            DefaultExt = ".json",
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
        };
        if (dlg.ShowDialog() != true) return;
        try
        {
            _store.ExportBackup(dlg.FileName);
            BrutalDialog.Alert("Backup saved", $"All your records were written to\n{dlg.FileName}\n\nFiles in the vault are in the data folder (vault).");
        }
        catch (Exception ex)
        {
            AppLog.Write("Export backup failed", ex);
            BrutalDialog.Alert("Backup failed", ex.Message);
        }
    }

    [RelayCommand]
    private void OpenLog()
    {
        if (!File.Exists(AppLog.PathOnDisk)) return;
        try { Process.Start(new ProcessStartInfo(AppLog.PathOnDisk) { UseShellExecute = true }); }
        catch (Exception ex) { AppLog.Write("Open log failed", ex); }
    }
}
