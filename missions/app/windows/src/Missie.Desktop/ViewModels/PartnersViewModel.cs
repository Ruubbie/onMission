using System.Collections.ObjectModel;
using System.Windows.Media;
using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class PartnerRow : EntityRow<Partner>
{
    public PartnerRow(Partner p, Action<Entity> save) : base(p, save) { }

    public string Name { get => Model.Name; set => Set(Model.Name, value ?? "", v => Model.Name = v); }
    public string Stage { get => Model.Stage; set => Set(Model.Stage, value ?? "idea", v => Model.Stage = v); }
    public string MonthlyText { get => Fmt.Amount(Model.MonthlyCents); set => SetAmount(Model.MonthlyCents, value, v => Model.MonthlyCents = v); }
    public string OneOffText { get => Fmt.Amount(Model.OneOffCents); set => SetAmount(Model.OneOffCents, value, v => Model.OneOffCents = v); }
    public string? Email { get => Model.Email; set => Set(Model.Email, Fmt.Opt(value), v => Model.Email = v); }
    public string? Phone { get => Model.Phone; set => Set(Model.Phone, Fmt.Opt(value), v => Model.Phone = v); }
    public string? Church { get => Model.Church; set => Set(Model.Church, Fmt.Opt(value), v => Model.Church = v); }
    public bool Prayer { get => Model.Prayer == true; set => Set(Model.Prayer == true, value, v => Model.Prayer = v); }
    public bool Newsletter { get => Model.Newsletter == true; set => Set(Model.Newsletter == true, value, v => Model.Newsletter = v); }
    public string LastContactText { get => Fmt.Date(Model.LastContactAt); set => SetDate(Model.LastContactAt, value, v => Model.LastContactAt = v); }
    public string NextFollowUpText { get => Fmt.Date(Model.NextFollowUp); set => SetDate(Model.NextFollowUp, value, v => Model.NextFollowUp = v); }
    public string ThankedText { get => Fmt.Date(Model.ThankedAt); set => SetDate(Model.ThankedAt, value, v => Model.ThankedAt = v); }
    public DateTime? NextFollowUpDate
    {
        get => Fmt.ToDateTime(Model.NextFollowUp);
        set => Set(Model.NextFollowUp, Fmt.FromDateTime(value), v => Model.NextFollowUp = v);
    }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }

    // Fields the iPhone app keeps in the record's data (not in the shared model): stored in Partner.Extra.
    /// <summary>A, B, C or K (iPhone app's partner category).</summary>
    public string? Category { get => GetExtra("category"); set => SetExtra("category", value); }
    public string? NextStep { get => GetExtra("nextStep"); set => SetExtra("nextStep", value); }
    public string? Address { get => GetExtra("address"); set => SetExtra("address", value); }
    /// <summary>YYYY-MM-DD.</summary>
    public DateTime? Birthday
    {
        get => Fmt.TryParseDate(GetExtra("birthday"), out var d) ? Fmt.ToDateTime(d) : null;
        set => SetExtra("birthday", Fmt.Date(Fmt.FromDateTime(value)));
    }

    public bool FollowUpDue => Model.NextFollowUp is { } d && d <= Fmt.Today && Model.Stage is not ("declined" or "paused");
    public Brush StageBrush => Palette.Get(Lists.StageColor(Model.Stage));
    public string LastContactNice => Model.LastContactAt is null ? "never" : Fmt.NiceDate(Model.LastContactAt);
    public string ThankedNice => Model.ThankedAt is null ? "not yet" : Fmt.NiceDate(Model.ThankedAt);

    protected override void OnModelChanged(string? name)
    {
        Notify(nameof(FollowUpDue), nameof(StageBrush), nameof(LastContactNice), nameof(ThankedNice),
            nameof(LastContactText), nameof(ThankedText), nameof(NextFollowUpText), nameof(NextFollowUpDate));
    }
}

