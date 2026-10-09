using Xunit;
using System.Net;
using System.Text.Json.Nodes;
using Missie.Core;

namespace Missie.Core.Tests;

public sealed class SyncTests : IDisposable
{
    private const string Url = "https://api.test";
    private readonly FakeApi _api = new();
    private readonly List<TempDir> _dirs = [];
    private readonly List<MissionStore> _stores = [];

    private MissionStore NewStore()
    {
        var d = new TempDir();
        _dirs.Add(d);
        var s = new MissionStore(d.Path, new MemorySecrets(), _api.Client());
        _stores.Add(s);
        return s;
    }

    private async Task<MissionStore> LoggedIn()
    {
        var s = NewStore();
        await s.LoginAsync(Url + "/", "ruben@example.com", "correct horse");
        return s;
    }

    public void Dispose()
    {
        foreach (var s in _stores) s.Dispose();
        foreach (var d in _dirs) d.Dispose();
    }

    [Fact]
    public async Task Not_logged_in_is_not_configured()
    {
        var s = NewStore();
        var r = await s.SyncAsync();
        Assert.False(r.Ok);
        Assert.Equal(SyncState.NotConfigured, s.SyncState);
        Assert.Empty(_api.Log);
    }

    [Fact]
    public async Task Login_failure_throws_api_exception()
    {
        var s = NewStore();
        var ex = await Assert.ThrowsAsync<ApiException>(() => s.LoginAsync(Url, "ruben@example.com", "wrong"));
        Assert.Equal(401, ex.Status);
        Assert.Equal("invalid_credentials", ex.Code);
        Assert.Equal("Wrong email or password.", ex.Message);
        Assert.False(s.IsLoggedIn);
    }

    [Fact]
    public async Task Login_setup_logout()
    {
        var s = NewStore();
        await s.SetupAsync(Url, "secret", "ruben@example.com", "correct horse", "Ruben");
        Assert.True(s.IsLoggedIn);
        Assert.Equal(Url, s.LocalSettings.ApiUrl);
        Assert.Equal("ruben@example.com", s.LocalSettings.Email);
        Assert.Equal(SyncState.Idle, s.SyncState);
        await s.LogoutAsync();
        Assert.False(s.IsLoggedIn);
        Assert.Contains("POST /v1/auth/logout", _api.Log);
        Assert.Equal(SyncState.NotConfigured, s.SyncState);
    }

    [Fact]
    public async Task Push_then_other_device_pulls_and_unknown_fields_survive()
    {
        var a = await LoggedIn();
        var task = new TaskItem { Title = "Apply for visa", DueDate = new DateOnly(2026, 10, 18) };
        a.Save(task);
        var r = await a.SyncAsync();
        Assert.True(r.Ok, r.Error);
        Assert.Equal(1, r.Pushed);
        Assert.Equal(0, a.PendingChanges);
        Assert.Equal(SyncState.Idle, a.SyncState);
        Assert.NotNull(a.LastSync);
        var sent = (JsonObject)_api.SyncRequests[0]["changes"]![0]!;
        Assert.Equal("tasks", (string?)sent["collection"]);
        Assert.Equal("2026-10-18", (string?)sent["data"]!["dueDate"]);
        Assert.Matches(@"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$", (string?)sent["updatedAt"]);
        Assert.Null(_api.SyncRequests[0]["cursor"]);

        // Another app adds a field we don't know.
        var row = _api.Records[task.Id];
        var data = (JsonObject)row.Data.DeepClone();
        data["iosOnly"] = new JsonObject { ["x"] = 1 };
        _api.Put(task.Id, "tasks", "2099-01-01T00:00:00.000Z", data);

        var b = await LoggedIn();
        var changed = 0;
        b.Changed += (_, _) => changed++;
        var rb = await b.SyncAsync();
        Assert.True(rb.Ok, rb.Error);
        Assert.Equal(1, rb.Pulled);
        Assert.True(changed > 0);
        var got = b.Get<TaskItem>(task.Id)!;
        Assert.Equal("Apply for visa", got.Title);
        Assert.Equal(0, b.PendingChanges);

        got.Title = "Apply for WHV";
        b.Save(got);
        // Server copy is from 2099, so this edit is stale: server wins.
        var rs = await b.SyncAsync();
        Assert.Equal(1, rs.Rejected);
        Assert.Equal("Apply for visa", b.Get<TaskItem>(task.Id)!.Title);
        Assert.Equal(0, b.PendingChanges);
        Assert.Equal(1, (int)_api.Records[task.Id].Data["iosOnly"]!["x"]!);
    }

