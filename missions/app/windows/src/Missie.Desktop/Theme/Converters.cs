using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace Missie.Desktop.Theme;

/// <summary>true → Visible, false/null → Collapsed. Invert="True" (or ConverterParameter "invert") flips it.</summary>
public sealed class BoolToVisibilityConverter : IValueConverter
{
    public bool Invert { get; set; }

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var b = value is true;
        if (Invert ^ IsInvert(parameter)) b = !b;
        return b ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var b = value is Visibility.Visible;
        return Invert ^ IsInvert(parameter) ? !b : b;
    }

    private static bool IsInvert(object? p) => p is string s && s.Equals("invert", StringComparison.OrdinalIgnoreCase);
}

/// <summary>null, empty string or 0-count collection → Collapsed, otherwise Visible. Invert="True" flips it.</summary>
public sealed class NullToCollapsedConverter : IValueConverter
{
    public bool Invert { get; set; }

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var empty = value is null || value is 0 || value is string { Length: 0 } || value is System.Collections.ICollection { Count: 0 };
        if (Invert) empty = !empty;
        return empty ? Visibility.Collapsed : Visibility.Visible;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => Binding.DoNothing;
}

/// <summary>Integer cents ⇄ "€ 1.234,50" (nl-NL). ConverterParameter "plain" gives "1.234,50" (for edit boxes),
/// "whole" rounds to whole euros ("€ 1.235"). ConvertBack accepts "1234,5", "1.234,50", "€ 12" or "12.50".</summary>
public sealed class CentsToEuroConverter : IValueConverter
{
    public static readonly CultureInfo Nl = CultureInfo.GetCultureInfo("nl-NL");

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        long? cents = value switch
        {
            long l => l,
            int i => i,
            decimal d => (long)d,
            double db => (long)db,
            _ => null,
        };
        if (cents is null) return "";
        return (parameter as string) switch
        {
            "plain" => Money.Plain(cents.Value),
            "whole" => Money.Whole(cents.Value),
            _ => Money.Euro(cents.Value),
        };
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var parsed = Money.TryParseCents(value as string);
        if (parsed is null)
        {
            if (string.IsNullOrWhiteSpace(value as string) && Nullable.GetUnderlyingType(targetType) is not null) return null;
            return DependencyProperty.UnsetValue;
        }
        if (targetType == typeof(int) || targetType == typeof(int?)) return (int)parsed.Value;
        return parsed.Value;
    }
}

/// <summary>Money formatting helpers (nl-NL): € 1.234,50.</summary>
public static class Money
{
    public static string Euro(long cents) => "€ " + Plain(cents);
    public static string Plain(long cents) => (cents / 100m).ToString("#,##0.00", CentsToEuroConverter.Nl);
    public static string Whole(long cents) => "€ " + Math.Round(cents / 100m, MidpointRounding.AwayFromZero).ToString("#,##0", CentsToEuroConverter.Nl);

    /// <summary>Parses "1.234,50", "1234,5", "12.50", "€ 12" to cents. Null when not a number.</summary>
    public static long? TryParseCents(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var s = text.Replace("€", "").Replace("EUR", "", StringComparison.OrdinalIgnoreCase).Replace(" ", "").Trim();
        if (s.Length == 0) return null;
        // Decide decimal separator: the last of ',' or '.' when followed by 1-2 digits.
        var lastComma = s.LastIndexOf(',');
        var lastDot = s.LastIndexOf('.');
        var sepIndex = Math.Max(lastComma, lastDot);
        string normalized;
        if (sepIndex >= 0 && s.Length - sepIndex - 1 is 1 or 2)
        {
            var intPart = s[..sepIndex].Replace(",", "").Replace(".", "");
            normalized = intPart + "." + s[(sepIndex + 1)..];
        }
        else
        {
            normalized = s.Replace(",", "").Replace(".", "");
        }
        return decimal.TryParse(normalized, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var d)
            ? (long)Math.Round(d * 100m, MidpointRounding.AwayFromZero)
            : null;
    }
}

/// <summary>DateOnly? ⇄ DateTime? for DatePicker.SelectedDate.</summary>
public sealed class DateOnlyToDateTimeConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is DateOnly d ? d.ToDateTime(TimeOnly.MinValue) : null;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is DateTime dt ? DateOnly.FromDateTime(dt) : null;
}

/// <summary>A key → accent brush. Accepts colour names (yellow, pink, green, lime, purple, sand, grey),
/// areas (visa, finance…), collections (tasks, partners…) and statuses; anything else gets a stable colour by hash.</summary>
public sealed class AccentFromKeyConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        Look.Accent(value as string ?? parameter as string);

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => Binding.DoNothing;
}

/// <summary>Area/collection key → icon glyph (Segoe Fluent Icons).</summary>
public sealed class GlyphFromKeyConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        Look.Glyph(value as string ?? parameter as string);

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => Binding.DoNothing;
}

