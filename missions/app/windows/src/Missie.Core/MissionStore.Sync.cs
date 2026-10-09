using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace Missie.Core;

// Account, vault files and POST /v1/sync.
public sealed partial class MissionStore
{
    private const string TokenKey = "token";
    private const int MaxChangesPerCall = 500;

    private readonly SemaphoreSlim _sync = new(1, 1);
    private SyncState _syncState;
    private string? _lastError;

    public bool IsLoggedIn => !string.IsNullOrEmpty(_secrets.Get(TokenKey));
    public SyncState SyncState => _syncState;
    public string? LastSyncError => _lastError;
    public DateTimeOffset? LastSync { get { lock (_gate) return _local.LastSync; } }
    public int PendingChanges { get { lock (_gate) return _recs.Values.Count(r => r.Dirty); } }

    private void SetState(SyncState state, string? error)
    {
        _syncState = state;
        _lastError = error;
        RaiseSync();
    }

    // ---- HTTP helpers --------------------------------------------------------------------------

    private string ApiBase(string? apiUrl = null)
    {
        var url = apiUrl;
        if (string.IsNullOrWhiteSpace(url)) lock (_gate) url = _local.ApiUrl;
        return url!.Trim().TrimEnd('/');
    }

    private HttpRequestMessage Request(HttpMethod method, string path, string? apiUrl = null, bool auth = true)
    {
        var req = new HttpRequestMessage(method, ApiBase(apiUrl) + path);
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        if (auth && _secrets.Get(TokenKey) is { Length: > 0 } token)
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return req;
    }

    private static StringContent JsonBody(JsonNode body) => new(body.ToJsonString(), Encoding.UTF8, "application/json");

    private async Task<JsonNode?> SendJsonAsync(HttpRequestMessage req, CancellationToken ct)
    {
        using (req)
        using (var resp = await _http.SendAsync(req, ct).ConfigureAwait(false))
        {
            if (!resp.IsSuccessStatusCode) throw await ToApiErrorAsync(resp, ct).ConfigureAwait(false);
            var text = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            return string.IsNullOrWhiteSpace(text) ? null : JsonNode.Parse(text);
        }
    }

    private static async Task<ApiException> ToApiErrorAsync(HttpResponseMessage resp, CancellationToken ct)
    {
        var status = (int)resp.StatusCode;
        var code = "http_" + status;
        var message = $"Server answered {status} {resp.ReasonPhrase}".Trim();
        try
        {
            var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            var err = JsonNode.Parse(body)?["error"];
            if (err is JsonObject o)
            {
                code = (string?)o["code"] ?? code;
                message = (string?)o["message"] ?? message;
            }
            else if (err is JsonValue v && v.TryGetValue<string>(out var s)) message = s;
        }
        catch (Exception) { /* not JSON */ }
        return new ApiException(status, code, message);
    }

    // ---- Account -------------------------------------------------------------------------------

    private JsonObject DeviceInfo()
    {
        string name;
        lock (_gate) name = _local.DeviceName;
        return new JsonObject { ["name"] = name, ["platform"] = "windows", ["appVersion"] = AppVersion };
    }

    public async Task LoginAsync(string apiUrl, string email, string password, CancellationToken ct = default)
    {
        var req = Request(HttpMethod.Post, "/v1/auth/login", apiUrl, auth: false);
        req.Content = JsonBody(new JsonObject { ["email"] = email, ["password"] = password, ["device"] = DeviceInfo() });
        AfterLogin(apiUrl, email, await SendJsonAsync(req, ct).ConfigureAwait(false));
    }

    public async Task SetupAsync(string apiUrl, string setupSecret, string email, string password, string name, CancellationToken ct = default)
    {
        var req = Request(HttpMethod.Post, "/v1/auth/setup", apiUrl, auth: false);
        req.Content = JsonBody(new JsonObject
        {
            ["setupSecret"] = setupSecret, ["email"] = email, ["password"] = password, ["name"] = name, ["device"] = DeviceInfo(),
        });
        AfterLogin(apiUrl, email, await SendJsonAsync(req, ct).ConfigureAwait(false));
    }