public sealed class GiftRow : EntityRow<Gift>
{
    public GiftRow(Gift g, Action<Entity> save) : base(g, save) { }
    public string Amount => Fmt.Money(Model.AmountCents, Model.Currency, whole: false);
    public string When => Fmt.NiceDate(Model.Date);
    public string Via => string.Join(" · ", new[] { Model.Via, Model.Recurring == true ? "monthly" : null }.Where(s => !string.IsNullOrEmpty(s)));
    public bool Thanked => Model.ThankedAt is not null;
    public string ThankedText => Model.ThankedAt is null ? "" : "thanked " + Fmt.NiceDate(Model.ThankedAt);
    public void MarkThanked() { Set(Model.ThankedAt, Fmt.Today, v => Model.ThankedAt = v, nameof(Thanked)); Notify(nameof(ThankedText)); }
}

public sealed class PartnersViewModel : EntityListViewModel<Partner, PartnerRow>
{
    string? _stageFilter;
    string _subtitle = "", _meterText = "", _receivedText = "", _newGiftAmount = "", _newGiftVia = "", _logText = "";
    double _committed, _minimum, _target, _meterMax = 1;
    DateTime? _newGiftDate = DateTime.Today;
    bool _newGiftRecurring;

    public PartnersViewModel()
    {
        StageChips.Add(new FilterChip(null, "All", "Paper") { IsActive = true });
        foreach (var s in Lists.PartnerStages) StageChips.Add(new FilterChip(s, s, Lists.StageColor(s)));
        StageChips.Add(new FilterChip("due", "Follow-up due", "Pink"));
    }

