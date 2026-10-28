# Tomato Flood: handoff for the iPhone build

> **Update (28 Oct 2026): the colours and type below are replaced.** The iPhone app now looks like the web app (`missions/app/web/assets/app.css`): the same screens, layout and motion, drawn in hesent.me’s paper and ink with the paper texture, Archivo only (no Caveat), sentence case, sage for what is done, and the traveller drawings from hesent.me on several posters. Ollie is no longer in the app (his PNGs are in `design/ollie`). The current values are in `design/tokens.json`. Layout, flows and motion in this document still apply.

This is the brief for rebuilding the onMission iPhone app (SwiftUI, iOS 17, SwiftData) in the new **Tomato Flood** style. Ruben approved this direction after five rounds of prototypes.

- **Source of truth:** [prototype.html](prototype.html), which sits next to this file. Open it in a browser (it needs internet for Google Fonts). Every screen, page, overlay and animation in this document can be clicked through there, and the side panel has buttons that jump straight to each moment. If this document and the prototype disagree, the prototype wins.
- **Branch:** `redesign/ios-workflows` in `Ruubbie/onMission`. Push only to a feature branch, never to `main`.
- **No Mac:** there is no local Mac. The build and simulator screenshots run on GitHub Actions: `.github/workflows/ios.yml` builds, and `.github/workflows/ios-screenshots.yml` takes the screenshots.
- **Measurements:** all are in points and taken from a 390 × 844 iPhone (14/15/16). The prototype's CSS pixels map 1:1 to points.

---

## 1. The idea in five rules

1. **One idea per screen.** Every tab and page leads with one big thing on tomato: days to go, money raised, one prayer, how packed the bag is. Never put two hero numbers on one screen.
2. **A calm cream sheet holds the rest,** at most 3–4 items before "All 48 people →" or "+2 more". The sheet scrolls inside itself; the poster above it never scrolls.
3. **Warm church-youth tone, not childish.** Use condensed display type, handwritten asides, and single-weight line drawings. There are no mascots in the UI, no emoji and no gradients. **Ollie appears only as a rare cameo** (see Open decisions).
4. **Motion is part of the UX.** When you do something, the screen answers: a check draws, a candle lights, a stamp lands. Everything has a Reduce Motion fallback (§9).
5. **The tab bar belongs to the page.** It has no hairline and no separate surface; it takes the colour of whatever sits at the bottom of the screen (§4).

---

## 2. Tokens

These replace the "Mocha & Ollie" palette and fonts completely. Update `missions/app/design/tokens.json`, which is the source of truth, then `tokens.css` and `Shared/Design/Tokens.swift`. Keep the `brand` block in tokens.json, because CI reads `brand.appName` from it.

### Colour

| Token | Hex | Use |
|---|---|---|
| `tomato` | `#D2462B` | The flood: poster background, primary buttons, active pill, rings, line accents on cream |
| `tomatoInk` | `#B23A22` | "Late" and alert text, and the recommended colour for small tomato text on cream (see §10) |
| `cream` | `#FBF1E3` | Sheets, cream pages, text and line art on tomato |
| `ink` | `#2E1C16` | Text on cream and on marigold |
| `marigold` | `#E8A13A` | The "Answered!" flood and the "Thinking" check-in |
| `plum` | `#4B3B52` | The "Not now" check-in |
| `blush` | `#F0A58F` | The toast's check icon |
| `rule` | tomato @ 16% | Row dividers on cream (1.5pt) |
| `tileRule` | tomato @ 35% | Move tile outline (1.6pt) |
| `chipRule` | ink @ 20–25% | Unselected chip/pill outline (1.6pt) |
| `inkSoft` | ink @ 68% / 55% | Row subtitles / section counts |
| `creamSoft` | cream @ 72–82% | Secondary text and inactive tab icons on tomato |

### Type

Bundle **Archivo** (the variable font, with a `wdth` axis of 62–125 and a `wght` axis of 100–900) and **Caveat** Bold, both OFL. Remove DM Sans and Lora once nothing uses them, and update `Resources/Fonts/OFL.txt`.

- **Archivo widths:** build the condensed cuts through `UIFontDescriptor` variation attributes (`kCTFontVariationAttribute`, with axes `wdth` `0x77647468` and `wght` `0x77676874`). Pass them through `UIFontMetrics(forTextStyle:)` so they still follow Dynamic Type.
- **Fallback:** if the variable font is painful, the static Google cuts are an acceptable stand-in. Use Archivo ExtraCondensed Black for display and Archivo Condensed for the 70–80% styles.