    private void AfterLogin(string apiUrl, string email, JsonNode? session)
    {
        var token = (string?)session?["token"];
        if (string.IsNullOrEmpty(token)) throw new ApiException(500, "bad_response", "The server did not return a token.");
        var url = ApiBase(apiUrl);
        lock (_gate)
        {
            var switched = _local.Email is not null &&
                (!string.Equals(_local.ApiUrl.TrimEnd('/'), url, StringComparison.OrdinalIgnoreCase) ||
                 !string.Equals(_local.Email, email, StringComparison.OrdinalIgnoreCase));
            if (switched)
            {
                // Another server/account: send it everything we have and pull it all from scratch.
                InTransaction(() =>
                {
                    Exec("UPDATE records SET dirty=1, seq=NULL");
                    Exec("UPDATE files SET uploaded=0");
                });
                foreach (var r in _recs.Values) { r.Dirty = true; r.Seq = null; }
            }
            UpdateLocal(s =>
            {
                s.ApiUrl = url;
                s.Email = email;
                if (switched) s.Cursor = null;
            });
        }
        _secrets.Set(TokenKey, token);
        SetState(SyncState.Idle, null);
    }

    public async Task LogoutAsync(CancellationToken ct = default)
    {
        if (IsLoggedIn)
        {
            try { await SendJsonAsync(Request(HttpMethod.Post, "/v1/auth/logout"), ct).ConfigureAwait(false); }
            catch (Exception ex) when (ex is HttpRequestException or ApiException or TaskCanceledException) { /* token is dropped anyway */ }
        }
        _secrets.Set(TokenKey, null);
        SetState(SyncState.NotConfigured, null);
    }

    // ---- Vault ---------------------------------------------------------------------------------