    public ObservableCollection<FilterChip> StageChips { get; } = new();
    public ObservableCollection<GiftRow> Gifts { get; } = new();

    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }
    public string MeterText { get => _meterText; private set => SetProperty(ref _meterText, value); }
    public string ReceivedText { get => _receivedText; private set => SetProperty(ref _receivedText, value); }
    public double Committed { get => _committed; private set => SetProperty(ref _committed, value); }
    public double Minimum { get => _minimum; private set => SetProperty(ref _minimum, value); }
    public double Target { get => _target; private set => SetProperty(ref _target, value); }
    public double MeterMax { get => _meterMax; private set => SetProperty(ref _meterMax, value); }
    public string MinimumLabel => $"min {Fmt.Euro((long)(_minimum * 100))}";
    public string TargetLabel => $"target {Fmt.Euro((long)(_target * 100))}";

    public string NewGiftAmount { get => _newGiftAmount; set => SetProperty(ref _newGiftAmount, value); }
    public DateTime? NewGiftDate { get => _newGiftDate; set => SetProperty(ref _newGiftDate, value); }
    public string NewGiftVia { get => _newGiftVia; set => SetProperty(ref _newGiftVia, value); }
    public bool NewGiftRecurring { get => _newGiftRecurring; set => SetProperty(ref _newGiftRecurring, value); }
    public string LogText { get => _logText; set => SetProperty(ref _logText, value); }

    protected override string[] WatchedCollections => [Collections.Partners, Collections.Gifts, Collections.Settings];
    protected override PartnerRow CreateRow(Partner p) => new(p, SaveEntity);
    protected override string SearchText(PartnerRow r) =>
        $"{r.Model.Name} {r.Model.Email} {r.Model.Phone} {r.Model.Church} {r.Model.Notes} {r.Model.Stage} {r.NextStep} {r.Address}";

    protected override bool Include(PartnerRow r) => MatchesSearch(r) && _stageFilter switch
    {
        null => true,
        "due" => r.FollowUpDue,
        var s => r.Model.Stage == s,
    };

    public void ToggleChip(FilterChip chip)
    {
        _stageFilter = chip.Key == _stageFilter ? null : chip.Key;
        foreach (var c in StageChips) c.IsActive = c.Key == _stageFilter;
        RefreshView();
    }

    protected override void ClearExtraFilters()
    {
        _stageFilter = null;
        foreach (var c in StageChips) c.IsActive = c.Key is null;
    }

    protected override void OnSelectedChanged() => LoadGifts();
    protected override void AfterReload() => LoadGifts();

    void LoadGifts()
    {
        Gifts.Clear();
        if (Selected is null) return;
        IEnumerable<Gift> gifts;
        try { gifts = Store.All<Gift>(); } catch { return; }
        foreach (var g in gifts.Where(g => g.PartnerId == Selected.Id).OrderByDescending(g => g.Date))
            Gifts.Add(new GiftRow(g, SaveEntity));
    }

    protected override void Recompute()
    {
        var today = Fmt.Today;
        foreach (var c in StageChips)
            c.Count = c.Key switch
            {
                null => Rows.Count,
                "due" => Rows.Count(r => r.FollowUpDue),
                var s => Rows.Count(r => r.Model.Stage == s),
            };

        double rate = 1.85;
        long committed = 0, min = 75000, target = 100000;
        try
        {
            var set = Store.SharedSettings;
            rate = set.NzdPerEur is > 0 ? set.NzdPerEur.Value : 1.85;
            min = set.SupportMinimumMonthlyCents ?? min;
            target = set.SupportTargetMonthlyCents ?? target;
        }
        catch { /* store not ready */ }
        try { committed = Store.GetSummary().CommittedMonthlyCents; }
        catch
        {
            committed = Rows.Where(r => r.Model.CountsAsSupport)
                .Sum(r => r.Model.Currency == "NZD" ? (long)((r.Model.MonthlyCents ?? 0) / rate) : r.Model.MonthlyCents ?? 0);
        }
        Committed = committed / 100.0;
        Minimum = min / 100.0;
        Target = target / 100.0;
        MeterMax = Math.Max(Target * 1.15, Committed);
        OnPropertyChanged(nameof(MinimumLabel));
        OnPropertyChanged(nameof(TargetLabel));
        var pct = target > 0 ? (int)Math.Round(100.0 * committed / target) : 0;
        MeterText = $"{Fmt.Euro(committed)} / month committed · {pct}% of target";

        long received = 0;
        try
        {
            received = Store.All<Gift>()
                .Where(g => g.Date.Year == today.Year && g.Date.Month == today.Month)
                .Sum(g => g.Currency == "NZD" ? (long)(g.AmountCents / rate) : g.AmountCents);
        }
        catch { }
        ReceivedText = $"{Fmt.Euro(received)} received in {today.ToString("MMMM", Fmt.Nl)}";

        int due = Rows.Count(r => r.FollowUpDue);
        int team = Rows.Count(r => r.Model.CountsAsSupport);
        Subtitle = $"{Rows.Count} people · {team} on the team · {due} follow-up{(due == 1 ? "" : "s")} due";
    }

    public PartnerRow New() => Add(new Partner { Name = "New partner", Stage = "idea", Currency = "EUR", Newsletter = true });

    public void MarkContactedToday() => Selected!.LastContactText = Fmt.Date(Fmt.Today);
    public void ThankedToday() => Selected!.ThankedText = Fmt.Date(Fmt.Today);

    /// <summary>Creates a meeting note linked to the selected partner and marks them contacted.</summary>
    public void LogConversation()
    {
        var row = Selected;
        if (row is null) return;
        var text = LogText.Trim();
        var note = new Note
        {
            Title = $"Talked with {row.Model.Name} · {Fmt.NiceDate(Fmt.Today)}",
            Kind = "meeting",
            Area = "support",
            Body = text.Length > 0 ? text : null,
        };
        Quiet(() =>
        {
            Store.Save(note);
            Store.Link(note, row.Model);
        });
        LogText = "";
        row.LastContactText = Fmt.Date(Fmt.Today);
        row.RaiseAll();
    }

    public bool AddGift()
    {
        var row = Selected;
        if (row is null) return false;
        if (!Fmt.TryParseAmount(NewGiftAmount, out var cents) || cents is null or <= 0) return false;
        var gift = new Gift
        {
            PartnerId = row.Id,
            AmountCents = cents.Value,
            Currency = row.Model.Currency ?? "EUR",
            Date = Fmt.FromDateTime(NewGiftDate) ?? Fmt.Today,
            Via = Fmt.Opt(NewGiftVia.Trim()),
            Recurring = NewGiftRecurring ? true : null,
        };
        SaveEntity(gift);
        NewGiftAmount = "";
        NewGiftVia = "";
        LoadGifts();
        Recompute();
        return true;
    }

    public void ThankGift(GiftRow gift)
    {
        gift.MarkThanked();
        ThankedToday();
    }

    public void DeleteGift(GiftRow gift)
    {
        Quiet(() => Store.Delete(gift.Id));
        Gifts.Remove(gift);
        Recompute();
    }
}
