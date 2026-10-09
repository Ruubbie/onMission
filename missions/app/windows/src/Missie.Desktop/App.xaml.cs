using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using Missie.Core;
using Missie.Desktop.Controls;
using Missie.Desktop.Services;

namespace Missie.Desktop;

public partial class App : Application
{
    private MissionStore? _store;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        DispatcherUnhandledException += OnDispatcherUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += (_, args) => AppLog.Write("Fatal unhandled exception", args.ExceptionObject as Exception);
        TaskScheduler.UnobservedTaskException += (_, args) => { AppLog.Write("Unobserved task exception", args.Exception); args.SetObserved(); };

        try
        {
            Directory.CreateDirectory(AppServices.DataDir);
            _store = new MissionStore(AppServices.DataDir, new WindowsSecretStore());
            AppServices.Store = _store;
            try { _store.SeedIfEmpty(); }
            catch (Exception ex) { AppLog.Write("Seeding failed", ex); }
        }
        catch (Exception ex)
        {
            AppLog.Write("Could not open the local data store", ex);
            MessageBox.Show($"Missie could not open its data in\n{AppServices.DataDir}\n\n{ex.Message}\n\nDetails are in log.txt in that folder.",
                "Missie", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
            return;
        }

        AppLog.Write($"Started Missie {AppServices.Version}");
        AppServices.Sync = new SyncCoordinator(_store);
        var window = new MainWindow();
        MainWindow = window;
        window.Show();
        AppServices.Sync.Start();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        try { _store?.Dispose(); } catch (Exception ex) { AppLog.Write("Store dispose failed", ex); }
        base.OnExit(e);
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        AppLog.Write("Unhandled UI exception", e.Exception);
        e.Handled = true;
        try
        {
            var msg = e.Exception is ApiException api ? api.Message : e.Exception.GetBaseException().Message;
            BrutalDialog.Alert("Oops, that didn't work",
                $"{msg}\n\nYour data is safe. The details were written to {AppLog.PathOnDisk}.");
        }
        catch
        {
            MessageBox.Show(e.Exception.Message, "Missie", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }
}