    private static readonly Dictionary<string, string> MimeTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        [".pdf"] = "application/pdf",
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".heic"] = "image/heic",
        [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        [".txt"] = "text/plain",
        [".md"] = "text/markdown",
        [".zip"] = "application/zip",
    };

    internal static string MimeOf(string? fileName) =>
        MimeTypes.GetValueOrDefault(Path.GetExtension(fileName ?? ""), "application/octet-stream");

    private string VaultPath(string fileId) =>
        Guid.TryParse(fileId, out var g) ? Path.Combine(_vaultDir, g.ToString("D")) : throw new ArgumentException("Not a file id.", nameof(fileId));

    public DocumentItem AddFile(string sourcePath, DocumentItem? existing = null, string kind = "other")
    {
        var fileId = Entity.NewId();
        var dest = VaultPath(fileId);
        File.Copy(sourcePath, dest, overwrite: true);
        string sha;
        using (var fs = File.OpenRead(dest)) sha = Convert.ToHexStringLower(SHA256.HashData(fs));
        var name = Path.GetFileName(sourcePath);
        var mime = MimeOf(name);
        var size = new FileInfo(dest).Length;

        var doc = existing ?? new DocumentItem { Kind = kind };
        doc.FileId = fileId;
        doc.FileName = name;
        doc.MimeType = mime;
        doc.SizeBytes = size;
        doc.Sha256 = sha;
        if (string.IsNullOrWhiteSpace(doc.Title)) doc.Title = Path.GetFileNameWithoutExtension(name);

        lock (_gate)
            Exec("INSERT OR REPLACE INTO files(file_id, file_name, mime_type, sha256, size_bytes, uploaded) VALUES($id,$n,$m,$s,$b,0)",
                ("$id", fileId), ("$n", name), ("$m", mime), ("$s", sha), ("$b", size));
        Save(doc);
        return doc;
    }

    public async Task<string?> GetFilePathAsync(string fileId, CancellationToken ct = default)
    {
        string path;
        try { path = VaultPath(fileId); }
        catch (ArgumentException) { return null; }
        if (File.Exists(path)) return path;
        if (!IsLoggedIn) return null;
        try { return await DownloadFileAsync(fileId, ct).ConfigureAwait(false) ? path : null; }
        catch (Exception ex) when (ex is HttpRequestException or ApiException or TaskCanceledException or IOException) { return null; }
    }

    /// <summary>GET /v1/files/{id} into the vault. False when the server doesn't have it.</summary>
    private async Task<bool> DownloadFileAsync(string fileId, CancellationToken ct)
    {
        var path = VaultPath(fileId);
        using var req = Request(HttpMethod.Get, "/v1/files/" + fileId);
        using var resp = await _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct).ConfigureAwait(false);
        if (resp.StatusCode == HttpStatusCode.NotFound) return false;
        if (!resp.IsSuccessStatusCode) throw await ToApiErrorAsync(resp, ct).ConfigureAwait(false);
        var part = path + ".part";
        await using (var fs = File.Create(part))
            await resp.Content.CopyToAsync(fs, ct).ConfigureAwait(false);
        File.Move(part, path, overwrite: true);
        lock (_gate)
            Exec("INSERT OR REPLACE INTO files(file_id, file_name, mime_type, sha256, size_bytes, uploaded) VALUES($id,$n,$m,NULL,$b,1)",
                ("$id", fileId), ("$n", resp.Content.Headers.ContentDisposition?.FileNameStar ?? resp.Content.Headers.ContentDisposition?.FileName),
                ("$m", resp.Content.Headers.ContentType?.MediaType), ("$b", new FileInfo(path).Length));
        return true;
    }

    private HashSet<string> ReferencedFileIds()
    {
        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var e in LiveEntities())
        {
            if (e is DocumentItem { FileId: { Length: > 0 } f }) ids.Add(f);
            foreach (var id in e.FileIds ?? []) ids.Add(id);
        }
        return ids;
    }

    private async Task<(int Uploaded, List<string> Errors)> UploadFilesAsync(CancellationToken ct)
    {
        var pending = new List<(string Id, string? Name, string? Mime, string? Sha)>();
        lock (_gate)
        {
            using var cmd = _db.CreateCommand();
            cmd.CommandText = "SELECT file_id, file_name, mime_type, sha256 FROM files WHERE uploaded=0";
            using var r = cmd.ExecuteReader();
            while (r.Read())
                pending.Add((r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1), r.IsDBNull(2) ? null : r.GetString(2), r.IsDBNull(3) ? null : r.GetString(3)));
        }
        if (pending.Count == 0) return (0, []);
        var referenced = ReferencedFileIds();
        var uploaded = 0;
        var errors = new List<string>();
        foreach (var f in pending)
        {
            ct.ThrowIfCancellationRequested();
            if (!referenced.Contains(f.Id)) continue; // record deleted before it was uploaded
            var path = VaultPath(f.Id);
            if (!File.Exists(path)) continue;
            var sha = f.Sha;
            if (sha is null)
                await using (var hs = File.OpenRead(path)) sha = Convert.ToHexStringLower(await SHA256.HashDataAsync(hs, ct).ConfigureAwait(false));

            await using var fs = File.OpenRead(path);
            var req = Request(HttpMethod.Put, "/v1/files/" + f.Id);
            req.Content = new StreamContent(fs);
            req.Content.Headers.ContentType = new MediaTypeHeaderValue(f.Mime ?? MimeOf(f.Name));
            if (!string.IsNullOrEmpty(f.Name)) req.Headers.TryAddWithoutValidation("X-File-Name", Uri.EscapeDataString(f.Name));
            req.Headers.TryAddWithoutValidation("X-Sha256", sha);
            try { await SendJsonAsync(req, ct).ConfigureAwait(false); }
            catch (ApiException ex) when (ex.Status is 400 or 413 or 415)
            {
                errors.Add($"{f.Name ?? f.Id}: {ex.Message}");
                continue;
            }
            lock (_gate) Exec("UPDATE files SET uploaded=1 WHERE file_id=$id", ("$id", f.Id));
            uploaded++;
        }
        return (uploaded, errors);
    }

    private async Task<int> DownloadOfflineFilesAsync(CancellationToken ct)
    {
        var count = 0;
        foreach (var d in All<DocumentItem>())
        {
            if (d.Offline != true || string.IsNullOrEmpty(d.FileId) || !Guid.TryParse(d.FileId, out _)) continue;
            if (File.Exists(VaultPath(d.FileId))) continue;
            if (await DownloadFileAsync(d.FileId, ct).ConfigureAwait(false)) count++;
        }
        return count;
    }

    // ---- Sync ----------------------------------------------------------------------------------

    private sealed class Counters
    {
        public int Pushed, Pulled, Rejected, Up, Down;
        public readonly List<string> Problems = [];
        public SyncResult Result(string? error) => new(Pushed, Pulled, Rejected, Up, Down, error);
    }

    public async Task<SyncResult> SyncAsync(CancellationToken ct = default)
    {
        if (!IsLoggedIn)
        {
            SetState(SyncState.NotConfigured, null);
            return new SyncResult(0, 0, 0, 0, 0, "Not logged in.");
        }
        try { await _sync.WaitAsync(ct).ConfigureAwait(false); }
        catch (OperationCanceledException) { return new SyncResult(0, 0, 0, 0, 0, "Cancelled."); }

        var c = new Counters();
        try
        {
            SetState(SyncState.Syncing, _lastError);
            var (up, fileErrors) = await UploadFilesAsync(ct).ConfigureAwait(false);
            c.Up = up;
            c.Problems.AddRange(fileErrors);
            await PushPullAsync(c, ct).ConfigureAwait(false);
            c.Down = await DownloadOfflineFilesAsync(ct).ConfigureAwait(false);
            UpdateLocal(s => s.LastSync = DateTimeOffset.UtcNow);
            SetState(SyncState.Idle, c.Problems.Count == 0 ? null : string.Join("\n", c.Problems));
            return c.Result(null);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            SetState(IsLoggedIn ? SyncState.Idle : SyncState.NotConfigured, _lastError);
            return c.Result("Cancelled.");
        }
        catch (ApiException ex)
        {
            var msg = ex.Status == 401 ? "Logged out by the server (" + ex.Message + "). Please log in again." : ex.Message;
            SetState(SyncState.Error, msg);
            return c.Result(msg);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or TimeoutException or IOException)
        {
            var msg = "Offline: " + ex.Message;
            SetState(SyncState.Offline, msg);
            return c.Result(msg);
        }
        catch (Exception ex)
        {
            SetState(SyncState.Error, ex.Message);
            return c.Result(ex.Message);
        }
        finally
        {
            _sync.Release();
            if (c.Pulled > 0) RaiseChanged(null);
        }
    }

    private async Task PushPullAsync(Counters c, CancellationToken ct)
    {
        var skip = new HashSet<string>(StringComparer.Ordinal); // not to be sent again in this run
        var resetDone = false;
        for (var round = 0; round < 10_000; round++)
        {
            List<(string Id, DateTimeOffset UpdatedAt, JsonObject Change)> batch;
            string? cursor;
            lock (_gate)
            {
                cursor = _local.Cursor;
                batch = _recs.Values.Where(r => r.Dirty && !skip.Contains(r.Id))
                    .OrderBy(r => r.UpdatedAt).Take(MaxChangesPerCall)
                    .Select(r => (r.Id, r.UpdatedAt, new JsonObject
                    {
                        ["id"] = r.Id,
                        ["collection"] = r.Collection,
                        ["updatedAt"] = MissieJson.Iso(r.UpdatedAt),
                        ["deletedAt"] = r.DeletedAt is { } d ? MissieJson.Iso(d) : null,
                        ["data"] = SafeParseObject(r.Data),
                    }))
                    .ToList();
            }

            var body = new JsonObject { ["cursor"] = cursor, ["changes"] = new JsonArray(batch.Select(b => (JsonNode)b.Change).ToArray()) };
            var req = Request(HttpMethod.Post, "/v1/sync");
            req.Content = JsonBody(body);
            var resp = await SendJsonAsync(req, ct).ConfigureAwait(false) as JsonObject
                       ?? throw new ApiException(500, "bad_response", "Empty sync response.");

            if ((bool?)resp["resetRequired"] == true)
            {
                if (resetDone) throw new ApiException(500, "reset_loop", "The server keeps asking for a full resync.");
                resetDone = true;
                UpdateLocal(s => s.Cursor = null);
                continue;
            }

            var sent = batch.ToDictionary(b => b.Id, b => b.UpdatedAt);
            lock (_gate)
            {
                InTransaction(() =>
                {
                    foreach (var a in resp["accepted"] as JsonArray ?? [])
                    {
                        var id = (string?)a?["id"];
                        if (id is null || !_recs.TryGetValue(id, out var rec)) continue;
                        rec.Seq = (long?)a!["seq"] ?? rec.Seq;
                        if (sent.TryGetValue(id, out var at) && rec.UpdatedAt == at) rec.Dirty = false;
                        Persist(rec);
                        c.Pushed++;
                    }
                    foreach (var j in resp["rejected"] as JsonArray ?? [])
                    {
                        var id = (string?)j?["id"];
                        if (id is null) continue;
                        c.Rejected++;
                        var reason = (string?)j!["reason"];
                        if (reason == "stale")
                        {
                            // Server copy is newer. Without `current` it arrives through `changes` (now or next page).
                            if (j["current"] is not JsonObject current) continue;
                            var editedSince = _recs.TryGetValue(id, out var local) && sent.TryGetValue(id, out var at) && local.UpdatedAt > at;
                            if (!editedSince && ApplyServerLocked(current, force: true)) c.Pulled++;
                        }
                        else
                        {
                            skip.Add(id);
                            c.Problems.Add($"Change rejected ({reason}): {(string?)j["message"] ?? id}");
                        }
                    }
                    foreach (var r in resp["changes"] as JsonArray ?? [])
                        if (r is JsonObject o && ApplyServerLocked(o, force: false)) c.Pulled++;
                });

                // Something the server neither accepted nor rejected: don't resend it in this run.
                foreach (var (id, at) in sent)
                    if (_recs.TryGetValue(id, out var rec) && rec.Dirty && rec.UpdatedAt == at) skip.Add(id);
            }

            var newCursor = (string?)resp["cursor"] ?? resp["cursor"]?.ToJsonString();
            if (newCursor is not null) UpdateLocal(s => s.Cursor = newCursor);

            bool moreToSend;
            lock (_gate) moreToSend = _recs.Values.Any(r => r.Dirty && !skip.Contains(r.Id));
            if ((bool?)resp["hasMore"] != true && !moreToSend) return;
        }
    }

    private static JsonObject SafeParseObject(string json)
    {
        try { return JsonNode.Parse(json) as JsonObject ?? []; }
        catch (System.Text.Json.JsonException) { return []; }
    }

    /// <summary>Applies one server record. Newest updatedAt wins against a dirty local copy (unless force);
    /// a clean local copy is always replaced. Inside _gate. True when local data changed.</summary>
    private bool ApplyServerLocked(JsonObject r, bool force)
    {
        var id = ((string?)r["id"])?.ToLowerInvariant();
        var collection = (string?)r["collection"];
        var updatedRaw = (string?)r["updatedAt"];
        if (id is null || collection is null || updatedRaw is null) return false;
        var updatedAt = MissieJson.ParseTime(updatedRaw);
        var deletedAt = MissieJson.ParseTimeOrNull((string?)r["deletedAt"]);
        var seq = r["seq"] is JsonValue sv && sv.TryGetValue<long>(out var s) ? s : (long?)null;

        _recs.TryGetValue(id, out var local);
        if (local is not null && !force)
        {
            if (local.Dirty && local.UpdatedAt >= updatedAt) return false;
            if (!local.Dirty && local.UpdatedAt == updatedAt && local.DeletedAt == deletedAt)
            {
                if (seq is not null && local.Seq != seq) { local.Seq = seq; Persist(local); }
                return false; // our own change echoed back
            }
        }

        var data = r["data"] as JsonObject;
        var rec = new Rec
        {
            Id = id,
            Collection = collection,
            // A tombstone may come without data; keep what we had so nothing is lost locally.
            Data = data?.ToJsonString() ?? local?.Data ?? "{}",
            UpdatedAt = updatedAt,
            DeletedAt = deletedAt,
            Seq = seq ?? local?.Seq,
            Dirty = false,
        };
        _recs[id] = rec;
        Persist(rec);
        return true;
    }
}