| Style | Font | Spec |
|---|---|---|
| Display (`disp`) | Archivo | wdth 64, wght 900, UPPERCASE, line height 0.88. Sizes: Today countdown 218, page big number 184, Settings date 150, Newsletters month 140, All done 128, Move 124, Packing 122, People 112, Tasks title 92, page money 104, partner name 96, check-in word 90, Answered! 74, reader title 62, step numerals 46 |
| Hand (`hand`) | Caveat 700 | Line height 0.95, often rotated −2° to −9°. Greetings 33–36, asides 26–34, "Amen." 46 |
| Cap (`cap`) | Archivo | wdth 70, wght 800, 21pt, tracking 0.06em, UPPERCASE. The line under each big number |
| Hero title | Archivo | wdth 78, wght 800, 29pt, line height 1.02 |
| Prayer text | Archivo | wdth 80, wght 800, 35pt, line height 1.06 |
| Capture entry | Archivo | wdth 78, wght 800, 36pt |
| Kicker (top bar) | Archivo | 700, 12.5pt, tracking 0.13em, UPPERCASE |
| Section header | Archivo | 800, 13pt, tracking 0.13em, UPPERCASE, tomato. The count sits right-aligned in 700, ink @ 55% |
| Row title / subtitle | Archivo | 700 16.5pt / 500 13pt @ 68% |
| Button | Archivo | 800 15pt (44pt tall, capsule), small 800 14pt (36pt tall) |
| Tab label | Archivo | 800 14.5pt |

### Shape and line

- **Radii:**
  - Sheets: 30, top corners only.
  - Buttons, chips, pills and search: full capsule.
  - Move tiles: 20.
  - Document boxes: 13.
  - SOLD stamp: 8.
- **Line art:** strokes are 2.4pt with round caps and joins. Use cream on tomato and tomato on cream. Closed shapes are filled with either the flood colour (so they knock out) or cream (so they glow). Dotted guide lines use a dash of `1 7` or `1 8` with round caps.
- **Icons:** Lucide on a 24 grid with a stroke of 2. Small glyphs (plus, x, chevrons, check) go up to 2.3–2.6.
- **Touch:** targets are at least 44pt. Rings keep their 28pt look and get padding for the tap area.

---

## 3. Screen anatomy

Every tab and every pushed page is built from the same stack of layers:

```
┌──────────────────────────────┐
│ status bar                   │
│ [‹] KICKER            [⚙][+] │  top bar: y 56, 48 tall, 24pt left inset
│                              │  20pt of air
│ handwritten aside            │  ┐
│ BIG NUMBER                   │  │ poster on tomato: one idea,
│ CAP LINE         line drawing│  │ never scrolls
│                              │  ┘
│╭────────────────────────────╮│  sheet: top corners 30, 22/20 padding
││ SECTION            count   ││
││ row                        ││  3–4 items max; scrolls inside
││ row                        ││
│╰────────────────────────────╯│
│  (●Today)  ☐   👥   🔥   ✈   │  tab bar: same colour as what's behind it
└──────────────────────────────┘
```

- **Top bar:**
  - The kicker shows the date, the tab name, or a count such as "Prayer · 6 open".
  - The **back** button is a 44pt circle with a 1.7pt outline. It grows in from width 0 when a page opens.
  - **⚙ Settings** shows only on the Move tab.
  - **+** (Capture) is a 44pt cream circle with a tomato glyph. On cream pages it inverts to a tomato circle with a cream glyph.
  - **The + hides on pushed pages,** so the top row is just Back and the page name, and it returns on the tabs. This was a deliberate fix for the cramped top bar.
- **Air:** the poster starts 20pt below the top bar. Ruben flagged cramped tops, so keep this gap.
- **Sheet tops on 844pt:**
  - Today: 404 (the hero card needs room).
  - Tasks: 290 (the list is the point).
  - People, Move and pages: 410.
  - On shorter phones, shrink the poster (scale the big number ~0.8) before the sheet; keep at least 3 rows visible. Build posters with stacks and fixed spacing, not absolute positions.
- **Pages:**
  - Most pushed pages flood tomato with a sheet.
  - The guide reader is a **cream page**: there is no poster, and the top bar turns ink.
- **Status bar:** use light content on tomato and dark content on cream, marigold and the check-in. Drive it from the same state as the tab-bar mode, for example with a `UIHostingController` subclass that overrides `preferredStatusBarStyle`.
- **Appearance:** the app is currently forced to Dark (`INFOPLIST_KEY_UIUserInterfaceStyle: Dark` in `project.yml`). Switch it to **Light** so the keyboard, alerts and share sheets match the cream surfaces.

---

## 4. The tab bar

These are the five tabs:

| Tab | Icon | Badge dot |
|---|---|---|
| Today | sun | — |
| Tasks | clipboard-check | overdue tasks |
| People | users | people waiting on you |
| Prayer | flame | — |
| Move | plane (custom, rounded) | — |

Build it as a custom view; hide the system tab bar. There is no border or hairline.

- **Layout:**
  - The bar runs edge to edge and its background extends through the bottom safe area, behind the home indicator.
  - The pill row is 46pt tall with 9pt above it.
  - The horizontal inset is 12pt. The active slot is 126pt wide and the other four share the remaining width equally.
  - The **pill** sits 4pt inside the active slot. It holds the icon (25pt) and the label (8pt gap).
  - Inactive tabs show the icon only.
- **Switching:**
  - The pill's x and width and every slot width animate with `timingCurve(0.3, 1.25, 0.45, 1, duration: 0.5)`, a slight overshoot.
  - The active label's width grows over 0.45s and fades in over 0.3s after a 0.12s delay.
  - The newly active icon plays its animation 140ms after the tap (§8).
- **Badge:** a 9pt dot at the icon's top-right, in the pill colour with a 2pt ring in the bar colour. It scales to 0 when its tab is active.

### Bar modes: the bar takes the page colour

