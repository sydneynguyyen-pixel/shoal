# Shoal prototype

Clickable HTML prototype of the Shoal onboarding flow, built from the "Hi-fi v2 · Onboarding" frames in Figma and revised from the Oct 20 user feedback: tasks are created before anything is split per person.

First open (in `start.js`, from the brand board in Figma): logo splash → sign in with a phone number (texted code), Google, or Facebook → five intro slides on what Shoal is, how it works, and privacy and security. Sign-in is simulated; any 6-digit code works.

Onboarding: care situation → (Pebble questions) → tasks → dates → people → calendar sync → free time per day → strengths → split → jars.

Main app (from the "Hi-fi" Figma frames, in `main-app.js`): setup & first stone (jars, pairing, glow, charging) → Home, My jar, People, and Settings tabs → task detail, hand off, add a task, give it a stone, a person's tasks and why, stones and stone detail → celebrations (done, say thanks, jar is clear, weekly recap, thanks to you, recap settings).

Pebble after setup (in `pebble.js` and `pebble.css`, from the "Pebble" sections of the Hi-fi Figma page) does its work inside the flow you're already in, instead of being a place to visit. What it notices (an urgent step no one has, a task with no one, a declined hand-off) is a banner on Home, a notification and a lock-screen notification, and at home the task's stone pulses; one tap ("Ask Mom") opens Hand off with the pick made and the note written, so what's left is Send. On Hand off, an optional line lets Pebble ask the next person with room if no one says yes by a time you pick. After Ana's visit note, the logistics in it are offered as tasks (medicine and symptom lines stay questions for her). On Add a task, a Medium or Large task can be split into steps; on a money task, Help with costs adds the first step. When a helper joins, Pebble drafts a catch-up note the main caregiver sends. Its tab is just Talk it through, the current notice, What Pebble did (with Undo), Something's wrong (the family's who-to-call screen, also one tap from Home, not Pebble) and a gentle When the time comes. Settings › Pebble has Quiet days, which pauses all of it. Pebble drafts and suggests; nothing changes until someone says yes, it never sends anything itself, and it never reads the care page. Turning Pebble off in Settings hides all of it. There's no AI backend: a few plain rules stand in for it.

The main app uses your onboarding answers. If onboarding was skipped, a demo family fills in. On desktop, "Skip to the main app" in the side panel jumps straight there.

## Run it

Serve the folder with any static server, then open http://localhost:5173:

```bash
python3 -m http.server 5173
```

Opening `index.html` straight from disk won't load the styles or script in some browsers.
