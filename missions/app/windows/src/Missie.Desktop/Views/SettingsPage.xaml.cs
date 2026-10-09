using System.Windows.Controls;
using Missie.Desktop.Services;
using Missie.Desktop.ViewModels;

namespace Missie.Desktop.Views;

public partial class SettingsPage : UserControl
{
    private readonly SettingsPageViewModel _vm = new();

    public SettingsPage()
    {
        InitializeComponent();
        DataContext = _vm;
        _vm.Load();
        IsVisibleChanged += (_, _) => { if (IsVisible) _vm.Load(); };
        AppServices.StoreChanged += (_, c) =>
        {
            // Pick up shared settings pulled by a sync, but never while the user is editing here.
            if (c is null or Missie.Core.Collections.Settings && IsVisible && !IsKeyboardFocusWithin) _vm.Load();
        };
    }
}
