using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.Win32;
using Missie.Core;
using Missie.Desktop.Services;

namespace Missie.Desktop.Views.Shared;

/// <summary>Formatting and lenient parsing for money (cents) and dates used by the grids.</summary>
public static class Fmt
{
    public static readonly CultureInfo Nl = CultureInfo.GetCultureInfo("nl-NL");
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    /// <summary>Cents as an editable amount: "12.50" ("" for null).</summary>
    public static string Amount(long? cents) => cents is null ? "" : (cents.Value / 100m).ToString("0.00", Inv);

    /// <summary>Accepts "12", "12.5", "12,50", "€ 1.250,00", "1,250.00". Returns false when not a number.</summary>
    public static bool TryParseAmount(string? text, out long? cents)
    {
        cents = null;
        var s = (text ?? "").Replace("€", "").Replace("NZ$", "").Replace("$", "").Replace(" ", "").Replace(" ", "").Trim();
        if (s.Length == 0) return true;
        int lastDot = s.LastIndexOf('.'), lastComma = s.LastIndexOf(',');
        if (lastDot >= 0 && lastComma >= 0)
        {
            // The last separator is the decimal one.
            s = lastComma > lastDot ? s.Replace(".", "").Replace(',', '.') : s.Replace(",", "");
        }
        else if (lastComma >= 0)
        {
            // "1,250" with exactly 3 digits after a single comma is ambiguous; Dutch habit: comma = decimals.
            s = s.Replace(',', '.');
        }
        if (!decimal.TryParse(s, NumberStyles.Number, Inv, out var d)) return false;
        cents = (long)Math.Round(d * 100m, MidpointRounding.AwayFromZero);
        return true;
    }

    /// <summary>"€ 1.250" (whole) or "€ 12,50" style display.</summary>
    public static string Euro(long cents, bool whole = true) =>
        "€ " + (cents / 100m).ToString(whole ? "N0" : "N2", Nl);

    public static string Money(long cents, string currency, bool whole = true) =>
        (currency == "NZD" ? "NZ$ " : "€ ") + (cents / 100m).ToString(whole ? "N0" : "N2", Nl);

    public static string Date(DateOnly? d) => d?.ToString("yyyy-MM-dd", Inv) ?? "";
    public static string NiceDate(DateOnly? d) => d?.ToString("d MMM yyyy", Nl) ?? "";

    /// <summary>Accepts ISO dates, Dutch dates (8-10-2026, 8 okt 2026), "today"/"vandaag". Empty = null.</summary>
    public static bool TryParseDate(string? text, out DateOnly? date)
    {
        date = null;
        var s = (text ?? "").Trim();
        if (s.Length == 0) return true;
        if (s.Equals("today", StringComparison.OrdinalIgnoreCase) || s.Equals("vandaag", StringComparison.OrdinalIgnoreCase))
        { date = Today; return true; }
        if (DateOnly.TryParseExact(s, ["yyyy-MM-dd", "yyyy-M-d", "yyyy/MM/dd"], Inv, DateTimeStyles.None, out var d)) { date = d; return true; }
        if (DateOnly.TryParse(s, Nl, DateTimeStyles.None, out d)) { date = d; return true; }
        if (DateOnly.TryParse(s, Inv, DateTimeStyles.None, out d)) { date = d; return true; }
        return false;
    }

    public static DateOnly Today => DateOnly.FromDateTime(DateTime.Today);
    public static DateTime? ToDateTime(DateOnly? d) => d?.ToDateTime(TimeOnly.MinValue);
    public static DateOnly? FromDateTime(DateTime? d) => d is null ? null : DateOnly.FromDateTime(d.Value);

    /// <summary>Optional string: empty becomes null (no trimming, so typing is never disturbed).</summary>
    public static string? Opt(string? s) => string.IsNullOrEmpty(s) ? null : s;
}

/// <summary>Theme brushes by key, with a fallback when the shell's theme doesn't define one.</summary>
public static class Palette
{
    static readonly Dictionary<string, string> Fallback = new()
    {
        ["Bg"] = "#FFD21F", ["Paper"] = "#FBF8F1", ["Ink"] = "#111111", ["Muted"] = "#5A5A5A", ["Yellow"] = "#FFC928",
        ["Pink"] = "#FF4F7B", ["Green"] = "#3CC13B", ["Lime"] = "#A6D930", ["Purple"] = "#8B6CF6", ["Sand"] = "#FBDB8E",
        ["Grey"] = "#9A9A9A",
    };