    [Fact]
    public async Task Edit_round_trip_keeps_unknown_fields()
    {
        var a = await LoggedIn();
        var id = Entity.NewId();
        _api.Put(id, "notes", "2026-10-01T10:00:00.000Z", new JsonObject { ["title"] = "Prayer", ["mood"] = "glad" });
        await a.SyncAsync();
        var n = a.Get<Note>(id)!;
        n.Body = "Thanks";
        a.Save(n);
        var r = await a.SyncAsync();
        Assert.Equal(1, r.Pushed);
        Assert.Equal("glad", (string?)_api.Records[id].Data["mood"]);
        Assert.Equal("Thanks", (string?)_api.Records[id].Data["body"]);
    }

    [Fact]
    public async Task Newer_local_dirty_copy_beats_older_server_change()
    {
        var a = await LoggedIn();
        await a.SyncAsync();
        var t = new TaskItem { Title = "local wins" };
        a.Save(t);
        // An older server version that hasn't been pulled yet.
        _api.Put(t.Id, "tasks", "2020-01-01T00:00:00.000Z", new JsonObject { ["title"] = "old server", ["status"] = "todo" });
        var r = await a.SyncAsync();
        Assert.True(r.Ok, r.Error);
        Assert.Equal("local wins", a.Get<TaskItem>(t.Id)!.Title);
        Assert.Equal("local wins", (string?)_api.Records[t.Id].Data["title"]);
    }

    [Fact]
    public async Task Tombstones_sync_both_ways()
    {
        var a = await LoggedIn();
        var b = await LoggedIn();
        var n = new Note { Title = "to delete" };
        a.Save(n);
        await a.SyncAsync();
        await b.SyncAsync();
        Assert.NotNull(b.Get(n.Id));
        a.Delete(n.Id);
        await a.SyncAsync();
        Assert.NotNull(_api.Records[n.Id].DeletedAt);
        await b.SyncAsync();
        Assert.Null(b.Get(n.Id));
    }

    [Fact]
    public async Task Has_more_pages_and_batches_of_500()
    {
        _api.PageSize = 2;
        for (var i = 0; i < 5; i++)
            _api.Put(Entity.NewId(), "packing", "2026-10-01T00:00:00.000Z", new JsonObject { ["name"] = "item " + i });
        var a = await LoggedIn();
        a.SaveMany(Enumerable.Range(0, 1203).Select(i => new PackingItem { Name = "local " + i }));
        var r = await a.SyncAsync();
        Assert.True(r.Ok, r.Error);
        Assert.Equal(1203, r.Pushed);
        Assert.Equal(5, r.Pulled);
        Assert.All(_api.SyncRequests, q => Assert.True(q["changes"]!.AsArray().Count <= 500));
        Assert.Equal(1208, a.All<PackingItem>().Count);
        Assert.Equal(0, a.PendingChanges);
        Assert.Equal(_api.Seq.ToString(), a.LocalSettings.Cursor);
    }

    [Fact]
    public async Task Reset_required_drops_cursor_and_resyncs()
    {
        var a = await LoggedIn();
        a.Save(new Note { Title = "one" });
        await a.SyncAsync();
        Assert.NotNull(a.LocalSettings.Cursor);
        _api.Put(Entity.NewId(), "notes", "2026-10-02T00:00:00.000Z", new JsonObject { ["title"] = "two" });
        _api.ResetOnce = true;
        var before = _api.SyncRequests.Count;
        var r = await a.SyncAsync();
        Assert.True(r.Ok, r.Error);
        Assert.Null(_api.SyncRequests[before + 1]["cursor"]);
        Assert.Equal(2, a.All<Note>().Count);
    }

