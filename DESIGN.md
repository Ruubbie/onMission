# Design: Tomato Flood (iPhone)

Token values live in `missions/app/design/tokens.json` (source of truth), mirrored in `missions/app/ios/OnMission/Shared/Design/Tokens.swift` and `tokens.css`. The full spec, with every screen and moment, is `missions/app/design/tomato-flood/HANDOFF.md`, and the clickable reference is `tomato-flood/prototype.html`. The Windows helper still uses the older Mocha look.

## World

- **One idea per screen.** Every tab and page leads with one big thing on tomato (`#D2462B`): days to go, money raised, one prayer, how packed the bag is. Never two hero numbers on one screen.
- **Poster and sheet.** The poster never scrolls: a handwritten aside, the big thing in condensed display type, a cap line under it, and a line drawing that draws itself in. Everything else sits on a cream sheet (`#FBF1E3`, ink `#2E1C16`, top corners 30) with three or four items at most.
- **Colours with a job.** Marigold `#E8A13A` is only for Answered! and the Thinking check-in; plum `#4B3B52` only for Not now. `tomatoInk #B23A22` is for late and small tomato text on cream.
- **Type.** Archivo (variable: condensed display at wdth 64 / wght 900, cap lines at wdth 70, prayer and hero text at wdth 78–80) and Caveat Bold for the asides, tilted −2° to −9°. Sizes follow Dynamic Type, except the posters, which scale with the phone.
- **Line art.** One weight (2.4pt), round caps; closed shapes knock out to tomato or glow cream. Drawings draw themselves in when a screen appears.
- **Ollie** appears once: asleep, small, on Today's All done.

## Navigation

- **Tabs:** Today · Tasks · People · Prayer · Move. The tab bar runs edge to edge and takes the colour of what sits at the bottom: cream under a sheet, tomato on a full poster (Prayer, All done), marigold while Answered is up. The active tab grows into a pill with its name; a dot marks tabs that need you.
- **Pages flood out of what you tap.** A pushed page grows as a circle from the tile, row or avatar you tapped (0.62s) and folds back into it. The left edge swipes it back, shrinking the circle under your finger. Pages stack (Task → Linked to → Vault).
- **Capture:** the cream + in the top bar floods a cream cover over everything. What you type picks the kind (`pray:`, `thanks:`, `sell:`, `pack:`, `note:`, `@Name`, or a natural-language task), the chips override it, and matching records show below. Screens register a default kind with `.captureContext(_:linkTo:)`. Adding folds the cover back, shows a toast and pops the destination tab's icon.
- **Overlays:** the check-in after a call (a slider whose colour runs plum → marigold → tomato), the Answered! flood, and the toast (an ink capsule under the top bar).

## Patterns

- **Moments.** When you do something, the screen answers: a ring ticks and the row folds, a candle lights, ALL IN and SOLD stamps land, an item flies into the suitcase, a letter flies off. Each has a Reduce Motion fallback and a haptic (HANDOFF.md §9, §11).
- **One next action:** the hero card holds the single most likely action as the filled button; detail pages put rarely used fields under the sheet's later sections.
- **Rows:** 12pt above and below, a 1.5pt tomato rule between them, a 28pt ring to tick, the "when" on the right (in `tomatoInk` when late).
- **Segments and pills:** underline segments for 2–4 views of one list; tomato pills for filters. Lists slide in the direction of travel.
- **Detail pages** (records not in the prototype) use the same pattern: the aside by hand, the record's name in display type, its fields on the sheet, links and Delete at the end.
- **Touch:** 44pt targets everywhere. Every gesture has a button or an accessibility action.
