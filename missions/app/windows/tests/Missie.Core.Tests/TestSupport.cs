using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Missie.Core;

namespace Missie.Core.Tests;

public sealed class MemorySecrets : ISecretStore
{
    private readonly Dictionary<string, string> _d = [];
    public string? Get(string key) => _d.GetValueOrDefault(key);
    public void Set(string key, string? value) { if (value is null) _d.Remove(key); else _d[key] = value; }
}

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "missie-tests", Guid.NewGuid().ToString("N"));
    public TempDir() => Directory.CreateDirectory(Path);
    public void Dispose() { try { Directory.Delete(Path, true); } catch (IOException) { } }
}

/// <summary>In-memory fake of the API contract (auth, /v1/sync, /v1/files).</summary>
public sealed class FakeApi : HttpMessageHandler
{
    public sealed class Row
    {
        public required string Id, Collection, UpdatedAt;
        public string? DeletedAt;
        public required JsonObject Data;
        public long Seq;
    }

    public sealed record StoredFile(byte[] Bytes, string? ContentType, string? FileName, string? Sha);

    public const string Token = "device-token-123";
    public readonly Dictionary<string, Row> Records = [];
    public readonly Dictionary<string, StoredFile> Files = [];
    public readonly List<JsonObject> SyncRequests = [];
    public readonly List<string> Log = [];
    public long Seq;
    public int PageSize = 500;
    public bool ResetOnce;
    public bool Down;
    public HttpStatusCode? FailSyncWith;

    public HttpClient Client() => new(this, disposeHandler: false);

    public void Put(string id, string collection, string updatedAt, JsonObject data, string? deletedAt = null) =>
        Records[id] = new Row { Id = id, Collection = collection, UpdatedAt = updatedAt, DeletedAt = deletedAt, Data = data, Seq = ++Seq };

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
    {
        if (Down) throw new HttpRequestException("No such host is known.");
        var path = req.RequestUri!.AbsolutePath;
        Log.Add($"{req.Method} {path}");
        var body = req.Content is null ? null : await req.Content.ReadAsByteArrayAsync(ct);

        if (path == "/v1/auth/login" || path == "/v1/auth/setup")
        {
            var j = JsonNode.Parse(body!)!;
            if ((string?)j["password"] != "correct horse") return Error(401, "invalid_credentials", "Wrong email or password.");
            if ((string?)j["device"]?["platform"] != "windows") return Error(400, "bad_device", "platform");
            return Json(path.EndsWith("setup") ? 201 : 200, new JsonObject
            {
                ["token"] = Token,
                ["user"] = new JsonObject { ["id"] = "u1", ["email"] = (string?)j["email"], ["name"] = "Ruben" },
                ["space"] = new JsonObject { ["id"] = "s1", ["name"] = "x", ["role"] = "owner" },
                ["device"] = new JsonObject { ["id"] = "d1", ["name"] = (string?)j["device"]?["name"], ["platform"] = "windows", ["createdAt"] = "2026-10-08T00:00:00.000Z" },
            });
        }

        if (req.Headers.Authorization?.Parameter != Token) return Error(401, "unauthorized", "Missing or revoked token.");

        if (path == "/v1/auth/logout") return new HttpResponseMessage(HttpStatusCode.NoContent);

        if (path == "/v1/sync")
        {
            if (FailSyncWith is { } fail) return Error((int)fail, "boom", "Server exploded.");
            var j = (JsonObject)JsonNode.Parse(body!)!;
            SyncRequests.Add(j);
            if (ResetOnce && j["cursor"] is not null) { ResetOnce = false; return Json(200, new JsonObject { ["cursor"] = "0", ["hasMore"] = false, ["resetRequired"] = true, ["serverTime"] = "2026-10-08T00:00:00.000Z", ["changes"] = new JsonArray(), ["accepted"] = new JsonArray(), ["rejected"] = new JsonArray() }); }
            var changes = (JsonArray)j["changes"]!;
            if (changes.Count > 500) return Error(413, "too_many", "max 500");
            var accepted = new JsonArray();
            var rejected = new JsonArray();
            foreach (var c in changes.Cast<JsonObject>())
            {
                var id = (string)c["id"]!;
                var upd = (string)c["updatedAt"]!;
                if (Records.TryGetValue(id, out var cur) && string.CompareOrdinal(cur.UpdatedAt, upd) >= 0)
                {
                    rejected.Add(new JsonObject { ["id"] = id, ["reason"] = "stale", ["current"] = ToJson(cur) });
                    continue;
                }
                Put(id, (string)c["collection"]!, upd, (JsonObject)c["data"]!.DeepClone(), (string?)c["deletedAt"]);
                accepted.Add(new JsonObject { ["id"] = id, ["seq"] = Seq });
            }
            var cursor = long.TryParse((string?)j["cursor"], out var cc) ? cc : 0;
            var newer = Records.Values.Where(r => r.Seq > cursor).OrderBy(r => r.Seq).ToList();
            var page = newer.Take(PageSize).ToList();
            return Json(200, new JsonObject
            {
                ["cursor"] = (page.Count > 0 ? page[^1].Seq : cursor).ToString(),
                ["hasMore"] = newer.Count > PageSize,
                ["resetRequired"] = false,
                ["serverTime"] = "2026-10-08T00:00:00.000Z",
                ["changes"] = new JsonArray(page.Select(r => (JsonNode)ToJson(r)).ToArray()),
                ["accepted"] = accepted,
                ["rejected"] = rejected,
            });
        }

        if (path.StartsWith("/v1/files/"))
        {
            var id = path["/v1/files/".Length..];
            if (req.Method == HttpMethod.Put)
            {
                Files[id] = new StoredFile(body!, req.Content!.Headers.ContentType?.MediaType,
                    req.Headers.TryGetValues("X-File-Name", out var n) ? n.First() : null,
                    req.Headers.TryGetValues("X-Sha256", out var s) ? s.First() : null);
                return Json(201, new JsonObject { ["id"] = id });
            }
            if (req.Method == HttpMethod.Get)
            {
                if (!Files.TryGetValue(id, out var f)) return Error(404, "not_found", "No such file.");
                var resp = new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(f.Bytes) };
                resp.Content.Headers.ContentType = new(f.ContentType ?? "application/octet-stream");
                return resp;
            }
        }
        return Error(404, "not_found", "Not found.");
    }

    public static JsonObject ToJson(Row r) => new()
    {
        ["id"] = r.Id, ["collection"] = r.Collection, ["updatedAt"] = r.UpdatedAt, ["deletedAt"] = r.DeletedAt,
        ["seq"] = r.Seq, ["data"] = r.Data.DeepClone(),
    };

    private static HttpResponseMessage Json(int status, JsonNode body) =>
        new((HttpStatusCode)status) { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") };

    private static HttpResponseMessage Error(int status, string code, string message) =>
        Json(status, new JsonObject { ["error"] = new JsonObject { ["code"] = code, ["message"] = message } });
}