/// <summary>Accent colours and icons for areas, collections and statuses; same values as Brutal.xaml.</summary>
public static class Look
{
    public static readonly SolidColorBrush Yellow = Freeze("#FFD21F");
    public static readonly SolidColorBrush Pink = Freeze("#FF4F7B");
    public static readonly SolidColorBrush Green = Freeze("#2DBE4E");
    public static readonly SolidColorBrush Lime = Freeze("#A4E22F");
    public static readonly SolidColorBrush Purple = Freeze("#7B61FF");
    public static readonly SolidColorBrush Sand = Freeze("#FFE08A");
    public static readonly SolidColorBrush Grey = Freeze("#9A9A9A");
    public static readonly SolidColorBrush Ink = Freeze("#111111");
    public static readonly SolidColorBrush Paper = Freeze("#FFFDF7");

    private static readonly SolidColorBrush[] Cycle = [Yellow, Pink, Green, Lime, Purple, Sand];

    // Glyph codepoints (Segoe Fluent Icons / MDL2 Assets)
    public const string GHome = "", GChecklist = "", GTask = "", GPeople = "", GMoney = "",
        GTag = "", GPackage = "", GDocument = "", GNote = "", GMail = "", GContact = "",
        GSettings = "", GSearch = "", GSync = "", GAdd = "", GDelete = "", GUp = "",
        GDown = "", GLink = "", GCalendar = "", GOpen = "", GFolder = "", GPlane = "",
        GClose = "", GEdit = "", GFlag = "", GHeart = "", GWarning = "", GBolt = "",
        GWorld = "", GShield = "", GHealth = "", GStar = "", GGift = "", GCheck = "",
        GClock = "", GMore = "";

    public static SolidColorBrush Accent(string? key) => (key ?? "").ToLowerInvariant() switch
    {
        "" => Grey,
        "yellow" => Yellow, "pink" => Pink, "green" => Green, "lime" => Lime, "purple" => Purple, "sand" => Sand, "grey" or "gray" => Grey,
        // areas (accentFor.area in missions/app/design/tokens.json)
        "visa" => Purple, "admin" => Grey, "finance" => Green, "support" => Pink, "newsletter" => Pink, "selling" => Sand,
        "packing" => Lime, "housing" => Sand, "health" => Pink, "insurance" => Purple, "church" => Yellow, "travel" => Lime,
        "ywam" => Yellow, "personal" => Sand, "other" => Grey,
        // collections / sections (accentFor in tokens.json)
        "today" => Yellow, "tasks" => Yellow, "checklists" => Lime, "partners" => Pink, "gifts" => Pink, "documents" => Purple,
        "budget" => Green, "sellitems" => Sand, "notes" => Sand, "prayer" => Purple, "newsletters" => Pink, "contacts" => Grey,
        "settings" => Grey,
        // statuses
        "todo" => Sand, "doing" => Yellow, "waiting" => Purple, "done" => Green, "skipped" => Grey,
        "high" => Pink, "normal" => Sand, "low" => Grey,
        _ => Cycle[(int)((uint)StableHash(key!) % Cycle.Length)],
    };

    public static string Glyph(string? key) => (key ?? "").ToLowerInvariant() switch
    {
        "visa" => GPlane, "admin" => GDocument, "finance" => GMoney, "support" => GHeart, "newsletter" => GMail, "selling" => GTag,
        "packing" => GPackage, "housing" => GHome, "health" => GHealth, "insurance" => GShield, "church" => GStar, "travel" => GPlane,
        "ywam" => GWorld, "personal" => GContact,
        "tasks" => GTask, "checklists" => GChecklist, "partners" => GPeople, "gifts" => GGift, "budget" => GMoney, "sellitems" => GTag,
        "notes" => GNote, "documents" => GDocument, "contacts" => GContact, "newsletters" => GMail, "settings" => GSettings,
        _ => GFolder,
    };

    /// <summary>Human label for a collection key (used for search groups and link chips).</summary>
    public static string CollectionLabel(string? collection) => collection switch
    {
        "tasks" => "Tasks", "checklists" => "Checklists", "partners" => "Partners", "gifts" => "Gifts", "budget" => "Budget",
        "sellItems" => "Selling", "packing" => "Packing", "notes" => "Notes", "documents" => "Documents", "contacts" => "Contacts",
        "newsletters" => "Newsletters", "settings" => "Settings",
        _ => collection ?? "",
    };

    /// <summary>Collection accent (same map as tokens.json accentFor).</summary>
    public static SolidColorBrush CollectionAccent(string? collection) => Accent(collection);

    private static int StableHash(string s)
    {
        unchecked
        {
            var h = 23;
            foreach (var ch in s) h = h * 31 + ch;
            return h;
        }
    }

    private static SolidColorBrush Freeze(string hex)
    {
        var b = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
        b.Freeze();
        return b;
    }
}