| Mode | When | Bar | Inactive icons | Pill | Active icon + label |
|---|---|---|---|---|---|
| `cream` (default) | any tab or page with a cream sheet at the bottom, and cream pages | cream | ink @ 60% | tomato | cream |
| `flood` | the Prayer tab; Today once **All done**; any pushed page without a sheet | tomato | cream @ 72% | cream | tomato |
| `gold` | while the **Answered!** flood is up | marigold | ink @ 60% | ink | marigold |

- **Rule (top wins):** use `gold` while Answered is up. Otherwise, if a page is open, use `cream` when the page is cream or has a sheet, and `flood` when it doesn't. Otherwise use the tab's own mode.
- **SwiftUI:** pass the mode up with a `PreferenceKey`, so the topmost visible screen decides. Cross-fade the colours over 0.45s with `timingCurve(0.4, 0, 0.2, 1)`.
- **Home indicator:** iOS colours it automatically against the content behind, so it needs no work. The prototype fakes this.

---

## 5. The five tabs

The numbers in the prototype are sample data. Bind each one to the real store; the "Data" lines below say where it comes from.

### Today
- **Poster:**
  - "Morning, {first name}!" in hand type; vary it by time of day.
  - The **days until departure** at 218pt, counting up from 0 on launch over 1s with an ease-out.
  - The cap line "Days till Queenstown", using the destination city.
  - A line drawing of a mountain, a flag and a dotted flight path.
- **Sheet:**
  - "NEXT UP · n today", then a **hero card** for the single most urgent task. The hero has the title at 29pt, a subtitle (in `tomatoInk` when late), and one or two buttons.
    - A call task shows **Call** (filled, which opens the check-in) and **Done** (outlined).
    - Any other task shows **✓ Done** and **Tomorrow**.
  - "LATER TODAY", then rows with rings.
- **Done on the hero:** the card slides out to the right (x +40, fade, 300ms ease-in). The next hero rises in (y +22, 460ms).
- **Tick a row:** see "Tick a row" in §7.
- **All done:**
  - The sheet drops off the bottom (0.6s, `timingCurve(0.6, 0, 0.25, 1)`).
  - The poster lifts and fades.
  - "ALL DONE." (128pt) and "Go enjoy the evening, {name}" fade in, and a drawing of two trees and a hammock draws itself.
  - **The tab bar turns tomato.** The Tasks badge clears.
- **Data:** tasks that are overdue or due today, plus the departure date and destination from Settings.

### Tasks
- **Poster:** "TASKS" at 92pt, the handwritten aside "12 left, you got this" rotated −5°, and a clipboard drawing. The sheet starts high (290).
- **Sheet:**
  - A segmented underline with **Today · This week · Later** and a count on each.
  - Rows show a ring, the title, the area, and a right-aligned "when" (in `tomatoInk` when late).
  - The underline slides over 0.42s (`0.3, 1.3, 0.5, 1`). The list slides in ±40pt in the direction of travel over 380ms.
- **Rows:** tapping a row opens the **Task page**; tapping its ring ticks it off.
- **Data:**
  - Map the existing groups onto the segments: Today = Overdue + Today; This week = Tomorrow + Next 7 days; Later = Later + No date.
  - **Keep the existing swipe actions:** the leading swipe is progress, the trailing swipes are reschedule, then Delete.

### People
- **Poster:**
  - "Monthly support", **€1,240** at 112pt, and "of €2,000 a month · 62%".
  - A dotted trail up a mountain to a flag. A walker dot travels along it to the support percentage over 1.5s on entry.
- **Sheet:**
  - "WAITING ON YOU · n" lists up to 3 people. Each row has an avatar (a 44pt circle with initials and a tomato outline) and **one action button** (Say thanks / Check in / Ask).
  - "All 48 people →" at the bottom opens the All people page.
- **Say thanks:** the button becomes "♥ Thanked" (the heart beats and the button pops), the subtitle changes to "Thanked just now", and after 0.7s the row folds away.
- **Check in:** opens the check-in slider (§6).
- **Empty:** "Nobody's waiting on you · Nice. Everyone has heard from you." The People badge clears.
- **Data:**
  - "Waiting on you" is the existing "Needs you" group.
  - The total and target come from gifts and Settings.

### Prayer (the bar is tomato)
- **Layout:** there is no sheet. The page is entirely tomato.
  - "pray for" in hand type.
  - **One prayer** at 35pt, with "Added after Sunday's call · prayed 3×" under it.
  - A line-drawn **candle**.
  - Two buttons: **Answered** (cream outline) and **🔥 I prayed** (a cream fill, at least 150 wide).
  - Pager dots: 7pt, with the active dot 20pt wide.
- **I prayed:**
  1. The button pops, and its flame icon draws.
  2. The candle's **flame catches**: it scales 0 → 1.25/1.3 → 0.94 → 1 over 700ms, then flickers twice (760ms each, with a slight squash and a ±3° rotation).
  3. Glow rays open around the flame (from scale 0.6, with a 260ms delay), and the candle dips 3pt.
  4. The "prayed n×" count rolls up.
  5. "Amen." pops in by hand at −9° after 450ms.
  6. After 2.1s, the card slides out to the left (with a −3° rotation, 260ms), the next prayer slides in (460ms), and the flame shrinks out (260ms).