    public static Brush Get(string key)
    {
        if (Application.Current?.TryFindResource(key) is Brush b) return b;
        var c = (Color)ColorConverter.ConvertFromString(Fallback.GetValueOrDefault(key, "#9A9A9A"));
        var sb = new SolidColorBrush(c); sb.Freeze(); return sb;
    }
}

/// <summary>Fixed choice lists (match the API enums).</summary>
public static class Lists
{
    public static string[] PartnerCategories { get; } = ["", "A", "B", "C", "K"];
    public static string[] PartnerStages { get; } = ["idea", "to-ask", "asked", "thinking", "committed", "giving", "declined", "paused"];
    public static string[] BudgetKinds { get; } = ["expense", "income", "saving"];
    public static string[] Currencies { get; } = ["EUR", "NZD"];
    public static string[] Recurrences { get; } = ["once", "monthly", "yearly"];
    public static string[] BudgetPhases { get; } = ["setup", "monthly"];
    public static string[] SellStatuses { get; } = ["decide", "to-list", "listed", "reserved", "sold", "given-away", "keep", "store"];
    public static string[] Bags { get; } = ["checked", "carry-on", "personal", "ship", "buy-there", "leave"];
    public static string[] NoteKinds { get; } = ["note", "prayer", "journal", "meeting", "idea"];
    public static string[] NewsletterStatuses { get; } = ["idea", "draft", "ready", "sent"];
    public static string[] DocumentKinds { get; } =
        ["passport", "visa", "insurance", "ticket", "id", "bank", "medical", "diploma", "reference", "contract", "receipt", "letter", "other"];
    public static string[] Areas { get; } = Missie.Core.Areas.All;

    public static string StageColor(string? stage) => stage switch
    {
        "idea" => "Grey", "to-ask" => "Sand", "asked" => "Yellow", "thinking" => "Purple",
        "committed" => "Lime", "giving" => "Green", "declined" => "Pink", _ => "Paper",
    };

    public static string SellColor(string? status) => status switch
    {
        "decide" => "Grey", "to-list" => "Sand", "listed" => "Yellow", "reserved" => "Purple",
        "sold" => "Green", "given-away" => "Lime", "keep" => "Paper", _ => "Pink",
    };

    public static string BagColor(string? bag) => bag switch
    {
        "checked" => "Yellow", "carry-on" => "Green", "personal" => "Purple", "ship" => "Sand", "buy-there" => "Lime", _ => "Grey",
    };

    public static string BagTitle(string? bag) => bag switch
    {
        "checked" => "Checked bag", "carry-on" => "Carry-on", "personal" => "Personal item", "ship" => "Ship ahead",
        "buy-there" => "Buy in NZ", "leave" => "Leave behind", _ => bag ?? "Other",
    };

    public static string NoteKindColor(string? kind) => kind switch
    {
        "prayer" => "Purple", "journal" => "Sand", "meeting" => "Green", "idea" => "Lime", _ => "Yellow",
    };

    public static string DocColor(string? kind) => kind switch
    {
        "passport" or "id" => "Purple", "visa" => "Green", "insurance" or "medical" => "Pink", "ticket" => "Yellow",
        "bank" or "receipt" => "Lime", "diploma" or "reference" => "Sand", _ => "Grey",
    };

    /// <summary>Segoe Fluent Icons glyph per document kind.</summary>
    public static string DocGlyph(string? kind) => kind switch
    {
        "passport" => "", "visa" => "", "insurance" => "", "ticket" => "", "id" => "",
        "bank" => "", "medical" => "", "diploma" => "", "reference" => "", "contract" => "",
        "receipt" => "", "letter" => "", _ => "",
    };

    /// <summary>Guess a document kind from a file name (Dutch and English words).</summary>
    public static string GuessDocKind(string fileName)
    {
        var n = Path.GetFileNameWithoutExtension(fileName).ToLowerInvariant();
        (string kind, string[] words)[] map =
        [
            ("passport", ["paspoort", "passport", "pasport"]),
            ("visa", ["visa", "visum", "whv", "working holiday", "nzeta", "eta"]),
            ("insurance", ["verzekering", "insurance", "polis", "zorgpas"]),
            ("ticket", ["ticket", "boarding", "vlucht", "flight", "e-ticket", "itinerary", "booking"]),
            ("id", ["identiteit", "idkaart", "id-kaart", "id card", "rijbewijs", "license", "licence"]),
            ("bank", ["bank", "iban", "rekening", "afschrift", "statement"]),
            ("medical", ["medisch", "medical", "vaccin", "inenting", "health", "huisarts", "xray", "x-ray"]),
            ("diploma", ["diploma", "certificaat", "certificate", "getuigschrift"]),
            ("reference", ["referentie", "reference", "aanbeveling", "recommendation"]),
            ("contract", ["contract", "overeenkomst", "agreement", "huur", "lease"]),
            ("receipt", ["bon", "receipt", "factuur", "invoice", "kwitantie"]),
            ("letter", ["brief", "letter", "uitnodiging", "invitation", "acceptance"]),
        ];
        foreach (var (kind, words) in map)
            if (words.Any(w => n.Contains(w))) return kind;
        return "other";
    }
}

