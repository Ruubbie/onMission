using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

namespace Missie.Core;

/// <summary>Deterministic ids, identical to the server's seed script (server/seed/seed.mjs).</summary>
internal static class StableIds
{
    /// <summary>uuidv5(URL namespace, "https://api.rubenonmission.nl/seed"). Never change it.</summary>
    public const string SeedNamespace = "5d2e260a-4981-59b8-9217-421fb993f1d5";

    /// <summary>Id of a seeded record: uuidv5("{collection}:{key}", SeedNamespace).</summary>
    public static string Seed(string collection, string key) => UuidV5(collection + ":" + key, SeedNamespace);

    public static string UuidV5(string name, string ns)
    {
        var nsBytes = Convert.FromHexString(ns.Replace("-", ""));
        var h = SHA1.HashData([.. nsBytes, .. Encoding.UTF8.GetBytes(name)]);
        h[6] = (byte)((h[6] & 0x0F) | 0x50);
        h[8] = (byte)((h[8] & 0x3F) | 0x80);
        var hex = Convert.ToHexStringLower(h, 0, 16);
        return $"{hex[..8]}-{hex[8..12]}-{hex[12..16]}-{hex[16..20]}-{hex[20..32]}";
    }
}

/// <summary>JSON rules shared with the API: camelCase, nulls omitted, dates yyyy-MM-dd, times UTC with ms.</summary>
public static class MissieJson
{
    public const string TimeFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";

    // Envelope fields live outside `data`; the store sets them from the record.
    private static readonly HashSet<string> EnvelopeProps = ["Id", "Collection", "UpdatedAt", "DeletedAt", "DisplayTitle"];

    public static readonly JsonSerializerOptions Options = Create();

    private static JsonSerializerOptions Create()
    {
        var o = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            PropertyNameCaseInsensitive = true,
            NumberHandling = JsonNumberHandling.AllowReadingFromString,
            TypeInfoResolver = new DefaultJsonTypeInfoResolver
            {
                Modifiers =
                {
                    ti =>
                    {
                        if (ti.Kind != JsonTypeInfoKind.Object || !typeof(Entity).IsAssignableFrom(ti.Type)) return;
                        for (var i = ti.Properties.Count - 1; i >= 0; i--)
                        {
                            var p = ti.Properties[i];
                            if (p.AttributeProvider is System.Reflection.PropertyInfo pi && EnvelopeProps.Contains(pi.Name))
                                ti.Properties.RemoveAt(i);
                        }
                    },
                },
            },
        };
        o.Converters.Add(new DateOnlyConverter());
        o.Converters.Add(new TimeConverter());
        o.MakeReadOnly(populateMissingResolver: false);
        return o;
    }

    public static string Iso(DateTimeOffset t) => t.ToUniversalTime().ToString(TimeFormat, CultureInfo.InvariantCulture);

    public static DateTimeOffset ParseTime(string s) =>
        DateTimeOffset.Parse(s, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);

    public static DateTimeOffset? ParseTimeOrNull(string? s) => string.IsNullOrEmpty(s) ? null : ParseTime(s);

    /// <summary>Now in UTC, truncated to whole milliseconds (what goes over the wire).</summary>
    public static DateTimeOffset UtcNowMs()
    {
        var n = DateTimeOffset.UtcNow;
        return new DateTimeOffset(n.Ticks - n.Ticks % TimeSpan.TicksPerMillisecond, TimeSpan.Zero);
    }

    public static string SerializeData(Entity e) => JsonSerializer.Serialize(e, e.GetType(), Options);

    public static Entity? DeserializeData(string collection, string json)
    {
        if (!Collections.Map.TryGetValue(collection, out var type)) return null;
        return (Entity?)JsonSerializer.Deserialize(string.IsNullOrWhiteSpace(json) ? "{}" : json, type, Options);
    }

    private sealed class DateOnlyConverter : JsonConverter<DateOnly>
    {
        public override DateOnly Read(ref Utf8JsonReader r, Type t, JsonSerializerOptions o)
        {
            var s = r.GetString() ?? throw new JsonException("date expected");
            if (DateOnly.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)) return d;
            // Tolerate a full timestamp where a date was expected.
            return DateOnly.FromDateTime(ParseTime(s).UtcDateTime);
        }

        public override void Write(Utf8JsonWriter w, DateOnly v, JsonSerializerOptions o) =>
            w.WriteStringValue(v.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    }

    private sealed class TimeConverter : JsonConverter<DateTimeOffset>
    {
        public override DateTimeOffset Read(ref Utf8JsonReader r, Type t, JsonSerializerOptions o) =>
            ParseTime(r.GetString() ?? throw new JsonException("timestamp expected"));

        public override void Write(Utf8JsonWriter w, DateTimeOffset v, JsonSerializerOptions o) => w.WriteStringValue(Iso(v));
    }
}
