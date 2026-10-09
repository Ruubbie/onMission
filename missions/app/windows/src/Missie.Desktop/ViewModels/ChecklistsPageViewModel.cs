using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Missie.Core;
using Missie.Desktop.Controls;
using Missie.Desktop.Services;
using Missie.Desktop.Theme;

namespace Missie.Desktop.ViewModels;

/// <summary>One entry in the left list (a checklist, or the virtual "All tasks").</summary>
public sealed partial class ChecklistEntry : ObservableObject
{
    public const string AllId = "*all";
    public required string Id { get; init; }
    [ObservableProperty] private string _title = "";
    [ObservableProperty] private string _subtitle = "";
    [ObservableProperty] private string _glyph = Look.GChecklist;
    [ObservableProperty] private Brush _accent = Look.Grey;
    [ObservableProperty] private bool _isSelected;
    public bool IsAll => Id == AllId;
}

/// <summary>Editable task row. Every change is saved immediately through the owner.</summary>
public sealed partial class TaskRow : ObservableObject
{
    private readonly ChecklistsPageViewModel _owner;

    public TaskRow(TaskItem model, ChecklistsPageViewModel owner, string? checklistTitle)
    {
        Model = model;
        _owner = owner;
        ChecklistTitle = checklistTitle;
    }

    public TaskItem Model { get; }
    public string Id => Model.Id;
    public string? ChecklistTitle { get; }

    public static string[] PriorityOptions { get; } = ["low", "normal", "high"];
    public static string[] AreaOptions { get; } = ["", .. Areas.All];

    private void Changed(string? prop = null)
    {
        _owner.SaveTask(Model);
        if (prop is not null) OnPropertyChanged(prop);
    }

    public string Title
    {
        get => Model.Title;
        set { if (value != Model.Title && !string.IsNullOrWhiteSpace(value)) { Model.Title = value.Trim(); Changed(); } OnPropertyChanged(); }
    }

    public string? Notes
    {
        get => Model.Notes;
        set { if (value != Model.Notes) { Model.Notes = string.IsNullOrWhiteSpace(value) ? null : value; Changed(); OnPropertyChanged(nameof(HasNotes)); } }
    }

    public bool HasNotes => !string.IsNullOrWhiteSpace(Model.Notes);

    public string Status
    {
        get => Model.Status;
        set
        {
            if (value == Model.Status) return;
            Model.Status = value;
            Model.CompletedAt = Model.IsDone ? DateTimeOffset.UtcNow : null;
            Changed();
            OnPropertyChanged(nameof(Status));
            OnPropertyChanged(nameof(IsDone));
            OnPropertyChanged(nameof(IsTodo));
            OnPropertyChanged(nameof(IsDoing));
            OnPropertyChanged(nameof(IsWaiting));
            OnPropertyChanged(nameof(StatusAccent));
            OnPropertyChanged(nameof(IsOverdue));
        }
    }

    public bool IsDone { get => Model.IsDone; set => Status = value ? "done" : "todo"; }
    public bool IsTodo { get => Model.Status == "todo"; set { if (value) Status = "todo"; } }
    public bool IsDoing { get => Model.Status == "doing"; set { if (value) Status = "doing"; } }
    public bool IsWaiting { get => Model.Status == "waiting"; set { if (value) Status = "waiting"; } }
    public Brush StatusAccent => Look.Accent(Model.Status);

    public string Priority
    {
        get => Model.Priority ?? "normal";
        set { if (value != Model.Priority) { Model.Priority = value; Changed(); OnPropertyChanged(nameof(IsHigh)); } }
    }
    public bool IsHigh => Model.Priority == "high";

    public string Area
    {
        get => Model.Area ?? "";
        set
        {
            var v = string.IsNullOrEmpty(value) ? null : value;
            if (v == Model.Area) return;
            Model.Area = v;
            Changed();
            OnPropertyChanged(nameof(AreaLabel));
        }
    }
    public string AreaLabel => string.IsNullOrEmpty(Model.Area) ? "no area" : Model.Area!;

    public DateTime? DueDate
    {
        get => Model.DueDate?.ToDateTime(TimeOnly.MinValue);
        set
        {
            var v = value is { } dt ? DateOnly.FromDateTime(dt) : (DateOnly?)null;
            if (v == Model.DueDate) return;
            Model.DueDate = v;
            Changed();
            OnPropertyChanged(nameof(DueText));
            OnPropertyChanged(nameof(IsOverdue));
        }
    }

