using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;

namespace Missie.Desktop.Views.Shared;

public static class PageHelpers
{
    /// <summary>Subscribe to store changes only while the page is on screen.</summary>
    public static void Wire(FrameworkElement page, Action attach, Action detach)
    {
        page.Loaded += (_, _) => attach();
        page.Unloaded += (_, _) => detach();
    }

    /// <summary>Scrolls to a row and starts editing the given column (used after "+ New").</summary>
    public static void EditCell(DataGrid grid, object? item, int column = 0)
    {
        if (item is null) return;
        grid.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() =>
        {
            grid.ScrollIntoView(item);
            grid.UpdateLayout();
            grid.Focus();
            grid.SelectedItem = item;
            if (column < grid.Columns.Count)
            {
                grid.CurrentCell = new DataGridCellInfo(item, grid.Columns[column]);
                grid.BeginEdit();
            }
        }));
    }

    public static void ScrollTo(DataGrid grid, object? item)
    {
        if (item is null) return;
        grid.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() => grid.ScrollIntoView(item)));
    }

    /// <summary>True when Delete was pressed on a grid row that is not being edited.</summary>
    public static bool IsRowDeleteKey(KeyEventArgs e) =>
        e.Key == Key.Delete && e.OriginalSource is DataGridCell or DataGridRow;

    public static void FocusLater(UIElement element) =>
        element.Dispatcher.BeginInvoke(DispatcherPriority.Input, new Action(() => { element.Focus(); Keyboard.Focus(element); }));
}
