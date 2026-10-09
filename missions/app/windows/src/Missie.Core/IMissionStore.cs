namespace Missie.Core;

/// <summary>Keeps the device token safe. The desktop app uses Windows DPAPI; tests use a plain in-memory one.</summary>
public interface ISecretStore
{
    string? Get(string key);
    void Set(string key, string? value);
}

/// <summary>
/// The one thing the desktop app talks to. Everything is saved locally first (SQLite in %LOCALAPPDATA%\Missie),
/// then exchanged with the API server by <see cref="SyncAsync"/> (POST /v1/sync). Works fully offline.
/// </summary>
public interface IMissionStore
{
    /// <summary>Raised after any local save/delete or after a sync pulled changes. Arg = affected collection, or null for "many".</summary>
    event EventHandler<string?>? Changed;
    /// <summary>Raised when SyncState / PendingChanges / LastSync change.</summary>
    event EventHandler? SyncStatusChanged;

    /// <summary>Live (not deleted) entities of one collection, ordered by Order then title.</summary>
    IReadOnlyList<T> All<T>() where T : Entity, new();
    T? Get<T>(string id) where T : Entity, new();
    /// <summary>Any live entity by id, whatever its collection.</summary>
    Entity? Get(string id);

    /// <summary>Insert or update; stamps UpdatedAt = now and marks it for sync.</summary>
    void Save<T>(T entity) where T : Entity;
    void SaveMany<T>(IEnumerable<T> entities) where T : Entity;
    /// <summary>Soft delete (tombstone with DeletedAt) so other devices learn about it.</summary>
    void Delete(string id);

    /// <summary>Entities linking to this one: through Links, or typed fields (TaskItem.ChecklistId/ParentTaskId, Partner.ContactId, Gift.PartnerId).</summary>
    IReadOnlyList<Entity> Backlinks(string id);
    /// <summary>Adds a link a→b and b→a (with label = other side's DisplayTitle). Saves both.</summary>
    void Link(Entity a, Entity b);
    void Unlink(Entity a, Entity b);
    /// <summary>Resolves a's Links to live entities (missing/deleted ones are skipped).</summary>
    IReadOnlyList<Entity> Linked(Entity a);

    /// <summary>Case-insensitive search across titles, names, notes and bodies of all collections.</summary>
    IReadOnlyList<SearchHit> Search(string query, int limit = 50);

    /// <summary>The shared "main" settings record (created with defaults if missing).</summary>
    SettingRecord SharedSettings { get; }
    LocalSettings LocalSettings { get; }
    void SaveLocalSettings(LocalSettings settings);
    Summary GetSummary(DateOnly? today = null);

    // Account (device token kept in ISecretStore).
    bool IsLoggedIn { get; }
    /// <summary>POST /v1/auth/login with platform "windows". Throws ApiException with the server message on failure.</summary>
    Task LoginAsync(string apiUrl, string email, string password, CancellationToken ct = default);
    /// <summary>POST /v1/auth/setup (first account only).</summary>
    Task SetupAsync(string apiUrl, string setupSecret, string email, string password, string name, CancellationToken ct = default);
    Task LogoutAsync(CancellationToken ct = default);

    // Vault: files kept in %LOCALAPPDATA%\Missie\vault\{fileId} and uploaded to PUT /v1/files/{fileId}.
    /// <summary>Copies a file into the vault (new fileId, sha256, mime type) and saves a DocumentItem for it.
    /// Pass an existing doc to attach/replace its file.</summary>
    DocumentItem AddFile(string sourcePath, DocumentItem? existing = null, string kind = "other");
    /// <summary>Local path of a file, downloading it first if only the server has it. Null when unavailable.</summary>
    Task<string?> GetFilePathAsync(string fileId, CancellationToken ct = default);

    SyncState SyncState { get; }
    string? LastSyncError { get; }
    DateTimeOffset? LastSync { get; }
    int PendingChanges { get; }
    /// <summary>Uploads pending files, then pushes/pulls records until hasMore is false. Never throws; see result.</summary>
    Task<SyncResult> SyncAsync(CancellationToken ct = default);

    /// <summary>Loads starter data (checklists + tasks from the visa checklist, budget lines, settings) when empty.</summary>
    void SeedIfEmpty();

    // Bulk work in Excel.
    string ExportCsv<T>() where T : Entity, new();
    /// <summary>Upserts by "id" column (new rows without id get one). Returns rows imported.</summary>
    int ImportCsv<T>(string csv) where T : Entity, new();
    /// <summary>Full JSON backup of all records (tombstones excluded) to a file.</summary>
    void ExportBackup(string path);
}

public sealed class ApiException(int status, string code, string message) : Exception(message)
{
    public int Status { get; } = status;
    public string Code { get; } = code;
}
