using Xunit;
using System.Text.Json;
using Missie.Core;

namespace Missie.Core.Tests;

/// <summary>Messages from hesent.me as the server stores them on a partner (siteMessages, replyWaiting).</summary>
public sealed class SiteMessageTests
{
    static Partner FromServer() => JsonSerializer.Deserialize<Partner>("""
        {
          "name": "Bram de Vries", "stage": "giving", "email": "bram@example.test", "nextFollowUp": "2026-10-28",
          "nextStep": "Reply to their message from hesent.me", "replyWaiting": true, "category": "A",
          "siteMessages": [
            { "at": "2026-10-28T09:12:00.000Z", "name": "Bram", "text": "Nog een vraag & meer.", "lang": "en" },
            { "at": "2026-10-20T18:00:00.000Z", "name": "Bram de Vries", "text": "Hoi Ruben,\n\nIk geef graag mee.", "lang": "nl" }
          ]
        }
        """, MissieJson.Options)!;

    [Fact]
    public void Reads_the_messages_newest_first()
    {
        var p = FromServer();
        Assert.True(p.ReplyWaiting);
        Assert.Equal(["Nog een vraag & meer.", "Hoi Ruben,\n\nIk geef graag mee."], p.SiteMessages.Select(m => m.Text));
        Assert.Equal("en", p.SiteMessages[0].Lang);
    }

    [Fact]
    public void Mark_answered_clears_the_reply_follow_up_and_keeps_the_rest()
    {
        var p = FromServer();
        p.MarkAnswered(new DateOnly(2026, 10, 28));
        Assert.False(p.ReplyWaiting);
        Assert.Null(p.NextFollowUp);
        Assert.Equal(new DateOnly(2026, 10, 28), p.LastContactAt);
        Assert.False(p.Extra!.ContainsKey("nextStep"));
        Assert.Equal(2, p.SiteMessages.Count);
        Assert.Equal("A", p.Extra["category"].GetString());
    }

    [Fact]
    public void Reply_mailto_quotes_the_newest_message_in_its_language()
    {
        var url = FromServer().ReplyMailto()!;
        Assert.StartsWith("mailto:bram@example.test?subject=Your%20message%20on%20hesent.me&body=", url);
        Assert.Contains(Uri.EscapeDataString("> Nog een vraag & meer."), url);
        Assert.Contains(Uri.EscapeDataString("Hi Bram,"), url);
    }
}
