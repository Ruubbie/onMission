using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Missie.Desktop.Services;
using Missie.Desktop.ViewModels;

namespace Missie.Desktop.Views;

public partial class HomePage : UserControl, ICreatesItems
{
    private readonly HomePageViewModel _vm = new();
    private bool _dirty = true;

    public HomePage()
    {
        InitializeComponent();
        DataContext = _vm;
        IsVisibleChanged += (_, _) => { if (IsVisible && _dirty) Refresh(); };
        AppServices.StoreChanged += (_, _) =>
        {
            _dirty = true;
            if (IsVisible) Dispatcher.BeginInvoke(Refresh, System.Windows.Threading.DispatcherPriority.Background);
        };
    }

    private void Refresh()
    {
        if (!_dirty) return;
        _dirty = false;
        _vm.Reload();
    }

    public void CreateNew()
    {
        Dispatcher.BeginInvoke(() => { QuickBox.Focus(); Keyboard.Focus(QuickBox); }, System.Windows.Threading.DispatcherPriority.Input);
    }

    private void OnSupportClick(object sender, MouseButtonEventArgs e) => AppServices.Navigator.Go(Pages.Partners);
}
