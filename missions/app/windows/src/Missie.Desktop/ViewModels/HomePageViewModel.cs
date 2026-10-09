using System.Collections.ObjectModel;
using System.Globalization;
using System.Windows;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Missie.Core;
using Missie.Desktop.Services;
using Missie.Desktop.Theme;

namespace Missie.Desktop.ViewModels;

public sealed partial class HomeTaskRow : ObservableObject
{
    private readonly TaskItem _task;
    private readonly Action<TaskItem> _save;

    public HomeTaskRow(TaskItem task, DateOnly today, string? checklistTitle, Action<TaskItem> save)
    {
        _task = task;
        _save = save;
        _isDone = task.IsDone;
        ChecklistTitle = checklistTitle;
        if (task.DueDate is { } d)
        {
            IsOverdue = d < today && !task.IsDone;
            var days = d.DayNumber - today.DayNumber;
            DueText = days switch
            {
                0 => "today",
                1 => "tomorrow",
                -1 => "yesterday",
                < -1 => $"{-days} days late",
                < 7 => d.ToString("dddd", CultureInfo.GetCultureInfo("en-GB")).ToLowerInvariant(),
                _ => d.ToString("d MMM", CentsToEuroConverter.Nl),
            };
        }
    }

    public string Id => _task.Id;
    public string Title => _task.Title;
    public string? Area => _task.Area;
    public bool IsHigh => _task.Priority == "high";
    public string? DueText { get; }
    public bool IsOverdue { get; }
    public string? ChecklistTitle { get; }
    public string? WaitingOn => string.IsNullOrWhiteSpace(_task.WaitingOn) ? null : "waiting on " + _task.WaitingOn;

    [ObservableProperty] private bool _isDone;

    partial void OnIsDoneChanged(bool value)
    {
        _task.Status = value ? "done" : "todo";
        _task.CompletedAt = value ? DateTimeOffset.UtcNow : null;
        _save(_task);
    }
}

public sealed record ChecklistCard(string Id, string Title, string Subtitle, string? Detail, string Glyph, Brush Accent, double? Progress, string? Badge);

public sealed record FollowUpRow(string Id, string Name, string WhenText, string Stage, bool IsLate);

public sealed partial class HomePageViewModel : ObservableObject
{
    private readonly IMissionStore _store = AppServices.Store;
    private bool _saving;

    public ObservableCollection<HomeTaskRow> TodayTasks { get; } = [];
    public ObservableCollection<ChecklistCard> Checklists { get; } = [];
    public ObservableCollection<FollowUpRow> FollowUps { get; } = [];

    [ObservableProperty] private string _headline = "Queenstown.";
    [ObservableProperty] private string _subHeadline = "";
    [ObservableProperty] private string _quickText = "";
    [ObservableProperty] private string _todayCount = "";

    // Support meter
    [ObservableProperty] private string _committedText = "€ 0";
    [ObservableProperty] private string _targetText = "";
    [ObservableProperty] private string _minimumText = "";
    [ObservableProperty] private string _supportStatus = "";
    [ObservableProperty] private Brush _supportBrush = Look.Pink;
    [ObservableProperty] private GridLength _committedStar = new(0, GridUnitType.Star);
    [ObservableProperty] private GridLength _restStar = new(1, GridUnitType.Star);
    [ObservableProperty] private GridLength _minStar = new(3, GridUnitType.Star);
    [ObservableProperty] private GridLength _afterMinStar = new(1, GridUnitType.Star);
    [ObservableProperty] private string _partnersText = "";

    // Stat tiles
    [ObservableProperty] private string _sellingText = "";
    [ObservableProperty] private string _sellingDetail = "";
    [ObservableProperty] private string _packingText = "";
    [ObservableProperty] private double? _packingProgress;
    [ObservableProperty] private string _documentsText = "";
    [ObservableProperty] private string _documentsDetail = "";
    [ObservableProperty] private string? _documentsBadge;

