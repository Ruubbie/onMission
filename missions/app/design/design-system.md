# Design system

The look of the iPhone app is the reference. Everything here (iPhone, Windows/React app, later the newsletter website) is built from the same tokens and the same handful of parts. Values live in `tokens.json` (source of truth) and `tokens.css` (the same values as CSS variables for web/React). The Swift copy is `ios/OnMission/Shared/Design/Tokens.swift`.

The app name is still open. Everywhere it shows up, it comes from one config value (`brand.appName` in `tokens.json`). The logo is **3a**, the yellow paper plane: `logo/plane-p1-icon.svg`. No wordmark until the name is chosen.

## 1. Principles

1. **Paper on cream.** The page is cream (`background`), things you can touch sit on paper (`paper`).
2. **Ink outlines.** Every touchable thing has a 2.5pt ink outline. Thin (1.5pt) for small things like chips and icon squares.
3. **Hard shadows, never blur.** A solid ink copy of the shape, offset 5pt right and down (3pt for small things).
4. **Pressing pushes it into its shadow.** On press, the face moves by the shadow offset and the shadow disappears. On hover (desktop/web), it lifts 1pt and the shadow grows 1pt.
5. **Colour means a place.** Each section has one accent (`accentFor`). Text on an accent is ink, except on purple, where it is white.
6. **Nothing looks like the operating system.** No grey grouped lists, no blue tint, no system switches, segmented controls, search bars or spinners. Native pop-ups (the menu list, the calendar, the share sheet, the camera) may stay because they are the system's own windows, but whatever opens them is ours.

## 2. Tokens (summary)

| Token | Value |
|---|---|
| background | `#FBF6EA` |
| paper | `#FFFDF7` |
| ink | `#111111` |
| muted | `#6E6A60` |
| hairline | `#E4DCC8` |
| accents | yellow `#FFD21F`, pink `#FF4F7B`, green `#2DBE4E`, lime `#A4E22F`, purple `#7B61FF`, sand `#FFE08A`, grey `#9A9A9A` |
| soft | yellow `#FFF3C4`, pink `#FFE1E8` |
| border | 2.5 / thin 1.5 |
| shadow | 5 / small 3, ink, no blur |
| radius | card 10, small 7, pill 999 |
| spacing | 4 · 8 · 12 · 16 · 24 · 32 |
| font | Familjen Grotesk, Bold for headings, Regular for body |
| type (phone) | h1 34, h2 24, h3 18, body 16, caption 12 |
| type (desktop/web) | h1 46, h2 26, h3 19, body 16, caption 13 |
| motion | press 80ms ease-out; sheets and tab changes 180ms ease-out; no bounce |

## 3. Core parts (already in the iPhone app)

| Part | Spec |
|---|---|
| **Box** | Fill + 2.5 ink outline + 5 hard shadow, radius 10. Everything else is built from it. |
| **Card** | Box with paper fill, 16 padding. |
| **Primary button** | Yellow box, radius 7, bold 16 label, padding 10×16. Secondary: paper fill. Danger: pink fill, white label. Compact: 14 label, 6×10 padding, 3 shadow. |
| **Icon button** | Square box 40, radius 7, 3 shadow, bold ink icon at 42% of size. Accent fill optional. |
| **Add button** | Yellow square 62, radius 10, 5 shadow, black-weight +. Floats bottom right, 20 from the edges, always above the tab bar. |
| **Accent square icon** | Accent fill, thin outline, radius 7, no shadow, size 38 (34 in rows, 64 in empty states). |
| **Chip** | Pill, thin outline, bold 12 text, padding 4×9. Selected = accent fill, unselected = paper. |
| **Section header** | Optional 12pt accent square, bold 20 title, muted count on the right. |
| **Progress bar** | Paper track, accent fill, 2.5 outline, radius 4, height 16 (8 in cards). A thin ink line marks the fill edge. |
| **Text field** | Paper box, radius 7, 3 shadow, 11×12 padding. Placeholder muted. |
| **Quick-add field** | Text field with a 26pt yellow + square on the left. Return adds. |
| **Empty state** | 64 accent square icon, bold 20 title, muted message, centred. |

