using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class BudgetPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly BudgetViewModel _vm = new();
    bool _syncingSelection;

    public BudgetPage()
    {
        InitializeComponent();
        DataContext = _vm;
        foreach (var g in Grids) SetUp(g);
        PageHelpers.Wire(this, _vm.Attach, _vm.Detach);
        _vm.PropertyChanged += Vm_PropertyChanged;
    }

    DataGrid[] Grids => [SetupGrid, MonthlyGrid, IncomeGrid];

    void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(BudgetViewModel.GapOpen))
            GapTile.SetResourceReference(StatTile.AccentProperty, _vm.GapOpen ? "Pink" : "Green");
    }

    /// <summary>The three tables share one column layout, built here instead of three times in XAML.</summary>
    void SetUp(DataGrid g)
    {
        g.AutoGenerateColumns = false;
        g.CanUserAddRows = false;
        g.CanUserDeleteRows = false;
        g.SelectionMode = DataGridSelectionMode.Single;
        g.HeadersVisibility = DataGridHeadersVisibility.Column;
        g.SelectionChanged += Grid_SelectionChanged;
        g.PreviewKeyDown += Grid_PreviewKeyDown;

        g.Columns.Add(Text("Label", nameof(BudgetRow.Label), 200));
        g.Columns.Add(Text("Category", nameof(BudgetRow.Category), 110));
        g.Columns.Add(Text("Amount", nameof(BudgetRow.AmountText), 90));
        g.Columns.Add(Combo("Cur.", nameof(BudgetRow.Currency), Lists.Currencies, 65));
        g.Columns.Add(Combo("Repeats", nameof(BudgetRow.Recurrence), Lists.Recurrences, 85));
        g.Columns.Add(Combo("Phase", nameof(BudgetRow.Phase), Lists.BudgetPhases, 85));
        g.Columns.Add(Combo("Kind", nameof(BudgetRow.Kind), Lists.BudgetKinds, 85));
        g.Columns.Add(Text("Date", nameof(BudgetRow.DateText), 95));
        g.Columns.Add(Check("Paid", nameof(BudgetRow.Paid)));
        g.Columns.Add(new DataGridTextColumn
        {
            Header = "Notes", Binding = new Binding(nameof(BudgetRow.Notes)), Width = new DataGridLength(1, DataGridLengthUnitType.Star), MinWidth = 120,
        });
    }

    static DataGridTextColumn Text(string header, string path, double width) =>
        new() { Header = header, Binding = new Binding(path), Width = width };

    static DataGridComboBoxColumn Combo(string header, string path, string[] items, double width) =>
        new() { Header = header, SelectedItemBinding = new Binding(path), ItemsSource = items, Width = width };

    static DataGridTemplateColumn Check(string header, string path)
    {
        var f = new FrameworkElementFactory(typeof(CheckBox));
        f.SetBinding(ToggleButton_IsChecked, new Binding(path) { UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged });
        f.SetValue(HorizontalAlignmentProperty, HorizontalAlignment.Center);
        return new DataGridTemplateColumn { Header = header, Width = 55, SortMemberPath = path, CellTemplate = new DataTemplate { VisualTree = f } };
    }

    static readonly DependencyProperty ToggleButton_IsChecked = System.Windows.Controls.Primitives.ToggleButton.IsCheckedProperty;

    void Grid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_syncingSelection) return;
        var grid = (DataGrid)sender;
        if (grid.SelectedItem is not BudgetRow row) return;
        _syncingSelection = true;
        foreach (var g in Grids) if (g != grid) g.SelectedItem = null;
        _syncingSelection = false;
        _vm.Selected = row;
    }

    void Grid_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (PageHelpers.IsRowDeleteKey(e)) { e.Handled = true; Delete_Click(sender, e); }
    }

    DataGrid GridFor(BudgetRow row) => row.Section switch { "monthly" => MonthlyGrid, "income" => IncomeGrid, _ => SetupGrid };

    public void Select(string entityId)
    {
        _vm.Attach();
        if (_vm.SelectId(entityId) && _vm.Selected is { } row)
        {
            var g = GridFor(row);
            g.SelectedItem = row;
            PageHelpers.ScrollTo(g, row);
        }
    }

    public void CreateNew() => AddIn("setup");

    void AddIn(string section)
    {
        _vm.Attach();
        var row = _vm.New(section);
        PageHelpers.EditCell(GridFor(row), row, 0);
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void AddIn_Click(object sender, RoutedEventArgs e) => AddIn((sender as FrameworkElement)?.Tag as string ?? "setup");
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("budget");

    void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Delete budget line \"{row.Label}\"?"))
            _vm.Delete(row);
    }
}