/// <summary>A grid/list row wrapping one entity. Setters change the entity and save it immediately.</summary>
public abstract class EntityRow<T> : ObservableObject where T : Entity
{
    readonly Action<Entity> _save;

    protected EntityRow(T model, Action<Entity> save)
    {
        Model = model;
        _save = save;
        Seen = model.UpdatedAt;
    }

    public T Model { get; private set; }
    public string Id => Model.Id;
    internal DateTimeOffset Seen { get; set; }

    /// <summary>Applies a change, raises PropertyChanged and saves the entity.</summary>
    protected bool Set<TV>(TV current, TV value, Action<TV> apply, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<TV>.Default.Equals(current, value)) return false;
        apply(value);
        OnPropertyChanged(name);
        OnModelChanged(name);
        _save(Model);
        return true;
    }

    /// <summary>Money text setter: invalid input keeps the old value.</summary>
    protected void SetAmount(long? current, string? text, Action<long?> apply, [CallerMemberName] string? name = null)
    {
        if (Fmt.TryParseAmount(text, out var cents)) Set(current, cents, apply, name);
        else OnPropertyChanged(name);
    }

    /// <summary>Date text setter: invalid input keeps the old value.</summary>
    protected void SetDate(DateOnly? current, string? text, Action<DateOnly?> apply, [CallerMemberName] string? name = null)
    {
        if (Fmt.TryParseDate(text, out var d)) Set(current, d, apply, name);
        else OnPropertyChanged(name);
    }

    /// <summary>A string kept in Entity.Extra (fields other apps store that this app's model doesn't name).</summary>
    protected string? GetExtra(string key) =>
        Model.Extra is { } x && x.TryGetValue(key, out var el)
            ? (el.ValueKind == System.Text.Json.JsonValueKind.String ? el.GetString() : el.ValueKind is System.Text.Json.JsonValueKind.Null or System.Text.Json.JsonValueKind.Undefined ? null : el.GetRawText())
            : null;

    /// <summary>Writes a string into Entity.Extra (removes the key when empty) and saves.</summary>
    protected void SetExtra(string key, string? value, [CallerMemberName] string? name = null)
    {
        value = string.IsNullOrWhiteSpace(value) ? null : value;
        if (GetExtra(key) == value) return;
        Set<string?>(GetExtra(key), value, v =>
        {
            if (v is null) { Model.Extra?.Remove(key); if (Model.Extra is { Count: 0 }) Model.Extra = null; }
            else (Model.Extra ??= new())[key] = System.Text.Json.JsonSerializer.SerializeToElement(v);
        }, name);
    }

    /// <summary>For computed properties that depend on the changed one.</summary>
    protected virtual void OnModelChanged(string? name) { }

    public void Save() => _save(Model);
    public void RaiseAll() => OnPropertyChanged(string.Empty);
    public void Notify(params string[] names) { foreach (var n in names) OnPropertyChanged(n); }

    internal void Replace(T model)
    {
        Model = model;
        Seen = model.UpdatedAt;
        OnPropertyChanged(string.Empty);
        OnModelChanged(null);
    }
}

