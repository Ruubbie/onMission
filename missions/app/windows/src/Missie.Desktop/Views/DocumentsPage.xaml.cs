using System.IO;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class DocumentsPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly DocumentsViewModel _vm = new();

    public DocumentsPage()
    {
        InitializeComponent();
        DataContext = _vm;
        PageHelpers.Wire(this, _vm.Attach, _vm.Detach);
    }

    public void Select(string entityId)
    {
        _vm.Attach();
        if (_vm.SelectId(entityId)) Cards.ScrollIntoView(_vm.Selected);
    }

    public void CreateNew()
    {
        _vm.Attach();
        Cards.ScrollIntoView(_vm.New());
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("documents");
    void Chip_Clicked(object? sender, FilterChip chip) => _vm.ToggleChip(chip);

    // ----- Drag & drop into the vault -----
    void Page_DragOver(object sender, DragEventArgs e)
    {
        bool files = e.Data.GetDataPresent(DataFormats.FileDrop);
        e.Effects = files ? DragDropEffects.Copy : DragDropEffects.None;
        DropOverlay.Visibility = files ? Visibility.Visible : Visibility.Collapsed;
        e.Handled = true;
    }

    void Page_DragLeave(object sender, DragEventArgs e) => DropOverlay.Visibility = Visibility.Collapsed;

    void Page_Drop(object sender, DragEventArgs e)
    {
        DropOverlay.Visibility = Visibility.Collapsed;
        if (e.Data.GetData(DataFormats.FileDrop) is not string[] paths) return;
        _vm.Attach();
        AddPaths(paths.SelectMany(p => Directory.Exists(p) ? Directory.GetFiles(p) : [p]));
    }

    void AddFiles_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog { Title = "Add documents to the vault", Multiselect = true, Filter = "All files (*.*)|*.*" };
        if (dlg.ShowDialog() == true) AddPaths(dlg.FileNames);
    }

    void AddPaths(IEnumerable<string> paths)
    {
        var row = _vm.AddFiles(paths);
        if (row is not null) Cards.ScrollIntoView(row);
    }

    // ----- File actions -----
    async void Open_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is not { } row) return;
        var path = await _vm.LocalPathAsync(row);
        if (path is null) { PageActions.Info("The file isn't on this PC yet and couldn't be downloaded. Try again after a sync."); return; }
        PageActions.Shell(path);
    }

    async void ShowInFolder_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is not { } row) return;
        var path = await _vm.LocalPathAsync(row);
        if (path is null) { PageActions.Info("The file isn't on this PC yet. Try again after a sync."); return; }
        PageActions.ShowInFolder(path);
    }

    void Replace_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is not { } row) return;
        var dlg = new OpenFileDialog { Title = $"File for \"{row.Title}\"", Filter = "All files (*.*)|*.*" };
        if (dlg.ShowDialog() == true) _vm.ReplaceFile(row, dlg.FileName);
    }

    void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Delete \"{row.Title}\"? The file is removed from the vault on every device."))
            _vm.Delete(row);
    }
}
