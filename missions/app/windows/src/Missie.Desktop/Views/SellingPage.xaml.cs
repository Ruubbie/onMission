using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class SellingPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly SellingViewModel _vm = new();

    public SellingPage()
    {
        InitializeComponent();
        DataContext = _vm;
        PageHelpers.Wire(this, _vm.Attach, _vm.Detach);
    }

    public void Select(string entityId)
    {
        _vm.Attach();
        if (_vm.SelectId(entityId)) PageHelpers.ScrollTo(Grid, _vm.Selected);
    }

    public void CreateNew()
    {
        _vm.Attach();
        PageHelpers.EditCell(Grid, _vm.New(), 0);
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("selling");
    void Chip_Clicked(object? sender, FilterChip chip) => _vm.ToggleChip(chip);

    void OpenUrl_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is SellRow row) PageActions.OpenUrl(row.ListingUrl);
    }

    void Grid_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (PageHelpers.IsRowDeleteKey(e)) { e.Handled = true; Delete_Click(sender, e); }
    }

    void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Delete \"{row.Name}\" from the selling list?"))
            _vm.Delete(row);
    }
}