- **Swipe:**
  - The card follows the finger and tilts by dx/40 degrees.
  - Past 70pt, it skips to the next or previous prayer.
  - Otherwise it springs back over 420ms.
- **Answered:**
  - A **marigold circle floods out of the button** over 0.65s (`0.7, 0, 0.2, 1`).
  - On the flood: "ANSWERED!", the prayer text by hand, a line-drawn sunrise that draws itself, and "SAVED IN PRAYER & THANKS".
  - **The tab bar goes gold.**
  - After 2.5s the flood retracts and the prayer leaves the list.
- **Kicker:** "Prayer · n open".
- **Data:**
  - Open prayers, with their prayed count and "added" context.
  - Answered moves the prayer to the existing Prayer & thanks record.

### Move
- **Poster:**
  - "Leaving 15 December", **64%** at 124pt, and "READY TO GO".
  - A dotted arc from AMS to ZQN. A plane flies along it to the readiness percentage, rotating with the curve (1.6s).
  - ⚙ Settings sits in the top bar.
- **Sheet:**
  - A 2-column grid of 8 **tiles** (70 tall, 9pt gap, a 20 radius, a tomato @ 35% outline). Each tile has an icon at the top left, a status at the top right (in `tomatoInk` if it needs attention), and the name at the bottom.
  - The tiles are Checklists, Vault, Packing, Budget, Selling, Newsletters, Notes and Guides.
  - The tiles rise in with a 35ms stagger, and their icons play one after another (from 260ms, 70ms apart).
- **Data:**
  - The status lines come from the existing `MoveView.Status`.
  - The readiness percentage needs a formula (see Open decisions).

---

## 6. Overlays

### Capture (+)
- **Open:**
  - It is a **full-screen cream cover that floods out of the + in a circle** (0.62s, `0.7, 0, 0.2, 1`) and covers the tab bar.
  - The + rotates 135° into a × and inverts its colours (0.5s, `0.3, 1.5, 0.5, 1`).
  - The kicker reads "ADD ANYTHING".
- **Layout:**
  - A line drawing for the current kind (task, person, gift, prayer or note) draws itself (650ms, 50ms stagger).
  - The typed entry is large (36pt condensed).
  - A handwritten guess, "↓ sounds like a person", fades in when the parser switches kind on its own.
  - Kind chips: a tomato pill slides under the selected one (0.45s).
  - One context field below the chips (Due / Stage / Amount / Remind me / Link to).
  - A full-width **Add {kind} →** button (60 tall).
- **Add:**
  1. The cover folds back into the +.
  2. A toast ("Added to Tasks").
  3. The destination tab's icon gives a little pop (scale 1.35 with a −8° rotation, 520ms).
- **Keep all of today's Capture logic:** the prefixes (`pray:`, `thanks:`, `sell:`, `pack:`, `note:`, `@Name`), natural-language tasks, chips overriding the guess, matching records shown below, `.captureContext(_:linkTo:)`, and "Add or find" search.
  - The prototype shows 5 kinds. The real app has more (see Open decisions).

### Check-in after a call
- **Open:** a full-screen cover that slides up from the bottom (0.55s, `0.2, 0.9, 0.2, 1`). The kicker reads "AFTER THE CALL", with an outlined × to close.
- **Layout:**
  - "how did it go with Anna?" in hand type.
  - A sky scene: a moon and stars, a sun, hills.
  - A big rolling word: **NOT NOW · THINKING · YES!**
  - One line saying what happens next.
  - A **3-stop slider** with a 54pt knob in the ink colour carrying a sun icon.
  - Stop labels.
  - **Add note** (outlined) and **Save →** (filled).
- **Dragging the slider:**
  - **The whole background interpolates** plum → marigold → tomato.
  - The ink colour flips cream / ink / cream at t < 0.27 / < 0.74 / above.
  - The sun rises from below the hills (cy 206 → 82). Its 12 rays grow (6 → 24pt) and fade in between t 0.3 and 0.75. The moon and stars fade out by t 0.42.
  - The word rolls vertically between stages: the old word goes out in 280ms ease-in, the new one comes in over 420ms with a slight overshoot.
  - The knob scales to 1.1 while held.
  - On release it snaps to the nearest stop with a small overshoot (420ms).
  - Tapping a label also snaps to it.
- **On open:** a hint nudge, 0.5 → 0.62 → 0.5 after 650ms, shows that the slider moves.
- **Save:**
  - Close, then show a toast "Anna Jansen · Thinking about it".
  - On her page: the path walker advances and haloes on Yes!, the path fades on Not now, and only the halo plays on Thinking. Her hero card swaps.
  - In lists: the hero or row resolves (folds out).
  - Map the stops to the existing stages: Not now / Thinking about it / Committed.
  - The next lines come from the reminder logic: "I'll remind you to follow up in 2 weeks." / "That's okay. I'll suggest a catch-up in spring." / "Committed! Next up: a thank-you and the amount."

### Toast
- **Look:** an ink capsule (40 tall), centred at y 104, with a blush check icon and a 14pt bold message.
- **Motion:** it drops 14pt with an overshoot over 0.45s, holds for 2.2s and fades.
- **Use:** the confirmation for every quiet action.

---

## 7. Pushed pages

