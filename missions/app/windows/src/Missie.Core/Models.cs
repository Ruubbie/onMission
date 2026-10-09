using System.Text.Json;
using System.Text.Json.Serialization;

namespace Missie.Core;

// Mirrors the API contract in missions/app/api/openapi.yaml.
// Every object is a Record { id, collection, updatedAt, deletedAt, data } on the server. The classes below are
// the typed shape of `data` per collection; property names serialise as camelCase. Fields this app doesn't know
// (added by the iPhone app or a newer version) are kept in Extra and sent back untouched.
// Money is integer cents + currency. Dates are DateOnly ("YYYY-MM-DD"), timestamps UTC ISO 8601 with ms.

public static class Collections
{
    public const string Tasks = "tasks";
    public const string Checklists = "checklists";
    public const string Partners = "partners";
    public const string Gifts = "gifts";
    public const string Budget = "budget";
    public const string SellItems = "sellItems";
    public const string Packing = "packing";
    public const string Notes = "notes";
    public const string Documents = "documents";
    public const string Contacts = "contacts";
    public const string Newsletters = "newsletters";
    public const string Settings = "settings";

    public static readonly IReadOnlyDictionary<string, Type> Map = new Dictionary<string, Type>
    {
        [Tasks] = typeof(TaskItem),
        [Checklists] = typeof(Checklist),
        [Partners] = typeof(Partner),
        [Gifts] = typeof(Gift),
        [Budget] = typeof(BudgetEntry),
        [SellItems] = typeof(SellItem),
        [Packing] = typeof(PackingItem),
        [Notes] = typeof(Note),
        [Documents] = typeof(DocumentItem),
        [Contacts] = typeof(Contact),
        [Newsletters] = typeof(Newsletter),
        [Settings] = typeof(SettingRecord),
    };

    public static string Of<T>() where T : Entity, new() => new T().Collection;
}

public static class Areas
{
    public static readonly string[] All =
        ["visa", "admin", "finance", "support", "newsletter", "selling", "packing", "housing", "health", "insurance", "church", "travel", "ywam", "personal", "other"];
}

public sealed class Link
{
    public string Collection { get; set; } = "";
    public string Id { get; set; } = "";
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] public string? Label { get; set; }
}

public abstract class Entity
{
    /// <summary>Lowercase UUID with dashes, generated on this device.</summary>
    [JsonIgnore] public string Id { get; set; } = NewId();
    [JsonIgnore] public abstract string Collection { get; }
    /// <summary>Last change (UTC). Newest wins in sync. Set by the store on Save.</summary>
    [JsonIgnore] public DateTimeOffset UpdatedAt { get; set; }
    [JsonIgnore] public DateTimeOffset? DeletedAt { get; set; }
    /// <summary>A human title for lists, search and link chips.</summary>
    [JsonIgnore] public abstract string DisplayTitle { get; }

    public List<Link>? Links { get; set; }
    public List<string>? Tags { get; set; }
    public List<string>? FileIds { get; set; }
    public double? Order { get; set; }

    /// <summary>Unknown fields from other apps/versions; round-tripped untouched.</summary>
    [JsonExtensionData] public Dictionary<string, JsonElement>? Extra { get; set; }

    public static string NewId() => Guid.NewGuid().ToString("D");
}

public sealed class TaskItem : Entity
{
    public override string Collection => Collections.Tasks;
    public override string DisplayTitle => Title;
    public string Title { get; set; } = "";
    public string? Notes { get; set; }
    /// <summary>todo, doing, waiting, done, skipped.</summary>
    public string Status { get; set; } = "todo";
    public string? Area { get; set; }
    /// <summary>low, normal, high.</summary>
    public string? Priority { get; set; } = "normal";
    public DateOnly? DueDate { get; set; }
    public DateTimeOffset? RemindAt { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }
    public string? ChecklistId { get; set; }
    public string? ParentTaskId { get; set; }
    public string? WaitingOn { get; set; }
    public string? SourceUrl { get; set; }

    [JsonIgnore] public bool IsDone => Status is "done" or "skipped";
}