    public string? DueText
    {
        get
        {
            if (Model.DueDate is not { } d) return null;
            var today = DateOnly.FromDateTime(DateTime.Today);
            var days = d.DayNumber - today.DayNumber;
            return days switch
            {
                0 => "today",
                1 => "tomorrow",
                -1 => "yesterday",
                > 1 and < 7 => d.ToString("dddd", CultureInfo.GetCultureInfo("en-GB")).ToLowerInvariant(),
                _ => d.ToString("d MMM", CentsToEuroConverter.Nl),
            };
        }
    }
    public bool IsOverdue => !Model.IsDone && Model.DueDate is { } d && d < DateOnly.FromDateTime(DateTime.Today);

    public string? WaitingOn
    {
        get => Model.WaitingOn;
        set { if (value != Model.WaitingOn) { Model.WaitingOn = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); Changed(); } }
    }

    public string? SourceUrl
    {
        get => Model.SourceUrl;
        set { if (value != Model.SourceUrl) { Model.SourceUrl = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); Changed(); OnPropertyChanged(nameof(HasUrl)); } }
    }
    public bool HasUrl => !string.IsNullOrWhiteSpace(Model.SourceUrl);

    [ObservableProperty] private bool _isExpanded;

    [RelayCommand]
    private void ToggleExpanded() => IsExpanded = !IsExpanded;

    [RelayCommand]
    private void OpenUrl()
    {
        if (!HasUrl) return;
        var url = Model.SourceUrl!;
        if (!url.Contains("://")) url = "https://" + url;
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (Exception ex) { AppLog.Write("Open URL failed", ex); }
    }
}

public sealed partial class ChecklistsPageViewModel : ObservableObject
{
    private readonly IMissionStore _store = AppServices.Store;
    private bool _saving;

    public ObservableCollection<ChecklistEntry> Lists { get; } = [];
    public ObservableCollection<TaskRow> Tasks { get; } = [];
    public ICollectionView TasksView { get; }

    public static string[] PhaseOptions { get; } = ["", "now", "before-departure", "departure-week", "arrival", "ongoing"];
    public static string[] AreaOptions => TaskRow.AreaOptions;

    [ObservableProperty] private string _selectedId = ChecklistEntry.AllId;
    [ObservableProperty] private bool _showDone;
    [ObservableProperty] private string _newTaskText = "";
    [ObservableProperty] private string _countText = "";
    [ObservableProperty] private bool _isAll = true;

    /// <summary>Raised when the view should bring a row into view (smart link to a task).</summary>
    public event Action<TaskRow>? RowFocusRequested;

    public ChecklistsPageViewModel()
    {
        TasksView = CollectionViewSource.GetDefaultView(Tasks);
    }

    // ===== Selected checklist header (editable) =====
    private Checklist? _current;
    public Checklist? Current => _current;

    public string ListTitle
    {
        get => _current?.Title ?? "All tasks";
        set
        {
            if (_current is null || string.IsNullOrWhiteSpace(value) || value == _current.Title) return;
            _current.Title = value.Trim();
            SaveChecklist(_current);
        }
    }

    public string? ListDescription
    {
        get => _current?.Description;
        set
        {
            if (_current is null || value == _current.Description) return;
            _current.Description = string.IsNullOrWhiteSpace(value) ? null : value;
            SaveChecklist(_current);
        }
    }

    public string ListArea
    {
        get => _current?.Area ?? "";
        set
        {
            if (_current is null) return;
            var v = string.IsNullOrEmpty(value) ? null : value;
            if (v == _current.Area) return;
            _current.Area = v;
            SaveChecklist(_current);
        }
    }

    public string ListPhase
    {
        get => _current?.Phase ?? "";
        set
        {
            if (_current is null) return;
            var v = string.IsNullOrEmpty(value) ? null : value;
            if (v == _current.Phase) return;
            _current.Phase = v;
            SaveChecklist(_current);
        }
    }

    partial void OnSelectedIdChanged(string value) => LoadTasks();
    partial void OnShowDoneChanged(bool value) => LoadTasks();

    // ===== Loading =====

