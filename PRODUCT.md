# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Ruben, preparing to move to YWAM Queenstown (New Zealand, departure set in Settings, default 5 Jan 2027). He is the only user. The app is most important at two moments: a **morning check-in** (what's due, thanks, today's few things) and **partner work** (calls, coffees, follow-ups, logging gifts, sending thanks).

## Product Purpose

One place for everything the move needs, all linked together: tasks, checklists, support partners and gifts, a document vault, budget, selling, packing, prayer and thanks, notes, newsletters, contacts and guides. It works offline and syncs with his own server and a Windows helper. It succeeds when raising support and preparing to leave feel calm and nothing slips.

## Positioning

A personal mission-preparation companion, not a generic to-do or CRM: partner stages drive automations (thank-you tasks, follow-ups), gifts update partners, and any record can link to any other.

## Operating Context

- Partner pipeline: On my list → To ask → Asked/meeting → Thinking → Committed → Giving (or Not now / Paused), with A/B/C/K categories and Dutch message templates.
- Quick add parses natural language ("Call Jan friday #support", "!" for high priority).
- Prayer points and thanks (thanks are journal notes marked `#thanks`).
- Windows app and server share the same records (`missions/app/api/openapi.yaml`).

## Capabilities and Constraints

- SwiftUI + SwiftData, iOS 17+, built by GitHub Actions (no local Mac). Pushes to non-main branches compile only; main also publishes the .ipa.
- The sync contract, models, enums, automations and logic layer must not change shape.
- Confirmed friction (Oct 2026): adding things outside Tasks, partner follow-up (long forms, many taps), finding things (11-tile More grid, search buried).
- Navigation may be restructured freely.

## Brand Commitments

- The look is "Tomato Flood" (`DESIGN.md`, `design/tokens.json`, `design/tomato-flood/HANDOFF.md`): tomato posters with one big thing, cream sheets, Archivo and Caveat, line art that draws itself, motion that answers what you do.
- Ollie, from Ruben's own character sheet (`Resources/Ollie`), is never redrawn in code. He appears once, asleep, on Today's All done.
- App name: hesent.me. Copy is short and plain, English UI, Dutch partner templates.

## Product Principles

1. The next action is always one tap away: every screen leads with what needs doing.
2. Capture anywhere, sort later: anything typed lands in the right place.
3. People before paperwork: partner relationships get the most direct flows.
4. Start with thanks: gratitude and prayer stay part of the daily ritual.
