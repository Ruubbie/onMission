using Xunit;
using System.Text.Json;
using System.Text.Json.Nodes;
using Missie.Core;

namespace Missie.Core.Tests;

public sealed class StoreTests : IDisposable
{
    private readonly TempDir _dir = new();
    private readonly MissionStore _store;

    public StoreTests() => _store = new MissionStore(_dir.Path, new MemorySecrets());

    public void Dispose()
    {
        _store.Dispose();
        _dir.Dispose();
    }

    [Fact]
    public void Save_get_delete_and_tombstone()
    {
        var changed = new List<string?>();
        _store.Changed += (_, c) => changed.Add(c);
        var t = new TaskItem { Title = "Apply for visa", DueDate = new DateOnly(2026, 10, 18), Area = "visa" };
        _store.Save(t);

        Assert.Equal(Collections.Tasks, changed.Single());
        Assert.NotEqual(default, t.UpdatedAt);
        Assert.Equal(0, t.UpdatedAt.Ticks % TimeSpan.TicksPerMillisecond);
        var got = _store.Get<TaskItem>(t.Id)!;
        Assert.Equal("Apply for visa", got.Title);
        Assert.Equal(new DateOnly(2026, 10, 18), got.DueDate);
        Assert.Equal(t.UpdatedAt, got.UpdatedAt);
        Assert.Null(_store.Get<Partner>(t.Id));
        Assert.Equal(1, _store.PendingChanges);

        _store.Delete(t.Id);
        Assert.Null(_store.Get(t.Id));
        Assert.Empty(_store.All<TaskItem>());
        Assert.Equal(1, _store.PendingChanges);
        Assert.Equal(2, changed.Count);

        // Persisted: a new store on the same folder still has the tombstone (pending sync).
        _store.Dispose();
        using var again = new MissionStore(_dir.Path, new MemorySecrets());
        Assert.Null(again.Get(t.Id));
        Assert.Equal(1, again.PendingChanges);
    }

    [Fact]
    public void All_orders_by_order_then_title()
    {
        _store.SaveMany([
            new PackingItem { Name = "zebra" }, new PackingItem { Name = "Apple" },
            new PackingItem { Name = "last", Order = 5 }, new PackingItem { Name = "first", Order = 1 },
        ]);
        Assert.Equal(["first", "last", "Apple", "zebra"], _store.All<PackingItem>().Select(p => p.Name));
    }

    [Fact]
    public void Json_format_and_unknown_fields_round_trip()
    {
        const string json = """
            {"title":"T","status":"todo","dueDate":"2026-10-20","remindAt":"2026-10-08T19:00:00Z",
             "futureField":{"a":[1,2]},"order":2.5}
            """;
        var e = (TaskItem)MissieJson.DeserializeData("tasks", json)!;
        Assert.Equal(new DateOnly(2026, 10, 20), e.DueDate);
        e.Title = "T2";
        var back = JsonNode.Parse(MissieJson.SerializeData(e))!.AsObject();
        Assert.Equal("T2", (string?)back["title"]);
        Assert.Equal("2026-10-20", (string?)back["dueDate"]);
        Assert.Equal("2026-10-08T19:00:00.000Z", (string?)back["remindAt"]);
        Assert.Equal("[1,2]", back["futureField"]!["a"]!.ToJsonString());
        Assert.False(back.ContainsKey("id"));
        Assert.False(back.ContainsKey("collection"));
        Assert.False(back.ContainsKey("displayTitle"));
        Assert.False(back.ContainsKey("isDone"));
        Assert.False(back.ContainsKey("notes")); // nulls omitted

        _store.Save(e);
        var stored = _store.Get<TaskItem>(e.Id)!;
        Assert.True(stored.Extra!.ContainsKey("futureField"));
    }

