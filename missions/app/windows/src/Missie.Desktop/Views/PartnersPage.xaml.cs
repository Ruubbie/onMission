using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Missie.Core;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class PartnersPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly PartnersViewModel _vm = new();

    public PartnersPage()
    {
        InitializeComponent();
        DataContext = _vm;
        PageHelpers.Wire(this, _vm.Attach, _vm.Detach);
    }

    public void Select(string entityId)
    {
        _vm.Attach();
        // A gift link opens its partner.
        try { if (Services.AppServices.Store.Get<Gift>(entityId) is { PartnerId: { } pid }) entityId = pid; } catch { }
        if (_vm.SelectId(entityId)) PageHelpers.ScrollTo(Grid, _vm.Selected);
    }

    public void CreateNew()
    {
        _vm.Attach();
        PageHelpers.EditCell(Grid, _vm.New(), 0);
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("partners");
    void Chip_Clicked(object? sender, FilterChip chip) => _vm.ToggleChip(chip);

    void Grid_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (PageHelpers.IsRowDeleteKey(e)) { e.Handled = true; Delete_Click(sender, e); }
    }

    void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Delete partner \"{row.Name}\"? Their gifts stay in the list."))
            _vm.Delete(row);
    }

    void Mail_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected?.Email is { Length: > 0 } mail) PageActions.Shell("mailto:" + mail);
    }

    void Contacted_Click(object sender, RoutedEventArgs e) { if (_vm.HasSelection) _vm.MarkContactedToday(); }
    void Thanked_Click(object sender, RoutedEventArgs e) { if (_vm.HasSelection) _vm.ThankedToday(); }
    void Log_Click(object sender, RoutedEventArgs e) => _vm.LogConversation();

    void AddGift_Click(object sender, RoutedEventArgs e)
    {
        if (!_vm.AddGift()) PageActions.Info("Type an amount first, like 25 or 12,50.");
    }

    void GiftAmount_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) { e.Handled = true; AddGift_Click(sender, e); }
    }

    void ThankGift_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is GiftRow g) _vm.ThankGift(g);
    }

    void DeleteGift_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is GiftRow g && PageActions.Confirm($"Delete the gift of {g.Amount} ({g.When})?"))
            _vm.DeleteGift(g);
    }
}
