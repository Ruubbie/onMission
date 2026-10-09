using System.Collections.ObjectModel;
using System.Windows.Media;
using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class NoteRow : EntityRow<Note>
{
    public NoteRow(Note n, Action<Entity> save) : base(n, save) { }

    public string Title { get => Model.Title; set => Set(Model.Title, value ?? "", v => Model.Title = v); }
    public string Kind { get => Model.Kind ?? "note"; set => Set(Model.Kind ?? "note", value ?? "note", v => Model.Kind = v); }
    public string? Area { get => Model.Area; set => Set(Model.Area, Fmt.Opt(value), v => Model.Area = v); }
    public bool Pinned { get => Model.Pinned == true; set => Set(Model.Pinned == true, value, v => Model.Pinned = v ? true : null); }
    public string? Body { get => Model.Body; set => Set(Model.Body, Fmt.Opt(value), v => Model.Body = v); }

    public bool IsPrayer => Model.Kind == "prayer";
    public bool Answered => Model.AnsweredAt is not null;
    public string AnsweredText => Model.AnsweredAt is { } d ? $"Answered {Fmt.NiceDate(d)}" : "";
    public Brush KindBrush => Palette.Get(Lists.NoteKindColor(Model.Kind));
    public string Preview
    {
        get
        {
            var b = (Model.Body ?? "").Replace("\r", "").Split('\n').Select(l => l.Trim().TrimStart('#', '-', '*', '>', ' ')).FirstOrDefault(l => l.Length > 0) ?? "";
            return b.Length > 90 ? b[..90] + "…" : b;
        }
    }
    public string When => Model.UpdatedAt == default ? "" : Model.UpdatedAt.ToLocalTime().ToString("d MMM", Fmt.Nl);

    public void SetAnswered(DateOnly? d) { Set(Model.AnsweredAt, d, v => Model.AnsweredAt = v, nameof(Answered)); }

    protected override void OnModelChanged(string? name) =>
        Notify(nameof(IsPrayer), nameof(Answered), nameof(AnsweredText), nameof(KindBrush), nameof(Preview), nameof(When));
}

public sealed class NotesViewModel : EntityListViewModel<Note, NoteRow>
{
    string? _kind;
    string _subtitle = "";

    public NotesViewModel()
    {
        KindChips.Add(new FilterChip(null, "All", "Paper") { IsActive = true });
        foreach (var k in Lists.NoteKinds) KindChips.Add(new FilterChip(k, k, Lists.NoteKindColor(k)));
        KindChips.Add(new FilterChip("open-prayer", "Prayer, not answered yet", "Purple"));
    }

    public ObservableCollection<FilterChip> KindChips { get; } = new();
    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }

    protected override NoteRow CreateRow(Note n) => new(n, SaveEntity);
    protected override string SearchText(NoteRow r) => $"{r.Model.Title} {r.Model.Body} {r.Model.Area}";

    /// <summary>Pinned first, then most recently changed.</summary>
    protected override IEnumerable<Note> Load() =>
        Store.All<Note>().OrderByDescending(n => n.Pinned == true).ThenByDescending(n => n.UpdatedAt);

    protected override bool Include(NoteRow r) => MatchesSearch(r) && _kind switch
    {
        null => true,
        "open-prayer" => r.IsPrayer && !r.Answered,
        var k => (r.Model.Kind ?? "note") == k,
    };

    public void ToggleChip(FilterChip chip)
    {
        _kind = chip.Key == _kind ? null : chip.Key;
        foreach (var c in KindChips) c.IsActive = c.Key == _kind;
        RefreshView();
    }

    protected override void ClearExtraFilters()
    {
        _kind = null;
        foreach (var c in KindChips) c.IsActive = c.Key is null;
    }

    protected override void Recompute()
    {
        foreach (var c in KindChips)
            c.Count = c.Key switch
            {
                null => Rows.Count,
                "open-prayer" => Rows.Count(r => r.IsPrayer && !r.Answered),
                var k => Rows.Count(r => (r.Model.Kind ?? "note") == k),
            };
        int prayers = Rows.Count(r => r.IsPrayer), answered = Rows.Count(r => r.IsPrayer && r.Answered);
        Subtitle = $"{Rows.Count} notes · {Rows.Count(r => r.Pinned)} pinned · {answered} of {prayers} prayer notes answered";
    }

    /// <summary>New note of the active kind (prayer filter makes a prayer note). The text is left for you to write.</summary>
    public NoteRow New()
    {
        var kind = _kind switch { null => "note", "open-prayer" => "prayer", var k => k };
        var title = kind switch
        {
            "prayer" => "New prayer note",
            "journal" => $"Journal {Fmt.NiceDate(Fmt.Today)}",
            "meeting" => $"Meeting {Fmt.NiceDate(Fmt.Today)}",
            "idea" => "New idea",
            _ => "New note",
        };
        var row = Add(new Note { Title = title, Kind = kind });
        // Put the new note on top of the list.
        var at = Rows.IndexOf(row);
        if (at > 0) Rows.Move(at, 0);
        return row;
    }

    public void ToggleAnswered()
    {
        if (Selected is not { } row) return;
        row.SetAnswered(row.Answered ? null : Fmt.Today);
    }
}