    public void Reload()
    {
        if (_saving) return;
        var today = DateOnly.FromDateTime(DateTime.Today);
        Summary s;
        try { s = _store.GetSummary(today); }
        catch (Exception ex) { AppLog.Write("GetSummary failed", ex); return; }

        // Headline
        Headline = s.DaysToDeparture switch
        {
            null => "Ready for Queenstown.",
            > 1 => $"Queenstown in {s.DaysToDeparture} days.",
            1 => "Queenstown tomorrow!",
            0 => "Queenstown today!",
            _ => "Kia ora, Queenstown.",
        };
        var parts = new List<string>();
        if (s.DepartureDate is { } dep) parts.Add("Departure " + dep.ToString("ddd d MMM yyyy", CultureInfo.GetCultureInfo("en-GB")));
        parts.Add($"{s.TasksOpen} open tasks");
        if (s.TasksOverdue > 0) parts.Add($"{s.TasksOverdue} overdue");
        if (s.TasksDueThisWeek > 0) parts.Add($"{s.TasksDueThisWeek} due this week");
        SubHeadline = string.Join("  ·  ", parts);

        var tasks = _store.All<TaskItem>();
        var checklists = _store.All<Checklist>();
        var checklistTitles = checklists.ToDictionary(c => c.Id, c => c.Title);

        // Today: open & overdue or due within 7 days, plus what was finished today (so a tick doesn't vanish).
        var horizon = today.AddDays(7);
        var todayRows = tasks
            .Where(t => (!t.IsDone && t.DueDate is { } d && d <= horizon)
                        || (t.IsDone && t.CompletedAt is { } c && DateOnly.FromDateTime(c.LocalDateTime) == today && t.DueDate is not null))
            .OrderBy(t => t.IsDone)
            .ThenBy(t => t.DueDate)
            .ThenBy(t => t.Priority == "high" ? 0 : 1)
            .Take(40)
            .Select(t => new HomeTaskRow(t, today, t.ChecklistId is { } cid && checklistTitles.TryGetValue(cid, out var ct) ? ct : null, Save));
        Replace(TodayTasks, todayRows);
        var openToday = TodayTasks.Count(r => !r.IsDone);
        TodayCount = openToday == 0 ? "All clear for the next 7 days." : $"{openToday} to do · overdue and next 7 days";

        // Checklist folder cards
        var byChecklist = tasks.Where(t => t.ChecklistId is not null).GroupBy(t => t.ChecklistId!).ToDictionary(g => g.Key, g => g.ToList());
        Replace(Checklists, checklists.Where(c => c.Archived != true).Select(c =>
        {
            var list = byChecklist.TryGetValue(c.Id, out var l) ? l : [];
            var open = list.Count(t => !t.IsDone);
            var late = list.Count(t => !t.IsDone && t.DueDate is { } d && d < today);
            return new ChecklistCard(c.Id, c.Title,
                list.Count == 0 ? "empty" : $"{open} open · {list.Count} total",
                c.Phase is null ? null : PhaseLabel(c.Phase),
                Look.Glyph(c.Area ?? "checklists"), Look.Accent(c.Area ?? "checklists"),
                list.Count == 0 ? null : (double)(list.Count - open) / list.Count,
                late > 0 ? $"{late} late" : null);
        }));

        // Support
        var target = Math.Max(1, s.TargetMonthlyCents);
        var committed = Math.Max(0, s.CommittedMonthlyCents);
        var min = Math.Clamp(s.MinimumMonthlyCents, 0, target);
        CommittedText = Money.Whole(committed);
        TargetText = $"of {Money.Whole(s.TargetMonthlyCents)} / month target";
        MinimumText = $"minimum {Money.Whole(s.MinimumMonthlyCents)}";
        var shown = Math.Min(committed, target);
        CommittedStar = new GridLength(shown, GridUnitType.Star);
        RestStar = new GridLength(Math.Max(0, target - shown), GridUnitType.Star);
        MinStar = new GridLength(Math.Max(1, min), GridUnitType.Star);
        AfterMinStar = new GridLength(Math.Max(1, target - min), GridUnitType.Star);
        var pct = (int)Math.Round(100.0 * committed / target);
        (SupportStatus, SupportBrush) = committed >= s.TargetMonthlyCents ? ($"{pct}% · target reached", Look.Green)
            : committed >= s.MinimumMonthlyCents ? ($"{pct}% · minimum reached", Look.Lime)
            : ($"{pct}% · {Money.Whole(s.MinimumMonthlyCents - committed)} to minimum", Look.Yellow);
        PartnersText = $"{s.Partners} partners" + (s.FollowUpsDue > 0 ? $" · {s.FollowUpsDue} follow-ups due" : "");

        // Tiles
        SellingText = $"{s.SellItemsLeft} left to sell";
        SellingDetail = $"{Money.Whole(s.SoldCents)} sold so far";
        PackingText = $"{s.PackingPacked} / {s.PackingTotal} packed";
        PackingProgress = s.PackingTotal == 0 ? null : (double)s.PackingPacked / s.PackingTotal;
        DocumentsText = $"{s.DocumentsTotal} documents";
        var docParts = new List<string>();
        if (s.DocumentsExpiringSoon > 0) docParts.Add($"{s.DocumentsExpiringSoon} expiring soon");
        if (s.DocumentsMissingFile > 0) docParts.Add($"{s.DocumentsMissingFile} without file");
        DocumentsDetail = docParts.Count == 0 ? "all safe" : string.Join(" · ", docParts);
        DocumentsBadge = s.DocumentsExpiringSoon > 0 ? "CHECK" : null;

        // Follow-ups
        var followHorizon = today.AddDays(7);
        Replace(FollowUps, _store.All<Partner>()
            .Where(p => p.NextFollowUp is { } d && d <= followHorizon && p.Stage is not ("declined" or "paused"))
            .OrderBy(p => p.NextFollowUp)
            .Take(8)
            .Select(p =>
            {
                var d = p.NextFollowUp!.Value;
                var days = d.DayNumber - today.DayNumber;
                var when = days switch { 0 => "today", 1 => "tomorrow", < 0 => $"{-days}d late", _ => $"in {days} days" };
                return new FollowUpRow(p.Id, p.Name, when, p.Stage, days < 0);
            }));
    }

    private static string PhaseLabel(string phase) => phase switch
    {
        "now" => "now",
        "before-departure" => "before departure",
        "departure-week" => "departure week",
        "arrival" => "on arrival",
        "ongoing" => "ongoing",
        _ => phase,
    };

    private void Save(TaskItem t)
    {
        _saving = true;
        try { _store.Save(t); }
        finally { _saving = false; }
        Application.Current.Dispatcher.BeginInvoke(Reload, System.Windows.Threading.DispatcherPriority.Background);
    }

    private static void Replace<T>(ObservableCollection<T> target, IEnumerable<T> items)
    {
        target.Clear();
        foreach (var i in items) target.Add(i);
    }

    [RelayCommand]
    private void AddTask()
    {
        var text = QuickText?.Trim();
        if (string.IsNullOrEmpty(text) || text == "#") return;
        var task = QuickAddParser.Parse(text);
        _store.Save(task);
        QuickText = "";
        Reload();
    }

    [RelayCommand]
    private void Open(string? id)
    {
        if (!string.IsNullOrEmpty(id)) AppServices.Navigator.Open(id);
    }

    [RelayCommand]
    private void Go(string? page)
    {
        if (!string.IsNullOrEmpty(page)) AppServices.Navigator.Go(page);
    }
}
