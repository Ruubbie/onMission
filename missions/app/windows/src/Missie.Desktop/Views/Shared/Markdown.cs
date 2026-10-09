using System.Text;
using System.Text.RegularExpressions;

namespace Missie.Desktop.Views.Shared;

/// <summary>
/// A small Markdown to HTML renderer (no packages): headings, paragraphs, line breaks, **bold**, *italic*, _italic_,
/// [links](url), ![images](url), - / * / 1. lists, &gt; quotes, --- rules, and raw HTML lines (starting with "&lt;").
/// Optional inline styles per tag are used for e-mail. "[placeholder]" text without a link becomes a highlighted fill
/// span on the website, like the hand-written newsletter.
/// </summary>
public static partial class Markdown
{
    public sealed class Styles
    {
        public string? P, H2, H3, Ul, Ol, Li, A, Blockquote, Img, Hr;
        public bool FillSpans;
    }

    public static string ToHtml(string? markdown, Styles? styles = null)
    {
        var st = styles ?? new Styles { FillSpans = true };
        var html = new StringBuilder();
        var para = new List<string>();
        var quote = new List<string>();
        string? listTag = null;

        string Attr(string? style) => string.IsNullOrEmpty(style) ? "" : $" style=\"{style}\"";

        void FlushPara()
        {
            if (para.Count == 0) return;
            html.Append("  <p").Append(Attr(st.P)).Append('>').Append(string.Join("<br>", para.Select(l => Inline(l, st)))).Append("</p>\n");
            para.Clear();
        }
        void FlushQuote()
        {
            if (quote.Count == 0) return;
            html.Append("  <blockquote").Append(Attr(st.Blockquote)).Append('>')
                .Append(string.Join("<br>", quote.Select(l => Inline(l, st)))).Append("</blockquote>\n");
            quote.Clear();
        }
        void CloseList()
        {
            if (listTag is null) return;
            html.Append("  </").Append(listTag).Append(">\n");
            listTag = null;
        }
        void FlushAll() { FlushPara(); FlushQuote(); CloseList(); }

        foreach (var raw in (markdown ?? "").Replace("\r\n", "\n").Replace('\r', '\n').Split('\n'))
        {
            var line = raw.TrimEnd();
            var t = line.TrimStart();

            if (t.Length == 0) { FlushAll(); continue; }

            Match m;
            if ((m = HeadingRx().Match(t)).Success)
            {
                FlushAll();
                var level = m.Groups[1].Value.Length;
                var tag = level >= 3 ? "h3" : "h2";
                html.Append("  <").Append(tag).Append(Attr(tag == "h2" ? st.H2 : st.H3)).Append('>')
                    .Append(Inline(m.Groups[2].Value, st)).Append("</").Append(tag).Append(">\n");
                continue;
            }
            if (t is "---" or "***" or "___")
            {
                FlushAll();
                html.Append("  <hr").Append(Attr(st.Hr)).Append(">\n");
                continue;
            }
            if ((m = BulletRx().Match(t)).Success || (m = NumberRx().Match(t)).Success)
            {
                FlushPara(); FlushQuote();
                var tag = char.IsDigit(t[0]) ? "ol" : "ul";
                if (listTag != tag) { CloseList(); html.Append("  <").Append(tag).Append(Attr(tag == "ul" ? st.Ul : st.Ol)).Append(">\n"); listTag = tag; }
                html.Append("    <li").Append(Attr(st.Li)).Append('>').Append(Inline(m.Groups[1].Value, st)).Append("</li>\n");
                continue;
            }
            if (t.StartsWith('>'))
            {
                FlushPara(); CloseList();
                quote.Add(t.TrimStart('>').TrimStart());
                continue;
            }
            if (t.StartsWith('<') && t.EndsWith('>'))
            {
                // Raw HTML (e.g. the gift box div) passes through untouched.
                FlushAll();
                html.Append("  ").Append(t).Append('\n');
                continue;
            }
            if (listTag is not null && raw.StartsWith("  ") )
            {
                // Continuation of the previous list item: append to it.
                var at = html.ToString().LastIndexOf("</li>", StringComparison.Ordinal);
                if (at >= 0) { html.Insert(at, "<br>" + Inline(t, st)); continue; }
            }
            FlushQuote(); CloseList();
            para.Add(line.EndsWith('\\') ? line[..^1] : line);
        }
        FlushAll();
        return html.ToString();
    }

    /// <summary>Inline markup on one line of text (HTML-escaped first).</summary>
    public static string Inline(string text, Styles st)
    {
        var tokens = new List<string>();
        string Keep(string html) { tokens.Add(html); return $"\u0001{tokens.Count - 1}\u0002"; }
        string Style(string? s) => string.IsNullOrEmpty(s) ? "" : $" style=\"{s}\"";

        var s = Encode(text);
        s = ImageRx().Replace(s, m => Keep($"<img src=\"{m.Groups[2].Value}\" alt=\"{m.Groups[1].Value}\"{Style(st.Img)}>"));
        s = LinkRx().Replace(s, m => Keep($"<a href=\"{m.Groups[2].Value}\"{Style(st.A)}>{Emphasis(m.Groups[1].Value)}</a>"));
        s = AutoLinkRx().Replace(s, m => Keep($"<a href=\"{m.Value}\"{Style(st.A)}>{m.Value}</a>"));
        s = Emphasis(s);
        if (st.FillSpans) s = FillRx().Replace(s, m => $"<span class=\"fill\">{m.Value}</span>");
        return TokenRx().Replace(s, m => tokens[int.Parse(m.Groups[1].Value)]);
    }

