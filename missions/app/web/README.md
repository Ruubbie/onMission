# Missie web

The browser version of the Mission app. It looks and works like the iPhone app (Tomato Flood, see
`missions/app/design/tomato-flood/HANDOFF.md`) and uses the same sync API as the iPhone and Windows apps
(`missions/app/api/openapi.yaml`). Plain HTML, CSS and ES modules, no build step.

## Run it

Serve the folder with any static server, then open it in a browser:

```bash
npx serve missions/app/web
```

Log in with your Mission account. The server address defaults to `https://api.hesent.me` and can be
changed on the login screen or in Settings. The token and address are kept per browser (localStorage).

## Deploy

It is a static site, like `missions/site`. Upload the folder, or add a `wrangler.toml` that serves `web/` as
assets. The API must allow CORS from the site's origin.

## Layout

- `index.html`: the page shell. `assets/app.css`: the screens' rules from the Tomato Flood prototype, in the look of hesent.me: the site's paper, ink, sage and ochre (the palette at the top of the file, from `missions/site/public/assets/tokens.css`), its paper texture and Archivo (`assets/texture/`, `assets/fonts/`, copied from the site). The layout and motion are unchanged.
- **Desktop (900px and wider):** a website. A sidebar with New, the five tabs, Search and Settings; a header bar
  with Back, the screen's name and search. Each screen scrolls as one page: the poster is a tomato header band
  (words left, drawing right) and the cream sheet is the page under it, up to 2600px wide so an ultrawide screen
  gets more columns rather than margins. Pages show their lists in columns. The tabs build their own desktop
  content (`isDesk()` in `ui.js`): Today is a dashboard (next up, this week, waiting on you, support and
  readiness), Tasks is a three-column board, People shows everyone waiting and where everyone is, Prayer is the
  candle stage with the list of prayers beside it, and Move adds what's next on the checklists and the missing papers.
  New opens the capture as a centred panel.
- **Phone (under 900px):** the screen fills the window with the tab bar at the bottom, as on the iPhone.
- `assets/js/main.js`: login, the phone shell, the tab bar, the page stack and routing (`#/route/id`).
- `assets/js/motion.js`: the Lucide icons and their motions, and the tween helpers. Generated from `prototype.html`.
- `assets/js/capture.js`: the + sheet. `assets/js/checkin.js`: the after-call slider.
- `assets/js/pages/`: one module per screen. Tabs: `today`, `tasks`, `people`, `prayer`, `move`.
  Pages: `checklists`, `vault`, `packing`, `budget`, `selling`, `newsletter`, `letter`, `notes`, `guides`, `guide`,
  `settings`, `task`, `partner`, `allpeople`, `search`.
- `assets/js/pages/letter.js`: the letter editor (`#/letter/<id>`, from Newsletters). Dutch or English at a time: title,
  subtitle, the letter as sections (a heading and its text, added with Add a section; each shows where it sits on the page),
  prayer points, side note, next time and (optional) your own line for the funds; photos (scaled to 1800 px and uploaded as files) with a caption per language,
  place, number, status and "Show on hesent.me". Fields save as you type. A letter written before sections (or edited
  on the iPhone since) gets its sections from the body once.
- `assets/js/pages/arrange.js`: Arrange the page (`#/arrange/<id>`, from the letter). The page drawn as hesent.me draws it
  (the headline beside the cover, three staggered columns, the text set as text, photos as taped prints, asides as pinned
  sheets, and under the columns the footer: next time on its envelope and the funds side by side by default, though any
  piece can go there; the illustrations are in `assets/art/`, copied from the site), scaled to fit, and
  a tray for pieces left off. Drag a piece (with a mouse straight away, on a touch screen after pressing and holding it) or tap it for buttons (column 1–3, Footer, Cover, Off, up, down); with a keyboard, arrows,
  1–3, 4 for the footer and Delete. Each move saves at once; Undo (or Ctrl Z) steps back and Arrange for me puts the automatic layout back.
- `assets/js/pages/sections.js`: the rules both pages share: sections ↔ body Markdown, and where new pieces go. The
  server applies the same rules (`arranged()` in `missions/app/server/src/index.js`).
- `assets/js/store.js`, `api.js`, `util.js`: the sync store, the API client and the shared rules (unchanged from the first web version).

## People are not a funnel

People give, pray, read the letters or want to meet, in any mix; none of it is further along than another. A person's
page shows those four as toggles (Gives is the stage `giving`, which the server counts as support; Prays and Gets letters
are `prayer` and `newsletter`; Wants to meet is the extra field `wantsToMeet`), with the monthly amount beside Gives.
"Waiting on you" lists only people who need something: a message from hesent.me, a thank-you owed, a follow-up you
planned yourself, or someone who wants to meet without a time yet. **Someone gives** (People tab, `pages/give.js`)
saves a name, an amount and monthly or once in one go, and the + does the same for "Jan €50 a month". The iPhone app
follows the same rules (`Way`, `SomeoneGivesSheet` and `GivingLine` in the iOS sources).

## The sheet rises

On a phone the sheet starts under the poster and rises to the top bar as soon as you scroll it; pull down at its top,
or tap its handle, to see the poster again (`initSheetLift` in `main.js`, `SheetLift` on the iPhone). The paper texture
is on the poster only; the sheet is plain paper so text sits on a calm ground. The poster drawings are the illustrations
in `assets/art/` (the traveller from hesent.me, and one per page made in Canva in the same sketchbook style).

## Choices to confirm

- **Move readiness** = the average of checklist progress, papers in the Vault and packing (HANDOFF §13, proposal).
- **Check-in stages**: Not now → `paused`, Thinking → `thinking`, Yes! → `committed`.
- **Ollie** is not used, here or on the iPhone; the traveller drawings from hesent.me took his place.
- **Guides** are the bundled text from the prototype, and what you've read is kept on this device only.

## Not in the web version (yet)

- The full animation set: the main moments (tick, I prayed, Answered, Sold, Mark sent, check-in slider) are
  here; some extra motion from the handoff is simplified.
- CSV import and export from the Windows app. The JSON backup is in Settings.
- Offline use: the web app needs the server.
- Contacts have no page of their own; they are listed under All people.
