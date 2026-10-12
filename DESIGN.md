# Design: Mocha & Ollie (iPhone)

Token values live in `missions/app/design/tokens.json` (source of truth), mirrored in `missions/app/ios/OnMission/Shared/Design/Tokens.swift` and `tokens.css`. `missions/app/design/design-system.md` is the older neo-brutalist spec; where it disagrees, tokens.json and this file win.

## World

- **Ground:** a mocha gradient (`#65493D` → `#53403A`), dark appearance only. Cards are a lighter mocha (`paper #735648`) with no outlines and no shadows.
- **Focal card:** one cream card per screen (`#FFF4E8`, cream ink `#4A3329`) with a dashed stitch inset 6pt. On Today it holds the top task card; on Prayer, the top prayer.
- **Accents** keep their slot names: `yellow` is Ollie's sage `#B3C9BD` and is the primary. Pink is for people, purple for papers and prayer, green for money and done, lime for packing and checklists, sand for selling and notes. Text on an accent is always `onAccent #24302C`.
- **Type:** DM Sans for everything (18pt max except big numbers). Lora Medium Italic only for the gratitude question and prayer text. Every size scales with the iPhone's text size (`Typeface` maps each size to a system text style).
- **Ollie** comes only from the PNG poses in `Resources/Ollie`: sit on the task deck, sleep for empty days, hug for partners, stand on Prayer, side on Move.

## Navigation

- **Tabs:** Today · Tasks · People · Prayer · Move. The tab bar is a floating mocha pill with icons and labels. The selected tab sits on a soft chip, and a pink dot marks tabs that need you (overdue tasks; partners to follow up or thank).
- **Capture:** the sage round + beside the tab bar, the same on every tab. It opens one sheet, "Add or find". What you type picks the kind (`pray:`, `thanks:`, `sell:`, `pack:`, `note:`, `@Name`, or a natural-language task), the chips override it, and matching records show below. Screens register a default kind with `.captureContext(_:linkTo:)`; a partner screen links new tasks to that partner.
- **Screen-level "new":** a + icon button in the navigation bar (`addButton` / `addMenu`) for things Capture can't make in one line: checklists, budget lines, documents, newsletters, contacts.

## Patterns

- **Grouped by what's next:** lists group by the action they need, not alphabetically. People puts "Needs you" first, then In conversation, To ask, Partners, On my list, Not now. Tasks runs Overdue, Today, Tomorrow, Next 7 days, Later, No date.
- **One next action:** detail screens open with the single most likely action as the primary sage button and its message template as the secondary one. Rarely used fields fold into `DisclosureGroup`s under Details, with a one-line summary.
- **Stage path:** six dots on a line from On my list to Giving. Tap a dot to set the stage; "Not now…" sits off the path.
- **Swipes:** leading = progress (Done, or the next stage, in green). Trailing = reschedule (Tomorrow purple, Next week sand), then Delete.
- **Quick dates:** chips under a date field (Today, Tomorrow, In 3 days, Next week).
- **Hub rows:** Move lists the sections in grouped mocha cards. Each row carries a live status line, in coral (`danger`) when something needs attention.
- **Touch:** 44pt targets everywhere. Small ticks keep their 28pt look and get padding for the tap area.