**Pages flood out of what you tap.** Each page is a full-screen layer that grows as a circle from the centre of the tapped tile, row, avatar or gear, under the tab bar.

- **Open and close:**
  - The circle opens over 0.62s with `timingCurve(0.7, 0, 0.2, 1)`.
  - The poster rises in after 140ms and the drawings draw in after 220ms.
  - **Back folds the circle into the same origin.**
  - Pages stack: Task → Linked to → Vault works.
- **Navigation model:** in SwiftUI, a `PageStack` model of `[Page]` (each with its origin point) renders above the tab content. Mask each page with an animatable `Circle` positioned at the origin; get the origin from an `anchorPreference` on the tapped view.
- **Keep the native edge-swipe back:** make it interactive, with the circle shrinking under the finger. The prototype has no gesture, but the app must.
- **Chrome:** the kicker becomes the page name, Back grows in with its chevron nudging, the + hides, and the bar mode updates.

Every page has a poster (hand aside, big thing, cap line, line drawing) and a sheet, unless noted otherwise. Each has **its own moment**:

| Page (kicker) | Poster | Sheet | The moment |
|---|---|---|---|
| **Checklists** | "Before you fly" · **things left** (184pt) · "Things left on 6 lists" · clipboard | Underline segments **Now · Before · Leaving · Arrival** with counts; each list is a row with a **progress ring** (36pt) and "3 of 5 done"; tap to expand its items (0.42s height + fade; others collapse). The first list opens itself on entry | Tick an item: the ring arc springs to the new fraction (520ms). When it is full, the ring turns solid, its check draws and it pops (1.3×), with a toast "Visa application · all done". The big number counts down |
| **Vault** | "Your papers" · **missing count** · "Papers still missing" · folder drawing | "NEEDED TO FLY · 4 of 9"; doc boxes (44pt, radius 13), **dashed** when missing, with a **Scan** button; "All 9 papers →" | Scan: a glowing line sweeps the box twice (480ms each way), the box turns solid tomato, its check draws, it pops, and "Scanned just now" appears. The count ticks down. At 0, the aside becomes "Nice work!", the cap "Nothing missing. You're set.", and an **ALL IN** stamp slams onto the folder |
| **Packing** | Bag name · **% packed** · "14.2 of 23 kg" · a **suitcase whose wavy fill level** rises | Segments **Checked · Carry-on · Ship**; 4 items with rings, then "+n more to pack" | Tick: a tomato dot **flies in an arc into the suitcase** (640ms), the suitcase wobbles, the level springs up (900ms), and the % and kg count up. The row folds. When empty: "All packed!" plus a toast |
| **Budget** | "Left over each month" · **+€320** · "€2,000 in · €1,680 out" · a **balance scale** labelled IN/OUT | Segments **Every month · Before you go**; rows with amounts (incoming in tomato) | The scale **tips toward the heavier side** with a spring (1.3s) on entry and on segment change. The aside, number and cap swap with a roll |
| **Selling** | "Selling up" · **€845** sold · "Sold so far · 5 things listed" · a swinging price tag | "ON THE MARKET · n"; rows with a price and a **Sold** button ("List" for unlisted items) | Sold: a **SOLD stamp slams** onto the row (260ms, starting at 1.9× and −18°), the row bumps 2pt, the **price label flies up into the total**, the total counts up, the tag swings, and the row folds |
| **Newsletters** | "Next letter" · **NOV** · "Due 1 November to 112 people" · an envelope on a dotted route | "DRAFT", then a hero card (title, "Started 3 days ago · 420 words", **Mark sent** and Open draft); "SENT · n" list | Mark sent: the letter slides into the envelope, the **flap closes**, and the envelope **flies off along the dotted route**, rotating and shrinking (950ms). The hero folds, a new "Sent · Today" row drops in, and NOV rolls to DEC |
| **Notes** | "Notes & journal" · **14** · "Written since August" · a notebook drawing | Pill filter **All · Journal · Meetings · Ideas** (the tomato pill slides) and rows | The filtered list slides in the direction of travel |
| **Guides** | "Read before you go" · **6** · "Guides · n read so far" · a book with a page that flips | Rows with a progress bar (46×6) that fills on entry, staggered, or "✓ Read" | Tap a row to open the reader |
| **Guide reader** (cream page) | No poster. A 3pt progress bar under the top bar tracks scrolling | Kicker "GUIDE · 6 MIN READ"; title in tomato display (62pt); a 18pt lead; numbered steps with 46pt tomato numerals; a handwritten quote; **Mark as read** (full width) | Mark as read: its check draws and it pops, the progress bar completes, the guides list updates, and the reader closes itself after 0.8s |
| **Partner** (People) | "Category A · close friend" · **ANNA JANSEN** (96pt) · a **6-stop stage path** List · Ask · Asked · Thinking · Yes · Giving | "NEXT", then a "Was due yesterday" hero card (Call / Message); "STORY · n" timeline rows | On entry, the walker slides along the path to her stage (1s) and a **halo** pulses (scale 2.6, fading). After a check-in: Yes! advances one stop with a spring, Not now dims the path to 35%, and the hero swaps. Say thanks becomes "♥ Thanked" with a toast |
| **All people** (People) | "Your people" · **48** · "19 give monthly · €1,240 together" · a group drawing | Category pills **All · A · B · C · K** with counts; a search field; rows | Pills slide; search filters live. Empty: "Nobody by that name · Add them with the + at the top." |
| **Task** | The area as the aside · the **task title** in display (68pt, or 58pt if over 22 characters) · "DUE TODAY" | "WHEN" pills **Today · Tomorrow · Next week · No date**; "LINKED TO", then a row (avatar or doc box) that opens that page; a full-width **✓ Mark done** | Pills swap the due line with a roll. Mark done: the check draws and pops, and the page goes back, where the row ticks itself off in the list. A changed date moves the task, with a toast "Moved to tomorrow" |
| **Settings** (from ⚙ on Move) | "Your mission" · **15.12** (150pt) · "Leaving for Queenstown, NZ" · a plane on a dotted loop | Sections **Mission** (Destination, Monthly target), **This iPhone** (Sync with a status line, Export a backup), **Account** ("Signed in as …", **Sign out** in tomato) | The sync icon spins once on entry; tap Sync and it spins while "Syncing…" shows, then "Synced just now" pops in |

