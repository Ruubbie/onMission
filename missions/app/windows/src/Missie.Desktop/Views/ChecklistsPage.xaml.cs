using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Missie.Desktop.Services;
using Missie.Desktop.ViewModels;

namespace Missie.Desktop.Views;

public partial class ChecklistsPage : UserControl, ISelectsEntity, ICreatesItems
{
    private readonly ChecklistsPageViewModel _vm = new();
    private bool _dirty = true;

    public ChecklistsPage()
    {
        InitializeComponent();
        DataContext = _vm;
        _vm.RowFocusRequested += row => Dispatcher.BeginInvoke(() =>
        {
            if (TaskList.ItemContainerGenerator.ContainerFromItem(row) is FrameworkElement fe)
                fe.BringIntoView(new Rect(0, 0, fe.ActualWidth, Math.Min(fe.ActualHeight, 400)));
        }, DispatcherPriority.Loaded);
        IsVisibleChanged += (_, _) => { if (IsVisible && _dirty) Refresh(); };
        AppServices.StoreChanged += (_, collection) =>
        {
            if (collection is not (null or Missie.Core.Collections.Tasks or Missie.Core.Collections.Checklists)) return;
            _dirty = true;
            // Don't rebuild under the user's cursor while they're typing in a row.
            if (IsVisible && !IsKeyboardFocusWithin) Dispatcher.BeginInvoke(Refresh, DispatcherPriority.Background);
        };
        LostKeyboardFocus += (_, _) => { if (_dirty && IsVisible && !IsKeyboardFocusWithin) Dispatcher.BeginInvoke(Refresh, DispatcherPriority.Background); };
    }

    private void Refresh()
    {
        if (!_dirty) return;
        _dirty = false;
        _vm.Reload();
    }

    public void Select(string entityId)
    {
        Refresh();
        _vm.Select(entityId);
    }

    /// <summary>Ctrl+N: focus the add-task box.</summary>
    public void CreateNew()
    {
        Dispatcher.BeginInvoke(() => { NewTaskBox.Focus(); Keyboard.Focus(NewTaskBox); }, DispatcherPriority.Input);
    }
}
