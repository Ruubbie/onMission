# On Mission (iPhone app)

An iPhone app for getting to YWAM Queenstown. Everything you need is in one place and linked together: tasks, checklists, support partners and gifts, a document vault, the budget, things to sell, packing, prayer, notes, newsletters, contacts, and the guides. It works offline and syncs with your own server (`../server`) and the Windows helper.

> This code has not been compiled yet, because there was no Mac or Swift compiler available while writing it. The first cloud build will show any compile errors. Send them to Claude and they'll be fixed.

## What's in it
- **Today:** a countdown to departure, quick add ("call Jan friday #support"), a heads-up list (overdue tasks, expiring documents, partners to follow up or thank), this week's tasks, and your support compared with the target.
- **Smart links:** any item can link to any other, for example a task to a partner, a document to a checklist, or a gift to a partner. Links show on both sides and sync to Windows.
- **Automations:**
  - Moving a partner to "committed" adds a thank-you task.
  - Recording a gift updates the partner.
  - Due dates become reminders at 9:00.
- **Vault:** scan, photograph or import passports, visas, insurance papers and tickets. Files are stored on the phone and on your server, and you can choose which ones every device keeps offline.
- **Partners:** stages, A/B/C/K categories, call/WhatsApp/email buttons, Dutch message templates, and CSV import and export.
- **Backup:** export and restore everything as one file (Settings).

## Get it on your iPhone without a Mac (cloud build)
1. **Apple Developer Program** (€99 a year): enrol at developer.apple.com/programs. This is needed for TestFlight.
2. **App record:** in App Store Connect, create an app with the bundle id `nl.rubenonmission.onmission`.
3. **API key:** in App Store Connect, go to Users and Access > Integrations > App Store Connect API and create a key with the App Manager role. Download the `.p8` file.
4. **GitHub repo:** make a private repo and put the `missions/` folder in it, keeping the same paths. Copy `ci/ios.yml` to `.github/workflows/ios.yml`.
5. **Secrets:** in the repo's Settings > Secrets and variables > Actions, add `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the full text of the .p8) and `APPLE_TEAM_ID`.
6. **Build:** every push builds the app on GitHub's Macs. To upload to TestFlight, go to Actions > iOS app > Run workflow and tick "Upload to TestFlight". Then install the TestFlight app on your iPhone and open On Mission.

## With a Mac instead
Run `brew install xcodegen`, then `xcodegen` in this folder. Open `OnMission.xcodeproj`, pick your team under Signing, and run it on your iPhone.

## Signing in
Create your account on the server first (see `../server/README.md`). Then open the app, go to Settings > Sync, and enter the server (now `api.92-5-233-11.sslip.io`, later `api.rubenonmission.nl`), your email and your password. Each device gets its own token, and you can revoke one under Settings > Devices.

## Privacy
Data is stored on your phone (SwiftData) and on your own server, and nowhere else. The login token is kept in the iPhone Keychain.

## Files
- `OnMission/Shared/Model`: records, which match `../api/openapi.yaml`. Unknown fields are kept.
- `OnMission/Shared/Sync`: login, sync and files.
- `OnMission/Shared/Logic`: insights, automations, reminders, the seeder and backups.
- `OnMission/Shared/Design` and `Views`: the neo-brutalist style. The colours come from `../design/tokens.json`, shared with Windows.
- `OnMission/Resources`: the font, the guides and the starter data (`tools/make-seed.mjs`).
- `tools/contract-check.mjs`: checks the app's record shapes against a running server.
- `INTERFACES.md`: how the layers fit together.
