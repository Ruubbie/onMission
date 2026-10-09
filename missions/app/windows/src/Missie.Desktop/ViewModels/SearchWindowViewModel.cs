using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows.Data;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using Missie.Desktop.Services;
using Missie.Desktop.Theme;

namespace Missie.Desktop.ViewModels;

public sealed class SearchResultItem
{
    public required string Id { get; init; }
    public required string Collection { get; init; }
    public required string Title { get; init; }
    public string Snippet { get; init; } = "";
    public string Group => Look.CollectionLabel(Collection);
    public string Glyph => Look.Glyph(Collection);
    public Brush Accent => Look.Accent(Collection);
}

public sealed partial class SearchWindowViewModel : ObservableObject
{
    public ObservableCollection<SearchResultItem> Results { get; } = [];
    public ICollectionView ResultsView { get; }

    [ObservableProperty] private string _query = "";
    [ObservableProperty] private SearchResultItem? _selected;
    [ObservableProperty] private string _hint = "Type to search everything. Enter opens, Esc closes.";

    public SearchWindowViewModel()
    {
        ResultsView = CollectionViewSource.GetDefaultView(Results);
        ResultsView.GroupDescriptions.Add(new PropertyGroupDescription(nameof(SearchResultItem.Group)));
    }

    partial void OnQueryChanged(string value) => Run(value);

    private void Run(string q)
    {
        Results.Clear();
        q = q.Trim();
        if (q.Length == 0)
        {
            Hint = "Type to search everything. Enter opens, Esc closes.";
            return;
        }
        try
        {
            // Group order = order of the first hit per collection; keep hits of one collection together.
            var hits = AppServices.Store.Search(q, 60);
            foreach (var g in hits.GroupBy(h => h.Collection))
                foreach (var h in g)
                    Results.Add(new SearchResultItem { Id = h.Id, Collection = h.Collection, Title = h.Title, Snippet = h.Snippet });
            Hint = Results.Count == 0 ? $"Nothing found for “{q}”." : $"{Results.Count} result{(Results.Count == 1 ? "" : "s")}";
        }
        catch (Exception ex)
        {
            AppLog.Write("Search failed", ex);
            Hint = "Search failed: " + ex.Message;
        }
        ResultsView.MoveCurrentToFirst();
        Selected = ResultsView.CurrentItem as SearchResultItem;
    }

    /// <summary>Moves the selection by delta in visual (grouped) order.</summary>
    public void Move(int delta)
    {
        var ordered = ResultsView.Cast<SearchResultItem>().ToList();
        if (ordered.Count == 0) return;
        var i = Selected is null ? -1 : ordered.IndexOf(Selected);
        i = Math.Clamp(i + delta, 0, ordered.Count - 1);
        Selected = ordered[i];
    }
}