## 4. Folder card, now with a slant

The folder card is the signature part (Today, More, desktop home). It is a paper body with an accent tab on its top-left edge, like a manila folder.

**The tab** sits on the top-left of the body and overlaps it by the border width, so the outlines merge.

- Left edge straight up, top-left corner radius 7.
- Top edge flat.
- **Right edge slants outward going down**, like a real folder tab: the top-right corner is inset by the tab height × 0.6 (about 12pt on a 20pt tab), with a small 4pt round at the top. This is the same shape as the desktop card (`M0,1 L0,0.25 Q0,0 0.06,0 L0.84,0 Q0.88,0 0.9,0.12 L1,1 Z`, normalised).
- Fill: accent. Outline: 2.5 ink. Shadow: same 5 offset as the body, drawn as one shape with the body so there is no gap.
- Title inside the tab: bold 14, accent text colour, one line, 12 left padding and 12 + slant right padding.

**The body**: paper, radius 10 everywhere except top-left (0, where the tab grows out of it). Accent square icon top-left, big bold count (30) top-right, muted subtitle (13) below. Optional 8pt progress bar at the bottom. Optional pink "badge" (white bold 11, radius 4) next to the subtitle, e.g. "3 late".

States: pressed moves body and tab together into the shadow. Selected (desktop) = soft yellow body.

SwiftUI: replace `UnevenRoundedRectangle` in `FolderTab` with a custom `FolderTabShape: Shape` drawing that path. Web: `clip-path` won't carry an outline, so draw the tab as an inline SVG path with `vector-effect: non-scaling-stroke`, sized by the title.

## 5. Floating tab bar (replaces the system tab bar)

A paper pill that floats above the content instead of a bar glued to the bottom.

- Position: 16 from the left and right edges, 8 above the bottom safe area (home indicator). Height 64.
- Shape: box with radius 22, 2.5 outline, 5 hard shadow.
- Five items (Today, Tasks, Partners, Vault, More), equal widths. Each: icon (20, bold) above a label (bold 10).
- Unselected: icon and label in muted, no fill.
- Selected: the item gets a rounded fill (about 40 high, radius 12) in its section accent (Today yellow, Tasks yellow, Partners pink, Vault purple, More sand) with a thin ink outline; icon and label in the accent's text colour. The fill slides between items in 180ms.
- Tapping the selected item again pops its screen back to the top level.
- Content scrolls behind it: every tab's scroll view gets a bottom inset of 64 + 8 + 16 so the last row and the floating + button clear it. The + button sits above the bar.
- Hidden when the keyboard is open, and on full-screen sheets.
- Badge: a pink dot with ink outline on the top-right of the icon (e.g. overdue tasks).

SwiftUI: keep the five `NavigationStack`s alive in a `ZStack` (opacity + hit testing by selection) or a `TabView` with `.toolbar(.hidden, for: .tabBar)`, and overlay `FloatingTabBar` with `.safeAreaInset(edge: .bottom)`.

## 6. Custom versions of the system elements

Every element below replaces something that currently looks like iOS. Each is listed with what it replaces and its spec. Names are the same on iPhone (`Brutal…`) and web (`<…>` React components).

### Navigation header (replaces the system navigation bar look)
- Large title: Familjen Bold 34, ink, on cream, no hairline under it. Inline title (after scrolling or on detail screens): Bold 17.
- **Back button**: icon button (36, paper, 3 shadow) with a bold left arrow, no text. 
- Toolbar actions on the right are icon buttons too, never blue text.
- When content scrolls under it, a 2.5 ink line appears under the bar instead of a blur.