    /// <summary>Escapes only what HTML needs, keeping é, ë, € readable in the exported file.</summary>
    public static string Encode(string? text) =>
        (text ?? "").Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;");

    static string Emphasis(string s)
    {
        s = BoldRx().Replace(s, "<b>$1</b>");
        s = BoldUnderscoreRx().Replace(s, "<b>$1</b>");
        s = ItalicRx().Replace(s, "<i>$1</i>");
        s = ItalicUnderscoreRx().Replace(s, "<i>$1</i>");
        return s;
    }

    /// <summary>Plain text of the first paragraph (used as intro / preheader).</summary>
    public static string FirstParagraph(string? markdown)
    {
        foreach (var block in Blocks(markdown))
        {
            var t = block.TrimStart();
            if (t.StartsWith('#') || t.StartsWith('!') || t.StartsWith('<') || t.StartsWith('>') || BulletRx().IsMatch(t) || IsGreeting(t)) continue;
            return block;
        }
        return "";
    }

    /// <summary>"Lieve {{NAAM}}," style salutation: one short line ending in a comma.</summary>
    static bool IsGreeting(string block) => !block.Contains('\n') && block.TrimEnd().EndsWith(',') && block.Length < 60;

    /// <summary>Replaces (or inserts) the first plain paragraph of the markdown.</summary>
    public static string WithFirstParagraph(string? markdown, string intro)
    {
        var blocks = Blocks(markdown).ToList();
        var current = FirstParagraph(markdown);
        intro = intro.Replace("\r\n", "\n").Trim();
        int at = current.Length > 0 ? blocks.IndexOf(current) : -1;
        if (at >= 0)
        {
            if (intro.Length == 0) blocks.RemoveAt(at); else blocks[at] = intro;
        }
        else if (intro.Length > 0)
        {
            // Put it after a leading heading/image, before everything else.
            int insert = 0;
            while (insert < blocks.Count && (blocks[insert].StartsWith('#') || blocks[insert].StartsWith('!') || IsGreeting(blocks[insert]))) insert++;
            blocks.Insert(insert, intro);
        }
        return string.Join("\n\n", blocks);
    }

    static IEnumerable<string> Blocks(string? markdown) =>
        BlankLineRx().Split((markdown ?? "").Replace("\r\n", "\n").Trim()).Select(b => b.Trim('\n')).Where(b => b.Trim().Length > 0);

    /// <summary>Strips markup for previews and meta descriptions.</summary>
    public static string PlainText(string? markdown)
    {
        var s = ImageRx().Replace(markdown ?? "", "");
        s = LinkRx().Replace(s, "$1");
        s = Regex.Replace(s, @"[*_#>`]", "");
        return Regex.Replace(s, @"\s+", " ").Trim();
    }

    public static int WordCount(string? markdown) =>
        PlainText(markdown).Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;

    [GeneratedRegex(@"^(#{1,6})\s+(.*)$")] private static partial Regex HeadingRx();
    [GeneratedRegex(@"^[-*+]\s+(.*)$")] private static partial Regex BulletRx();
    [GeneratedRegex(@"^\d+[.)]\s+(.*)$")] private static partial Regex NumberRx();
    [GeneratedRegex(@"!\[([^\]]*)\]\(([^)\s]+)\)")] private static partial Regex ImageRx();
    [GeneratedRegex(@"\[([^\]]+)\]\(([^)\s]+)\)")] private static partial Regex LinkRx();
    [GeneratedRegex(@"(?<![""=])\bhttps?://[^\s<]+[^\s<.,;:!?)]")] private static partial Regex AutoLinkRx();
    [GeneratedRegex(@"\*\*(.+?)\*\*")] private static partial Regex BoldRx();
    [GeneratedRegex(@"(?<!\w)__(.+?)__(?!\w)")] private static partial Regex BoldUnderscoreRx();
    [GeneratedRegex(@"(?<![*\w])\*(?![\s*])(.+?)(?<![\s*])\*(?![*\w])")] private static partial Regex ItalicRx();
    [GeneratedRegex(@"(?<!\w)_(?![\s_])(.+?)(?<![\s_])_(?!\w)")] private static partial Regex ItalicUnderscoreRx();
    [GeneratedRegex(@"\[[^\]\u0001\u0002]+\]")] private static partial Regex FillRx();
    [GeneratedRegex("\u0001(\\d+)\u0002")] private static partial Regex TokenRx();
    [GeneratedRegex(@"\n\s*\n")] private static partial Regex BlankLineRx();
}