    public void Reload()
    {
        if (_saving) return;
        var tasks = _store.All<TaskItem>();
        var counts = tasks.Where(t => t.ChecklistId is not null).GroupBy(t => t.ChecklistId!)
            .ToDictionary(g => g.Key, g => (Open: g.Count(t => !t.IsDone), Total: g.Count()));
        var lists = _store.All<Checklist>().Where(c => c.Archived != true).ToList();

        Lists.Clear();
        var openAll = tasks.Count(t => !t.IsDone);
        Lists.Add(new ChecklistEntry
        {
            Id = ChecklistEntry.AllId, Title = "All tasks", Subtitle = $"{openAll} open · by area",
            Glyph = Look.GTask, Accent = Look.Yellow,
        });
        foreach (var c in lists)
        {
            var (open, total) = counts.TryGetValue(c.Id, out var x) ? x : (0, 0);
            Lists.Add(new ChecklistEntry
            {
                Id = c.Id, Title = c.Title, Subtitle = total == 0 ? "empty" : $"{open} open · {total} total",
                Glyph = Look.Glyph(c.Area ?? "checklists"), Accent = Look.Accent(c.Area ?? "checklists"),
            });
        }
        if (Lists.All(l => l.Id != SelectedId)) SelectedId = ChecklistEntry.AllId;
        LoadTasks();
    }

    private void LoadTasks()
    {
        foreach (var l in Lists) l.IsSelected = l.Id == SelectedId;
        IsAll = SelectedId == ChecklistEntry.AllId;
        _current = IsAll ? null : _store.Get<Checklist>(SelectedId);
        OnPropertyChanged(nameof(Current));
        OnPropertyChanged(nameof(ListTitle));
        OnPropertyChanged(nameof(ListDescription));
        OnPropertyChanged(nameof(ListArea));
        OnPropertyChanged(nameof(ListPhase));

        var expanded = Tasks.Where(t => t.IsExpanded).Select(t => t.Id).ToHashSet();
        var titles = _store.All<Checklist>().ToDictionary(c => c.Id, c => c.Title);
        var all = _store.All<TaskItem>().Where(t => t.ParentTaskId is null || IsAll);
        var mine = IsAll ? all : all.Where(t => t.ChecklistId == SelectedId);
        var list = mine.ToList();
        var openCount = list.Count(t => !t.IsDone);
        if (!ShowDone) list = list.Where(t => !t.IsDone).ToList();

        Tasks.Clear();
        foreach (var t in list)
        {
            var row = new TaskRow(t, this, IsAll && t.ChecklistId is { } cid && titles.TryGetValue(cid, out var ct) ? ct : null)
            {
                IsExpanded = expanded.Contains(t.Id),
            };
            Tasks.Add(row);
        }

        using (TasksView.DeferRefresh())
        {
            TasksView.GroupDescriptions.Clear();
            TasksView.SortDescriptions.Clear();
            if (IsAll)
            {
                TasksView.GroupDescriptions.Add(new PropertyGroupDescription(nameof(TaskRow.AreaLabel)));
                TasksView.SortDescriptions.Add(new SortDescription(nameof(TaskRow.AreaLabel), ListSortDirection.Ascending));
            }
        }
        CountText = $"{openCount} open" + (ShowDone ? $" · {list.Count} shown" : "");
    }

    // ===== Saving =====

    internal void SaveTask(TaskItem t)
    {
        _saving = true;
        try { _store.Save(t); }
        finally { _saving = false; }
        RefreshCounts();
    }

    private void SaveChecklist(Checklist c)
    {
        _saving = true;
        try { _store.Save(c); }
        finally { _saving = false; }
        var entry = Lists.FirstOrDefault(l => l.Id == c.Id);
        if (entry is not null)
        {
            entry.Title = c.Title;
            entry.Glyph = Look.Glyph(c.Area ?? "checklists");
            entry.Accent = Look.Accent(c.Area ?? "checklists");
        }
    }

    private void RefreshCounts()
    {
        var tasks = _store.All<TaskItem>();
        foreach (var l in Lists)
        {
            if (l.IsAll) { l.Subtitle = $"{tasks.Count(t => !t.IsDone)} open · by area"; continue; }
            var mine = tasks.Where(t => t.ChecklistId == l.Id).ToList();
            l.Subtitle = mine.Count == 0 ? "empty" : $"{mine.Count(t => !t.IsDone)} open · {mine.Count} total";
        }
        CountText = $"{Tasks.Count(t => !t.IsDone)} open" + (ShowDone ? $" · {Tasks.Count} shown" : "");
    }

    // ===== Commands =====

    [RelayCommand]
    private void SelectList(string? id)
    {
        if (id is not null) SelectedId = id;
    }

