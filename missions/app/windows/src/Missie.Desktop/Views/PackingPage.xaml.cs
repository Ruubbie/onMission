using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class PackingPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly PackingViewModel _vm = new();

    public PackingPage()
    {
        InitializeComponent();
        DataContext = _vm;
        PageHelpers.Wire(this, _vm.Attach, _vm.Detach);
    }

    /// <summary>Smart link: make the item visible and put the cursor in its name.</summary>
    public void Select(string entityId)
    {
        _vm.Attach();
        if (!_vm.SelectId(entityId) || _vm.Selected is not { } row) return;
        _vm.Regroup();
        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, new Action(() =>
        {
            var box = FindTextBox(this, t => t.DataContext == row && t.Name == "NameBox");
            if (box is null) return;
            box.BringIntoView();
            box.Focus();
            box.SelectAll();
        }));
    }

    /// <summary>"+ New" puts the cursor in the checked bag's quick-add box.</summary>
    public void CreateNew()
    {
        _vm.Attach();
        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, new Action(() =>
        {
            var box = FindTextBox(this, t => t.Tag as string == "checked");
            if (box is null) return;
            box.BringIntoView();
            box.Focus();
        }));
    }

    static TextBox? FindTextBox(DependencyObject root, Func<TextBox, bool> match)
    {
        for (int i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is TextBox t && match(t)) return t;
            var found = FindTextBox(child, match);
            if (found is not null) return found;
        }
        return null;
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("packing");

    void Reset_Click(object sender, RoutedEventArgs e)
    {
        if (PageActions.Confirm("Untick every packed item?", "Reset packed", "Reset")) _vm.ResetPacked();
    }

    void QuickAdd_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        e.Handled = true;
        AddFrom((FrameworkElement)sender);
        ((UIElement)sender).Focus();
    }

    void QuickAdd_Click(object sender, RoutedEventArgs e) => AddFrom((FrameworkElement)sender);

    void AddFrom(FrameworkElement source)
    {
        if (source.DataContext is not BagGroup group) return;
        var name = group.QuickAdd.Trim();
        if (name.Length == 0) return;
        _vm.AddTo(group.Key, name);
        group.QuickAdd = "";
    }

    void DeleteItem_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is PackingRow row && PageActions.Confirm($"Delete \"{row.Name}\" from the packing list?"))
            _vm.Remove(row);
    }
}
