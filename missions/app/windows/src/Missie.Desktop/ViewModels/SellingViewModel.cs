using System.Collections.ObjectModel;
using System.Windows.Media;
using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class SellRow : EntityRow<SellItem>
{
    public SellRow(SellItem s, Action<Entity> save) : base(s, save) { }

    public string Name { get => Model.Name; set => Set(Model.Name, value ?? "", v => Model.Name = v); }
    public string Status { get => Model.Status; set => Set(Model.Status, value ?? "decide", v => Model.Status = v); }
    public string AskingText { get => Fmt.Amount(Model.AskingCents); set => SetAmount(Model.AskingCents, value, v => Model.AskingCents = v); }
    public string SoldText { get => Fmt.Amount(Model.SoldCents); set => SetAmount(Model.SoldCents, value, v => Model.SoldCents = v); }
    public string? Platform { get => Model.Platform; set => Set(Model.Platform, Fmt.Opt(value), v => Model.Platform = v); }
    public string? ListingUrl { get => Model.ListingUrl; set => Set(Model.ListingUrl, Fmt.Opt(value), v => Model.ListingUrl = v); }
    public string? Buyer { get => Model.Buyer; set => Set(Model.Buyer, Fmt.Opt(value), v => Model.Buyer = v); }
    public string PickupText { get => Fmt.Date(Model.PickupDate); set => SetDate(Model.PickupDate, value, v => Model.PickupDate = v); }
    public DateTime? PickupDate
    {
        get => Fmt.ToDateTime(Model.PickupDate);
        set => Set(Model.PickupDate, Fmt.FromDateTime(value), v => Model.PickupDate = v);
    }
    public string? Location { get => Model.Location; set => Set(Model.Location, Fmt.Opt(value), v => Model.Location = v); }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }

    public bool HasUrl => !string.IsNullOrWhiteSpace(Model.ListingUrl);
    public Brush StatusBrush => Palette.Get(Lists.SellColor(Model.Status));
    public bool IsLeft => SellingViewModel.LeftStatuses.Contains(Model.Status);

    protected override void OnModelChanged(string? name) =>
        Notify(nameof(HasUrl), nameof(StatusBrush), nameof(IsLeft), nameof(PickupText), nameof(PickupDate));
}

public sealed class SellingViewModel : EntityListViewModel<SellItem, SellRow>
{
    public static readonly string[] LeftStatuses = ["decide", "to-list", "listed", "reserved"];
    string? _statusFilter;
    string _subtitle = "", _leftText = "", _soldText = "", _listedText = "", _askingText = "", _pickupText = "";

    public SellingViewModel()
    {
        StatusChips.Add(new FilterChip(null, "All", "Paper") { IsActive = true });
        StatusChips.Add(new FilterChip("left", "Still to go", "Pink"));
        foreach (var s in Lists.SellStatuses) StatusChips.Add(new FilterChip(s, s, Lists.SellColor(s)));
    }

    public ObservableCollection<FilterChip> StatusChips { get; } = new();
    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }
    public string LeftText { get => _leftText; private set => SetProperty(ref _leftText, value); }
    public string SoldText { get => _soldText; private set => SetProperty(ref _soldText, value); }
    public string ListedText { get => _listedText; private set => SetProperty(ref _listedText, value); }
    public string AskingText { get => _askingText; private set => SetProperty(ref _askingText, value); }
    public string PickupText { get => _pickupText; private set => SetProperty(ref _pickupText, value); }

    protected override SellRow CreateRow(SellItem s) => new(s, SaveEntity);
    protected override string SearchText(SellRow r) =>
        $"{r.Model.Name} {r.Model.Platform} {r.Model.Buyer} {r.Model.Location} {r.Model.Notes} {r.Model.Status}";

    protected override bool Include(SellRow r) => MatchesSearch(r) && _statusFilter switch
    {
        null => true,
        "left" => r.IsLeft,
        var s => r.Model.Status == s,
    };

    public void ToggleChip(FilterChip chip)
    {
        _statusFilter = chip.Key == _statusFilter ? null : chip.Key;
        foreach (var c in StatusChips) c.IsActive = c.Key == _statusFilter;
        RefreshView();
    }

    protected override void ClearExtraFilters()
    {
        _statusFilter = null;
        foreach (var c in StatusChips) c.IsActive = c.Key is null;
    }

    protected override void Recompute()
    {
        foreach (var c in StatusChips)
            c.Count = c.Key switch
            {
                null => Rows.Count,
                "left" => Rows.Count(r => r.IsLeft),
                var s => Rows.Count(r => r.Model.Status == s),
            };
        int left = Rows.Count(r => r.IsLeft);
        long sold = Rows.Where(r => r.Model.Status == "sold").Sum(r => r.Model.SoldCents ?? r.Model.AskingCents ?? 0);
        long asking = Rows.Where(r => r.IsLeft).Sum(r => r.Model.AskingCents ?? 0);
        int listed = Rows.Count(r => r.Model.Status is "listed" or "reserved");
        var today = Fmt.Today;
        var nextPickup = Rows.Where(r => r.Model.PickupDate is { } d && d >= today && r.Model.Status is "reserved" or "sold")
            .OrderBy(r => r.Model.PickupDate).FirstOrDefault();
        LeftText = left.ToString();
        SoldText = Fmt.Euro(sold);
        ListedText = listed.ToString();
        AskingText = $"{Fmt.Euro(asking)} still asked for";
        PickupText = nextPickup is null ? "no pickups planned" : $"next pickup: {nextPickup.Model.Name}, {Fmt.NiceDate(nextPickup.Model.PickupDate)}";
        Subtitle = $"{left} item{(left == 1 ? "" : "s")} still to go · {Fmt.Euro(sold)} sold so far";
    }

    public SellRow New() => Add(new SellItem { Name = "New item", Status = "decide", Currency = "EUR" });
}