### Toggle → `BrutalToggle`
- Track 52×30 pill, 2.5 outline. Off: paper. On: green (`ok`), or the section accent.
- Knob: 22 circle, paper fill, 2.5 outline, with a 2pt hard shadow; slides 22pt in 120ms.
- Label left (body 16), toggle right.
- SwiftUI: `ToggleStyle`, set once on the root with `.toggleStyle(.brutal)` so every Toggle picks it up.

### Segmented control → `BrutalSegmented`
- Box (radius 7, 3 shadow) split into equal segments by 2.5 ink lines.
- Selected segment: accent fill (yellow by default), bold label. Others: paper, regular label.
- No sliding grey thumb.

### Picker / select → `BrutalSelect`
- Looks like a text field: paper box, radius 7, 3 shadow, value on the left, small bold chevron-down on the right.
- Opens the system menu list (allowed, see principle 6). In a form row: label left, the select on the right.
- For short choice lists (≤4, like priority or status) use a row of filter chips instead.

### Date field → `BrutalDateField`
- Looks like a select, with a calendar icon instead of the chevron, showing "Fri 9 Oct" (the app's `shortDate`).
- Opens the system calendar pop-up. Optional dates show a small "×" icon button to clear, instead of a separate on/off switch.

### Stepper → `BrutalStepper`
- Two compact icon buttons (− and +, 32) with the number between them in bold 17, monospaced digits.
- − is disabled (muted icon, no shadow) at the minimum.

### Search bar → `BrutalSearchField`
- Text field with a bold magnifying glass on the left and a clear "×" on the right once there's text.
- Sits pinned at the top of the list, under the title, on cream. Never the system pull-down search.

### Form → `BrutalForm` and `FormSection` (replaces grouped grey forms)
- The page is a scroll view on cream with 16 side padding and 24 between sections.
- Each section: a bold 15 header above, then a **card** holding the rows, then an optional muted 13 footer.
- Rows inside a card: 12 vertical, 16 horizontal padding, separated by 1.5 `hairline` lines (not ink).
- Text fields inside a form row are bare (no box): label muted 13 above, value 16 below. Multi-line text (notes, letter body) gets its own paper box with min height 120.
- Destructive action (Delete) is a danger button at the bottom of the form, full width, never red text.

### List rows (replaces system list cells)
- Each row is its own small card (radius 7, 3 shadow) with 6 top, 8 bottom spacing. Already done as `brutalRow()`.
- No chevrons. Swipe actions keep the system gesture, but buttons use accent colours: done = green, delete = pink, other = yellow.

### Spinner → `BrutalSpinner`
- A 20pt square with 2.5 ink outline and yellow fill that rotates 90° in steps (every 150ms), instead of the system activity indicator. Inside a button it replaces the label.

### Confirmation dialog / alert → `BrutalDialog`
- Centre card on a 40% ink scrim: paper box, radius 10, 5 shadow, 24 padding.
- Bold 20 title, body 15, then buttons stacked full width: the destructive one as a danger button, Cancel as secondary.
- Replaces the system action sheet for Delete confirmations.

### Sheet → `BrutalSheet`
- Cream background, top corners radius 16 with a 2.5 ink top outline, a 40×5 ink grab handle.
- Header row: Cancel as a secondary compact button left, title bold 17 centre, Save as a primary compact button right.

### Menu trigger
- The + button, "…" icon buttons and selects open the system menu list. The trigger is always one of our buttons.

### Toast / snackbar (new)
- Small box at the bottom above the tab bar: paper, radius 7, 3 shadow, bold 14 text, optional "Undo" compact button. Disappears after 3 s.

### Badge (new)
- Pink pill or dot, ink thin outline, white bold 11 text. For counts on tabs and "late"/"new" on cards.

## 7. Icons

- iPhone: SF Symbols in bold weight. Desktop/web: the same icon names mapped to Lucide (stroke 2.5). Icons are always ink or the accent's text colour, never coloured on their own.

## 8. Writing in the interface

Short, plain words. Buttons are verbs ("Add task", "Save"). Empty states say what to do next. Dates as "Fri 9 Oct", money as "€ 750".
