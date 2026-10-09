using System.Windows.Data;
using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class BudgetRow : EntityRow<BudgetEntry>
{
    public BudgetRow(BudgetEntry b, Action<Entity> save) : base(b, save) { }

    public string Label { get => Model.Label; set => Set(Model.Label, value ?? "", v => Model.Label = v); }
    public string Kind { get => Model.Kind; set => Set(Model.Kind, value ?? "expense", v => Model.Kind = v); }
    public string? Category { get => Model.Category; set => Set(Model.Category, Fmt.Opt(value), v => Model.Category = v); }
    public string AmountText
    {
        get => Fmt.Amount(Model.AmountCents);
        set => SetAmount(Model.AmountCents, value, v => Model.AmountCents = v ?? 0);
    }
    public string Currency { get => Model.Currency; set => Set(Model.Currency, value ?? "EUR", v => Model.Currency = v); }
    public string? Recurrence { get => Model.Recurrence; set => Set(Model.Recurrence, Fmt.Opt(value), v => Model.Recurrence = v); }
    public string? Phase { get => Model.Phase; set => Set(Model.Phase, Fmt.Opt(value), v => Model.Phase = v); }
    public string DateText { get => Fmt.Date(Model.Date); set => SetDate(Model.Date, value, v => Model.Date = v); }
    public bool Paid { get => Model.Paid == true; set => Set(Model.Paid == true, value, v => Model.Paid = v); }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }

    /// <summary>"income", "setup" or "monthly": which table the row shows in.</summary>
    public string Section => SectionOf(Model);

    public static string SectionOf(BudgetEntry b) =>
        b.Kind == "income" ? "income"
        : b.Phase == "setup" ? "setup"
        : b.Phase == "monthly" ? "monthly"
        : b.Recurrence is "monthly" or "yearly" ? "monthly" : "setup";

    protected override void OnModelChanged(string? name) => Notify(nameof(Section));
}

public sealed class BudgetViewModel : EntityListViewModel<BudgetEntry, BudgetRow>
{
    string _subtitle = "", _setupTotal = "", _setupSub = "", _monthlyTotal = "", _monthlySub = "",
        _committedText = "", _gapText = "", _gapSub = "", _incomeTotal = "", _incomeSub = "";
    bool _gapOpen;

    public BudgetViewModel()
    {
        SetupView = MakeView("setup");
        MonthlyView = MakeView("monthly");
        IncomeView = MakeView("income");
    }

    ListCollectionView MakeView(string section)
    {
        var v = new ListCollectionView(Rows) { Filter = o => o is BudgetRow r && r.Section == section && MatchesSearch(r) };
        v.IsLiveFiltering = true;
        v.LiveFilteringProperties.Add(nameof(BudgetRow.Section));
        return v;
    }

