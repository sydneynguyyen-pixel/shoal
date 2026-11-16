# Shoal: handoff notes

Context for picking this project up in a new Claude session.

## What this is

Shoal is a caregiving prototype for a family looking after "Dad". It's a shared to-do list where each person has a jar of glowing stones, one per task. There's also an optional physical home kit (real jars and stones), plus Pebble, an AI helper that can be turned off.

There are two versions in this repo:

- **Web app**, the source of truth for design and behavior. It's vanilla JS in the repo root: `main-app.js`, `people.js`, `pebble.js`, `roles.js`, `styles.css`, `pebble.css`, etc. Screens are `SCREENS.<name>` functions and buttons are `ACTIONS.<name>`. The global state is `S`.
- **SwiftUI app** in `ShoalApp/`, a native rebuild that should match the web.

The user demos this in class, so **every button must do something**. No dead taps.

## Rules from the user (follow every time)

- **Push to GitHub only when the user says yes, each time.** Ask before committing too.
- **Never enable GitHub Pages.** "Just push to GitHub, no Pages."
- **Don't commit `print/` or `docs/`.** They have local changes that stay uncommitted. Stage only what you changed, for example `git add ShoalApp`.
- `gh pr create` is blocked. Work happens on `main`.
- Keep UI text minimal and plain.
- Say "yellow", never "honey".
- The phone number field shows formatted numbers like (503) 555-0188, never raw digits.
- Keep the user's personal details (such as their email) out of anything sent to outside services.

## Current state (as of commit `b037b48` on `main`)

The Swift app now matches the web on these screens:

- **Home**: urgent banner, family jars, Your jar / Home kit cards, Dad's care, This week chart.
- **My jar**:
  - The check-in card shows by default, because `ringOn = false` to start, like the web.
  - 3-column stats.
  - Underlined All / One-time / Ongoing tabs.
  - Request rows.
- **People**:
  - Monthly check-in entry at the top, then family jars.
  - Sam is invited: a "Pending" row opens a sheet with Resend and Cancel invite.
  - Extended circle: Trusted circle, Hospice nurse (goes to `.care(nurse: true)`), Dad's care.
- **Task page**:
  - Step checkboxes and a progress bar.
  - Glossary: underlined words (PRN, hospice, palliative, respite, POLST, DNR, IHSS) open `TermSheet`.
  - ••• menu: change date or days, find or link a stone, hand off.
  - Back is an icon-only arrow.
- **Pebble tab**:
  - Hero with no glow.
  - Pebble-noticed card (`PebbleHomeCard`, shared with Home).
  - Four tiles: Find someone, Help with costs, Monthly check-in, What I did.
  - Full-width "What Pebble can see" row.
- **Settings**: account card, then Family (care lock, Family setup), Notifications (two sample-notification buttons), My jar (progress ring), Stones, Pebble, Account (Sign out), and Restart prototype.
- **Seed data** (`Model.swift`): includes Leo (Dad's grandson, 14, kid tier) and kid tasks. That gives 30 tasks with 5 unassigned, matching the web.

## What's left / ideas for next steps

These web screens have **no Swift version yet**, so their entry points were left out of the Swift app:

- Help and resources (web `SCREENS.resources`, the `RESOURCES` data in `main-app.js`)
- Thank-yous & recaps settings, the weekly recap
- Notification settings (the web's `notifications` screen; Swift only has the sample-notification buttons)
- Volunteer code
- "See Shoal as someone else" (role views from `roles.js`; Swift only has the nurse view)
- "Take the tour again"

To add one:

1. Build the screen.
2. Add a `Route` case in `Store.swift`.
3. Add the row back where the web has it: Settings or People.

Then compare the other Swift screens against the web for remaining differences:

- Handoff
- New task
- Care page
- Kit
- Talk it through
- Costs
- Onboarding

## How to build and run

Run from `ShoalApp/`:

```bash
xcodebuild -project Shoal.xcodeproj -scheme Shoal -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build/dd build 2>&1 | grep -E "^/.*error:|BUILD" | sort -u
```

The app ends up at `build/dd/Build/Products/Debug-iphonesimulator/Shoal.app`. Change the simulator name if yours differs.

Web: serve the repo root on any static server (it was run on port 5174) and view it at phone size, 402×874.

## Swift code map

- `Store.swift`: all state (`@Observable Store`).
  - Navigation: `store.go(Route)` and `store.back()`.
  - `store.say("...")` shows a toast.
  - `reset()` restarts the demo.
  - Onboarding state: `onboarded`, `first: FirstStage`.
- `Model.swift`: `Person`, `CareTask`, the demo seed (`DEMO_PEOPLE`, `demoTasks()`), `LOVED` ("Dad").
- `Theme.swift`: shared UI.
  - `Font.app(size, weight)` is Figtree; `.title()` is Fraunces.
  - Components: `Eyebrow`, `Badge`, `Chevron`, `Avatar`, `Jar`, `RowSep`, `SectionH`, `.glassCard()`, `.pearl()` (the Pebble surface), `Pressable`, `PrimaryButton`, `GhostButton`, `PearlChip`.
- Screens: `HomeView`, `MyJarView`, `PeopleView`, `TaskView`, `PebbleView`, `SettingsView`, `HandoffView`, `NewTaskView`, `CareView`, `Kit`, `Talk`, `Onboarding`, `Setup`.

## Simulator tips

The simulator is 402×874 points. Driving it:

1. **Onboarding:** tap "Skip sign-in (testing)" at about (201, 642), then the intro's "Skip" at the top right (362, 84), then "Skip onboarding (testing)" at about (201, 562).
2. **Tab bar:** y ≈ 821. Home x=63, My jar 131, People 201, Pebble 270, Settings 338.

Things that trip you up:

- Each skip tap often needs a second tap.
- Taps made during a screen transition get lost, and sometimes land on whatever is underneath, so wait about 0.5 s.
- A screenshot taken right after a tap can still show the old screen. Take another before deciding the tap failed.
