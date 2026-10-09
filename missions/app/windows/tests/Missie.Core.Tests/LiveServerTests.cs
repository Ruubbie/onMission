using Missie.Core;
using Xunit;

namespace Missie.Core.Tests;

// End-to-end against a real server. Skipped unless MISSIE_E2E_URL is set, e.g.
//   (in app/server) npm run dev     then     MISSIE_E2E_URL=http://localhost:8787 dotnet test
// The server must have SETUP_SECRET="dev-setup-secret" in .dev.vars.
public class LiveServerTests
{
    static readonly string? Url = Environment.GetEnvironmentVariable("MISSIE_E2E_URL");
    const string Email = "e2e@example.com", Password = "e2e-password-123";

    static async Task<MissionStore> Device(TempDir dir, string name)
    {
        var store = new MissionStore(dir.Path, new MemorySecrets());
        var local = store.LocalSettings;
        local.DeviceName = name;
        store.SaveLocalSettings(local);
        try { await store.SetupAsync(Url!, "dev-setup-secret", Email, Password, "Ruben"); }
        catch (ApiException e) when (e.Status == 409) { await store.LoginAsync(Url!, Email, Password); }
        return store;
    }

    [Fact]
    public async Task Two_devices_sync_records_links_deletes_and_files()
    {
        if (string.IsNullOrEmpty(Url)) return;
        using var dirA = new TempDir();
        using var dirB = new TempDir();
        using var a = await Device(dirA, "PC");
        using var b = await Device(dirB, "Laptop");

        a.SeedIfEmpty();
        var partner = new Partner { Name = "Oma Jansen " + Guid.NewGuid().ToString("N")[..6], Stage = "committed", MonthlyCents = 2500 };
        var task = new TaskItem { Title = "Bel " + partner.Name, DueDate = new DateOnly(2026, 11, 1) };
        a.Save(partner);
        a.Save(task);
        a.Link(task, partner);

        var file = Path.Combine(dirA.Path, "paspoort.pdf");
        File.WriteAllBytes(file, "%PDF-1.4 test"u8.ToArray());
        var doc = a.AddFile(file, kind: "passport");

        var ra = await a.SyncAsync();
        Assert.True(ra.Ok, ra.Error);
        Assert.True(ra.FilesUploaded >= 1);
        Assert.Equal(0, a.PendingChanges);

        var rb = await b.SyncAsync();
        Assert.True(rb.Ok, rb.Error);
        var bTask = b.Get<TaskItem>(task.Id);
        Assert.NotNull(bTask);
        Assert.Contains(b.Linked(bTask!), e => e.Id == partner.Id);
        Assert.Equal(2500, b.Get<Partner>(partner.Id)!.MonthlyCents);
        Assert.Equal(SettingRecord.MainId, b.SharedSettings.Id);

        var path = await b.GetFilePathAsync(doc.FileId!);
        Assert.NotNull(path);
        Assert.Equal(File.ReadAllBytes(file), File.ReadAllBytes(path!));

        // Edit on B, delete on B, both reach A.
        bTask!.Status = "done";
        b.Save(bTask);
        b.Delete(partner.Id);
        Assert.True((await b.SyncAsync()).Ok);
        Assert.True((await a.SyncAsync()).Ok);
        Assert.Equal("done", a.Get<TaskItem>(task.Id)!.Status);
        Assert.Null(a.Get<Partner>(partner.Id));
    }
}