**Not in the prototype.** Contacts, Search and the existing detail screens (gift, budget entry, sell item, packing item, document, newsletter, contact) are not prototyped. Build them as pushed pages in the same pattern. For screens that are pure lists, use a cream page or a short poster plus a sheet. Keep the existing **"one next action"** rule: the primary button is the most likely action, and rarely used fields fold under Details.

---

## 8. Animated icons (Lucide Animated)

The icons are **Lucide** geometry (ISC licence), and each one's motion is ported from **lucide-animated** (pqoqubbw/icons, MIT). Credit both in Settings › About or the README.

### How to build them in SwiftUI

- **Drawing:** draw each icon as SwiftUI `Shape`s from the Lucide path data. The prototype's `I` map has the exact `d` strings. Either add a small `Path(svgPath:)` parser or pre-convert them with a script. Stroke them with `StrokeStyle(lineWidth: 2 × size/24, lineCap: .round, lineJoin: .round)`.
- **Component:** one component, `AnimatedIcon(.sun, size: 25, trigger: someCounter)`. Drive it with `keyframeAnimator(initialValue:trigger:)` or `phaseAnimator(_:trigger:)`. Each icon animates only its tagged parts.
- **Path drawing:** "draw" motions (pathLength 0 → 1 in Lucide) map to `.trim(from: 0, to: progress)`.
- **Springs:** `spring(k, c)` in the table means a mass-1 spring and maps **exactly** to `.interpolatingSpring(mass: 1, stiffness: k, damping: c)`.
- **Triggers:**
  - A tap on the host (a button, row, tile or setting) plays its icon.
  - A tab becoming active plays its icon after 140ms.
  - The Move tiles play in sequence on entry.
  - The icons on Vault doc boxes and Settings rows play on open (480ms + i × 90ms).
  - Icons that swap in after an action play once ("🔥 Prayed", "♥ Thanked", "✓ Done").
  - Optional: `.onHover` for iPad pointers.

### The icon set

| Key | Lucide name | Where | Motion |
|---|---|---|---|
| sun | `sun` | Today tab, check-in knob | the 8 rays fade on one by one (300ms each, 90ms apart) |
| list | `clipboard-check` | Tasks tab, Checklists tile | the check draws (320ms ease-in-out) |
| users | `users` | People tab | the second person slides in from x −6 (spring 200/13, 100ms delay) |
| flame | `flame` | Prayer tab, I prayed | the outline draws (450ms, 100ms delay) |
| plane | custom rounded plane | Move tab | the plane takes off from (−25, +10), scale 0.8, −15° (1.1s, `0.25, 1, 0.5, 1`) |
| plus | `plus` | + | rotates 180° (spring 100/15) |
| x | `x` | close | the two strokes draw one after the other (320ms, 200ms apart) |
| phone | `phone-call` | Call | rings: rotates 10 → 20 → −10 → 10 → 0° with a slight scale (900ms); the waves blink |
| check | `check` | Done, rings | draws (400ms) and scales up from 0.5 |
| heart | `heart` | Say thanks | beats ×3 (scale 1.12, 450ms each) |
| arrow | `arrow-right` | Save, "All … →" | the shaft shortens and the head pulls back 3pt (400ms) |
| gear | `settings` | ⚙ | rotates 180° (spring 50/10) |
| lock | `lock` | Vault tile | jiggles (rotate −3/1/−2° with a small scale, 1s); the shackle lifts |
| case | `briefcase-business` | Packing tile | sways from the handle (±4°, 900ms) |
| euro | `euro` | Budget tile | the € draws (600ms), then the two bars draw (400ms, 500ms delay) |
| tag | `hand-coins` | Selling tile | the coins drop in from y −20 (spring 150/15, 150ms apart) |
| mail | `mail-check` | Newsletters, Mark sent | the check draws (400ms) |
| note | `file-text` | Notes tile, visa, backup | pops to 1.06 and back; the text lines redraw one by one |
| book | `book-text` | Guides tile | wobbles (rotate ±8° with a lift, 600ms) |
| back | `chevron-left` | Back | nudges 2pt left (500ms); plays when Back appears |
| chev | `chevron-right` | rows | nudges 2pt right |
| camera | `camera` | Scan | the lens squeezes to 0.55 then 1.15 (520ms) |
| search | `search` | search field | small hop up, then left (1s) |
| sync | `refresh-cw` | Sync | turns 50° and back (spring 250/25) |
| pass | `id-card` | Passport | the parts draw in order (300ms, 100ms steps) |
| ticket | `ticket` | Flight tickets | **tears**: the halves pull apart 3pt and tilt 4°, then rejoin (spring 300/20) |
| shield | `shield-check` | Insurance | the check draws and scales up |

