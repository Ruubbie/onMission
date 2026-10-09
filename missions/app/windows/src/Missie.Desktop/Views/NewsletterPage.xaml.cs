using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Navigation;
using System.Windows.Threading;
using Missie.Desktop.ViewModels;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.Views;

public partial class NewsletterPage : UserControl, ISelectsEntity, ICreatesItems
{
    readonly NewsletterViewModel _vm = new();
    readonly DispatcherTimer _previewTimer = new() { Interval = TimeSpan.FromMilliseconds(450) };
    NewsletterRow? _watched;

    public NewsletterPage()
    {
        InitializeComponent();
        DataContext = _vm;
        PageHelpers.Wire(this, () => { _vm.Attach(); QueuePreview(); }, _vm.Detach);
        _previewTimer.Tick += (_, _) => { _previewTimer.Stop(); RenderPreview(); };
        _vm.PropertyChanged += Vm_PropertyChanged;
    }

    void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(NewsletterViewModel.Selected)) return;
        if (_watched is not null) _watched.PropertyChanged -= Row_PropertyChanged;
        _watched = _vm.Selected;
        if (_watched is not null) _watched.PropertyChanged += Row_PropertyChanged;
        QueuePreview();
    }

    void Row_PropertyChanged(object? sender, PropertyChangedEventArgs e) => QueuePreview();

    void QueuePreview()
    {
        _previewTimer.Stop();
        _previewTimer.Start();
    }

    void RenderPreview()
    {
        try
        {
            Browser.NavigateToString(_vm.Selected is { } row
                ? NewsletterExport.Preview(row.Model)
                : "<html><body style=\"font-family:Segoe UI;color:#6E6A60;padding:24px\">The preview shows here.</body></html>");
        }
        catch { /* the browser control can fail while the page is unloading */ }
    }

    /// <summary>Links in the preview open in the normal browser.</summary>
    void Browser_Navigating(object sender, NavigatingCancelEventArgs e)
    {
        if (e.Uri is null || e.Uri.Scheme == "about") return;
        e.Cancel = true;
        PageActions.OpenUrl(e.Uri.ToString());
    }

    public void Select(string entityId)
    {
        _vm.Attach();
        if (_vm.SelectId(entityId)) List.ScrollIntoView(_vm.Selected);
    }

    public void CreateNew()
    {
        _vm.Attach();
        List.ScrollIntoView(_vm.New());
    }

    void New_Click(object sender, RoutedEventArgs e) => CreateNew();
    void Import_Click(object sender, RoutedEventArgs e) => _vm.ImportCsv();
    void Export_Click(object sender, RoutedEventArgs e) => _vm.ExportCsv("newsletters");
    void CopyRecipients_Click(object sender, RoutedEventArgs e) => _vm.CopyRecipients();
    void ExportWeb_Click(object sender, RoutedEventArgs e) => _vm.Export(email: false);
    void ExportEmail_Click(object sender, RoutedEventArgs e) => _vm.Export(email: true);

    void MarkSent_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Mark #{row.Model.Number} \"{row.Title}\" as sent?", "Mark sent", "Mark sent"))
            row.MarkSent();
    }

    void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_vm.Selected is { } row && PageActions.Confirm($"Delete newsletter \"{row.Title}\"?"))
            _vm.Delete(row);
    }
}
