# iPhone redesign plan (Oct 2026)

> **Superseded** by Tomato Flood (`tomato-flood/HANDOFF.md`, `DESIGN.md`). Kept for its history: the flows it describes (Capture, the partner path, Move) carried over; the Mocha look did not.

Keeps the Mocha & Ollie colours, DM Sans and Lora, Ollie, and every model, sync and automation. Changes the layout and flows only.
Built around the confirmed answers: the moments that matter are the morning check-in and partner work, and the pain points are adding things, partner follow-up and finding things.

## 1. Navigation

| Now | New |
|---|---|
| Today · Tasks · Support · Prayer · More | **Today · Tasks · People · Prayer · Move** |
| + button with different behaviour per screen | One **Capture** button on every tab (the floating sage +), opening the same sheet |
| Search is one tile among 11 | Search sits at the top of Move, and a long press on Capture also opens it |

- **People** replaces Support: partners first, contacts as a second segment, so everyone you phone is in one place.
- **Move** replaces More: the 11 tiles grouped into *Leaving* (Checklists, Vault, Packing), *Money* (Budget, Selling), *Words* (Newsletters, Notes, Guides), with a live line on each (for example "2 docs expire", "€ 340 to sell"). Settings and sync go in the header.

## 2. Capture (fixes "adding things")

One sheet with one field that reuses `QuickAdd.parse` and adds a type prefix:
- `Call Anna friday #support` → task (as now)
- `pray: …` → prayer point · `thanks: …` → thanks
- `sell: Bike 150` → item to sell (reuses the SellView price parsing)
- `pack: charger` → packing item · `@Anna Jansen` → new partner
- A row of type chips under the field shows what it will become; tap one to override. The type defaults to the current tab (People → partner, Prayer → prayer).
- After saving, a toast with **Undo** and **Open** appears, and the sheet stays open for the next item.

## 3. Today (morning check-in)

Top to bottom:
1. Date and countdown on one line ("Mon 12 Oct · 85 days to Queenstown").
2. **Start with thanks** card (as now, Lora).
3. **Today's cards**: the deck stays, but swiping or tapping Later now moves the task to tomorrow (it was only reordered for that visit).
4. **People waiting on you**: the merged follow-ups and thanks, each with a one-tap action (Call, WhatsApp, Mark thanked), not just a link.
5. Support progress bar (tap → People) and a collapsed Heads up section.

Remove the hardcoded "Ruben" greeting and read the name from Settings, or leave it out.

## 4. People and partner follow-up

- The list is grouped by **what's next**, not alphabetically: *Needs you* (follow-up due, to thank), *In conversation* (asked, thinking), *To ask*, *Partners* (committed, giving), *Later* (on my list, not now, paused). The summary card keeps the progress bar, and the stage chips become the group jump.
- Swipe right on a row → advance one stage (this runs `Automations.partnerStageChanged`). Swipe left → schedule a follow-up.
- **Partner detail** becomes an action screen instead of an 8-section form:
  - Header: name, a pipeline strip (dots for each stage, tap one to set it), and Call, WhatsApp and Email.
  - One **primary action by stage**: To ask → "Send invite" (template D) · Asked → "Log the meeting" · Thinking → "Follow up" (template B, and a date is set) · Committed → "Send thank-you card" (marks thanked) · Giving → "Record a gift".
  - Next step and date inline, then the gifts timeline, then the suggested templates as chips.
  - Giving, contact, notes and links fold into collapsible sections below.

## 5. Tasks (small changes)

Grouped as Overdue / Today / Tomorrow / This week / Later / No date. Swipe actions: Done, Tomorrow, Next week. A filter chip row for area. Quick add moves into Capture, and an inline field stays at the top.

## 6. Shared components

- `Typeface` scales with Dynamic Type (`.custom(_:size:relativeTo:)`), keeping the same faces and sizes at the default setting.
- Use native `Toggle` and `Picker` where custom ones gain nothing; keep the sage tint.
- All tap targets at least 44pt (the checkboxes are currently 28).

## Build order

Capture sheet and RootTab change → People list and partner detail → Today → Move hub → Tasks polish → Dynamic Type pass. Push each step to a `redesign/ios-workflows` branch so CI compiles it.
