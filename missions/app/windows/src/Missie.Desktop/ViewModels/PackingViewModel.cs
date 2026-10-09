using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using Missie.Core;
using Missie.Desktop.Services;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class PackingRow : EntityRow<PackingItem>
{
    public PackingRow(PackingItem p, Action<Entity> save) : base(p, save) { }

    public string Name { get => Model.Name; set => Set(Model.Name, value ?? "", v => Model.Name = v); }
    public string Bag { get => Model.Bag ?? "checked"; set => Set(Model.Bag ?? "checked", value ?? "checked", v => Model.Bag = v); }
    public string? Category { get => Model.Category; set => Set(Model.Category, Fmt.Opt(value), v => Model.Category = v); }
    public bool Packed { get => Model.Packed; set => Set(Model.Packed, value, v => Model.Packed = v); }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }

    public string QuantityText
    {
        get => (Model.Quantity ?? 1).ToString(CultureInfo.InvariantCulture);
        set
        {
            if (int.TryParse((value ?? "").Trim(), out var q) && q >= 0) Set(Model.Quantity, (int?)q, v => Model.Quantity = v);
            else Notify(nameof(QuantityText));
        }
    }

    /// <summary>Weight per piece in grams; accepts "350", "350 g", "1,2 kg".</summary>
    public string WeightText
    {
        get => Model.WeightGrams?.ToString(CultureInfo.InvariantCulture) ?? "";
        set
        {
            if (TryParseGrams(value, out var g)) Set(Model.WeightGrams, g, v => Model.WeightGrams = v);
            else Notify(nameof(WeightText));
        }
    }

    public double TotalKg => (Model.WeightGrams ?? 0) * (Model.Quantity ?? 1) / 1000.0;

    static bool TryParseGrams(string? text, out int? grams)
    {
        grams = null;
        var s = (text ?? "").Trim().ToLowerInvariant().Replace(" ", "");
        if (s.Length == 0) return true;
        double factor = 1;
        if (s.EndsWith("kg")) { factor = 1000; s = s[..^2]; }
        else if (s.EndsWith('g')) s = s[..^1];
        if (!double.TryParse(s.Replace(',', '.'), NumberStyles.Float, CultureInfo.InvariantCulture, out var d) || d < 0) return false;
        grams = (int)Math.Round(d * factor);
        return true;
    }

    protected override void OnModelChanged(string? name) => Notify(nameof(TotalKg), nameof(WeightText), nameof(QuantityText));
}

/// <summary>One bag card: its items, total weight and limit.</summary>
public sealed partial class BagGroup : ObservableObject
{
    readonly Action _limitChanged;

    public BagGroup(string key, double limitKg, Action limitChanged)
    {
        Key = key;
        _limitKg = limitKg;
        _limitChanged = limitChanged;
    }

    public string Key { get; }
    public string Title => Lists.BagTitle(Key);
    public Brush Accent => Palette.Get(Lists.BagColor(Key));
    public ObservableCollection<PackingRow> Items { get; } = new();

    [ObservableProperty] private double _totalKg;
    [ObservableProperty] private string _summary = "";
    [ObservableProperty] private string _quickAdd = "";

    double _limitKg;
    public double LimitKg
    {
        get => _limitKg;
        private set
        {
            if (SetProperty(ref _limitKg, value))
            {
                OnPropertyChanged(nameof(HasLimit)); OnPropertyChanged(nameof(LimitText)); OnPropertyChanged(nameof(MeterMax));
                OnPropertyChanged(nameof(LimitLabel)); OnPropertyChanged(nameof(MeterLimit));
            }
        }
    }

    /// <summary>Editable limit in kg ("" = no limit).</summary>
    public string LimitText
    {
        get => _limitKg > 0 ? _limitKg.ToString("0.#", CultureInfo.InvariantCulture) : "";
        set
        {
            var s = (value ?? "").Trim().Replace(',', '.').Replace("kg", "");
            if (s.Length == 0) LimitKg = 0;
            else if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) && d >= 0) LimitKg = d;
            else { OnPropertyChanged(); return; }
            _limitChanged();
            Recompute(Items);
        }
    }

    public bool HasLimit => _limitKg > 0;
    public double MeterMax => Math.Max(_limitKg * 1.15, TotalKg);
    public double MeterLimit => _limitKg > 0 ? _limitKg : double.NaN;
    public string LimitLabel => $"limit {_limitKg:0.#} kg";

    public void Recompute(IEnumerable<PackingRow> all)
    {
        var list = all.ToList();
        TotalKg = Math.Round(list.Sum(r => r.TotalKg), 2);
        OnPropertyChanged(nameof(MeterMax));
        int packed = list.Count(r => r.Packed);
        var weight = _limitKg > 0 ? $"{TotalKg:0.0} / {_limitKg:0.#} kg" : $"{TotalKg:0.0} kg";
        var over = _limitKg > 0 && TotalKg > _limitKg ? $" · {TotalKg - _limitKg:0.0} kg too heavy!" : "";
        Summary = $"{packed}/{list.Count} packed · {weight}{over}";
    }
}

