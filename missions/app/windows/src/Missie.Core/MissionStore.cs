using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Data.Sqlite;

namespace Missie.Core;

/// <summary>
/// Local-first store: SQLite at {dataDir}/missie.db with an in-memory copy of every record (raw JSON),
/// plus the vault folder {dataDir}/vault. All public members are safe to call from the UI thread and a
/// background sync at the same time (one lock around the cache and the connection).
/// Entities handed out are fresh copies: edit them, then Save.
/// </summary>
public sealed partial class MissionStore : IMissionStore, IDisposable
{
    private sealed class Rec
    {
        public required string Id;
        public required string Collection;
        public required string Data;
        public DateTimeOffset UpdatedAt;
        public DateTimeOffset? DeletedAt;
        public long? Seq;
        public bool Dirty;
    }

    private readonly object _gate = new();
    private readonly string _vaultDir;
    private readonly ISecretStore _secrets;
    private readonly HttpClient _http;
    private readonly bool _ownsHttp;
    private readonly SqliteConnection _db;
    private readonly Dictionary<string, Rec> _recs = new(StringComparer.Ordinal);
    private LocalSettings _local;

    /// <param name="dataDir">Folder for missie.db and vault\ (desktop: %LOCALAPPDATA%\Missie).</param>
    /// <param name="secrets">Where the device token is kept.</param>
    /// <param name="http">Optional HttpClient (tests pass a fake handler).</param>
    public MissionStore(string dataDir, ISecretStore secrets, HttpClient? http = null)
    {
        _vaultDir = Path.Combine(dataDir, "vault");
        Directory.CreateDirectory(_vaultDir);
        _secrets = secrets;
        _ownsHttp = http is null;
        _http = http ?? new HttpClient { Timeout = TimeSpan.FromSeconds(100) };

        _db = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = Path.Combine(dataDir, "missie.db"),
            Pooling = false,
        }.ToString());
        _db.Open();
        Exec("PRAGMA journal_mode=WAL;");
        Exec("""
            CREATE TABLE IF NOT EXISTS records(
              id TEXT PRIMARY KEY, collection TEXT NOT NULL, data TEXT NOT NULL,
              updated_at TEXT NOT NULL, deleted_at TEXT NULL, seq INTEGER NULL, dirty INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX IF NOT EXISTS records_collection ON records(collection);
            CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT);
            CREATE TABLE IF NOT EXISTS files(
              file_id TEXT PRIMARY KEY, file_name TEXT NULL, mime_type TEXT NULL, sha256 TEXT NULL,
              size_bytes INTEGER NULL, uploaded INTEGER NOT NULL DEFAULT 0);
            """);

        using (var cmd = _db.CreateCommand())
        {
            cmd.CommandText = "SELECT id, collection, data, updated_at, deleted_at, seq, dirty FROM records";
            using var r = cmd.ExecuteReader();
            while (r.Read())
            {
                var rec = new Rec
                {
                    Id = r.GetString(0),
                    Collection = r.GetString(1),
                    Data = r.GetString(2),
                    UpdatedAt = MissieJson.ParseTime(r.GetString(3)),
                    DeletedAt = r.IsDBNull(4) ? null : MissieJson.ParseTime(r.GetString(4)),
                    Seq = r.IsDBNull(5) ? null : r.GetInt64(5),
                    Dirty = r.GetInt64(6) != 0,
                };
                _recs[rec.Id] = rec;
            }
        }

        _local = LoadLocal();
        _syncState = IsLoggedIn ? SyncState.Idle : SyncState.NotConfigured;
    }

    public event EventHandler<string?>? Changed;
    public event EventHandler? SyncStatusChanged;

    private void RaiseChanged(string? collection) => Changed?.Invoke(this, collection);
    private void RaiseSync() => SyncStatusChanged?.Invoke(this, EventArgs.Empty);

    // ---- SQL helpers (call inside _gate) -------------------------------------------------------

    private void Exec(string sql, params (string, object?)[] args)
    {
        using var cmd = _db.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (n, v) in args) cmd.Parameters.AddWithValue(n, v ?? DBNull.Value);
        cmd.ExecuteNonQuery();
    }

    private object? Scalar(string sql, params (string, object?)[] args)
    {
        using var cmd = _db.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (n, v) in args) cmd.Parameters.AddWithValue(n, v ?? DBNull.Value);
        var o = cmd.ExecuteScalar();
        return o is DBNull ? null : o;
    }

    private void Persist(Rec r) => Exec(
        """
        INSERT INTO records(id, collection, data, updated_at, deleted_at, seq, dirty) VALUES($id,$c,$d,$u,$del,$s,$dirty)
        ON CONFLICT(id) DO UPDATE SET collection=$c, data=$d, updated_at=$u, deleted_at=$del, seq=$s, dirty=$dirty
        """,
        ("$id", r.Id), ("$c", r.Collection), ("$d", r.Data), ("$u", MissieJson.Iso(r.UpdatedAt)),
        ("$del", r.DeletedAt is { } d ? MissieJson.Iso(d) : null), ("$s", r.Seq), ("$dirty", r.Dirty ? 1 : 0));

    private void InTransaction(Action a)
    {
        using var tx = _db.BeginTransaction();
        a();
        tx.Commit();
    }

    private static Entity? ToEntity(Rec r)
    {
        Entity? e;
        try { e = MissieJson.DeserializeData(r.Collection, r.Data); }
        catch (Exception ex) when (ex is JsonException or FormatException or InvalidOperationException) { return null; }
        if (e is null) return null;
        e.Id = r.Id;
        e.UpdatedAt = r.UpdatedAt;
        e.DeletedAt = r.DeletedAt;
        return e;
    }

    private List<Entity> LiveEntities(string? collection = null)
    {
        List<Rec> recs;
        lock (_gate) recs = _recs.Values.Where(r => r.DeletedAt is null && (collection is null || r.Collection == collection)).ToList();
        var list = new List<Entity>(recs.Count);
        foreach (var r in recs) if (ToEntity(r) is { } e) list.Add(e);
        return list;
    }

    // ---- Read --------------------------------------------------------------------------------

    public IReadOnlyList<T> All<T>() where T : Entity, new() =>
        LiveEntities(Collections.Of<T>()).OfType<T>()
            .OrderBy(e => e.Order ?? double.MaxValue)
            .ThenBy(e => e.DisplayTitle, StringComparer.CurrentCultureIgnoreCase)
            .ToList();

    public T? Get<T>(string id) where T : Entity, new() => Get(id) as T;

    public Entity? Get(string id)
    {
        if (string.IsNullOrEmpty(id)) return null;
        Rec? r;
        lock (_gate) r = _recs.GetValueOrDefault(id);
        return r is null || r.DeletedAt is not null ? null : ToEntity(r);
    }

    // ---- Write -------------------------------------------------------------------------------

    public void Save<T>(T entity) where T : Entity => SaveMany([entity]);

    public void SaveMany<T>(IEnumerable<T> entities) where T : Entity
    {
        var list = entities.ToList();
        if (list.Count == 0) return;
        var now = MissieJson.UtcNowMs();
        lock (_gate)
        {
            InTransaction(() =>
            {
                foreach (var e in list) WriteLocked(e, now);
            });
        }
        var cols = list.Select(e => e.Collection).Distinct().ToList();
        RaiseChanged(cols.Count == 1 ? cols[0] : null);
        RaiseSync();
    }

    /// <summary>Stores an entity with the given UpdatedAt and marks it dirty. Inside _gate.</summary>
    private void WriteLocked(Entity e, DateTimeOffset updatedAt)
    {
        e.Id = string.IsNullOrWhiteSpace(e.Id) ? Entity.NewId() : e.Id.Trim().ToLowerInvariant();
        e.UpdatedAt = updatedAt;
        var rec = new Rec
        {
            Id = e.Id,
            Collection = e.Collection,
            Data = MissieJson.SerializeData(e),
            UpdatedAt = updatedAt,
            DeletedAt = e.DeletedAt,
            Seq = _recs.GetValueOrDefault(e.Id)?.Seq,
            Dirty = true,
        };
        _recs[rec.Id] = rec;
        Persist(rec);
    }

    public void Delete(string id)
    {
        string collection;
        lock (_gate)
        {
            if (!_recs.TryGetValue(id, out var r) || r.DeletedAt is not null) return;
            var now = MissieJson.UtcNowMs();
            r.DeletedAt = now;
            r.UpdatedAt = now;
            r.Dirty = true;
            Persist(r);
            collection = r.Collection;
        }
        RaiseChanged(collection);
        RaiseSync();
    }

    // ---- Smart links -------------------------------------------------------------------------

    public IReadOnlyList<Entity> Backlinks(string id) =>
        LiveEntities().Where(e => e.Id != id && (
                e.Links?.Any(l => l.Id == id) == true ||
                e is TaskItem t && (t.ChecklistId == id || t.ParentTaskId == id) ||
                e is Partner p && p.ContactId == id ||
                e is Gift g && g.PartnerId == id))
            .OrderBy(e => e.Collection, StringComparer.Ordinal)
            .ThenBy(e => e.Order ?? double.MaxValue)
            .ThenBy(e => e.DisplayTitle, StringComparer.CurrentCultureIgnoreCase)
            .ToList();

    public void Link(Entity a, Entity b)
    {
        if (a.Id == b.Id) return;
        AddLink(a, b);
        AddLink(b, a);
        SaveMany([a, b]);
    }

    private static void AddLink(Entity from, Entity to)
    {
        from.Links ??= [];
        var existing = from.Links.FirstOrDefault(l => l.Id == to.Id);
        if (existing is null) from.Links.Add(new Link { Collection = to.Collection, Id = to.Id, Label = to.DisplayTitle });
        else { existing.Collection = to.Collection; existing.Label = to.DisplayTitle; }
    }

    public void Unlink(Entity a, Entity b)
    {
        a.Links?.RemoveAll(l => l.Id == b.Id);
        b.Links?.RemoveAll(l => l.Id == a.Id);
        if (a.Links is { Count: 0 }) a.Links = null;
        if (b.Links is { Count: 0 }) b.Links = null;
        SaveMany([a, b]);
    }

    public IReadOnlyList<Entity> Linked(Entity a)
    {
        var result = new List<Entity>();
        foreach (var l in a.Links ?? [])
            if (Get(l.Id) is { } e && result.All(x => x.Id != e.Id)) result.Add(e);
        return result;
    }

    // ---- Search ------------------------------------------------------------------------------

    private static readonly string[] SearchFields = ["Title", "Name", "Label", "Notes", "Body", "Description"];

    public IReadOnlyList<SearchHit> Search(string query, int limit = 50)
    {
        query = query?.Trim() ?? "";
        if (query.Length == 0) return [];
        var hits = new List<(int Rank, SearchHit Hit)>();
        foreach (var e in LiveEntities())
        {
            var title = e.DisplayTitle ?? "";
            var ti = title.IndexOf(query, StringComparison.CurrentCultureIgnoreCase);
            if (ti >= 0)
            {
                hits.Add((ti == 0 ? 0 : 1, new SearchHit(e.Id, e.Collection, title, Snippet(title, ti, query.Length))));
                continue;
            }
            foreach (var name in SearchFields)
            {
                if (e.GetType().GetProperty(name)?.GetValue(e) is not string text || text.Length == 0) continue;
                var i = text.IndexOf(query, StringComparison.CurrentCultureIgnoreCase);
                if (i < 0) continue;
                hits.Add((2, new SearchHit(e.Id, e.Collection, title, Snippet(text, i, query.Length))));
                break;
            }
        }
        return hits.OrderBy(h => h.Rank).ThenBy(h => h.Hit.Title, StringComparer.CurrentCultureIgnoreCase)
            .Take(limit).Select(h => h.Hit).ToList();
    }

    private static string Snippet(string text, int index, int length, int context = 40)
    {
        var start = Math.Max(0, index - context);
        var end = Math.Min(text.Length, index + length + context);
        var s = text[start..end].ReplaceLineEndings(" ").Trim();
        return (start > 0 ? "…" : "") + s + (end < text.Length ? "…" : "");
    }

    // ---- Settings ----------------------------------------------------------------------------

    /// <summary>Shared settings and seed data created locally get this old timestamp, so a copy that already
    /// exists on the server (made or edited on another device) always wins the first sync.</summary>
    internal static readonly DateTimeOffset SeedTime = new(2026, 10, 8, 0, 0, 0, TimeSpan.Zero); // = SEED_UPDATED_AT in server/seed/seed.mjs

    public SettingRecord SharedSettings
    {
        get
        {
            if (Get<SettingRecord>(SettingRecord.MainId) is { } s) return s;
            var other = All<SettingRecord>().FirstOrDefault(x => x.Key == "main");
            if (other is not null) return other;
            var created = new SettingRecord { Id = SettingRecord.MainId };
            lock (_gate)
            {
                if (_recs.ContainsKey(created.Id)) return created; // tombstoned: hand out defaults, don't resurrect
                InTransaction(() => WriteLocked(created, SeedTime));
            }
            RaiseChanged(Collections.Settings);
            RaiseSync();
            return created;
        }
    }

    public LocalSettings LocalSettings
    {
        get { lock (_gate) return Clone(_local); }
    }

    public void SaveLocalSettings(LocalSettings settings)
    {
        UpdateLocal(s =>
        {
            s.ApiUrl = settings.ApiUrl;
            s.Email = settings.Email;
            s.DeviceName = settings.DeviceName;
            s.AutoSync = settings.AutoSync;
            s.Cursor = settings.Cursor;
            s.LastSync = settings.LastSync;
        });
        RaiseSync();
    }

    private LocalSettings LoadLocal()
    {
        var json = Scalar("SELECT value FROM meta WHERE key='local'") as string;
        if (json is null) return new LocalSettings();
        try { return JsonSerializer.Deserialize<LocalSettings>(json, MissieJson.Options) ?? new LocalSettings(); }
        catch (JsonException) { return new LocalSettings(); }
    }

    private static LocalSettings Clone(LocalSettings s) =>
        JsonSerializer.Deserialize<LocalSettings>(JsonSerializer.Serialize(s, MissieJson.Options), MissieJson.Options)!;

    private void UpdateLocal(Action<LocalSettings> change)
    {
        lock (_gate)
        {
            var s = Clone(_local);
            change(s);
            _local = s;
            Exec("INSERT INTO meta(key, value) VALUES('local', $v) ON CONFLICT(key) DO UPDATE SET value=$v",
                ("$v", JsonSerializer.Serialize(_local, MissieJson.Options)));
        }
    }

    // ---- Summary -----------------------------------------------------------------------------

    public Summary GetSummary(DateOnly? today = null)
    {
        var d = today ?? DateOnly.FromDateTime(DateTime.Now);
        var settings = SharedSettings;
        var rate = settings.NzdPerEur is > 0 ? settings.NzdPerEur.Value : 1.85;
        long ToEur(long cents, string? currency) =>
            string.Equals(currency, "NZD", StringComparison.OrdinalIgnoreCase) ? (long)Math.Round(cents / rate) : cents;

        var tasks = All<TaskItem>();
        var open = tasks.Where(t => !t.IsDone).ToList();
        var partners = All<Partner>();
        var supporting = partners.Where(p => p.CountsAsSupport).ToList();
        var sell = All<SellItem>();
        var packing = All<PackingItem>().Where(p => p.Bag != "leave").ToList();
        var docs = All<DocumentItem>();

        return new Summary(
            d, settings.DepartureDate, settings.DepartureDate is { } dep ? dep.DayNumber - d.DayNumber : null,
            TasksOpen: open.Count,
            TasksOverdue: open.Count(t => t.DueDate < d),
            TasksDueThisWeek: open.Count(t => t.DueDate >= d && t.DueDate <= d.AddDays(6)),
            TasksDone: tasks.Count(t => t.IsDone),
            CommittedMonthlyCents: supporting.Sum(p => ToEur(p.MonthlyCents ?? 0, p.Currency)),
            TargetMonthlyCents: settings.SupportTargetMonthlyCents ?? 0,
            MinimumMonthlyCents: settings.SupportMinimumMonthlyCents ?? 0,
            Partners: supporting.Count,
            FollowUpsDue: partners.Count(p => p.NextFollowUp <= d),
            SellItemsLeft: sell.Count(s => s.Status is not ("sold" or "given-away" or "keep")),
            SoldCents: sell.Where(s => s.Status == "sold").Sum(s => ToEur(s.SoldCents ?? 0, s.Currency)),
            PackingTotal: packing.Count,
            PackingPacked: packing.Count(p => p.Packed),
            DocumentsTotal: docs.Count,
            DocumentsMissingFile: docs.Count(x => string.IsNullOrEmpty(x.FileId)),
            DocumentsExpiringSoon: docs.Count(x => x.ExpiresAt is { } e && e <= d.AddDays(180)));
    }

    // ---- Seed --------------------------------------------------------------------------------

    public void SeedIfEmpty()
    {
        lock (_gate) if (_recs.Count > 0) return;
        var seed = SeedData.Build();
        lock (_gate)
        {
            if (_recs.Count > 0) return;
            InTransaction(() =>
            {
                foreach (var e in seed) WriteLocked(e, SeedTime);
            });
        }
        RaiseChanged(null);
        RaiseSync();
    }

    // ---- CSV ---------------------------------------------------------------------------------

    public string ExportCsv<T>() where T : Entity, new() => Csv.Export(All<T>());

    public int ImportCsv<T>(string csv) where T : Entity, new()
    {
        var items = Csv.Import<T>(csv, Get<T>, Get);
        SaveMany(items);
        return items.Count;
    }

    // ---- Backup ------------------------------------------------------------------------------

    public void ExportBackup(string path)
    {
        List<Rec> recs;
        lock (_gate) recs = _recs.Values.Where(r => r.DeletedAt is null)
            .OrderBy(r => r.Collection, StringComparer.Ordinal).ThenBy(r => r.Id, StringComparer.Ordinal).ToList();
        var arr = new JsonArray();
        foreach (var r in recs)
            arr.Add(new JsonObject
            {
                ["id"] = r.Id,
                ["collection"] = r.Collection,
                ["updatedAt"] = MissieJson.Iso(r.UpdatedAt),
                ["deletedAt"] = null,
                ["data"] = JsonNode.Parse(r.Data),
            });
        var root = new JsonObject { ["exportedAt"] = MissieJson.Iso(DateTimeOffset.UtcNow), ["records"] = arr };
        var dir = Path.GetDirectoryName(Path.GetFullPath(path));
        if (dir is not null) Directory.CreateDirectory(dir);
        File.WriteAllText(path, root.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }

    public void Dispose()
    {
        lock (_gate) _db.Dispose();
        if (_ownsHttp) _http.Dispose();
    }

    internal static string AppVersion =>
        typeof(MissionStore).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion?.Split('+')[0]
        ?? typeof(MissionStore).Assembly.GetName().Version?.ToString(3) ?? "1.0.0";
}