    [Fact]
    public async Task Files_upload_before_records_and_offline_files_download()
    {
        var a = await LoggedIn();
        var src = Path.Combine(_dirs[0].Path, "Visum é.pdf");
        File.WriteAllBytes(src, [1, 2, 3, 4]);
        var doc = a.AddFile(src, kind: "visa");
        doc.Offline = true;
        a.Save(doc);
        var r = await a.SyncAsync();
        Assert.True(r.Ok, r.Error);
        Assert.Equal(1, r.FilesUploaded);
        var f = _api.Files[doc.FileId!];
        Assert.Equal("application/pdf", f.ContentType);
        Assert.Equal(Uri.EscapeDataString("Visum é.pdf"), f.FileName);
        Assert.Equal(doc.Sha256, f.Sha);
        Assert.Equal([1, 2, 3, 4], f.Bytes);
        Assert.True(_api.Log.IndexOf($"PUT /v1/files/{doc.FileId}") < _api.Log.IndexOf("POST /v1/sync"));

        // Uploaded once only.
        var r2 = await a.SyncAsync();
        Assert.Equal(0, r2.FilesUploaded);

        var b = await LoggedIn();
        var rb = await b.SyncAsync();
        Assert.Equal(1, rb.FilesDownloaded);
        var path = await b.GetFilePathAsync(doc.FileId!);
        Assert.Equal([1, 2, 3, 4], File.ReadAllBytes(path!));
    }

    [Fact]
    public async Task Get_file_path_downloads_on_demand()
    {
        var a = await LoggedIn();
        var id = Entity.NewId();
        _api.Files[id] = new FakeApi.StoredFile([9, 9], "image/png", "x.png", null);
        var path = await a.GetFilePathAsync(id);
        Assert.NotNull(path);
        Assert.Equal([9, 9], File.ReadAllBytes(path!));
        Assert.Null(await a.GetFilePathAsync(Entity.NewId()));
        Assert.Null(await a.GetFilePathAsync("../../etc/passwd"));
    }

    [Fact]
    public async Task Offline_and_error_states()
    {
        var a = await LoggedIn();
        a.Save(new Note { Title = "x" });
        var events = 0;
        a.SyncStatusChanged += (_, _) => events++;

        _api.Down = true;
        var r = await a.SyncAsync();
        Assert.False(r.Ok);
        Assert.Equal(SyncState.Offline, a.SyncState);
        Assert.Equal(1, a.PendingChanges);
        Assert.True(events >= 2);

        _api.Down = false;
        _api.FailSyncWith = HttpStatusCode.InternalServerError;
        r = await a.SyncAsync();
        Assert.Equal(SyncState.Error, a.SyncState);
        Assert.Equal("Server exploded.", a.LastSyncError);
        Assert.Equal("Server exploded.", r.Error);

        _api.FailSyncWith = null;
        r = await a.SyncAsync();
        Assert.True(r.Ok);
        Assert.Equal(SyncState.Idle, a.SyncState);
        Assert.Null(a.LastSyncError);
        Assert.Equal(0, a.PendingChanges);
    }

    [Fact]
    public async Task Concurrent_syncs_run_one_at_a_time()
    {
        var a = await LoggedIn();
        a.SaveMany(Enumerable.Range(0, 50).Select(i => new TaskItem { Title = "t" + i }));
        var results = await Task.WhenAll(a.SyncAsync(), a.SyncAsync(), a.SyncAsync());
        Assert.All(results, x => Assert.True(x.Ok, x.Error));
        Assert.Equal(50, results.Sum(x => x.Pushed));
        Assert.Equal(50, _api.Records.Count);
    }

    [Fact]
    public async Task Seed_on_two_devices_does_not_duplicate()
    {
        var a = await LoggedIn();
        a.SeedIfEmpty();
        await a.SyncAsync();
        var count = _api.Records.Count;
        var b = await LoggedIn();
        b.SeedIfEmpty();
        var r = await b.SyncAsync();
        Assert.True(r.Ok, r.Error);
        Assert.Equal(count, _api.Records.Count);
        Assert.Equal(0, b.PendingChanges);
        Assert.Equal(a.All<TaskItem>().Count, b.All<TaskItem>().Count);
    }
}