/// <summary>
/// Base for the list pages: loads one collection into rows, filters by a search box, saves on edit,
/// and reloads (in place, keeping the selection) when the store says the collection changed elsewhere.
/// </summary>
public abstract class EntityListViewModel<T, TRow> : ObservableObject
    where T : Entity, new()
    where TRow : EntityRow<T>
{
    int _suppress;
    bool _attached, _reloadQueued;
    string _search = "";
    TRow? _selected;

    protected EntityListViewModel()
    {
        View = new ListCollectionView(Rows) { Filter = o => o is TRow r && Include(r) };
    }

    protected IMissionStore Store => AppServices.Store;
    public ObservableCollection<TRow> Rows { get; } = new();
    public ListCollectionView View { get; }

    public string Search
    {
        get => _search;
        set { if (SetProperty(ref _search, value)) RefreshView(); }
    }

    public TRow? Selected
    {
        get => _selected;
        set { if (SetProperty(ref _selected, value)) { OnPropertyChanged(nameof(HasSelection)); OnSelectedChanged(); } }
    }

    public bool HasSelection => _selected is not null;

    protected virtual void OnSelectedChanged() { }
    protected virtual string[] WatchedCollections => [Collections.Of<T>()];
    protected virtual IEnumerable<T> Load() => Store.All<T>();
    protected abstract TRow CreateRow(T entity);
    protected virtual string SearchText(TRow row) => row.Model.DisplayTitle;
    protected virtual bool Include(TRow row) => MatchesSearch(row);
    /// <summary>Recompute stats / subtitles after loading or an edit.</summary>
    protected virtual void Recompute() { }
    /// <summary>Reset page-specific filters (chips) so a selected row is visible.</summary>
    protected virtual void ClearExtraFilters() { }

    protected bool MatchesSearch(TRow row)
    {
        var q = _search.Trim();
        return q.Length == 0 || SearchText(row).Contains(q, StringComparison.OrdinalIgnoreCase);
    }

    public void Attach()
    {
        if (_attached) return;
        _attached = true;
        AppServices.StoreChanged += OnStoreChanged;
        Reload();
    }

    public void Detach()
    {
        if (!_attached) return;
        _attached = false;
        AppServices.StoreChanged -= OnStoreChanged;
    }

    void OnStoreChanged(object? sender, string? collection)
    {
        var d = Application.Current?.Dispatcher;
        if (d is null) return;
        if (_suppress > 0 && d.CheckAccess()) return; // our own save
        if (collection is not null && !WatchedCollections.Contains(collection)) return;
        if (_reloadQueued) return;
        _reloadQueued = true;
        d.BeginInvoke(DispatcherPriority.Background, new Action(Reload));
    }

    /// <summary>Reloads from the store, updating rows in place so editing and selection survive.</summary>
    public void Reload()
    {
        _reloadQueued = false;
        var items = Load().ToList();
        var byId = Rows.ToDictionary(r => r.Id);
        var target = new List<TRow>(items.Count);
        foreach (var e in items)
        {
            if (byId.TryGetValue(e.Id, out var row))
            {
                if (!ReferenceEquals(row.Model, e) || row.Seen != e.UpdatedAt) row.Replace(e);
                target.Add(row);
            }
            else target.Add(CreateRow(e));
        }
        Reorder(Rows, target);
        if (_selected is not null && !Rows.Contains(_selected)) Selected = null;
        AfterReload();
        Recompute();
    }

    /// <summary>Hook for pages that keep extra lists (gifts, groups) in step with the store.</summary>
    protected virtual void AfterReload() { }

    static void Reorder(ObservableCollection<TRow> rows, List<TRow> target)
    {
        var keep = new HashSet<TRow>(target);
        for (int i = rows.Count - 1; i >= 0; i--) if (!keep.Contains(rows[i])) rows.RemoveAt(i);
        for (int i = 0; i < target.Count; i++)
        {
            if (i < rows.Count && ReferenceEquals(rows[i], target[i])) continue;
            var at = rows.IndexOf(target[i]);
            if (at >= 0) rows.Move(at, i); else rows.Insert(i, target[i]);
        }
    }

    /// <summary>Save without triggering our own reload.</summary>
    public void SaveEntity(Entity e)
    {
        _suppress++;
        try { Store.Save(e); }
        catch (Exception ex) { PageActions.Error("Couldn't save", ex); }
        finally { _suppress--; }
        foreach (var r in Rows) if (r.Id == e.Id) { r.Seen = e.UpdatedAt; break; }
        Recompute();
    }

    /// <summary>Runs store work without reloading this page because of it.</summary>
    public void Quiet(Action work)
    {
        _suppress++;
        try { work(); }
        catch (Exception ex) { PageActions.Error("That didn't work", ex); }
        finally { _suppress--; }
        Recompute();
    }

    public void SaveMany(IEnumerable<T> entities)
    {
        var list = entities.ToList();
        if (list.Count == 0) return;
        _suppress++;
        try { Store.SaveMany(list); }
        catch (Exception ex) { PageActions.Error("Couldn't save", ex); }
        finally { _suppress--; }
        Reload();
    }

    /// <summary>Saves a new entity, adds its row, makes it visible and selects it.</summary>
    public TRow Add(T entity)
    {
        SaveEntity(entity);
        var row = CreateRow(entity);
        Rows.Add(row);
        if (!Include(row)) ClearFilters();
        Selected = row;
        Recompute();
        return row;
    }

    public void Delete(TRow row)
    {
        _suppress++;
        try { Store.Delete(row.Id); }
        catch (Exception ex) { PageActions.Error("Couldn't delete", ex); return; }
        finally { _suppress--; }
        if (ReferenceEquals(_selected, row)) Selected = null;
        Rows.Remove(row);
        Recompute();
    }

    /// <summary>Smart link target: select the row with this id (clearing filters if it was hidden).</summary>
    public bool SelectId(string id)
    {
        var row = Rows.FirstOrDefault(r => r.Id == id);
        if (row is null) { Reload(); row = Rows.FirstOrDefault(r => r.Id == id); }
        if (row is null) return false;
        if (!Include(row)) ClearFilters();
        Selected = row;
        return true;
    }

    public void ClearFilters()
    {
        _search = "";
        OnPropertyChanged(nameof(Search));
        ClearExtraFilters();
        RefreshView();
    }

    public virtual void RefreshView()
    {
        try
        {
            if (View.IsAddingNew) View.CommitNew();
            if (View.IsEditingItem) View.CommitEdit();
            View.Refresh();
        }
        catch (InvalidOperationException)
        {
            // A grid is still mid-edit; try again once it settles.
            Application.Current?.Dispatcher.BeginInvoke(DispatcherPriority.ContextIdle, new Action(() =>
            {
                try { View.Refresh(); } catch (InvalidOperationException) { }
            }));
        }
        Recompute();
    }

    public void ImportCsv() { if (PageActions.ImportCsv<T>() is > 0) Reload(); }
    public void ExportCsv(string name) => PageActions.ExportCsv<T>(name);
}

