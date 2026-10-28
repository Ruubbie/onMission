---
version: 1
slug: "missions-site-public-nl-index-html"
primary_target: "missions/site/public/nl/index.html"
related_targets: ["missions/site/public/en/index.html"]
---

# hesent.me supporter site

Scope: the public website on hesent.me (`missions/site`), Dutch at /nl/ and English at /en/. Mode: Persuade.

Audience: people who have never met Ruben. They reach the site from a flyer, a church evening or a shared link. Job: understand who he is, what YWAM Queenstown is, why it matters, then subscribe to the newsletter. Secondary: pray along (live public prayer points from the app) and become a monthly partner (personal IBAN).

Proof/content: the live days-to-go and support % from the sync server's public summary; prayer points Ruben marks public in the app; his photos (portrait, Queenstown, YWAM base), supplied later, with placeholders until then. Copy is drafted from repo facts and flagged for Ruben to check in `content/*.json`.

Constraints: Tomato Flood world (tokens and line art from `missions/app/design/tomato-flood`). No Ollie, no emoji, no gradients. Self-hosted fonts (EU visitors). Ruben deploys it himself.

## Direction contract

THESIS: The site is Ruben's zine: a folded booklet that introduces him to a stranger, one spread per question a newcomer asks (who, where, why, how to follow). It refuses the missionary-site default of a hero photo, a mission statement, and three equal "Pray / Give / Go" cards.

OWN-WORLD: Tomato flood covers and cream inside pages, joined on a visible gutter. Archivo at 64% width, weight 900 and uppercase for display; Caveat by hand for asides, rotated −2 to −9°; single-weight 2.4px cream-on-tomato line drawings with numbered callouts; capsule buttons; page numbers in the corners; one handwritten signature stamp.

STORY: "Hé, I'm Ruben, and I'm moving to New Zealand." → what YWAM Queenstown is and what he'll do there → why → pray along (live candle and prayer points) → partner monthly → "read along" sign-up. The visitor leaves subscribed.

FIRST VIEWPORT: one cover spread. Left page (tomato): "HÉ, IK BEN RUBEN." at poster scale, a portrait in a flat cream-framed block, "en ik ga naar Nieuw-Zeeland" by hand, and the signature stamp. Right page (cream): the live days-to-go, three plain lines on what this booklet is, and the working "Lees mee" form (name, e-mail, button). Page-number navigation runs along the top edge, with the NL/EN switch.

FORM: the zine (youth-group booklet), position 6 on the ordered list; seed key a9b757cf, re-roll 1. Raises: numbered callouts on drawings (patent sheet), page numbers as real navigation (teletext), one handwritten signature stamp (design annual). Signature interaction: the spreads turn like pages on scroll (each spread's cover floods from the gutter); subscribing stamps the form "INGESCHREVEN" and draws a check.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
