using System.Windows;
using System.Windows.Input;
using Missie.Desktop.Services;
using Missie.Desktop.ViewModels;

namespace Missie.Desktop.Views;

/// <summary>Ctrl+K quick search: type, results grouped by collection, Enter opens via Navigator.Open.</summary>
public partial class SearchWindow : Window
{
    private readonly SearchWindowViewModel _vm = new();
    private bool _closing;

    public SearchWindow(string initial = "")
    {
        InitializeComponent();
        DataContext = _vm;
        _vm.Query = initial;
        Loaded += (_, _) =>
        {
            if (Owner is not null)
            {
                Left = Owner.Left + (Owner.ActualWidth - ActualWidth) / 2;
                Top = Owner.Top + 70;
                if (Owner.WindowState == WindowState.Maximized)
                {
                    Left = (SystemParameters.WorkArea.Width - ActualWidth) / 2;
                    Top = SystemParameters.WorkArea.Top + 70;
                }
            }
            QueryBox.Focus();
            QueryBox.CaretIndex = QueryBox.Text.Length;
        };
        Deactivated += (_, _) => SafeClose();
        PreviewKeyDown += (_, e) => { if (e.Key == Key.Escape) { SafeClose(); e.Handled = true; } };
        MouseLeftButtonDown += (_, e) => { try { DragMove(); } catch { /* not a drag */ } };
    }

    private void SafeClose()
    {
        if (_closing) return;
        _closing = true;
        Dispatcher.BeginInvoke(Close);
    }

    private void OpenSelected()
    {
        var item = _vm.Selected ?? _vm.ResultsView.Cast<SearchResultItem>().FirstOrDefault();
        if (item is null) return;
        SafeClose();
        AppServices.Navigator.Open(item.Id);
    }

    private void OnQueryKeyDown(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Down: _vm.Move(1); ScrollToSelected(); e.Handled = true; break;
            case Key.Up: _vm.Move(-1); ScrollToSelected(); e.Handled = true; break;
            case Key.Enter: OpenSelected(); e.Handled = true; break;
        }
    }

    private void ScrollToSelected()
    {
        if (_vm.Selected is not null) ResultList.ScrollIntoView(_vm.Selected);
    }

    private void OnListKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) { OpenSelected(); e.Handled = true; }
    }

    private void OnResultDoubleClick(object sender, MouseButtonEventArgs e) => OpenSelected();
}