/// <summary>Dialogs and shell actions shared by the pages.</summary>
public static class PageActions
{
    public static void ExportCsv<T>(string name) where T : Entity, new()
    {
        var dlg = new SaveFileDialog
        {
            Title = "Export CSV",
            Filter = "CSV file (*.csv)|*.csv",
            FileName = $"{name}-{DateTime.Today:yyyy-MM-dd}.csv",
        };
        if (dlg.ShowDialog() != true) return;
        try
        {
            File.WriteAllText(dlg.FileName, AppServices.Store.ExportCsv<T>(), new UTF8Encoding(true));
        }
        catch (Exception ex) { Error("Export failed", ex); }
    }

    /// <summary>Returns rows imported, or null when cancelled/failed.</summary>
    public static int? ImportCsv<T>() where T : Entity, new()
    {
        var dlg = new OpenFileDialog { Title = "Import CSV", Filter = "CSV file (*.csv)|*.csv|All files (*.*)|*.*" };
        if (dlg.ShowDialog() != true) return null;
        try
        {
            var n = AppServices.Store.ImportCsv<T>(File.ReadAllText(dlg.FileName));
            Info($"Imported {n} row{(n == 1 ? "" : "s")}. Rows with an id were updated, rows without one were added.");
            return n;
        }
        catch (Exception ex) { Error("Import failed", ex); return null; }
    }

    public static bool Confirm(string message, string title = "Are you sure?", string okText = "Delete") =>
        Controls.BrutalDialog.Confirm(title, message, okText, danger: okText == "Delete");

    public static void Info(string message, string title = "Missie") => Controls.BrutalDialog.Alert(title, message);

    public static void Error(string what, Exception ex) => Controls.BrutalDialog.Alert(what, ex.Message);

    public static void OpenUrl(string? url)
    {
        if (string.IsNullOrWhiteSpace(url)) return;
        var u = url.Trim();
        if (!u.Contains("://") && !u.StartsWith("mailto:", StringComparison.OrdinalIgnoreCase)) u = "https://" + u;
        Shell(u);
    }

    public static void Shell(string target)
    {
        try { Process.Start(new ProcessStartInfo(target) { UseShellExecute = true }); }
        catch (Exception ex) { Error("Couldn't open it", ex); }
    }

    public static void ShowInFolder(string path)
    {
        try { Process.Start("explorer.exe", $"/select,\"{path}\""); }
        catch (Exception ex) { Error("Couldn't open the folder", ex); }
    }

    public static void Navigate(string entityId)
    {
        try { AppServices.Navigator.Open(entityId); } catch { /* shell not ready */ }
    }
}

/// <summary>A clickable filter chip with a count.</summary>
public sealed partial class FilterChip : ObservableObject
{
    public FilterChip(string? key, string label, string colorKey)
    {
        Key = key;
        Label = label;
        ColorKey = colorKey;
    }

    public string? Key { get; }
    public string Label { get; }
    public string ColorKey { get; }
    public Brush Fill => Palette.Get(ColorKey);

    [ObservableProperty] private int _count;
    [ObservableProperty] private bool _isActive;
    public string Text => Count >= 0 ? $"{Label} · {Count}" : Label;
    partial void OnCountChanged(int value) => OnPropertyChanged(nameof(Text));
}
