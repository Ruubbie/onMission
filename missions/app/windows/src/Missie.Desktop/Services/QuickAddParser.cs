using System.Globalization;
using System.Text.RegularExpressions;
using Missie.Core;

namespace Missie.Desktop.Services;

/// <summary>Turns "call bank fri ! #finance" into a TaskItem: "!" = high priority, "#area" = area,
/// dates: today, tomorrow/morgen, weekday names (en/nl, short or long: next one after today), "12/11", "12-11", "12/11/2026", "2026-11-12".</summary>
public static partial class QuickAddParser
{
    private static readonly Dictionary<string, DayOfWeek> Days = new(StringComparer.OrdinalIgnoreCase)
    {
        ["mon"] = DayOfWeek.Monday, ["monday"] = DayOfWeek.Monday, ["ma"] = DayOfWeek.Monday, ["maandag"] = DayOfWeek.Monday,
        ["tue"] = DayOfWeek.Tuesday, ["tues"] = DayOfWeek.Tuesday, ["tuesday"] = DayOfWeek.Tuesday, ["di"] = DayOfWeek.Tuesday, ["dinsdag"] = DayOfWeek.Tuesday,
        ["wed"] = DayOfWeek.Wednesday, ["wednesday"] = DayOfWeek.Wednesday, ["wo"] = DayOfWeek.Wednesday, ["woensdag"] = DayOfWeek.Wednesday,
        ["thu"] = DayOfWeek.Thursday, ["thur"] = DayOfWeek.Thursday, ["thurs"] = DayOfWeek.Thursday, ["thursday"] = DayOfWeek.Thursday, ["do"] = DayOfWeek.Thursday, ["donderdag"] = DayOfWeek.Thursday,
        ["fri"] = DayOfWeek.Friday, ["friday"] = DayOfWeek.Friday, ["vr"] = DayOfWeek.Friday, ["vrijdag"] = DayOfWeek.Friday,
        ["sat"] = DayOfWeek.Saturday, ["saturday"] = DayOfWeek.Saturday, ["za"] = DayOfWeek.Saturday, ["zaterdag"] = DayOfWeek.Saturday,
        ["sun"] = DayOfWeek.Sunday, ["sunday"] = DayOfWeek.Sunday, ["zo"] = DayOfWeek.Sunday, ["zondag"] = DayOfWeek.Sunday,
    };

    [GeneratedRegex(@"^(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?$")]
    private static partial Regex DayMonth();

    public static TaskItem Parse(string input, DateOnly? today = null)
    {
        var now = today ?? DateOnly.FromDateTime(DateTime.Today);
        var task = new TaskItem { Status = "todo", Priority = "normal" };
        var kept = new List<string>();
        var tokens = input.Trim().TrimStart('#').Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);

        foreach (var raw in tokens)
        {
            var t = raw.Trim();
            if (t is "!" or "!!" or "!!!") { task.Priority = "high"; continue; }
            if (t.Length > 1 && t.EndsWith('!') && ReferenceEquals(raw, tokens[^1]))
            {
                // "call bank!" at the end also means high priority
                task.Priority = "high";
                t = t.TrimEnd('!');
            }
            if (t.StartsWith('#') && t.Length > 1 && Areas.All.Contains(t[1..].ToLowerInvariant()))
            {
                task.Area = t[1..].ToLowerInvariant();
                continue;
            }
            if (task.DueDate is null && TryDate(t, now) is { } d) { task.DueDate = d; continue; }
            kept.Add(t);
        }
        task.Title = string.Join(' ', kept);
        if (string.IsNullOrWhiteSpace(task.Title)) task.Title = input.Trim();
        return task;
    }

    public static DateOnly? TryDate(string t, DateOnly today)
    {
        switch (t.ToLowerInvariant())
        {
            case "today": case "vandaag": return today;
            case "tomorrow": case "tmr": case "morgen": return today.AddDays(1);
            case "overmorgen": return today.AddDays(2);
            case "nextweek": return today.AddDays(7);
        }
        if (Days.TryGetValue(t, out var dow))
        {
            var diff = ((int)dow - (int)today.DayOfWeek + 7) % 7;
            return today.AddDays(diff == 0 ? 7 : diff);
        }
        if (DateOnly.TryParseExact(t, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var iso)) return iso;
        var m = DayMonth().Match(t);
        if (m.Success)
        {
            var day = int.Parse(m.Groups[1].Value);
            var month = int.Parse(m.Groups[2].Value);
            if (month is < 1 or > 12 || day < 1 || day > DateTime.DaysInMonth(2028, month)) return null;
            int year;
            if (m.Groups[3].Success)
            {
                year = int.Parse(m.Groups[3].Value);
                if (year < 100) year += 2000;
            }
            else
            {
                year = today.Year;
                if (new DateOnly(year, month, Math.Min(day, DateTime.DaysInMonth(year, month))) < today) year++;
            }
            if (day > DateTime.DaysInMonth(year, month)) return null;
            return new DateOnly(year, month, day);
        }
        return null;
    }
}