public sealed class Checklist : Entity
{
    public override string Collection => Collections.Checklists;
    public override string DisplayTitle => Title;
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public string? Area { get; set; }
    /// <summary>now, before-departure, departure-week, arrival, ongoing.</summary>
    public string? Phase { get; set; }
    public bool? Archived { get; set; }
}

public sealed class Partner : Entity
{
    public override string Collection => Collections.Partners;
    public override string DisplayTitle => Name;
    public string Name { get; set; } = "";
    public string? ContactId { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Church { get; set; }
    /// <summary>idea, to-ask, asked, thinking, committed, giving, declined, paused.</summary>
    public string Stage { get; set; } = "idea";
    public long? MonthlyCents { get; set; }
    public long? OneOffCents { get; set; }
    public string? Currency { get; set; } = "EUR";
    public DateOnly? StartDate { get; set; }
    public bool? Prayer { get; set; }
    public bool? Newsletter { get; set; }
    public DateOnly? LastContactAt { get; set; }
    public DateOnly? NextFollowUp { get; set; }
    public DateOnly? ThankedAt { get; set; }
    public string? Notes { get; set; }

    [JsonIgnore] public bool CountsAsSupport => Stage is "committed" or "giving";
}

/// <summary>A gift actually received (for thank-yous and the real monthly total).</summary>
public sealed class Gift : Entity
{
    public override string Collection => Collections.Gifts;
    public override string DisplayTitle => $"{AmountCents / 100m:0.00} {Currency} {Date:yyyy-MM-dd}";
    public string? PartnerId { get; set; }
    public long AmountCents { get; set; }
    public string Currency { get; set; } = "EUR";
    public DateOnly Date { get; set; } = DateOnly.FromDateTime(DateTime.Today);
    public bool? Recurring { get; set; }
    public string? Via { get; set; }
    public DateOnly? ThankedAt { get; set; }
    public string? Notes { get; set; }
}

public sealed class BudgetEntry : Entity
{
    public override string Collection => Collections.Budget;
    public override string DisplayTitle => Label;
    /// <summary>income, expense, saving.</summary>
    public string Kind { get; set; } = "expense";
    public string Label { get; set; } = "";
    public string? Category { get; set; }
    public long AmountCents { get; set; }
    public string Currency { get; set; } = "EUR";
    /// <summary>once, monthly, yearly.</summary>
    public string? Recurrence { get; set; } = "once";
    public DateOnly? Date { get; set; }
    /// <summary>setup (one-off before leaving) or monthly (running cost).</summary>
    public string? Phase { get; set; }
    public bool? Paid { get; set; }
    public string? Notes { get; set; }
}

public sealed class SellItem : Entity
{
    public override string Collection => Collections.SellItems;
    public override string DisplayTitle => Name;
    public string Name { get; set; } = "";
    /// <summary>decide, to-list, listed, reserved, sold, given-away, keep, store.</summary>
    public string Status { get; set; } = "decide";
    public long? AskingCents { get; set; }
    public long? SoldCents { get; set; }
    public string? Currency { get; set; } = "EUR";
    public string? Platform { get; set; }
    public string? ListingUrl { get; set; }
    public string? Buyer { get; set; }
    public DateOnly? PickupDate { get; set; }
    public string? Location { get; set; }
    public string? Notes { get; set; }
}

public sealed class PackingItem : Entity
{
    public override string Collection => Collections.Packing;
    public override string DisplayTitle => Name;
    public string Name { get; set; } = "";
    /// <summary>checked, carry-on, personal, ship, buy-there, leave.</summary>
    public string? Bag { get; set; } = "checked";
    public string? Category { get; set; }
    public int? Quantity { get; set; } = 1;
    public bool Packed { get; set; }
    public int? WeightGrams { get; set; }
    public string? Notes { get; set; }
}

/// <summary>Notes, prayer notes, journal, meeting notes.</summary>
public sealed class Note : Entity
{
    public override string Collection => Collections.Notes;
    public override string DisplayTitle => Title;
    public string Title { get; set; } = "";
    /// <summary>Markdown.</summary>
    public string? Body { get; set; }
    public string? Area { get; set; }
    public bool? Pinned { get; set; }
    /// <summary>note, prayer, journal, meeting, idea.</summary>
    public string? Kind { get; set; } = "note";
    public DateOnly? AnsweredAt { get; set; }
}

/// <summary>An important document you must not lose. The file lives at /v1/files/{fileId} and in the local vault.</summary>
public sealed class DocumentItem : Entity
{
    public override string Collection => Collections.Documents;
    public override string DisplayTitle => Title;
    public string Title { get; set; } = "";
    /// <summary>passport, visa, insurance, ticket, id, bank, medical, diploma, reference, contract, receipt, letter, other.</summary>
    public string Kind { get; set; } = "other";
    public string? FileId { get; set; }
    public string? FileName { get; set; }
    public string? MimeType { get; set; }
    public long? SizeBytes { get; set; }
    public string? Sha256 { get; set; }
    public string? Number { get; set; }
    public DateOnly? IssuedAt { get; set; }
    public DateOnly? ExpiresAt { get; set; }
    public bool? Offline { get; set; }
    public string? Notes { get; set; }
}

public sealed class Contact : Entity
{
    public override string Collection => Collections.Contacts;
    public override string DisplayTitle => Name;
    public string Name { get; set; } = "";
    public string? Role { get; set; }
    public string? Organisation { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? Notes { get; set; }
}

public sealed class Newsletter : Entity
{
    public override string Collection => Collections.Newsletters;
    public override string DisplayTitle => Title;
    public string Title { get; set; } = "";
    public int? Number { get; set; }
    /// <summary>idea, draft, ready, sent.</summary>
    public string Status { get; set; } = "draft";
    public DateOnly? PlannedDate { get; set; }
    public DateTimeOffset? SentAt { get; set; }
    /// <summary>Markdown.</summary>
    public string? Body { get; set; }
    public string? WebUrl { get; set; }
    public string? Notes { get; set; }
}

/// <summary>Shared settings record (key "main", fixed id <see cref="MainId"/>), same on every device.</summary>
public sealed class SettingRecord : Entity
{
    public const string MainId = "60a98c2f-4004-58e7-bcc2-c88a62377933";
    public override string Collection => Collections.Settings;
    public override string DisplayTitle => Key;
    public string Key { get; set; } = "main";
    public DateOnly? DepartureDate { get; set; } = new(2027, 1, 5);
    public long? SupportTargetMonthlyCents { get; set; } = 100000;
    public long? SupportMinimumMonthlyCents { get; set; } = 75000;
    public string? Currency { get; set; } = "EUR";
    public double? NzdPerEur { get; set; } = 1.85;
}

/// <summary>This-device-only settings (stored locally, never synced).</summary>
public sealed class LocalSettings
{
    public string ApiUrl { get; set; } = "https://api.92-5-233-11.sslip.io";
    public string? Email { get; set; }
    public string DeviceName { get; set; } = Environment.MachineName;
    public bool AutoSync { get; set; } = true;
    /// <summary>Opaque sync cursor from the last SyncResponse.</summary>
    public string? Cursor { get; set; }
    public DateTimeOffset? LastSync { get; set; }
}

public enum SyncState { NotConfigured, Idle, Syncing, Offline, Error }

public sealed record SyncResult(int Pushed, int Pulled, int Rejected, int FilesUploaded, int FilesDownloaded, string? Error)
{
    public bool Ok => Error is null;
}

public sealed record SearchHit(string Id, string Collection, string Title, string Snippet);

/// <summary>Home screen numbers, computed locally (works offline).</summary>
public sealed record Summary(
    DateOnly Today, DateOnly? DepartureDate, int? DaysToDeparture,
    int TasksOpen, int TasksOverdue, int TasksDueThisWeek, int TasksDone,
    long CommittedMonthlyCents, long TargetMonthlyCents, long MinimumMonthlyCents, int Partners, int FollowUpsDue,
    int SellItemsLeft, long SoldCents,
    int PackingTotal, int PackingPacked,
    int DocumentsTotal, int DocumentsMissingFile, int DocumentsExpiringSoon);
