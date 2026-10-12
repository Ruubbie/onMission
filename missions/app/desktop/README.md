# Desktop app (React)

The desktop helper, rebuilt in React so it runs in a browser for previewing and as a Windows app through Tauri. It replaces the WPF app in `../windows` and syncs with the same API (`../api/openapi.yaml`), so the iPhone app sees the same data. The look follows `../design/design-system.md`.

## Install on Windows

Download **OnMission-Setup.exe** from the [desktop-latest release](https://github.com/Ruubbie/onMission/releases/download/desktop-latest/OnMission-Setup.exe) and run it. It installs for your user only (no admin). Windows SmartScreen may warn because the app isn't signed: **More info → Run anyway**. Every push to `missions/app/desktop` builds a fresh installer.

## Preview in your browser

Needs [Node.js](https://nodejs.org) 20 or newer.

```
cd missions/app/desktop
npm install
npm run dev
```

Open http://localhost:5173. Edits to the code show up instantly. Data in the browser preview is separate from the installed app.

To run it as the real Windows app while developing (needs Rust from https://rustup.rs): `npm run tauri dev`.

## What's where

| Folder | What |
|---|---|
| `src/ui` | The design-system parts as React components (buttons, folder card with slanted tab, toggle, segmented, select, date field, stepper, search, forms, sheet, dialog, toast, badge). No app logic, so the newsletter website can reuse it. |
| `src/design` | `tokens.css` (copy of `../design/tokens.css`), `brand.ts` (app name and section colours; change the name here). |
| `src/newsletter/render.ts` | Turns a newsletter into a web page or email HTML. The website can reuse it. |
| `src/data` | Local store (browser storage), sync with `/v1/sync`, document files (cached locally, uploaded to `/v1/files`), starter data. |
| `src/pages` | Home, Checklists, Partners, Budget, Selling, Packing, Documents, Notes, Newsletter, Contacts, Settings. |
| `src-tauri` | The Windows shell (Tauri 2). |

Keys: **Ctrl+K** search everything, **Ctrl+N** add, **Ctrl+1…9** switch pages, **F5** sync.

When the design tokens change, copy `../design/tokens.css` to `src/design/tokens.css`. When the starter data changes, copy `../ios/OnMission/Resources/seed-records.json` to `src/data/`.