    [Fact]
    public void Links_backlinks_and_unlink()
    {
        var doc = new DocumentItem { Title = "Passport", Kind = "passport" };
        var task = new TaskItem { Title = "Scan passport" };
        var list = new Checklist { Title = "Visa" };
        var contact = new Contact { Name = "YWAM" };
        var partner = new Partner { Name = "Jan", ContactId = contact.Id };
        var gift = new Gift { PartnerId = partner.Id, AmountCents = 2500 };
        _store.SaveMany<Entity>([doc, task, list, contact, partner, gift]);
        task.ChecklistId = list.Id;
        _store.Save(task);

        _store.Link(task, doc);
        var t = _store.Get<TaskItem>(task.Id)!;
        Assert.Equal("Passport", t.Links!.Single().Label);
        Assert.Equal(Collections.Documents, t.Links!.Single().Collection);
        var d = _store.Get<DocumentItem>(doc.Id)!;
        Assert.Equal("Scan passport", d.Links!.Single().Label);
        Assert.Equal(doc.Id, _store.Linked(t).Single().Id);
        Assert.Equal(task.Id, _store.Backlinks(doc.Id).Single().Id);
        Assert.Equal(task.Id, _store.Backlinks(list.Id).Single().Id);
        Assert.Equal(partner.Id, _store.Backlinks(contact.Id).Single().Id);
        Assert.Equal(gift.Id, _store.Backlinks(partner.Id).Single().Id);

        // Linking twice doesn't duplicate.
        _store.Link(t, d);
        Assert.Single(_store.Get<TaskItem>(task.Id)!.Links!);

        _store.Delete(doc.Id);
        Assert.Empty(_store.Linked(_store.Get<TaskItem>(task.Id)!));

        _store.Unlink(t, d);
        Assert.Null(_store.Get<TaskItem>(task.Id)!.Links);
    }

    [Fact]
    public void Search_is_case_insensitive_with_snippet()
    {
        _store.Save(new TaskItem { Title = "Apply for Working Holiday Visa" });
        _store.Save(new Note { Title = "Call with church", Body = "We talked about the zendingscommissie budget and when to present it in a service. " + new string('x', 80) });
        _store.Save(new Partner { Name = "Visser family", Notes = "met at church" });
        var deleted = new Note { Title = "visa old" };
        _store.Save(deleted);
        _store.Delete(deleted.Id);

        var hits = _store.Search("VISA");
        Assert.Single(hits);
        Assert.Equal("Apply for Working Holiday Visa", hits[0].Title);

        var body = _store.Search("ZENDINGS").Single();
        Assert.Equal(Collections.Notes, body.Collection);
        Assert.Contains("zendingscommissie", body.Snippet);
        Assert.EndsWith("…", body.Snippet);

        Assert.Equal(2, _store.Search("church").Count);
        Assert.Empty(_store.Search("  "));
    }

    [Fact]
    public void Csv_round_trip_comma()
    {
        var a = new SellItem { Name = "Bike, red", Status = "listed", AskingCents = 15000, Notes = "Says \"barely used\"\nsecond line", Tags = ["garage", "big"] };
        var b = new SellItem { Name = "Desk", Status = "sold", SoldCents = 4000, PickupDate = new DateOnly(2026, 11, 2) };
        _store.SaveMany([a, b]);
        var csv = _store.ExportCsv<SellItem>();
        Assert.StartsWith("﻿id,name,status,", csv);

        using var dir2 = new TempDir();
        using var other = new MissionStore(dir2.Path, new MemorySecrets());
        Assert.Equal(2, other.ImportCsv<SellItem>(csv));
        var a2 = other.Get<SellItem>(a.Id)!;
        Assert.Equal(a.Name, a2.Name);
        Assert.Equal(a.Notes, a2.Notes);
        Assert.Equal(15000, a2.AskingCents);
        Assert.Equal(["garage", "big"], a2.Tags);
        Assert.Null(a2.SoldCents);
        Assert.Equal(new DateOnly(2026, 11, 2), other.Get<SellItem>(b.Id)!.PickupDate);
    }

    [Fact]
    public void Csv_import_semicolon_dutch_excel()
    {
        var existing = new PackingItem { Name = "Old name", Packed = false, Notes = "keep?" };
        _store.Save(existing);
        var csv = "﻿id;name;bag;quantity;packed;weightGrams;order;notes\r\n" +
                  $"{existing.Id.ToUpperInvariant()};Rain jacket;carry-on;1;ja;450;1,5;\r\n" +
                  ";\"Hiking boots; size 44\";checked;2;0;;;\"multi\nline\"\r\n" +
                  ";;;;;;;\r\n";
        Assert.Equal(2, _store.ImportCsv<PackingItem>(csv));
        var e = _store.Get<PackingItem>(existing.Id)!;
        Assert.Equal("Rain jacket", e.Name);
        Assert.True(e.Packed);
        Assert.Equal(450, e.WeightGrams);
        Assert.Equal(1.5, e.Order);
        Assert.Null(e.Notes);
        var boots = _store.All<PackingItem>().Single(p => p.Id != existing.Id);
        Assert.Equal("Hiking boots; size 44", boots.Name);
        Assert.Equal(2, boots.Quantity);
        Assert.Equal("multi\nline", boots.Notes);
    }

