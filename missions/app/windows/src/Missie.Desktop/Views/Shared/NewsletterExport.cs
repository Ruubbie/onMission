using System.Globalization;
using System.Text;
using Missie.Core;

namespace Missie.Desktop.Views.Shared;

/// <summary>
/// Turns a Newsletter into the same files as the hand-made issue #1 in missions/website:
/// nieuwsbrief/{n}-{slug}.html (site page) and email/{n}-{slug}.html (inline-styled mail for tools/verstuur.mjs).
/// </summary>
public static class NewsletterExport
{
    public const string SiteUrl = "https://rubenonmission.nl";
    static readonly CultureInfo Nl = CultureInfo.GetCultureInfo("nl-NL");

    public static string FileName(Newsletter n) => $"{n.Number ?? 0}-{Slug(n.Title)}.html";

    public static string Slug(string? title)
    {
        var norm = (title ?? "").Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var ch in norm)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark) continue;
            var c = char.ToLowerInvariant(ch);
            if (c is >= 'a' and <= 'z' or >= '0' and <= '9') sb.Append(c);
            else if (sb.Length > 0 && sb[^1] != '-') sb.Append('-');
        }
        var s = sb.ToString().Trim('-');
        return s.Length == 0 ? "nieuwsbrief" : s;
    }

    static DateOnly IssueDate(Newsletter n) =>
        n.PlannedDate ?? (n.SentAt is { } s ? DateOnly.FromDateTime(s.LocalDateTime) : Fmt.Today);

    static string Eyebrow(Newsletter n) => $"Nieuwsbrief #{n.Number ?? 0} · {IssueDate(n).ToString("MMMM yyyy", Nl)}";

    static string Minutes(Newsletter n) => $"{Math.Max(1, (int)Math.Ceiling(Markdown.WordCount(n.Body) / 200.0))} minuten lezen";

    public static string Intro(Newsletter n) => Markdown.PlainText(Markdown.FirstParagraph(n.Body));

    /// <summary>{{NAAM}} only makes sense in the e-mail; on the site it reads "allemaal" like verstuur.mjs's fallback.</summary>
    static string ForSite(string? body) => (body ?? "").Replace("{{NAAM}}", "allemaal");

    static string E(string? s) => Markdown.Encode(s);

    /// <summary>The website page, same wrapper as nieuwsbrief/1-ik-ga-naar-queenstown.html.</summary>
    public static string WebsitePage(Newsletter n)
    {
        var body = Markdown.ToHtml(ForSite(n.Body), new Markdown.Styles { FillSpans = true });
        return $$"""
<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{{E(n.Title)}} · Ruben on Mission</title>
<meta name="description" content="Nieuwsbrief #{{n.Number ?? 0}}: {{E(Intro(n))}}">
<link rel="stylesheet" href="../fonts/fonts.css">
<link rel="stylesheet" href="../style.css">
</head>
<body>
<div class="wide"><nav class="nav" aria-label="Hoofdmenu"><a class="brand" href="../index.html">Ruben on Mission</a><a href="../index.html#verhaal">Verhaal</a><a href="../bidden.html">Bid mee</a><a href="../steun.html">Steun</a><a href="../nieuwsbrief/index.html" aria-current="page">Nieuwsbrief</a></nav></div>
<main>
<article class="letter col">
  <header>
    <div class="eyebrow">{{E(Eyebrow(n))}}</div>
    <h1>{{E(n.Title)}}</h1>
    <div class="meta">{{IssueDate(n).ToString("d MMMM yyyy", Nl)}} · {{Minutes(n)}}</div>
  </header>

{{body}}</article>
<section class="band" style="margin-top:40px">
  <div class="col">
    <h2>Deze nieuwsbrief elke maand ontvangen?</h2>
      <form class="signup">
        <label for="naam" class="sr">Voornaam</label>
        <input type="text" id="naam" name="naam" placeholder="Voornaam" autocomplete="given-name" maxlength="80">
        <label for="email" class="sr">E-mailadres</label>
        <input type="email" id="email" name="email" placeholder="je@email.nl" required autocomplete="email">
        <input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true">
        <button class="btn" type="submit">Aanmelden</button>
        <p class="check">Je krijgt eerst een mail om je aanmelding te bevestigen. Ik gebruik je adres alleen voor deze nieuwsbrief en je kunt je altijd met één klik afmelden. <a href="../privacy.html">Privacy</a></p>
      </form>
      <div class="signup-msg" aria-live="polite"></div>
  </div>
</section>
</main>
<footer>
  <div class="wide">Ruben on Mission · met Jeugd met een Opdracht (YWAM) Queenstown, Nieuw-Zeeland · <a href="../privacy.html">Privacy</a></div>
</footer>
<script src="../signup.js"></script>
</body>
</html>

""";
    }

    static readonly Markdown.Styles EmailStyles = new()
    {
        P = "margin:0 0 16px;",
        H2 = "font-family:Arial,Helvetica,sans-serif;font-size:21px;margin:24px 0 8px;",
        H3 = "font-family:Arial,Helvetica,sans-serif;font-size:18px;margin:20px 0 6px;",
        Ul = "margin:0 0 16px;padding-left:22px;",
        Ol = "margin:0 0 16px;padding-left:22px;",
        A = "color:#0F5D6B;",
        Blockquote = "margin:16px 0;padding:4px 0 4px 16px;border-left:3px solid #C08A2E;font-style:italic;color:#58676D;",
        Img = "width:100%;height:auto;border-radius:10px;",
        Hr = "border:0;border-top:1px solid #DCE2E0;margin:24px 0;",
        FillSpans = false,
    };

    /// <summary>The e-mail, same table layout and inline styles as email/1-ik-ga-naar-queenstown.html.</summary>
    public static string Email(Newsletter n)
    {
        var body = Markdown.ToHtml(n.Body, EmailStyles)
            .Replace("href=\"../", $"href=\"{SiteUrl}/")
            .Replace("src=\"../", $"src=\"{SiteUrl}/");
        var online = string.IsNullOrWhiteSpace(n.WebUrl) ? $"{SiteUrl}/nieuwsbrief/{FileName(n)}" : n.WebUrl!.Trim();
        return $$"""
<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{E(n.Title)}}</title>
<!-- Nieuwsbrief #{{n.Number ?? 0}}, e-mailversie (gemaakt met de Missie-app). <title> is het onderwerp.
     {{"{{NAAM}}"}} en {{"{{AFMELDEN}}"}} vult tools/verstuur.mjs per lezer in. -->
</head>
<body style="margin:0;padding:0;background:#F7F8F6;">
<div style="display:none;max-height:0;overflow:hidden;">{{E(Intro(n))}}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F7F8F6;padding:24px 12px;">
<tr><td align="center">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#FFFFFF;border:1px solid #DCE2E0;border-radius:12px;font-family:Georgia,'Times New Roman',serif;color:#152127;font-size:17px;line-height:1.6;">
<tr><td style="background:#0A3F49;color:#F2F7F7;padding:28px 32px;border-radius:12px 12px 0 0;font-family:Arial,Helvetica,sans-serif;">
  <div style="font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#E2B864;font-weight:bold;">{{E(Eyebrow(n))}}</div>
  <div style="font-size:32px;line-height:1.1;font-weight:bold;margin-top:10px;color:#F2F7F7;">{{E(n.Title)}}</div>
</td></tr>
<tr><td style="padding:28px 32px;">
{{body}}</td></tr>
<tr><td style="padding:18px 32px;border-top:1px solid #DCE2E0;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.5;color:#58676D;">
Je ontvangt deze mail omdat je je hebt aangemeld voor de nieuwsbrief van Ruben on Mission.<br>
<a href="{{E(online)}}" style="color:#58676D;">Lees online</a> · <a href="{{"{{AFMELDEN}}"}}" style="color:#58676D;">Afmelden</a>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>

""";
    }

    /// <summary>Self-contained preview for the WebBrowser control (IE engine: no CSS variables, no web fonts).</summary>
    public static string Preview(Newsletter n)
    {
        var body = Markdown.ToHtml(ForSite(n.Body), new Markdown.Styles { FillSpans = true });
        var html = $$"""
<!doctype html>
<html lang="nl"><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge">
<style>
body{margin:0;background:#F7F8F6;color:#152127;font-family:Georgia,'Times New Roman',serif;font-size:18px;line-height:1.6}
.col{max-width:680px;margin:0 auto;padding:0 24px 48px}
h1,h2,h3,.eyebrow,.meta{font-family:'Segoe UI',Arial,sans-serif}
header{padding:32px 0 8px}
.eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;font-weight:600;color:#C08A2E}
h1{font-size:44px;line-height:1;letter-spacing:-.02em;margin:6px 0 0;font-weight:700}
.meta{font-size:14px;color:#58676D;margin-top:12px}
h2{font-size:25px;line-height:1.1;margin:32px 0 10px;font-weight:700}
h3{font-size:20px;margin:20px 0 6px}
p{margin:0 0 1em}
a{color:#0F5D6B}
img{max-width:100%;border-radius:12px}
blockquote{margin:24px 0;padding:4px 0 4px 20px;border-left:3px solid #C08A2E;font-style:italic;color:#58676D}
ul,ol{padding-left:22px}
.fill{background:#F5EAD3;border-bottom:2px dotted #C08A2E;padding:0 3px}
.goal{background:#fff;border:1px solid #DCE2E0;border-radius:16px;padding:24px}
.photo{background:#EEF3F3;border:1px dashed #DCE2E0;border-radius:12px;padding:40px 16px;color:#58676D;text-align:center;font-family:'Segoe UI',Arial,sans-serif;font-size:15px;margin:24px 0}
.intro{font-family:'Segoe UI',Arial,sans-serif;font-size:12px;color:#58676D;background:#EEF3F3;padding:8px 24px}
</style></head>
<body>
<div class="intro">Preview / preheader: {{E(Intro(n))}}</div>
<article class="col">
  <header>
    <div class="eyebrow">{{E(Eyebrow(n))}}</div>
    <h1>{{E(n.Title)}}</h1>
    <div class="meta">{{IssueDate(n).ToString("d MMMM yyyy", Nl)}} · {{Minutes(n)}}</div>
  </header>
{{body}}</article>
</body></html>
""";
        // NavigateToString mangles non-ASCII text; send it as character references.
        var sb = new StringBuilder(html.Length + 256);
        foreach (var r in html.EnumerateRunes())
            if (r.Value > 127) sb.Append("&#").Append(r.Value).Append(';'); else sb.Append((char)r.Value);
        return sb.ToString();
    }
}
