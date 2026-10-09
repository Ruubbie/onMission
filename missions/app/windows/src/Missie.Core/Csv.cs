using System.Globalization;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Missie.Core;

/// <summary>
/// CSV for working in Excel. Columns: id + every simple data field (camelCase, as in the API). Lists (tags, fileIds)
/// are ';'-separated, links are "collection:id" separated by ';'. Money stays in cents. Export is UTF-8 with BOM and
/// commas; import detects ',', ';' (Excel on Dutch Windows) or tab from the header line.
/// </summary>
internal static class Csv
{
    private sealed record Column(string Name, PropertyInfo Prop);

    private static readonly Dictionary<Type, List<Column>> ColumnCache = [];

    private static List<Column> Columns(Type t)
    {
        lock (ColumnCache)
        {
            if (ColumnCache.TryGetValue(t, out var cached)) return cached;
            var props = t.GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.CanRead && p.CanWrite && p.GetIndexParameters().Length == 0)
                .Where(p => p.GetCustomAttribute<JsonIgnoreAttribute>() is not { Condition: JsonIgnoreCondition.Always })
                .Where(p => p.GetCustomAttribute<JsonExtensionDataAttribute>() is null)
                .Where(p => p.Name is not ("Id" or "UpdatedAt" or "DeletedAt"))
                .Where(p => IsSimple(p.PropertyType) || p.PropertyType == typeof(List<string>) || p.PropertyType == typeof(List<Link>))
                .OrderBy(p => p.DeclaringType == t ? 0 : 1)
                .ThenBy(p => p.MetadataToken)
                .Select(p => new Column(JsonNamingPolicy.CamelCase.ConvertName(p.Name), p))
                .ToList();
            var list = new List<Column> { new("id", typeof(Entity).GetProperty(nameof(Entity.Id))!) };
            list.AddRange(props);
            ColumnCache[t] = list;
            return list;
        }
    }

    private static bool IsSimple(Type t)
    {
        t = Nullable.GetUnderlyingType(t) ?? t;
        return t == typeof(string) || t == typeof(bool) || t == typeof(int) || t == typeof(long) || t == typeof(double)
               || t == typeof(decimal) || t == typeof(DateOnly) || t == typeof(DateTimeOffset);
    }

    // ---- Export --------------------------------------------------------------------------------

    public static string Export<T>(IEnumerable<T> items) where T : Entity
    {
        var cols = Columns(typeof(T));
        var sb = new StringBuilder("﻿");
        sb.Append(string.Join(",", cols.Select(c => Quote(c.Name)))).Append("\r\n");
        foreach (var e in items)
            sb.Append(string.Join(",", cols.Select(c => Quote(Format(c.Prop.GetValue(e)))))).Append("\r\n");
        return sb.ToString();
    }

    private static string Format(object? v) => v switch
    {
        null => "",
        string s => s,
        bool b => b ? "true" : "false",
        DateOnly d => d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
        DateTimeOffset t => MissieJson.Iso(t),
        List<string> l => string.Join(";", l),
        List<Link> l => string.Join(";", l.Select(x => x.Collection + ":" + x.Id)),
        IFormattable f => f.ToString(null, CultureInfo.InvariantCulture),
        _ => v.ToString() ?? "",
    };

    private static string Quote(string s) =>
        s.IndexOfAny([',', ';', '"', '\r', '\n', '\t']) >= 0 || s != s.Trim() ? "\"" + s.Replace("\"", "\"\"") + "\"" : s;

    // ---- Import --------------------------------------------------------------------------------

    public static List<T> Import<T>(string csv, Func<string, T?> getExisting, Func<string, Entity?> getAny) where T : Entity, new()
    {
        csv = csv.TrimStart('﻿');
        var headerEnd = csv.IndexOfAny(['\r', '\n']);
        var delimiter = DetectDelimiter(headerEnd < 0 ? csv : csv[..headerEnd]);
        var rows = Parse(csv, delimiter);
        if (rows.Count == 0) return [];

        var byName = Columns(typeof(T)).ToDictionary(c => c.Name, StringComparer.OrdinalIgnoreCase);
        var header = rows[0].Select(h => byName.GetValueOrDefault(h.Trim())).ToList();
        var result = new List<T>();
        foreach (var row in rows.Skip(1))
        {
            if (row.All(string.IsNullOrWhiteSpace)) continue;
            string? id = null;
            for (var i = 0; i < header.Count && i < row.Count; i++)
                if (header[i]?.Name == "id") id = row[i].Trim().ToLowerInvariant();
            var entity = (!string.IsNullOrEmpty(id) ? getExisting(id) : null) ?? new T();
            if (!string.IsNullOrEmpty(id) && Guid.TryParse(id, out _)) entity.Id = id;
            for (var i = 0; i < header.Count && i < row.Count; i++)
            {
                var col = header[i];
                if (col is null || col.Name == "id") continue;
                col.Prop.SetValue(entity, ParseValue(row[i], col.Prop, col.Prop.GetValue(entity), getAny));
            }
            result.Add(entity);
        }
        return result;
    }

    private static char DetectDelimiter(string header)
    {
        int comma = 0, semi = 0, tab = 0;
        var quoted = false;
        foreach (var ch in header)
        {
            if (ch == '"') quoted = !quoted;
            else if (!quoted)
            {
                if (ch == ',') comma++;
                else if (ch == ';') semi++;
                else if (ch == '\t') tab++;
            }
        }
        return tab > comma && tab > semi ? '\t' : semi > comma ? ';' : ',';
    }

    /// <summary>RFC 4180: quoted fields, doubled quotes, line breaks inside quotes.</summary>
    internal static List<List<string>> Parse(string text, char delimiter)
    {
        var rows = new List<List<string>>();
        var row = new List<string>();
        var field = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < text.Length; i++)
        {
            var ch = text[i];
            if (quoted)
            {
                if (ch == '"')
                {
                    if (i + 1 < text.Length && text[i + 1] == '"') { field.Append('"'); i++; }
                    else quoted = false;
                }
                else field.Append(ch);
            }
            else if (ch == '"') quoted = true;
            else if (ch == delimiter) { row.Add(field.ToString()); field.Clear(); }
            else if (ch is '\r' or '\n')
            {
                if (ch == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
                row.Add(field.ToString()); field.Clear();
                rows.Add(row); row = [];
            }
            else field.Append(ch);
        }
        if (field.Length > 0 || row.Count > 0) { row.Add(field.ToString()); rows.Add(row); }
        return rows;
    }

    private static readonly CultureInfo Dutch = CultureInfo.GetCultureInfo("nl-NL");

    private static object? ParseValue(string raw, PropertyInfo prop, object? current, Func<string, Entity?> getAny)
    {
        var type = prop.PropertyType;
        var s = raw.Trim();
        var under = Nullable.GetUnderlyingType(type);
        var nullable = under is not null || !type.IsValueType && IsNullableRef(prop);
        var t = under ?? type;

        if (type == typeof(List<string>))
            return s.Length == 0 ? null : s.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
        if (type == typeof(List<Link>))
        {
            if (s.Length == 0) return null;
            var old = (current as List<Link>) ?? [];
            var links = new List<Link>();
            foreach (var part in s.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var idx = part.IndexOf(':');
                var id = (idx >= 0 ? part[(idx + 1)..] : part).Trim().ToLowerInvariant();
                var target = getAny(id);
                var collection = target?.Collection ?? (idx >= 0 ? part[..idx].Trim() : "");
                if (collection.Length == 0) continue;
                links.Add(new Link { Collection = collection, Id = id, Label = target?.DisplayTitle ?? old.FirstOrDefault(l => l.Id == id)?.Label });
            }
            return links.Count == 0 ? null : links;
        }
        // An empty cell clears an optional text (null) but keeps "" for required ones like Title.
        if (t == typeof(string)) return raw.Length == 0 && nullable ? null : raw;
        if (s.Length == 0) return nullable ? null : current;

        try
        {
            if (t == typeof(bool))
                return s.ToLowerInvariant() switch
                {
                    "true" or "1" or "yes" or "ja" or "waar" or "x" => true,
                    "false" or "0" or "no" or "nee" or "onwaar" => false,
                    _ => current,
                };
            if (t == typeof(int)) return (int)ParseNumber(s);
            if (t == typeof(long)) return (long)ParseNumber(s);
            if (t == typeof(double)) return (double)ParseNumber(s);
            if (t == typeof(decimal)) return ParseNumber(s);
            if (t == typeof(DateOnly))
            {
                if (DateOnly.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)) return d;
                if (DateOnly.TryParse(s, Dutch, DateTimeStyles.None, out d)) return d;
                return DateOnly.FromDateTime(MissieJson.ParseTime(s).UtcDateTime);
            }
            if (t == typeof(DateTimeOffset))
            {
                if (DateTimeOffset.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var x)) return x.ToUniversalTime();
                return DateTimeOffset.Parse(s, Dutch, DateTimeStyles.AssumeLocal).ToUniversalTime();
            }
        }
        catch (FormatException) { return current; }
        catch (OverflowException) { return current; }
        return current;
    }

    private static bool IsNullableRef(PropertyInfo p)
    {
        lock (Nullability) return Nullability.Create(p).WriteState != NullabilityState.NotNull;
    }

    private static readonly NullabilityInfoContext Nullability = new();

    private static decimal ParseNumber(string s)
    {
        s = s.Replace(" ", "").Replace(" ", "");
        // "1.5" or "1,5" (Dutch Excel); with both, the last one is the decimal separator.
        var lastDot = s.LastIndexOf('.');
        var lastComma = s.LastIndexOf(',');
        if (lastComma > lastDot) s = s.Replace(".", "").Replace(',', '.');
        else if (lastDot > lastComma && lastComma >= 0) s = s.Replace(",", "");
        return decimal.Parse(s, NumberStyles.Float, CultureInfo.InvariantCulture);
    }
}
