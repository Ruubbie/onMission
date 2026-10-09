# Missie for Windows

The desktop helper for bigger PC work: bulk-editing partners and budget, writing newsletters, keeping your documents safe. It works fully offline and syncs with the mission API, so the iPhone app sees the same data.

## Install (2 minutes)

1. Download `dist/Missie-windows.zip` and unzip it anywhere (for example `Documents\Missie`).
2. Double-click `Missie.exe`. Nothing else to install; .NET is inside the exe.
3. The first time, Windows SmartScreen may say "Windows protected your PC" because the app isn't signed. Click **More info → Run anyway**.
4. Optional: right-click `Missie.exe` → **Pin to Start**.

## First run

- The app opens with starter data (checklists from the visa plan, budget lines, packing list, document placeholders).
- To sync: **Settings** → server URL (default `https://api.92-5-233-11.sslip.io`; change it to `https://api.rubenonmission.nl` once that domain is live) → log in with the same email and password as on the iPhone. The first time ever, use **Create account** with the server's setup secret.
- After that it syncs on start, every 5 minutes, and when you click the sync pill (or press F5).

## What's in it

| Page | For |
|---|---|
| Home | Days to Queenstown, quick-add task, today/overdue, checklist folders, support meter |
| Checklists | All tasks by checklist, status, due dates, links |
| Partners | Bulk-edit grid, stages, gifts, follow-ups, thank-yous, conversation log |
| Budget | Setup costs, monthly NZ costs, income, EUR/NZD totals, monthly gap |
| Selling | Things to sell or give away, Marktplaats links, sold total |
| Packing | Per bag with weight limits (23 kg checked, 7 kg carry-on) |
| Documents | Vault: drag files in; expiry warnings; open even offline |
| Notes | Notes, prayer notes, journal, meetings |
| Newsletter | Write in Markdown, live preview, export website page and email HTML |
| Contacts | YWAM staff and other people |

Every list has **Import CSV / Export CSV** for Excel (Dutch semicolon files work). Smart links: any item can link to any other (a task to a document, a partner to a note); click a link chip to jump there. **Ctrl+K** searches everything, **Ctrl+N** adds an item, **Ctrl+1…9** switches pages.

## Where your data lives

`%LOCALAPPDATA%\Missie` (Settings → Open data folder): `missie.db` (all records), `vault\` (your files), `log.txt`. Your login token is encrypted with your Windows account. Settings → Export backup writes everything to one JSON file.

## For developers

- .NET 10. `src/Missie.Core` (storage, sync, vault; cross-platform), `src/Missie.Desktop` (WPF), `tests/Missie.Core.Tests` (xUnit).
- Build/run on Windows: `dotnet run --project src/Missie.Desktop`.
- Tests: `dotnet test`. With a local server running (`npm run dev` in `app/server`), `MISSIE_E2E_URL=http://localhost:8787 dotnet test` also runs a two-device sync test against it.
- Release exe: `dotnet publish src/Missie.Desktop -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o dist`.
- API contract: `../api/openapi.yaml`. Design tokens shared with the iPhone app: `../design/tokens.json`.
