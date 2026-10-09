using System.Collections.ObjectModel;
using System.IO;
using System.Windows.Media;
using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class DocRow : EntityRow<DocumentItem>
{
    public DocRow(DocumentItem d, Action<Entity> save) : base(d, save) { }

    public string Title { get => Model.Title; set => Set(Model.Title, value ?? "", v => Model.Title = v); }
    public string Kind { get => Model.Kind; set => Set(Model.Kind, value ?? "other", v => Model.Kind = v); }
    public string? Number { get => Model.Number; set => Set(Model.Number, Fmt.Opt(value), v => Model.Number = v); }
    public DateTime? IssuedDate
    {
        get => Fmt.ToDateTime(Model.IssuedAt);
        set => Set(Model.IssuedAt, Fmt.FromDateTime(value), v => Model.IssuedAt = v);
    }
    public DateTime? ExpiresDate
    {
        get => Fmt.ToDateTime(Model.ExpiresAt);
        set => Set(Model.ExpiresAt, Fmt.FromDateTime(value), v => Model.ExpiresAt = v);
    }
    public bool Offline { get => Model.Offline == true; set => Set(Model.Offline == true, value, v => Model.Offline = v); }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }

    public string Glyph => Lists.DocGlyph(Model.Kind);
    public Brush Accent => Palette.Get(Lists.DocColor(Model.Kind));
    public bool HasFile => !string.IsNullOrEmpty(Model.FileId);
    public string FileText => HasFile
        ? $"{Model.FileName ?? "file"}{(Model.SizeBytes is { } b ? $" · {Size(b)}" : "")}"
        : "No file yet: drop one on this page or use Replace file";

    public string MaskedNumber => Model.Number is { Length: > 0 } n
        ? (n.Length <= 4 ? new string('•', n.Length) : new string('•', Math.Min(8, n.Length - 4)) + n[^4..])
        : "no number";

    public int? DaysLeft => Model.ExpiresAt is { } d ? d.DayNumber - Fmt.Today.DayNumber : null;
    public bool Expired => DaysLeft is < 0;
    public bool ExpiringSoon => DaysLeft is >= 0 and < 180;
    public string ExpiryText => DaysLeft switch
    {
        null => "no expiry date",
        < 0 => $"EXPIRED {Fmt.NiceDate(Model.ExpiresAt)}",
        0 => "expires today",
        < 180 => $"expires in {DaysLeft} days",
        _ => $"valid until {Fmt.NiceDate(Model.ExpiresAt)}",
    };

    static string Size(long bytes) => bytes switch
    {
        < 1024 => $"{bytes} B",
        < 1024 * 1024 => $"{bytes / 1024.0:0} KB",
        _ => $"{bytes / 1024.0 / 1024.0:0.0} MB",
    };

    protected override void OnModelChanged(string? name) =>
        Notify(nameof(Glyph), nameof(Accent), nameof(HasFile), nameof(FileText), nameof(MaskedNumber), nameof(DaysLeft),
            nameof(Expired), nameof(ExpiringSoon), nameof(ExpiryText));
}

public sealed class DocumentsViewModel : EntityListViewModel<DocumentItem, DocRow>
{
    string? _chip;
    string _subtitle = "";
    bool _showNumber;

    public DocumentsViewModel()
    {
        Chips.Add(new FilterChip(null, "All", "Paper") { IsActive = true });
        Chips.Add(new FilterChip("soon", "Expiring < 6 months", "Pink"));
        Chips.Add(new FilterChip("nofile", "No file yet", "Sand"));
        Chips.Add(new FilterChip("offline", "Offline copy", "Green"));
    }

    public ObservableCollection<FilterChip> Chips { get; } = new();
    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }
    /// <summary>Reveals the document number in the detail panel.</summary>
    public bool ShowNumber { get => _showNumber; set => SetProperty(ref _showNumber, value); }

    protected override DocRow CreateRow(DocumentItem d) => new(d, SaveEntity);
    protected override string SearchText(DocRow r) => $"{r.Model.Title} {r.Model.Kind} {r.Model.FileName} {r.Model.Notes}";
    protected override IEnumerable<DocumentItem> Load() =>
        Store.All<DocumentItem>().OrderBy(d => d.ExpiresAt is null).ThenBy(d => d.ExpiresAt).ThenBy(d => d.Title, StringComparer.CurrentCultureIgnoreCase);

    protected override bool Include(DocRow r) => MatchesSearch(r) && _chip switch
    {
        "soon" => r.Expired || r.ExpiringSoon,
        "nofile" => !r.HasFile,
        "offline" => r.Offline,
        _ => true,
    };

    protected override void OnSelectedChanged() => ShowNumber = false;

    public void ToggleChip(FilterChip chip)
    {
        _chip = chip.Key == _chip ? null : chip.Key;
        foreach (var c in Chips) c.IsActive = c.Key == _chip;
        RefreshView();
    }

    protected override void ClearExtraFilters()
    {
        _chip = null;
        foreach (var c in Chips) c.IsActive = c.Key is null;
    }

    protected override void Recompute()
    {
        int soon = Rows.Count(r => r.Expired || r.ExpiringSoon), nofile = Rows.Count(r => !r.HasFile);
        foreach (var c in Chips)
            c.Count = c.Key switch { "soon" => soon, "nofile" => nofile, "offline" => Rows.Count(r => r.Offline), _ => Rows.Count };
        Subtitle = $"{Rows.Count} documents · {nofile} still without a file · {soon} expiring within 6 months";
    }

    public DocRow New() => Add(new DocumentItem { Title = "New document", Kind = "other" });

    /// <summary>Copies files into the vault (one document each, kind guessed from the name). Returns the last one.</summary>
    public DocRow? AddFiles(IEnumerable<string> paths)
    {
        string? lastId = null;
        foreach (var path in paths.Where(File.Exists))
        {
            Quiet(() =>
            {
                var doc = Store.AddFile(path, null, Lists.GuessDocKind(path));
                if (string.IsNullOrWhiteSpace(doc.Title))
                {
                    doc.Title = Path.GetFileNameWithoutExtension(path);
                    Store.Save(doc);
                }
                lastId = doc.Id;
            });
        }
        Reload();
        if (lastId is null) return null;
        SelectId(lastId);
        return Selected;
    }

    public void ReplaceFile(DocRow row, string path)
    {
        Quiet(() => Store.AddFile(path, row.Model, row.Model.Kind));
        Reload();
        row.RaiseAll();
    }

    /// <summary>Local path of the selected file, downloading it from the server first if needed.</summary>
    public async Task<string?> LocalPathAsync(DocRow row)
    {
        if (row.Model.FileId is not { } id) return null;
        try { return await Store.GetFilePathAsync(id); }
        catch (Exception ex) { PageActions.Error("Couldn't get the file", ex); return null; }
    }
}