    [RelayCommand]
    public void NewChecklist()
    {
        var name = BrutalDialog.Prompt("New checklist", "Name", "", "Create");
        if (name is null) return;
        var c = new Checklist { Title = name, Phase = "now" };
        _saving = true;
        try { _store.Save(c); }
        finally { _saving = false; }
        Reload();
        SelectedId = c.Id;
    }

    [RelayCommand]
    private void DeleteChecklist()
    {
        if (_current is null) return;
        var tasks = _store.All<TaskItem>().Where(t => t.ChecklistId == _current.Id).ToList();
        if (!BrutalDialog.Confirm("Delete checklist?",
                $"“{_current.Title}” and its {tasks.Count} task(s) will be deleted on all devices.", "Delete", danger: true)) return;
        _saving = true;
        try
        {
            foreach (var t in tasks) _store.Delete(t.Id);
            _store.Delete(_current.Id);
        }
        finally { _saving = false; }
        SelectedId = ChecklistEntry.AllId;
        Reload();
    }

    [RelayCommand]
    private void ArchiveChecklist()
    {
        if (_current is null) return;
        _current.Archived = true;
        SaveChecklist(_current);
        SelectedId = ChecklistEntry.AllId;
        Reload();
    }

    [RelayCommand]
    public void AddTask()
    {
        var text = NewTaskText?.Trim();
        if (string.IsNullOrEmpty(text)) return;
        var t = QuickAddParser.Parse(text);
        if (!IsAll) t.ChecklistId = SelectedId;
        if (t.Area is null && _current?.Area is { } area) t.Area = area;
        var maxOrder = Tasks.Select(r => r.Model.Order ?? 0).DefaultIfEmpty(0).Max();
        t.Order = maxOrder + 10;
        _saving = true;
        try { _store.Save(t); }
        finally { _saving = false; }
        NewTaskText = "";
        var row = new TaskRow(t, this, null);
        Tasks.Add(row);
        RefreshCounts();
    }

    [RelayCommand]
    private void DeleteTask(TaskRow? row)
    {
        if (row is null) return;
        if (!BrutalDialog.Confirm("Delete task?", $"“{row.Title}” will be deleted on all devices.", "Delete", danger: true)) return;
        _saving = true;
        try { _store.Delete(row.Id); }
        finally { _saving = false; }
        Tasks.Remove(row);
        RefreshCounts();
    }

    [RelayCommand]
    private void MoveUp(TaskRow? row) => Move(row, -1);

    [RelayCommand]
    private void MoveDown(TaskRow? row) => Move(row, +1);

    private void Move(TaskRow? row, int delta)
    {
        if (row is null) return;
        // Move within the visible (possibly grouped) order.
        var visible = TasksView.Cast<TaskRow>().ToList();
        var i = visible.IndexOf(row);
        var j = i + delta;
        if (i < 0 || j < 0 || j >= visible.Count) return;
        if (IsAll && visible[j].AreaLabel != row.AreaLabel) return;

        // Normalise orders so swapping is meaningful, then swap the two.
        (visible[i], visible[j]) = (visible[j], visible[i]);
        var changed = new List<TaskItem>();
        for (var k = 0; k < visible.Count; k++)
        {
            var order = (k + 1) * 10.0;
            if (visible[k].Model.Order != order)
            {
                visible[k].Model.Order = order;
                changed.Add(visible[k].Model);
            }
        }
        _saving = true;
        try { _store.SaveMany(changed); }
        finally { _saving = false; }

        var a = Tasks.IndexOf(row);
        var b = Tasks.IndexOf(visible[i]);
        if (a >= 0 && b >= 0) Tasks.Move(a, b);
        TasksView.Refresh();
    }

    /// <summary>Smart link target: a checklist id selects it; a task id selects its checklist and opens the row.</summary>
    public void Select(string entityId)
    {
        var e = _store.Get(entityId);
        switch (e)
        {
            case Checklist c:
                if (c.Archived == true) { c.Archived = false; SaveChecklist(c); Reload(); }
                SelectedId = c.Id;
                break;
            case TaskItem t:
                var target = t.ChecklistId is { } cid && Lists.Any(l => l.Id == cid) ? cid : ChecklistEntry.AllId;
                if (t.IsDone) ShowDone = true;
                if (SelectedId != target) SelectedId = target; else LoadTasks();
                var row = Tasks.FirstOrDefault(r => r.Id == t.Id);
                if (row is not null)
                {
                    row.IsExpanded = true;
                    RowFocusRequested?.Invoke(row);
                }
                break;
        }
    }
}
