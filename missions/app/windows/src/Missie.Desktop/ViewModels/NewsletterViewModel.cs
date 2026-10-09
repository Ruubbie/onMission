using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Media;
using Microsoft.Win32;
using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class NewsletterRow : EntityRow<Newsletter>
{
    public NewsletterRow(Newsletter n, Action<Entity> save) : base(n, save) { }

    public string Title { get => Model.Title; set => Set(Model.Title, value ?? "", v => Model.Title = v); }
    public string NumberText
    {
        get => Model.Number?.ToString() ?? "";
        set
        {
            var s = (value ?? "").Trim().TrimStart('#');
            if (s.Length == 0) Set(Model.Number, null, v => Model.Number = v);
            else if (int.TryParse(s, out var n) && n >= 0) Set(Model.Number, (int?)n, v => Model.Number = v);
            else Notify(nameof(NumberText));
        }
    }
    public string Status { get => Model.Status; set => Set(Model.Status, value ?? "draft", v => Model.Status = v); }
    public DateTime? PlannedDate
    {
        get => Fmt.ToDateTime(Model.PlannedDate);
        set => Set(Model.PlannedDate, Fmt.FromDateTime(value), v => Model.PlannedDate = v);
    }
    public string? Body { get => Model.Body; set => Set(Model.Body, Fmt.Opt(value), v => Model.Body = v); }
    public string? WebUrl { get => Model.WebUrl; set => Set(Model.WebUrl, Fmt.Opt(value), v => Model.WebUrl = v); }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }

    /// <summary>The intro is the first paragraph of the body (there is no separate field).</summary>
    public string Intro
    {
        get => Markdown.FirstParagraph(Model.Body);
        set => Set(Model.Body, Fmt.Opt(Markdown.WithFirstParagraph(Model.Body, value ?? "")), v => Model.Body = v, nameof(Body));
    }

    public string Heading => $"#{Model.Number?.ToString() ?? "?"} {Model.Title}";
    public string Meta => Model.Status switch
    {
        "sent" when Model.SentAt is { } s => $"sent {s.LocalDateTime.ToString("d MMM yyyy", Fmt.Nl)}",
        _ when Model.PlannedDate is { } d => $"{Model.Status} · planned {Fmt.NiceDate(d)}",
        _ => Model.Status,
    };
    public int Words => Markdown.WordCount(Model.Body);
    public Brush StatusBrush => Palette.Get(Model.Status switch { "sent" => "Green", "ready" => "Lime", "draft" => "Yellow", _ => "Grey" });

    public void MarkSent()
    {
        Model.SentAt ??= DateTimeOffset.UtcNow;
        Status = "sent";
    }

    protected override void OnModelChanged(string? name) =>
        Notify(nameof(Heading), nameof(Meta), nameof(Words), nameof(StatusBrush), nameof(Intro), nameof(Body), nameof(NumberText));
}

public sealed class NewsletterViewModel : EntityListViewModel<Newsletter, NewsletterRow>
{
    string _subtitle = "";

    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }

    /// <summary>How sending works today (missions/website/tools/verstuur.mjs + README.md); the app doesn't send.</summary>
    public string SendingHowTo =>
        "Sending happens outside this app: save \"Export email HTML\" into website/email/ and the site page into website/nieuwsbrief/. " +
        "Then run node tools/verstuur.mjs email/<file>.html --test you@… (test), without flags (dry run: who gets it) and with --echt to send " +
        "via Brevo to everyone who confirmed on the website (max 300 a day). {{NAAM}} and {{AFMELDEN}} are filled in per reader; " +
        "finish with npx wrangler deploy to put the page online.";

    protected override NewsletterRow CreateRow(Newsletter n) => new(n, SaveEntity);
    protected override string SearchText(NewsletterRow r) => $"{r.Model.Title} {r.Model.Body} {r.Model.Notes} {r.Model.Status}";
    protected override IEnumerable<Newsletter> Load() =>
        Store.All<Newsletter>().OrderByDescending(n => n.Number ?? int.MaxValue).ThenByDescending(n => n.UpdatedAt);

    protected override void Recompute()
    {
        int sent = Rows.Count(r => r.Model.Status == "sent");
        var next = Rows.Where(r => r.Model.Status != "sent" && r.Model.PlannedDate is not null).OrderBy(r => r.Model.PlannedDate).FirstOrDefault();
        Subtitle = $"{sent} sent · {Rows.Count - sent} in the works" +
                   (next is null ? "" : $" · next: #{next.Model.Number} on {Fmt.NiceDate(next.Model.PlannedDate)}");
    }

    public NewsletterRow New()
    {
        int next = Rows.Select(r => r.Model.Number ?? 0).DefaultIfEmpty(0).Max() + 1;
        var row = Add(new Newsletter
        {
            Title = "Nieuwe nieuwsbrief",
            Number = next,
            Status = "draft",
            Body = "Lieve {{NAAM}},\n\n",
        });
        var at = Rows.IndexOf(row);
        if (at > 0) Rows.Move(at, 0);
        return row;
    }

    public void Export(bool email)
    {
        if (Selected is not { } row) return;
        var dlg = new SaveFileDialog
        {
            Title = email ? "Export email HTML (website/email/)" : "Export for website (website/nieuwsbrief/)",
            Filter = "HTML page (*.html)|*.html",
            FileName = NewsletterExport.FileName(row.Model),
        };
        if (dlg.ShowDialog() != true) return;
        try
        {
            var html = email ? NewsletterExport.Email(row.Model) : NewsletterExport.WebsitePage(row.Model);
            File.WriteAllText(dlg.FileName, html, new UTF8Encoding(false));
            if (!email && string.IsNullOrWhiteSpace(row.WebUrl))
                row.WebUrl = $"{NewsletterExport.SiteUrl}/nieuwsbrief/{Path.GetFileName(dlg.FileName)}";
            PageActions.Info(email
                ? "Saved. Send a test first: node tools/verstuur.mjs email/" + Path.GetFileName(dlg.FileName) + " --test you@…"
                : "Saved. Add it to the top of nieuwsbrief/index.html and run npx wrangler deploy.", "Exported");
        }
        catch (Exception ex) { PageActions.Error("Export failed", ex); }
    }

    /// <summary>E-mail addresses of partners who want the newsletter, for pasting into a mail's BCC.</summary>
    public void CopyRecipients()
    {
        var emails = Store.All<Partner>()
            .Where(p => p.Newsletter == true && !string.IsNullOrWhiteSpace(p.Email))
            .Select(p => p.Email!.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (emails.Count == 0) { PageActions.Info("No partners with \"newsletter\" ticked and an email address yet."); return; }
        try { Clipboard.SetText(string.Join("; ", emails)); }
        catch (Exception ex) { PageActions.Error("Couldn't use the clipboard", ex); return; }
        PageActions.Info($"Copied {emails.Count} address{(emails.Count == 1 ? "" : "es")}. Paste them in BCC. " +
                         "Note: the website list (verstuur.mjs) only has people who signed up themselves.", "Copied");
    }
}