    public ListCollectionView SetupView { get; }
    public ListCollectionView MonthlyView { get; }
    public ListCollectionView IncomeView { get; }

    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }
    public string SetupTotal { get => _setupTotal; private set => SetProperty(ref _setupTotal, value); }
    public string SetupSub { get => _setupSub; private set => SetProperty(ref _setupSub, value); }
    public string MonthlyTotal { get => _monthlyTotal; private set => SetProperty(ref _monthlyTotal, value); }
    public string MonthlySub { get => _monthlySub; private set => SetProperty(ref _monthlySub, value); }
    public string IncomeTotal { get => _incomeTotal; private set => SetProperty(ref _incomeTotal, value); }
    public string IncomeSub { get => _incomeSub; private set => SetProperty(ref _incomeSub, value); }
    public string CommittedText { get => _committedText; private set => SetProperty(ref _committedText, value); }
    public string GapText { get => _gapText; private set => SetProperty(ref _gapText, value); }
    public string GapSub { get => _gapSub; private set => SetProperty(ref _gapSub, value); }
    /// <summary>True while monthly costs are higher than committed support.</summary>
    public bool GapOpen { get => _gapOpen; private set => SetProperty(ref _gapOpen, value); }

    protected override string[] WatchedCollections => [Collections.Budget, Collections.Partners, Collections.Settings];
    protected override BudgetRow CreateRow(BudgetEntry b) => new(b, SaveEntity);
    protected override string SearchText(BudgetRow r) => $"{r.Model.Label} {r.Model.Category} {r.Model.Notes} {r.Model.Kind}";

    public override void RefreshView()
    {
        base.RefreshView();
        foreach (var v in new[] { SetupView, MonthlyView, IncomeView })
        {
            try
            {
                if (v.IsEditingItem) v.CommitEdit();
                v.Refresh();
            }
            catch (InvalidOperationException) { }
        }
    }

    double Rate()
    {
        try { var r = Store.SharedSettings.NzdPerEur; return r is > 0 ? r.Value : 1.85; } catch { return 1.85; }
    }

    static long ToEur(BudgetEntry b, double rate) => b.Currency == "NZD" ? (long)Math.Round(b.AmountCents / rate) : b.AmountCents;
    static long PerMonth(BudgetEntry b, double rate) => b.Recurrence == "yearly" ? ToEur(b, rate) / 12 : ToEur(b, rate);

    protected override void Recompute()
    {
        var rate = Rate();
        var rows = Rows.Select(r => r.Model).ToList();

        var setup = rows.Where(b => BudgetRow.SectionOf(b) == "setup").ToList();
        long setupEur = setup.Sum(b => ToEur(b, rate));
        long setupOpen = setup.Where(b => b.Paid != true).Sum(b => ToEur(b, rate));
        SetupTotal = Fmt.Euro(setupEur);
        SetupSub = $"NZ$ {Nzd(setupEur, rate)} · {Fmt.Euro(setupOpen)} still to pay";

        var monthly = rows.Where(b => BudgetRow.SectionOf(b) == "monthly").ToList();
        long monthEur = monthly.Sum(b => PerMonth(b, rate));
        MonthlyTotal = Fmt.Euro(monthEur);
        MonthlySub = $"NZ$ {Nzd(monthEur, rate)} per month in Queenstown";

        var income = rows.Where(b => b.Kind == "income").ToList();
        long incMonthly = income.Where(b => b.Recurrence is "monthly" or "yearly").Sum(b => PerMonth(b, rate));
        long incOnce = income.Where(b => b.Recurrence is not ("monthly" or "yearly")).Sum(b => ToEur(b, rate));
        IncomeTotal = Fmt.Euro(incOnce);
        IncomeSub = $"one-off · plus {Fmt.Euro(incMonthly)} / month";

        long committed = 0;
        try { committed = Store.GetSummary().CommittedMonthlyCents; } catch { }
        CommittedText = Fmt.Euro(committed);
        long gap = monthEur - committed;
        GapOpen = gap > 0;
        GapText = gap > 0 ? Fmt.Euro(gap) : "€ 0";
        GapSub = gap > 0 ? $"still needed each month (NZ$ {Nzd(gap, rate)})" : $"covered, {Fmt.Euro(-gap)} spare";

        Subtitle = $"{Rows.Count} lines · setup {Fmt.Euro(setupEur)} · {Fmt.Euro(monthEur)} / month · 1 EUR = {rate:0.00} NZD";
    }

    static string Nzd(long eurCents, double rate) => (eurCents * rate / 100).ToString("N0", Fmt.Nl);

    public BudgetRow New(string section = "setup") => Add(section switch
    {
        "monthly" => new BudgetEntry { Label = "New monthly cost", Kind = "expense", Phase = "monthly", Recurrence = "monthly", Currency = "NZD" },
        "income" => new BudgetEntry { Label = "New income", Kind = "income", Recurrence = "once", Currency = "EUR" },
        _ => new BudgetEntry { Label = "New setup cost", Kind = "expense", Phase = "setup", Recurrence = "once", Currency = "EUR" },
    });
}