    [Fact]
    public void Csv_links_column()
    {
        var doc = new DocumentItem { Title = "Passport" };
        var task = new TaskItem { Title = "Scan" };
        _store.SaveMany<Entity>([doc, task]);
        _store.Link(task, doc);
        var csv = _store.ExportCsv<TaskItem>();
        Assert.Contains($"documents:{doc.Id}", csv);
        _store.ImportCsv<TaskItem>(csv);
        Assert.Equal("Passport", _store.Get<TaskItem>(task.Id)!.Links!.Single().Label);
    }

    [Fact]
    public void Summary_math()
    {
        var today = new DateOnly(2026, 10, 8);
        var s = _store.SharedSettings;
        s.NzdPerEur = 2.0;
        _store.Save(s);
        _store.SaveMany([
            new TaskItem { Title = "overdue", DueDate = today.AddDays(-1) },
            new TaskItem { Title = "today", DueDate = today },
            new TaskItem { Title = "in 6 days", DueDate = today.AddDays(6) },
            new TaskItem { Title = "in 7 days", DueDate = today.AddDays(7) },
            new TaskItem { Title = "done", Status = "done", DueDate = today.AddDays(-3) },
            new TaskItem { Title = "skipped", Status = "skipped" },
        ]);
        _store.SaveMany([
            new Partner { Name = "a", Stage = "committed", MonthlyCents = 2500 },
            new Partner { Name = "b", Stage = "giving", MonthlyCents = 5000, Currency = "NZD", NextFollowUp = today },
            new Partner { Name = "c", Stage = "asked", MonthlyCents = 9999, NextFollowUp = today.AddDays(1) },
            new Partner { Name = "d", Stage = "thinking", NextFollowUp = today.AddDays(-2) },
        ]);
        _store.SaveMany([
            new SellItem { Name = "a", Status = "sold", SoldCents = 1000 },
            new SellItem { Name = "b", Status = "given-away" },
            new SellItem { Name = "c", Status = "keep" },
            new SellItem { Name = "d", Status = "listed" },
            new SellItem { Name = "e", Status = "decide" },
        ]);
        _store.SaveMany([new PackingItem { Name = "a", Packed = true }, new PackingItem { Name = "b" }]);
        _store.SaveMany([
            new DocumentItem { Title = "passport", FileId = Entity.NewId(), ExpiresAt = today.AddDays(180) },
            new DocumentItem { Title = "visa", ExpiresAt = today.AddDays(181) },
            new DocumentItem { Title = "old", FileId = Entity.NewId(), ExpiresAt = today.AddDays(-5) },
        ]);

        var sum = _store.GetSummary(today);
        Assert.Equal(new DateOnly(2027, 1, 5), sum.DepartureDate);
        Assert.Equal(89, sum.DaysToDeparture);
        Assert.Equal(4, sum.TasksOpen);
        Assert.Equal(1, sum.TasksOverdue);
        Assert.Equal(2, sum.TasksDueThisWeek);
        Assert.Equal(2, sum.TasksDone);
        Assert.Equal(2500 + 2500, sum.CommittedMonthlyCents);
        Assert.Equal(100000, sum.TargetMonthlyCents);
        Assert.Equal(75000, sum.MinimumMonthlyCents);
        Assert.Equal(2, sum.Partners);
        Assert.Equal(2, sum.FollowUpsDue);
        Assert.Equal(2, sum.SellItemsLeft);
        Assert.Equal(1000, sum.SoldCents);
        Assert.Equal(2, sum.PackingTotal);
        Assert.Equal(1, sum.PackingPacked);
        Assert.Equal(3, sum.DocumentsTotal);
        Assert.Equal(1, sum.DocumentsMissingFile);
        Assert.Equal(2, sum.DocumentsExpiringSoon);
    }

