using System.Windows;
using System.Windows.Controls;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class NotesPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly NotesViewModel _vm = new();

    public NotesPage()
    {
        InitializeComponent();
        DataContext = _vm;
        PageHelpers.Wire(this, _vm.Attach, _vm.Detach);
    }

    public void Select(string entityId)
    {
        _vm.Attach();
        if (_vm.SelectId(entityId)) List.ScrollIntoView(_vm.Selected);
    }

    public void CreateNew()
    {
        _vm.Attach();
        var row = _vm.New();
        List.ScrollIntoView(row);
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("notes");
    void Chip_Clicked(object? sender, FilterChip chip) => _vm.ToggleChip(chip);
    void Answered_Click(object sender, RoutedEventArgs e) => _vm.ToggleAnswered();

    void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Delete note \"{row.Title}\"?"))
            _vm.Delete(row);
    }
}