public sealed class PackingViewModel : EntityListViewModel<PackingItem, PackingRow>
{
    static readonly Dictionary<string, double> DefaultLimits = new() { ["checked"] = 23, ["carry-on"] = 7 };
    static string LimitsFile => Path.Combine(AppServices.DataDir, "packing-limits.json");

    string _subtitle = "";
    bool _hidePacked, _regroupQueued;

    public PackingViewModel()
    {
        var limits = LoadLimits();
        foreach (var bag in Lists.Bags)
            Groups.Add(new BagGroup(bag, limits.GetValueOrDefault(bag, DefaultLimits.GetValueOrDefault(bag)), SaveLimits));
    }

    public ObservableCollection<BagGroup> Groups { get; } = new();
    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }

    public bool HidePacked
    {
        get => _hidePacked;
        set { if (SetProperty(ref _hidePacked, value)) Regroup(); }
    }

    protected override PackingRow CreateRow(PackingItem p)
    {
        var row = new PackingRow(p, SaveEntity);
        row.PropertyChanged += Row_PropertyChanged;
        return row;
    }

    void Row_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PackingRow.Bag) || (e.PropertyName == nameof(PackingRow.Packed) && _hidePacked))
            QueueRegroup();
    }

    protected override string SearchText(PackingRow r) => $"{r.Model.Name} {r.Model.Category} {r.Model.Notes}";
    protected override bool Include(PackingRow r) => MatchesSearch(r) && !(_hidePacked && r.Packed);
    protected override void ClearExtraFilters() { _hidePacked = false; OnPropertyChanged(nameof(HidePacked)); }
    protected override void AfterReload() => Regroup();

    public override void RefreshView()
    {
        base.RefreshView();
        Regroup();
    }

    void QueueRegroup()
    {
        if (_regroupQueued) return;
        _regroupQueued = true;
        Application.Current?.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(Regroup));
    }

    /// <summary>Puts each visible row in its bag card (reusing rows so editing isn't disturbed).</summary>
    public void Regroup()
    {
        _regroupQueued = false;
        foreach (var g in Groups)
        {
            var target = Rows.Where(r => (r.Bag == g.Key || (g.Key == "leave" && !Lists.Bags.Contains(r.Bag))) && Include(r))
                .OrderBy(r => r.Packed).ThenBy(r => r.Model.Category).ThenBy(r => r.Name, StringComparer.CurrentCultureIgnoreCase).ToList();
            Sync(g.Items, target);
        }
        Recompute();
    }

    static void Sync(ObservableCollection<PackingRow> items, List<PackingRow> target)
    {
        var keep = new HashSet<PackingRow>(target);
        for (int i = items.Count - 1; i >= 0; i--) if (!keep.Contains(items[i])) items.RemoveAt(i);
        for (int i = 0; i < target.Count; i++)
        {
            if (i < items.Count && ReferenceEquals(items[i], target[i])) continue;
            var at = items.IndexOf(target[i]);
            if (at >= 0) items.Move(at, i); else items.Insert(i, target[i]);
        }
    }

    protected override void Recompute()
    {
        foreach (var g in Groups) g.Recompute(Rows.Where(r => r.Bag == g.Key));
        int total = Rows.Count(r => r.Bag != "leave"), packed = Rows.Count(r => r.Bag != "leave" && r.Packed);
        var flying = Groups.Where(g => g.Key is "checked" or "carry-on" or "personal").Sum(g => g.TotalKg);
        var over = Groups.Where(g => g.HasLimit && g.TotalKg > g.LimitKg).Select(g => g.Title).ToList();
        Subtitle = $"{packed} of {total} packed · {flying:0.0} kg in the bags you fly with"
                   + (over.Count > 0 ? $" · too heavy: {string.Join(", ", over)}" : "");
    }

    public PackingRow AddTo(string bag, string name)
    {
        var row = Add(new PackingItem { Name = name, Bag = bag, Quantity = 1 });
        Regroup();
        return row;
    }

    public void ResetPacked() => SaveMany(Rows.Where(r => r.Packed).Select(r => { r.Model.Packed = false; return r.Model; }));

    public void Remove(PackingRow row)
    {
        Delete(row);
        Regroup();
    }

    static Dictionary<string, double> LoadLimits()
    {
        try
        {
            if (File.Exists(LimitsFile))
                return JsonSerializer.Deserialize<Dictionary<string, double>>(File.ReadAllText(LimitsFile)) ?? new();
        }
        catch { }
        return new();
    }

    void SaveLimits()
    {
        try
        {
            Directory.CreateDirectory(AppServices.DataDir);
            File.WriteAllText(LimitsFile, JsonSerializer.Serialize(Groups.ToDictionary(g => g.Key, g => g.LimitKg)));
        }
        catch { /* limits are a convenience; ignore disk errors */ }
        Recompute();
    }
}