Replace every SF Symbol in `AppSection.symbol` and in the views with these. Any icon not in this list should come from Lucide too, with a lucide-animated motion where one exists.

---

## 9. Motion system

### Shared primitives

Build these once, so every screen reuses them:

| Primitive | Spec | SwiftUI |
|---|---|---|
| **rise** | Each poster element: opacity 0 → 1, y +16 → 0, 480ms, 50ms stagger, `(0.2, 0.8, 0.2, 1)`. The sheet: y +46 → 0, opacity 0.4 → 1, 520ms, `(0.2, 0.85, 0.25, 1)` | a staggered `.transition` / `.offset` with `timingCurve` |
| **draw** | Each line-art path draws in over 900ms, `(0.6, 0, 0.3, 1)`, 55ms apart. Dotted guides fade in after 500ms over 700ms | `.trim(from: 0, to: p)` per path |
| **flood / fold** | A circle mask from the origin over 0.62s, `(0.7, 0, 0.2, 1)`; the reverse to close | an animatable `Circle` mask |
| **tick a row** | The ring fills (0.22s); the check draws (0.32s after 0.12s); the title strikes through. After 560ms the row folds: height → 0, x +30, fade, 360ms `(0.4, 0, 0.2, 1)` | `.transition(.asymmetric(...))` plus `withAnimation` |
| **slideIn** | A list changes by sliding in from ±40pt in the direction of travel, 380ms `(0.2, 0.85, 0.25, 1)` | `.transition(.push(from:))` or an offset |
| **indicator** | Segment underlines, pills and the chip pill slide over 0.42–0.45s `(0.3, 1.3, 0.5, 1)` | `matchedGeometryEffect` |
| **swapText** | The old text goes up 14pt and fades (170ms ease-in); the new text comes from below (340ms) | `.contentTransition(.numericText())` for numbers, a custom transition for words |
| **countTo** | Numbers count with an ease-out cubic (400–1000ms) | `.contentTransition(.numericText(value:))` |
| **fly** | A dot or label arcs (its peak 80pt above the midpoint) to a target; it scales to 1.15 midway and 0.45 at the end; 640ms `(0.45, 0, 0.4, 1)` | a `keyframeAnimator` on an overlay |
| **pop** | Scale 1 → 1.18 → 1, 460ms `(0.3, 1.6, 0.5, 1)` | `.phaseAnimator` |
| **press** | Buttons scale to 0.95 (tiles to 0.97) while pressed | a `ButtonStyle` |

**Curves.** Every `cubic-bezier(a, b, c, d)` above maps directly to `Animation.timingCurve(a, b, c, d, duration:)`, which accepts the overshoot control points.

### Haptics

Use `.sensoryFeedback`, available on iOS 17:

| Moment | Feedback |
|---|---|
| Tab switch, segment or pill change | `.selection` |
| Tick a ring or row | `.impact(weight: .light)` |
| Checklist ring full, all packed | `.success` |
| Check-in slider crosses a stage | `.selection` |
| Check-in snaps to a stop | `.impact(flexibility: .rigid)` |
| Check-in saved | `.success` |
| Candle lights | `.impact(flexibility: .soft)` |
| Answered! | `.success` |
| SOLD stamp, ALL IN stamp | `.impact(weight: .heavy)` |
| Item lands in the suitcase | `.impact(flexibility: .soft)` |
| Capture opens | `.impact(weight: .light)` |
| Item added | `.success` |
| Letter sent | `.success` |

### Reduce Motion

Read `@Environment(\.accessibilityReduceMotion)`.

| Normal motion | With Reduce Motion |
|---|---|
| Circle floods | a 0.2s cross-fade |
| rise | a plain fade |
| draw | appears at once |
| Icon motions | none (static icons) |
| Springs and overshoots | 0.2s ease-out |
| countTo | jumps to the final value |
| fly | does not happen |

**What stays:** state changes, the bar colour change (a short fade), the check-in background colour (it follows the finger, so it is not motion), the candle (shown lit, without the flicker) and all haptics.

---

## 10. Accessibility and quality floor

- **Contrast:**
  - Cream on tomato is about **4.0:1**. That passes for large text (the big numbers, display and hand type, 18pt bold and up) but **not for small text**.
  - Keep body-size copy on the cream sheet where you can.
  - Use `tomatoInk #B23A22` (5.3:1 on cream) for small tomato text on cream: section headers, alerts, "Sign out".
  - The cream kicker (12.5pt) on tomato is a known gap; see Open decisions.
- **Dynamic Type:**
  - Sheets scale fully.
  - Posters scale with `relativeTo:`. Cap display sizes with `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` and `minimumScaleFactor`, so a 218pt number never pushes the sheet off screen.
  - At accessibility sizes the poster shrinks and the sheet scrolls.