    [Fact]
    public void Shared_settings_use_fixed_id()
    {
        var s = _store.SharedSettings;
        Assert.Equal(SettingRecord.MainId, s.Id);
        Assert.Equal("main", s.Key);
        Assert.Equal(SettingRecord.MainId, StableIds.UuidV5("settings:main", StableIds.SeedNamespace));
        Assert.Equal(MissionStore.SeedTime, s.UpdatedAt);
        s.SupportTargetMonthlyCents = 120000;
        _store.Save(s);
        Assert.Equal(120000, _store.SharedSettings.SupportTargetMonthlyCents);
        Assert.Single(_store.All<SettingRecord>());
    }

    [Fact]
    public void Seed_loads_once_with_resolved_references()
    {
        _store.SeedIfEmpty();
        var lists = _store.All<Checklist>();
        var tasks = _store.All<TaskItem>();
        Assert.True(lists.Count >= 6);
        Assert.True(tasks.Count >= 30);
        Assert.All(tasks, t => Assert.NotNull(_store.Get<Checklist>(t.ChecklistId!)));
        Assert.Contains(tasks, t => t.SourceUrl?.StartsWith("https://www.immigration.govt.nz") == true);
        Assert.Contains(tasks, t => t.Links?.Any(l => _store.Get(l.Id) is Contact) == true);
        Assert.Contains(_store.All<BudgetEntry>(), b => b.AmountCents == 77000 && b.Currency == "NZD");
        Assert.True(_store.All<PackingItem>().Count >= 15);
        Assert.Equal(SettingRecord.MainId, _store.SharedSettings.Id);
        Assert.Equal(StableIds.Seed("checklists", "visa"), lists.Single(l => l.Title == "Visa").Id);
        Assert.All(_store.All<TaskItem>(), t => Assert.Equal(MissionStore.SeedTime, t.UpdatedAt));

        var count = _store.PendingChanges;
        _store.SeedIfEmpty();
        Assert.Equal(count, _store.PendingChanges);
    }

    [Fact]
    public async Task Vault_add_file()
    {
        var src = Path.Combine(_dir.Path, "Paspoort scan.pdf");
        File.WriteAllText(src, "pdf bytes");
        var doc = _store.AddFile(src, kind: "passport");
        Assert.Equal("Paspoort scan", doc.Title);
        Assert.Equal("application/pdf", doc.MimeType);
        Assert.Equal(9, doc.SizeBytes);
        Assert.Equal(Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData("pdf bytes"u8.ToArray())), doc.Sha256);
        Assert.True(File.Exists(Path.Combine(_dir.Path, "vault", doc.FileId!)));
        Assert.Equal("passport", _store.Get<DocumentItem>(doc.Id)!.Kind);
        Assert.Equal(Path.Combine(_dir.Path, "vault", doc.FileId!), await _store.GetFilePathAsync(doc.FileId!));
        Assert.Null(await _store.GetFilePathAsync(Entity.NewId())); // not logged in, not local
    }

    [Fact]
    public void Backup_excludes_tombstones()
    {
        var a = new Note { Title = "keep" };
        var b = new Note { Title = "gone" };
        _store.SaveMany([a, b]);
        _store.Delete(b.Id);
        var path = Path.Combine(_dir.Path, "out", "backup.json");
        _store.ExportBackup(path);
        var root = JsonNode.Parse(File.ReadAllText(path))!;
        Assert.NotNull((string?)root["exportedAt"]);
        var rec = root["records"]!.AsArray().Single()!;
        Assert.Equal(a.Id, (string?)rec["id"]);
        Assert.Equal("notes", (string?)rec["collection"]);
        Assert.Equal("keep", (string?)rec["data"]!["title"]);
    }

    [Fact]
    public void Local_settings_persist()
    {
        var s = _store.LocalSettings;
        s.DeviceName = "Ruben-PC";
        s.AutoSync = false;
        _store.SaveLocalSettings(s);
        _store.Dispose();
        using var again = new MissionStore(_dir.Path, new MemorySecrets());
        Assert.Equal("Ruben-PC", again.LocalSettings.DeviceName);
        Assert.False(again.LocalSettings.AutoSync);
    }
}
