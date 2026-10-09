using System.Text.Json;
using System.Text.Json.Nodes;

namespace Missie.Core;

/// <summary>
/// Starter data embedded as Seed/seed.json: the same file as server/seed/seed-data.json (checklists and tasks from
/// admin/visa-en-vertrek-checklist.md, budget lines, packing list, document placeholders, settings).
/// Ids follow the server's seed script (uuidv5 of "collection:key"), so seeding here and on the server never duplicates.
/// </summary>
internal static class SeedData
{
    public static List<Entity> Build()
    {
        using var stream = typeof(SeedData).Assembly.GetManifestResourceStream("Missie.Core.Seed.seed.json")
                           ?? throw new InvalidOperationException("Seed resource missing.");
        var items = JsonNode.Parse(stream) as JsonArray ?? throw new InvalidOperationException("Seed must be an array.");
        var list = new List<Entity>();
        foreach (var item in items.OfType<JsonObject>())
        {
            var collection = (string?)item["collection"];
            var key = (string?)item["key"];
            if (collection is null || key is null || item["data"] is not JsonObject src) continue;
            var data = (JsonObject)src.DeepClone();
            Ref(data, "checklistId", Collections.Checklists);
            Ref(data, "parentTaskId", Collections.Tasks);
            Ref(data, "contactId", Collections.Contacts);
            Ref(data, "partnerId", Collections.Partners);
            if (data["links"] is JsonArray links)
                foreach (var l in links.OfType<JsonObject>())
                    if ((string?)l["key"] is { } lk && (string?)l["collection"] is { } lc)
                    {
                        l.Remove("key");
                        l["id"] = StableIds.Seed(lc, lk);
                    }
            var e = MissieJson.DeserializeData(collection, data.ToJsonString());
            if (e is null) continue;
            e.Id = StableIds.Seed(collection, key);
            list.Add(e);
        }
        return list;
    }

    private static void Ref(JsonObject data, string field, string collection)
    {
        if ((string?)data[field] is { } key) data[field] = StableIds.Seed(collection, key);
    }
}