- **VoiceOver:**
  - The poster reads as one element, for example "85 days till Queenstown".
  - Line art is `accessibilityHidden`.
  - Icon-only tabs and buttons have labels.
  - The check-in slider is an `accessibilityAdjustableAction` that steps between the three stops.
  - Ring buttons announce "Mark done".
  - Toasts post `UIAccessibility.post(notification: .announcement)`.
- **Gestures:** every gesture has a button. Skipping a prayer by swipe also works through the pager or an accessibility action, and back works by edge swipe as well as the button.
- **Touch:** targets are at least 44pt.

---

## 11. Mapping to the codebase

All paths are under `missions/app/ios/OnMission/`.

| File | What changes |
|---|---|
| `Shared/Design/Tokens.swift` | New `Palette` (tomato, cream, ink, marigold, plum…), new `Typeface` (Archivo widths and Caveat), `Metrics` kept. Migrate screen by screen, then delete Mocha, `Accent` and `Cream` |
| `Shared/Design/Components.swift`, `Controls.swift` | New Poster, Sheet, Row, Ring, Hero card, Tile, Segments, Pills, Capsule buttons, Toast, `AnimatedIcon`, `LineArt` (with draw-in) and the motion primitives |
| `Shared/Views/Navigation.swift` | A new root: tab content + custom `TabBar` (with the bar-mode preference) + `PageStack` (circle push and pop, edge-swipe back) + overlays (Capture, Check-in, Answered, Toast). `MoveView` becomes the Move tab (poster + tile grid) |
| `Shared/App/AppSection.swift` | `symbol` → the icon key from §8 |
| `TodayView`, `TasksView` | §5 Today and Tasks; the hero card and the All done state |
| `PartnersView`, `ContactsView` | People tab, Partner page (stage path + check-in), All people |
| `HeartViews` | The Prayer tab (candle, swipe, Answered flood) and the thanks flows |
| `ChecklistsView`, `VaultView`, `PackingView`, `MoneyViews`, `NewslettersView`, `GuidesView`, `SettingsView` | The pages in §7, each with its moment |
| `CaptureView` | The circle-reveal cover, keeping every bit of its parsing and matching logic |
| `Resources/Fonts` | Add Archivo (variable) and Caveat; later remove DM Sans and Lora |
| `Resources/Ollie` | Keep the PNGs, but use them for the cameo only. **Never redraw Ollie in code** |
| `project.yml` | `UIUserInterfaceStyle` → Light |

**Product behaviour stays.** The redesign changes the look, not what the app does. That covers grouping by what's next, one next action, the stage path, the swipe actions, quick dates, reminders, sync and backup, and the capture prefixes.

---

## 12. Suggested build order

1. **Foundation:** tokens, fonts, `AnimatedIcon` with the 5 tab icons, the motion primitives, and the Reduce Motion switch.
2. **Shell:** the root, tab bar with bar modes, top bar, Poster and Sheet scaffolds, the circle page push and pop (with swipe back), and Toast.
3. **Tabs:** Today (including All done), Tasks, People, Prayer (candle + Answered), Move.
4. **Overlays:** Capture and Check-in.
5. **Pages:** Checklists, Vault, Packing, Budget, Selling, Newsletters, Notes, Guides + Reader, Partner, All people, Task, Settings. Then restyle the remaining detail screens.
6. **The rest of the icons,** and haptics everywhere.
7. **Verify:**
   - Push to a feature branch, let `ios.yml` build, and run `ios-screenshots.yml`.
   - Compare each screenshot against the same prototype screen at 390 × 844.
   - Check:
     - Dynamic Type at XXXL and AX3
     - VoiceOver on the tabs, slider and rings
     - Reduce Motion
     - a 375 × 667 SE-size phone
8. **Docs:**
   - Rewrite `DESIGN.md` (Tomato Flood).
   - Update `tokens.json` and `tokens.css`.
   - Fix `PRODUCT.md` lines 37–38, which still say to keep Mocha & Ollie, DM Sans and Lora.
   - Mark `missions/app/design/ios-redesign-plan.md` as superseded.
   - Refresh the README screenshots.

**Done when** every screen in the prototype exists in the app with its moment, the tab bar matches the page everywhere, every icon animates, Reduce Motion is clean, and the CI screenshots sit side by side with the prototype without surprises.

---

## 13. Open decisions (ask Ruben)

1. **Move readiness %.** The prototype shows 64% with no formula behind it. Proposal: the average of checklist completion, Vault papers present, and packing %, rounded.
2. **Ollie's cameo.** He is not in the prototype at all. Proposal: show `ollie-sleep` small, once, on Today's "All done." screen, and maybe on Answered!. Nowhere else.
3. **The small kicker on tomato.** It is 12.5pt cream at 4.0:1. Accept it as decorative, enlarge it to about 15pt bold, or deepen the flood slightly. Recommendation: enlarge.
4. **Capture kinds.** The prototype shows Task, Person, Gift, Prayer and Note. The app also has thanks, sell, pack and others. Proposal: horizontally scrolling chips with the five most common first; the typed prefixes still pick any kind.
5. **+ on pushed pages.** It is hidden by design to calm the top bar. Confirm that's wanted everywhere, including on long pages like All people.
