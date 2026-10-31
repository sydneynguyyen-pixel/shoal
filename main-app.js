/* Shoal main app: setup & first stone, the four tabs, task flows, stones, and celebrations.
   Shares state (S), helpers, sheets, and the render loop with app.js. */

const SETUP = ["ready", "jars", "pick", "hold", "paired", "find", "glow", "charge", "pairRest"];
const TABS = [["home", "Home"], ["myjar", "My jar"], ["peopleTab", "People"], ["pebble", "Pebble"], ["settings", "Settings"]];
// Pebble gets a tab only while it's turned on in Settings.
const shownTabs = () => TABS.filter(([id]) => id !== "pebble" || pebbleOn());
const APP_SCREENS = new Set([
  ...SETUP, ...TABS.map((t) => t[0]),
  "task", "handoff", "newTask", "newStone", "person", "kit", "stones", "stoneDetail",
  "done", "thanks", "clear", "recap", "notifications", "recapSettings", "resources",
]);
const KIT = 36;
const BATTERY = [82, 64, 91, 18, 77, 55, 100, 12, 69, 88, 73, 95, 60, 47, 84, 70, 93, 66, 79, 90, 58, 86, 75, 97, 81, 68, 92, 74, 87, 63, 99, 71, 85, 78, 94, 67];
// The kit comes with real stones in three sizes, to match task sizes: 12 small, 15 medium, 9 large.
const STONE_SIZE = [2, 1, 2, 1, 3, 2, 1, 2, 3, 1, 2, 1, 2, 3, 3, 2, 1, 2, 3, 1, 2, 3, 1, 2, 2, 1, 3, 2, 1, 2, 3, 1, 2, 1, 2, 3];
const sizeName = (w) => WEIGHT_LABEL[w].toLowerCase();
const L = () => S.lovedOne || "Dad";

/* ---------- Demo family (used when onboarding was skipped or left empty) ---------- */

const DEMO_PEOPLE = [
  { id: "mom", name: "Mom", img: "avatar-mom.png", tier: "main", cap: 9, about: "Lives with ", joined: true,
    best: "Mornings", reach: "Call", contact: "(408) 555-0142", know: ["Doesn't drive after dark", "Needs a nap around 2, so no calls then", "Knows all the meds by heart"] },
  { id: "bill", name: "Bill", img: "avatar-bill.png", tier: "main", cap: 6, about: "Free evenings · 10 min away", joined: true,
    best: "After 6 PM", reach: "Text", contact: "(408) 555-0179", know: ["Bad back, so no heavy lifting", "Has the truck, good for big pickups", "Works days, can't take calls till lunch"] },
  { id: "sam", name: "Sam", img: "avatar-sam.png", tier: "main", cap: 3, remote: true, about: "Helps from Portland", via: "text", contact: "(503) 555-0188", rel: "Grandchild",
    best: "Weekends", reach: "Text", know: ["Great with insurance and forms", "Visiting Thanksgiving week", "Can make calls on work breaks"] },
  { id: "nora", name: "Nora", img: "avatar-nora.png", tier: "trusted", cap: 2, about: "Neighbor", joined: true,
    best: "Weekdays", reach: "Text", contact: "(408) 555-0115", know: ["Has a spare key", "Can check in if no one answers"] },
];

function demoTasks() {
  const l = L();
  let n = 0;
  // when: a number = one-time, due that many days from today; an array = ongoing on those days
  const mk = (name, who, w, k, when, extra = {}) => ({
    id: `d${n++}`, n: name, w, k, y: false, cat: "", on: true, pebble: false,
    kind: Array.isArray(when) ? "repeat" : "once",
    days: Array.isArray(when) ? when : ["Sat"],
    date: Array.isArray(when) ? addDays(3) : addDays(when),
    time: "", who, done: false, steps: [], notes: "", remote: false, ...extra,
  });
  return [
    mk(`Refill ${l}'s prescription`, "you", 1, "meds", 1, {
      notes: "Ask for the 90-day supply. The old bottle is in the kitchen drawer. The hospice nurse said to fill the PRN dose too.",
      steps: [
        { n: "Call the pharmacy", who: "you", done: true, when: "Mon" },
        { n: "Check insurance covers it", who: "bill", done: false },
        { n: "Pick up or get it delivered", who: null, done: false },
      ],
    }),
    mk("Ask hospice about a bed", "you", 1, "phone", 4),
    mk("Figure out help paying for care", "you", 2, "paper", 6),
    mk(`Sort ${l}'s mail`, "you", 1, "paper", ["Mon"]),
    mk("Fill the weekly pill box", "you", 1, "meds", ["Sun"]),
    mk("Book the eye exam", "you", 1, "phone", -2, { done: true }),
    mk("Call about the hospital bill", "you", 2, "phone", -4, { done: true }),
    mk("Return the walker", "you", 1, "drive", -5, { done: true }),
    mk("Cook dinners", "mom", 2, "cook", ["Mon", "Wed", "Fri"]),
    mk("Morning meds", "mom", 1, "meds", [...DAYS], { medIds: ["metoprolol"] }),
    // Med tasks point at meds on the care page, where anyone who gives a dose logs it.
    mk("Comfort meds", "mom", 1, "meds", [...DAYS], {
      notes: "From the hospice comfort kit in the fridge. Call hospice before giving more than the plan says.",
      medIds: ["morphine", "lorazepam"],
    }),
    mk(`Keep ${l} company`, "mom", 2, "there", [...DAYS]),
    mk("Laundry and sheets", "mom", 2, "there", -1, { done: true }),
    mk(`Drive ${l} to Thursday's visit`, "bill", 2, "drive", 2, { why: "10 minutes away" }),
    mk("Pick up groceries", "bill", 2, "drive", ["Sat"], { why: "Free evenings" }),
    mk("Fix the stair rail", "bill", 2, "there", 5, { why: "Said he's handy" }),
    mk("Weekend visits", "bill", 2, "there", ["Sun"], { why: "Wants to be there" }),
    mk("Take out recycling", "bill", 1, "there", ["Tue"], { why: "Lives closest" }),
    mk(`Drive ${l} to his checkup`, "bill", 2, "drive", 0, { done: true, doneAt: "Today, 2:00 PM" }),
    mk("Order groceries online", "sam", 1, "phone", ["Fri"], { remote: true, why: "Can do it from anywhere" }),
    mk(`Video call with ${l}`, "sam", 1, "there", ["Wed", "Sun"], { remote: true, why: "Wants to be there" }),
    mk("Pay the utility bills", "sam", 1, "paper", -3, { done: true, remote: true }),
    mk("Bring in the mail", "nora", 1, "there", ["Mon", "Thu"]),
    mk("Be there for the nurse visit", null, 2, "there", 2),
    mk("Mow the lawn", null, 2, "there", ["Sat"]),
  ];
}

// Sets up everything the main app needs, from onboarding answers if there are any.
function ensureAppData() {
  if (S.app) return;
  // Skipping onboarding (testing) loads a sample family. Finishing it starts a real, empty plan.
  const demo = !S.setup && !S.tasks.some((t) => t.on);
  if (demo) {
    S.kit ??= "yes"; // the sample family shows the physical kit too
    S.stage ??= "final"; // and is in hospice, which the sample tasks assume
    if (!S.lovedOne) S.lovedOne = "Dad";
    DEMO_PEOPLE.forEach((p) => {
      if (!S.people.some((x) => x.name === p.name)) S.people.push({ ...p, note: "", invited: true, about: p.about === "Lives with " ? `Lives with ${L()}` : p.about });
    });
    S.tasks = demoTasks();
  }
  S.tasks.forEach(normTask);
  // Jars and the base are powered, so a stone charges anywhere but "out" (on a table, in a bag).
  S.stones = Array.from({ length: KIT }, (_, i) => ({ id: i + 1, task: null, battery: BATTERY[i], out: i === 3, size: STONE_SIZE[i] }));
  // In the demo, the rest of the family has already paired a few of their own stones.
  if (demo) ["mom", "mom", "bill", "bill", "bill", "sam"].forEach((who) => {
    const t = S.tasks.find((x) => x.on && !x.done && x.who === who && !stoneOf(x));
    if (t) pairStone(t.id);
  });
  const helper = S.people.find((p) => p.tier === "main" && p.id !== "you");
  S.app = {
    day: iso(TODAY), jarTab: "all", stoneFilter: "all", showDone: false, morePair: false,
    first: null, heard: false, blink: null, task: null, person: null, stone: null, draft: null, stoneFor: null,
    handTo: undefined, note: "", thankFor: null, thankPick: 0, thanksNote: "", shareThanks: true, thanked: {}, dismissed: {}, seenNotes: false,
    requests: helper ? [{ id: "r1", from: helper.id, n: "Call the pharmacy", note: "They'll only talk to the main contact." }] : [],
    prefs: { ring: false, little: true, weekly: true, names: true, quiet: false, quietFor: "week", publicCode: false, night: true, nightFrom: "22:00", nightTo: "07:00", glow: "on" },
    demo,
  };
}

// Tasks made in setup get the fields the app screens expect.
function normTask(t) {
  t.w ??= 2; t.done ??= false; t.steps ??= []; t.notes ??= ""; t.remote ??= false;
}

/* ---------- Model helpers ---------- */

const active = () => S.tasks.filter((t) => t.on && !t.done);
const mine = (who = "you") => S.tasks.filter((t) => t.on && t.who === who);
const stoneOf = (t) => S.stones?.find((s) => s.task === t.id);
const taskOf = (s) => s.task && S.tasks.find((t) => t.id === s.task);
// Kid tasks are nice to have, so they never turn urgent or nag anyone.
const isUrgent = (t) => !t.y && t.kind === "once" && !t.done && t.date <= addDays(2);
function stateOf(t) {
  if (t.done) return "done";
  if (!t.who) return "open";
  return isUrgent(t) ? "urgent" : "progress";
}
const STATE = {
  urgent: ["Urgent", "yellow", "Due soon"],
  progress: ["In progress", "ice blue", "Someone is on it"],
  open: ["Unassigned", "white", "No one has it yet"],
  done: ["Done", "light off", "Light is off"],
};
const nameOf = (id) => (id ? person(id)?.name || "Someone" : "Unassigned");
const possessive = (p) => (p.id === "you" ? "your" : `${p.name}'s`);
function dueLabel(t) {
  if (t.kind === "repeat") return repeatLabel(t.days);
  const d = Math.round((fromIso(t.date) - TODAY) / 864e5);
  if (d === 0) return "due today";
  if (d === 1) return "due tomorrow";
  if (d < 0) return fmtDate(t.date);
  return `due ${fmtDate(t.date)}`;
}
// A task gets a free stone its own size, or the closest size left.
const freeStone = (w = 2) => {
  const free = S.stones.filter((x) => !x.task);
  return free.sort((a, b) => Math.abs(a.size - w) - Math.abs(b.size - w))[0];
};
const pairMsg = (s, t, verb = "paired") => (s ? `Stone ${String(s.id).padStart(2, "0")} ${verb} · ${sizeName(s.size)}` : `All ${KIT} stones are in use`);
function pairStone(taskId) {
  const s = freeStone(S.tasks.find((t) => t.id === taskId)?.w);
  if (s) s.task = taskId;
  return s;
}
// Only stones away from a jar or the base can run down.
const notCharging = () => S.stones.filter((s) => s.out);
const lowBattery = () => notCharging().filter((s) => s.battery < 30);
const inJar = (s) => { const t = taskOf(s); return t && t.who && person(t.who).tier === "main"; };
const outLabel = (s) => (s.task ? "out of its jar" : "off the base");
const placeOf = (s) => (s.out ? `${outLabel(s)[0].toUpperCase()}${outLabel(s).slice(1)} · not charging` : inJar(s) ? `In ${possessive(person(taskOf(s).who))} jar · charging` : "On the base · charging");
const battLabel = (s) => (s.out ? `${s.battery}%` : `⚡ ${s.battery}%`);
const WHY = { drive: "Lives nearby", phone: "Good on the phone", cook: "Likes to cook", meds: "Knows the meds", paper: "Good with paperwork", there: "Wants to be there" };
const whyOf = (t, p) => t.why || (p.remote || t.remote ? "Can do it from anywhere" : WHY[t.k] || "Had free time then");

/* ---------- Pieces ---------- */

const gem = (state, { dark = false, size = "", cls = "", style = "" } = {}) =>
  `<span class="gem ${state} ${dark ? "dark" : ""} ${size} ${cls}" ${style ? `style="${style}"` : ""} aria-hidden="true"></span>`;
// A task's stone is as big as the task: small, medium or large.
// Urgent is separate from who has it. "nobody" stays as a hook, but carries no mark: only urgent stones do.
const gemOf = (t, opts = {}) => gem(stateOf(t), { dark: t.kind === "repeat", ...opts, cls: `w${opts.w || t.w || 2} ${!t.who && !t.done ? "nobody" : ""} ${opts.cls || ""}` });
const toggle = (on, act, id = "", label = "") => `<button class="switch ${on ? "on" : ""}" role="switch" aria-checked="${on}" ${label ? `aria-label="${label}"` : ""} data-act="${act}" data-id="${id}"><i></i></button>`;
const chev = `<img class="chev" src="${A("chevron.svg")}" alt="">`;

const ICONS = {
  home: `<path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1z"/>`,
  myjar: `<path d="M8.5 3h7M7.5 6h9M7.5 6C6.3 7 5.5 8.3 5.5 10v9a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2v-9c0-1.7-.8-3-2-4"/><path d="M8.5 15.5h7"/>`,
  peopleTab: `<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19.5c.6-3 2.8-5 5.5-5s4.9 2 5.5 5"/><circle cx="16.5" cy="9" r="2.6"/><path d="M15.8 14.3c2.5-.1 4.3 1.7 4.8 4.4"/>`,
  settings: `<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
  bell: `<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>`,
  kit: `<rect x="3" y="17.5" width="18" height="3.5" rx="1.75"/><path d="M5.5 17.5V10a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v7.5M12.5 17.5V10a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v7.5M7 5.5h3M14 5.5h3"/>`,
  pebble: `<path d="M12 5.5c5 0 8.5 3 8.5 7S17 19 12 19s-8.5-2.5-8.5-6.5S7 5.5 12 5.5z"/><path d="M9.5 11.5v.6M14.5 11.5v.6M10 14.6c1.2.8 2.8.8 4 0"/>`,
  glow: `<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.6 10.8c.7.6 1.1 1.4 1.1 2.2h5c0-.8.4-1.6 1.1-2.2A6 6 0 0 0 12 3z"/>`,
};
const icon = (k) => `<svg aria-hidden="true" focusable="false" viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${ICONS[k]}</svg>`;

function tabbar() {
  const tab = S.screen === "person" || S.screen === "stones" ? "" : S.screen;
  return `<nav class="tabbar">${shownTabs().map(([id, l]) => `<button class="${tab === id ? "on" : ""}" ${tab === id ? 'aria-current="page"' : ""} data-act="tab" data-to="${id}">${icon(id)}<span>${l}</span></button>`).join("")}</nav>`;
}
function navtop(label, right = "") {
  return `<div class="navtop"><button class="navback" data-act="back" aria-label="Back"><img src="${A("back.svg")}" alt="">${esc(label)}</button>${right}</div>`;
}
function setupTop(n) {
  return `<div class="topbar">
    <button class="back" data-act="back" aria-label="Back"><img src="${A("back.svg")}" alt=""></button>
    <div class="progress">${Array.from({ length: 8 }, (_, k) => `<span class="${k < n ? "on" : ""}"></span>`).join("")}</div>
    <button class="skip" data-act="tab" data-to="home">Skip</button>
  </div>`;
}
const solo = (label, act, sec, attrs = "") => `<div class="footer">
  <button class="btn-primary" data-act="${act}" ${attrs}>${label}</button>
  ${sec ? `<button class="btn-text" data-act="${sec[1]}" ${sec[2] || ""}>${sec[0]}</button>` : `<span style="height:20px"></span>`}
</div>`;
const duo = (left, right) => `<div class="footer duo">
  <button class="btn-ghost" data-act="${left[1]}" ${left[2] || ""}>${left[0]}</button>
  <button class="btn-primary" data-act="${right[1]}" ${right[2] || ""}>${right[0]}</button>
</div>`;

// Jar stones (size "s"), in px for each task size.
const JAR_STONE = { 1: [18, 14], 2: [24, 18], 3: [31, 23] };
// Takes tasks, or just a count for sample jars, which get a mix of sizes (big ones at the bottom).
const SAMPLE_W = [3, 2, 1, 2, 2, 1, 1, 2, 1];
const sampleW = (i) => SAMPLE_W[i % SAMPLE_W.length];
const jarSlots = (ts) => packStones((typeof ts === "number" ? Array.from({ length: ts }, (_, i) => ({ w: sampleW(i) })) : ts).map((t) => JAR_STONE[t.w || 2]));
// Jars on a shelf. Done stones sit at the bottom, glowing ones on top, big ones under small ones.
// Each stone drops in once; later re-renders (like picking a day) leave it still.
const dropped = new Set();
function familyJars({ empty = false, only = null, act = true } = {}) {
  const ppl = S.people.filter((p) => p.tier === "main" && (!only || p.id === only));
  const glow = S.app?.prefs?.glow || "on";
  const html = `<div class="shelf-jars glow-${glow}">${ppl.map((p) => {
    const all = empty ? [] : mine(p.id).sort((a, b) => b.done - a.done || (b.w || 2) - (a.w || 2));
    // A full jar lets done stones go first, so what's still glowing stays in view.
    let ts = all, pos = jarSlots(ts);
    while (pos.some((x) => !x) && ts.some((t) => t.done)) { ts = ts.slice(1); pos = jarSlots(ts); }
    const more = all.length - pos.filter(Boolean).length;
    const tag = act ? "button" : "div";
    return `<${tag} class="rjar" ${act ? `data-act="openPerson" data-id="${p.id}"` : ""}>
      <div class="glassbox"><img class="glass" src="${A("jar.png")}" alt="">
        ${ts.map((t, i) => (pos[i] ? gemOf(t, { size: "s", cls: `${S.app?.blink === t.id ? "blink" : ""} ${dropped.has(`${p.id}:${t.id}`) ? "still" : ""} ${typeof pebblePulse === "function" && pebblePulse(t) ? "peb-pulse" : ""}`, style: `left:${pos[i].x}px;top:${pos[i].y}px` }) : "")).join("")}${jarMore(more)}
      </div><span class="who">${esc(p.name)}</span>${empty ? "" : `<span class="jar-n">${(() => { const n = all.filter((t) => !t.done).length; return typeof pending === "function" && pending(p) ? "Invited" : n ? `${n} to do` : "All done"; })()}</span>`}</${tag}>`;
  }).join("")}</div>`;
  ppl.forEach((p) => { if (!empty) mine(p.id).forEach((t) => dropped.add(`${p.id}:${t.id}`)); });
  return html;
}
const GLOW = { on: "Glow on", dim: "Dimmed", off: "Glow off" };
const unread = () => !S.app.seenNotes && notifications().length > 0;
const legend = () => `<div class="legend">${Object.keys(STATE).map((s) => `<span>${gem(s, { size: "xs" })}${STATE[s][0]}</span>`).join("")}</div>`;

// One task line: gem, name, meta, optional trailing bit.
function taskLine(t, { meta, trail = "", act = "openTask", showWho = true } = {}) {
  const p = t.who && person(t.who);
  const m = meta ?? `${showWho && p ? `${avatar(p, "s20")} ${esc(p.name)} · ` : showWho && !p ? "Unassigned · " : ""}${dueLabel(t)}${t.time ? ` · ${fmtTime(t.time)}` : ""}${t.remote ? " · remote" : ""}`;
  return `<div class="tline ${t.done ? "is-done" : ""}">
    <${act === "noop" ? "div" : "button"} class="tl-main" ${act === "noop" ? "" : `data-act="${act}" data-id="${t.id}"`}>${gemOf(t)}<span class="sr-only">${STATE[stateOf(t)][0]}:</span>
      <span class="tl-txt"><span class="n">${esc(t.n)}</span><span class="m">${m}</span></span></${act === "noop" ? "div" : "button"}>${trail}
  </div>`;
}

/* ---------- Setup checklist ---------- */

// What onboarding used to ask all at once, now done from Home in any order, one short sitting each.
const SETUP_STEPS = [
  { id: "tasks", t: "Add what needs doing", m: "About 5 min" },
  { id: "calendar", t: "Bring in your calendar", m: "About 1 min · so tasks land on free time" },
  { id: "schedule", t: "Put tasks on the calendar", m: "About 3 min", needs: "tasks" },
  { id: "split", t: "Choose who does what", m: "About 3 min · then send the plan", needs: "tasks" },
  { id: "stones", t: "Connect a Shoal kit", m: "Optional · real jars and glowing stones at home", needs: "tasks", optional: true },
];
// The kit step only counts once a family says they have one. Saying no hides it.
const countedSteps = () => SETUP_STEPS.filter((x) => !x.optional || hasKit());
const shownSteps = () => SETUP_STEPS.filter((x) => !x.optional || S.kit !== "no");
const setupCount = () => countedSteps().filter((x) => S.setup[x.id]).length;

function setupCard() {
  if (!S.setup || S.setup.hidden) return "";
  const n = setupCount(), total = countedSteps().length;
  if (n === total && (S.kit || S.setup.stones)) return `<div class="card setup-card all-set">
    <span class="tl-txt"><span class="n">You're all set up</span><span class="m">Change anything from My jar, People, or Settings.</span></span>
    <button class="linkish" data-act="hideSetup">Hide</button></div>`;
  const nextUp = shownSteps().find((x) => !S.setup[x.id] && (!x.needs || S.setup[x.needs]));
  return homeSec("setup", "Finish setting up", `<span class="hs-count">${n} of ${total}</span>`, `<div class="card setup-card">
    <div class="bar" aria-hidden="true"><i style="width:${Math.max(4, (n / total) * 100)}%"></i></div>
    <div class="tlist flat">${shownSteps().map((x) => {
      const done = S.setup[x.id], locked = x.needs && !S.setup[x.needs];
      return `<button class="srow sc-row ${done ? "done" : ""} ${locked ? "locked" : ""} ${x === nextUp ? "next" : ""}" data-act="setupStep" data-id="${x.id}">
        <span class="sc-check">${done ? `<img src="${A("check.svg")}" alt="Done">` : ""}</span>
        <span class="tl-txt"><span class="n">${x.t}</span><span class="m">${locked ? "Add tasks first" : done ? "Done · tap to change" : x.m}</span></span>${chev}</button>`;
    }).join("")}</div>
  </div>`, nextUp ? `<button class="card sc-peek" data-act="setupStep" data-id="${nextUp.id}"><span class="tl-txt"><span class="m">Next up</span><span class="n">${nextUp.t}</span></span>${chev}</button>` : "");
}

// A titled Home section that folds closed. Closed, it can still show a one-line peek.
function homeSec(id, title, right, body, peek = "") {
  const shut = S.app.shut?.[id];
  return `<section class="hsec ${shut ? "shut" : ""}" data-sec="${id}">
    <button class="hsec-head" data-act="homeFold" data-id="${id}" aria-expanded="${!shut}"><span class="hs-title">${title}</span>${right}<span class="hs-chev" aria-hidden="true"></span></button>
    ${shut ? peek : body}
  </section>`;
}

function finishOnboarding() {
  S.setup = {};
  ensureAppData();
  tabTo("home");
}
function setupDone(id) {
  if (S.setup) S.setup[id] = true;
  tabTo("home");
  if (!S.setup) return;
  const n = setupCount(), total = countedSteps().length;
  toast(n === total ? "All set up" : `${n} of ${total} done`);
}

// The kit is an add-on. Everything works in the app; the kit puts the jars on a shelf at home.
function kitSheet() {
  openSheet(`<h3>Do you have a Shoal kit?</h3>
    <p class="small">Shoal works fully in the app. The kit adds real jars and stones that glow at home, so the family can see the plan without picking up a phone.</p>
    <div class="kit-pitch">${familyJars({ act: false })}</div>
    <div class="actions col"><button class="btn-primary" data-act="kitYes">Yes, set it up</button><button class="btn-soft" data-act="kitNo">Not now, just the app</button></div>`);
}

/* ---------- Setup & first stone ---------- */

function firstTask() {
  if (!S.app.first) {
    const yours = active().filter((t) => t.who === "you");
    const pick = yours.find(isUrgent) || yours[0] || active()[0];
    S.app.first = pick?.id || null;
  }
  return S.tasks.find((t) => t.id === S.app.first);
}

SCREENS.ready = () => {
  const helpers = S.people.filter((p) => p.tier === "main").length;
  const steps = [["Set up the jars", "One per person, about a minute"], ["Pair your first stone", "Tap it to one of your tasks"], ["Try it out", "Find a stone and see the glow"]];
  return `${setupTop(0)}
  <div class="content">
    <p class="eyebrow">Setup · about 5 minutes</p>
    <h1 class="title">Your plan is ready</h1>
    <p class="sub">${active().length} tasks, shared by ${helpers} of you. Next, set up the jars and pair your first stone.</p>
    <div class="shelf">${familyJars({ act: false })}</div>
    <div class="card steps-list">${steps.map(([t, d], i) => `<div class="step"><span class="num">${i + 1}</span><span><b>${t}</b><small>${d}</small></span></div>`).join("")}</div>
  </div>
  ${solo("Start setup", "setupNext", ["Do it later", "tab", 'data-to="home"'])}`;
};

SCREENS.jars = () => {
  const main = S.people.filter((p) => p.tier === "main");
  const others = S.people.filter((p) => p.tier !== "main");
  const steps = [["Plug in the base", "It powers the jars and charges spare stones"], ["Snap on one jar per person", "Use only as many as you need"], ["Write a name on each lid", listNames(main)]];
  return `${setupTop(1)}
  <div class="content">
    <p class="eyebrow">Step 1 of 8</p>
    <h1 class="title">Set up the jars</h1>
    <p class="sub">One jar for each person who takes on tasks.${others.length ? ` ${esc(listNames(others))} can follow along without one.` : ""}</p>
    <div class="shelf">${familyJars({ empty: true, act: false })}</div>
    <div class="card steps-list">${steps.map(([t, d], i) => `<div class="step"><span class="num">${i + 1}</span><span><b>${t}</b><small>${esc(d)}</small></span></div>`).join("")}</div>
  </div>
  ${solo("The jars are on", "setupNext")}`;
};

SCREENS.pick = () => {
  const t = firstTask(), w = t?.w || 2;
  return `${setupTop(2)}
  <div class="content">
    <p class="eyebrow">Step 2 of 8 · First stone</p>
    <h1 class="title">Pick up a ${sizeName(w)} stone</h1>
    <p class="sub">${t ? `“${esc(t.n)}” is a ${sizeName(w)} task, so it gets a ${sizeName(w)} stone. ` : ""}Lift one from the round end of the base. It glows white when it's ready to pair.</p>
    <div class="stage-card tall">${gem("open", { size: "xl", cls: `breathe w${w}` })}<p class="cap">${WEIGHT_LABEL[w]} stone · white glow · ready to pair</p></div>
    <div class="card kit-sizes">${[1, 2, 3].map((k) => `<div class="${k === w ? "on" : ""}">${gem("open", { size: "s", cls: `w${k}` })}<b>${WEIGHT_LABEL[k]}</b><small>${S.stones.filter((x) => x.size === k).length} in the kit</small></div>`).join("")}</div>
  </div>
  ${solo("I've got one", "setupNext")}`;
};

SCREENS.hold = () => {
  const t = firstTask();
  return `${setupTop(3)}
  <div class="content">
    <p class="eyebrow">Step 3 of 8 · First stone</p>
    <h1 class="title">Hold it to your phone</h1>
    <p class="sub">Touch the stone to the back of your phone. This is the only screen that listens for stones, so nothing pairs by accident.</p>
    <div class="stage-card">
      ${gem(S.app.heard ? stateOf(t) : "open", { size: "l", dark: S.app.heard && t.kind === "repeat", cls: `${S.app.heard ? "" : "breathe"} w${t?.w || 2}` })}
      <span class="status-pill">${S.app.heard ? (() => { const st = stoneOf(t) || freeStone(t?.w); return `✓ Stone ${String(st?.id || 1).padStart(2, "0")} found · ${WEIGHT_LABEL[st?.size || 2]}`; })() : "<i></i> Listening for a stone…"}</span>
    </div>
    ${t ? `<div class="card pair-to"><p class="eyebrow grey">Pairing it to</p>${taskLine(t, { act: "noop" })}</div>` : ""}
  </div>
  ${solo("It's paired", "setupNext", ["Stone not lighting up?", "toast", 'data-msg="Set it in a jar or on the base for 10 minutes, then try again"'], S.app.heard ? "" : "disabled")}`;
};

SCREENS.paired = () => {
  const t = firstTask();
  const st = stateOf(t);
  return `${setupTop(4)}
  <div class="content">
    <p class="eyebrow">Step 4 of 8 · First stone</p>
    <h1 class="title">Paired. Now drop it in your jar.</h1>
    <p class="sub">Your stone now glows ${STATE[st][1]} because ${st === "urgent" ? `the task is urgent. Once it's underway, it turns ${STATE.progress[1]}.` : st === "progress" ? `someone is on it. It turns ${STATE.urgent[1].replace("glowing ", "")} when it's due soon.` : "no one has it yet."}</p>
    <div class="stage-card tall"><span class="okdot"><img src="${A("check.svg")}" alt=""></span>${gemOf(t, { size: "xl", cls: "breathe" })}
      <span class="badge ${st === "urgent" ? "amber" : ""}">${STATE[st][0]} · ${STATE[st][1]}</span>
      <p class="cap">${esc(t.n)} · ${esc(nameOf(t.who))}</p>
    </div>
  </div>
  ${solo("It's in my jar", "setupNext")}`;
};

SCREENS.find = () => {
  const t = firstTask();
  const blinking = S.app.blink === t.id;
  return `${setupTop(5)}
  <div class="content">
    <p class="eyebrow">Step 5 of 8 · Try it</p>
    <h1 class="title">Find a stone</h1>
    <p class="sub">Tap Find stone on any task. Its stone blinks so you can spot it in the jar.</p>
    <div class="stage-card">${familyJars({ only: "you", act: false })}<span class="badge amber ${blinking ? "" : "ghost"}">Blinking</span></div>
    <div class="card pair-to">${taskLine(t, { act: "noop" })}<button class="btn-wide" data-act="findStone" data-id="${t.id}">Find stone</button></div>
    ${blinking ? `<p class="label">Did it blink?</p>` : ""}
  </div>
  ${blinking ? duo(["Not yet", "toast", 'data-msg="Lift the lid and look again. It blinks for 30 seconds."'], ["Yes, I see it", "setupNext"]) : solo("Find stone", "findStone", null, `data-id="${t.id}"`)}`;
};

SCREENS.glow = () => `${setupTop(6)}
  <div class="content">
    <p class="eyebrow">Step 6 of 8 · Try it</p>
    <h1 class="title">What the glow means</h1>
    <p class="sub">Every stone tells you where its task stands, right from the jar.</p>
    <div class="glow-grid">${Object.entries(STATE).map(([s, [n, , d]]) => `<div class="card glow-tile">${gem(s, { size: "m" })}<b class="st-${s}">${n}</b><small>${d}</small></div>`).join("")}</div>
    <div class="card kinds">
      <div>${gem("open", { size: "s" })}<span><b>Light stone</b><small>One-time task</small></span></div>
      <div>${gem("open", { size: "s", dark: true })}<span><b>Dark stone</b><small>Ongoing task</small></span></div>
      <p class="small">Both kinds glow the same colors.</p>
    </div>
    <div class="card kinds marks">
      <div>${gem("urgent", { size: "s" })}<span><b>! means urgent</b><small>At home, urgent stones pulse</small></span></div>
      <div>${gem("open", { size: "s" })}<span><b>Dashed ring</b><small>No one has it yet</small></span></div>
      <div>${gem("done", { size: "s" })}<span><b>Grey and plain</b><small>Done, light off</small></span></div>
      <p class="small">In the app, urgent and unclaimed stones carry a mark too, so you never have to tell colors apart.</p>
    </div>
    <div class="card kinds sizes">
      ${[1, 2, 3].map((w) => `<div><span class="kind-stone">${gem("open", { size: "s", cls: `w${w}` })}</span><span><b>${WEIGHT_LABEL[w]} stone</b><small>${SIZE_HINT[w]}</small></span></div>`).join("")}
      <p class="small">A full jar of big stones means someone's carrying a lot.</p>
    </div>
    <button class="btn-wide" data-act="colorSheet">Choose your own colors</button>
  </div>
  ${solo("Next", "setupNext")}`;

SCREENS.charge = () => `${setupTop(7)}
  <div class="content">
    <p class="eyebrow">Step 7 of 8 · Try it</p>
    <h1 class="title">Stones charge in the jar</h1>
    <p class="sub">The jars sit on the base, so every stone charges while it's in a jar. Spare stones charge on the round end. You never have to move a stone just to charge it.</p>
    <div class="stage-card">
      <div class="base"><i></i><i></i><i></i><b>${gem("open", { size: "s" })}</b></div>
      <div class="base-caps"><small class="blue">Jars charge here</small><small class="blue">Spares charge here</small></div>
      <div class="fade-row"><span>${gem("done", { size: "m", cls: "faded" })}<small>Left out, it fades</small></span><span class="arrow">→</span><span>${gem("open", { size: "m" })}<small>Back in a jar</small></span></div>
    </div>
    <p class="small center">If a stone stays out, like on a table, we'll let you know before it runs low.</p>
  </div>
  ${solo("Got it", "setupNext")}`;

SCREENS.pairRest = () => {
  const paired = S.stones.filter((s) => s.task).length;
  const list = active().filter((t) => t.who).sort((a, b) => (a.who === "you" ? -1 : 0) - (b.who === "you" ? -1 : 0));
  const shown = S.app.morePair ? list : list.slice(0, 5);
  return `${setupTop(8)}
  <div class="content">
    <p class="eyebrow">Step 8 of 8 · Almost done</p>
    <h1 class="title">Pair the rest</h1>
    <p class="sub">Each task takes a stone its size: S, M or L. Pair them now, or anyone can pair their own later.</p>
    <div class="card meter"><div class="meter-top"><b>${paired} of ${KIT} paired</b><span class="small">${KIT - paired} to go</span></div><div class="bar"><i style="width:${(paired / KIT) * 100}%"></i></div></div>
    <div class="card tlist">${shown.map((t) => taskLine(t, {
      act: "noop",
      trail: stoneOf(t) ? `<span class="paired-tag">✓ Paired</span>` : `<button class="pill-btn" data-act="pairTask" data-id="${t.id}" aria-label="Pair a ${sizeName(t.w || 2)} stone">Pair ${WEIGHT_LABEL[t.w || 2][0]}</button>`,
    })).join("")}
    ${list.length > 5 ? `<button class="more" data-act="morePair">${S.app.morePair ? "Show fewer" : `+ ${list.length - 5} more tasks`}${chev}</button>` : ""}</div>
  </div>
  ${solo("Go to Home", "finishStones", ["Do this later", "tab", 'data-to="home"'])}`;
};

/* ---------- Home ---------- */

// How much the family has on each day this week. Tap a bar to see that day's tasks.
function loadChart(week) {
  const days = DAYS.map((d, i) => {
    const date = fromIso(shift(week, i)), id = iso(date);
    const list = active().filter((t) => occurs(t, date));
    return { d, date, id, n: list.length, urgent: list.some((t) => isUrgent(t) && t.date === id) };
  });
  const max = Math.max(1, ...days.map((x) => x.n));
  const heavy = days.reduce((a, b) => (b.n > a.n ? b : a));
  return `<div class="load-chart">${days.map((x) => `<button class="lc-day ${x.id === S.app.day ? "on" : ""} ${x.id === iso(TODAY) ? "today" : ""} ${heavy.n && x.n === heavy.n ? "heavy" : ""}" data-act="homeDay" data-id="${x.id}"
      aria-pressed="${x.id === S.app.day}" aria-label="${DAY_FULL[dayKey(x.date)]} ${x.date.getDate()}, ${x.n} task${x.n === 1 ? "" : "s"}${x.urgent ? ", one is urgent" : ""}">
      <span class="lc-col">${x.urgent ? gem("urgent", { size: "xs" }) : ""}<span class="lc-bar" style="height:${Math.max(8, Math.round((x.n / max) * 84))}px"></span></span>
      <small>${x.d[0]}</small><b>${x.date.getDate()}</b></button>`).join("")}</div>
    <p class="lc-cap">${heavy.n ? `${DAY_FULL[dayKey(heavy.date)]} is the heavy day · ${heavy.n} tasks` : "A light week"}</p>`;
}

SCREENS.home = () => {
  const urgent = active().filter(isUrgent).sort((a, b) => a.date.localeCompare(b.date));
  const finished = S.tasks.find((t) => t.done && t.doneAt && t.who !== "you" && !S.app.thanked[t.id] && !S.app.dismissed[t.id]);
  const week = mondayOf(iso(TODAY));
  const day = fromIso(S.app.day);
  const today = active().filter((t) => occurs(t, day)).sort((a, b) => (a.time || "99").localeCompare(b.time || "99"));
  return `<div class="content app">
    <div class="apphead">${shoalMark(30)}<span class="head-btns">
      ${hasKit() ? `<button class="bell" data-act="go" data-to="kit" aria-label="Home kit">${icon("kit")}${notCharging().length && (!S.setup || S.setup.stones) ? `<i class="dot warn"></i>` : ""}</button>` : ""}
      <button class="bell" data-act="go" data-to="notifications" aria-label="Notifications">${icon("bell")}${unread() ? `<i class="dot"></i>` : ""}</button></span></div>
    <p class="eyebrow grey">${TODAY.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}</p>
    <h1 class="title">Good morning</h1>
    ${setupCard()}
    ${urgent.length ? `<button class="card attention" data-act="openTask" data-id="${urgent[0].id}">${gemOf(urgent[0], { size: "m" })}
        <span class="tl-txt"><span class="n">${esc(urgent[0].n)}</span><span class="m"><b class="st-urgent">Urgent</b> · ${dueLabel(urgent[0])} · ${esc(nameOf(urgent[0].who))}</span></span>
        ${urgent.length > 1 ? `<span class="count">+${urgent.length - 1}</span>` : chev}
      </button>` : ""}
    ${finished ? `<div class="finished">${avatar(person(finished.who), "s20")}<span class="fin-txt"><b>${esc(person(finished.who).name)}</b> finished “${esc(finished.n)}”</span>
      <button class="linkish" data-act="sayThanks" data-id="${finished.id}">Thank</button><button class="x-btn" data-act="dismissThanks" data-id="${finished.id}" aria-label="Dismiss"><span aria-hidden="true">×</span></button></div>` : ""}
    ${pebbleHomeCard()}
    ${homeSec("jars", "Family jars", "", `<div class="shelf">${familyJars()}</div>`)}
    ${homeSec("week", "This week", "", `<div class="card week">
      ${active().length ? `${loadChart(week)}
      <div class="tlist flat">${today.length ? today.map((t) => taskLine(t)).join("") : `<p class="small empty">Nothing on ${DAY_FULL[dayKey(day)]}.</p>`}</div>`
        : `<p class="small empty">No tasks yet. Once you add some, your family's week shows here.</p>`}
    </div>`)}
  </div>
  ${tabbar()}`;
};

/* ---------- My jar ---------- */

// Completion ring: done (blue), urgent (yellow), still to do (grey), one gap between each.
function ring(segs, { size = 220, stroke = 12 } = {}) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r, total = segs.reduce((n, x) => n + x.v, 0) || 1;
  const gap = segs.filter((x) => x.v).length > 1 ? 6 : 0;
  let at = 0;
  return `<svg class="ring-svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true">
    <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="rgba(110,115,124,0.13)" stroke-width="${stroke}"/>
    ${segs.filter((x) => x.v).map((x) => {
      const len = Math.max(0, (x.v / total) * c - gap);
      const el = `<circle class="ring-seg" cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${x.color}" stroke-width="${stroke}" stroke-linecap="round"
        stroke-dasharray="${len} ${c}" stroke-dashoffset="${-at}" transform="rotate(-90 ${size / 2} ${size / 2})"/>`;
      at += (x.v / total) * c;
      return el;
    }).join("")}
  </svg>`;
}

const jarOrder = (t) => (isUrgent(t) ? 0 : t.kind === "once" ? 1 : 2);
function jarMeta(t) {
  if (isUrgent(t)) return `<span class="st-urgent">${dueLabel(t)[0].toUpperCase()}${dueLabel(t).slice(1)}</span>`;
  return t.kind === "once" ? fmtDate(t.date) : repeatLabel(t.days);
}

SCREENS.myjar = () => {
  const all = mine("you");
  const live = all.filter((t) => !t.done);
  const done = all.filter((t) => t.done);
  const urgent = live.filter(isUrgent);
  // "Today" counts what happens today plus anything urgent that needs attention now.
  const today = live.filter((t) => occurs(t, TODAY) || isUrgent(t)).length;
  const tab = S.app.jarTab;
  const shown = live.filter((t) => tab === "all" || t.kind === tab).sort((a, b) => jarOrder(a) - jarOrder(b) || (a.date || "").localeCompare(b.date || ""));
  const count = (k) => live.filter((t) => k === "all" || t.kind === k).length;
  return `<div class="content app">
    <div class="apphead"><h1 class="title">Your jar</h1><button class="round-btn" data-act="newTask" aria-label="Add a task"><img src="${A("plus.svg")}" alt=""></button></div>
    <section class="jar-free" aria-label="Your jar">${familyJars({ only: "you", act: false })}</section>
    <div class="jh-stats">
      <span><b>${today}</b> today</span><span><b class="st-urgent">${urgent.length}</b> urgent</span><span><b>${live.length}</b> left</span>
    </div>
    ${S.app.prefs.ring ? `<div class="card jar-hero"><div class="jh-ring" role="img" aria-label="${done.length} of ${all.length} done, ${urgent.length} urgent, ${today} for today">
        ${ring([{ v: done.length, color: "#418ef3" }, { v: urgent.length, color: urgentHex() }, { v: live.length - urgent.length, color: "transparent" }], { size: 150, stroke: 10 })}
        <div class="ring-mid"><b>${done.length}<small>/${all.length}</small></b><span>done</span></div>
      </div></div>` : `<div class="card jar-check">${checkIn()}</div>`}
    <div class="card jar-list">
      <div class="utabs" role="tablist">${[["all", "All"], ["once", "One-time"], ["repeat", "Ongoing"]].map(([id, l]) => `<button role="tab" class="${tab === id ? "on" : ""}" aria-selected="${tab === id}" data-act="jarTab" data-id="${id}">${l}<small>${count(id)}</small></button>`).join("")}</div>
      ${tab !== "repeat" && S.app.checkin === "break" && !S.app.heldOpen && S.app.requests.length ? `<button class="jl-req held" data-act="showHeld"><span class="tl-txt"><span class="eyebrow">On hold till Sunday</span><span class="n">${S.app.requests.length} ask${S.app.requests.length === 1 ? "" : "s"} waiting</span></span><span class="linkish">See</span></button>` : ""}
      ${tab !== "repeat" && (S.app.checkin !== "break" || S.app.heldOpen) ? S.app.requests.map((r) => `<div class="jl-req"><span class="tl-txt"><span class="eyebrow">Request from ${esc(nameOf(r.from))}</span><span class="n">${esc(r.n)}</span></span><button class="linkish" data-act="review" data-id="${r.id}">Review</button></div>`).join("") : ""}
      ${shown.map((t) => taskLine(t, { meta: jarMeta(t), trail: `<button class="tick" data-act="markDone" data-id="${t.id}" aria-label="Mark ${esc(t.n)} done">${check(false)}</button>` })).join("")}
      ${!shown.length ? `<p class="small empty">Nothing here. Tap + to add a task.</p>` : ""}
    </div>
    ${done.length ? `<button class="collapsed" data-act="showDone" aria-expanded="${!!S.app.showDone}">Done · ${done.length}<img src="${A("chevron.svg")}" alt="" style="transform:rotate(${S.app.showDone ? 90 : 0}deg)"></button>
      ${S.app.showDone ? `<div class="card tlist">${done.map((t) => taskLine(t, { showWho: false, meta: "Done" })).join("")}</div>` : ""}` : ""}
  </div>
  ${tabbar()}`;
};

/* ---------- Task detail ---------- */

const curTask = () => S.tasks.find((t) => t.id === S.app.task);
// "Bill", "Bill and Sam", "Bill, Sam and Nora"
const namesList = (ids) => { const n = ids.map(nameOf); return n.length < 2 ? n.join("") : `${n.slice(0, -1).join(", ")} and ${n[n.length - 1]}`; };
// Who a hand-off went to (one person or several), and who said yes.
const handTargets = (h) => [].concat(h.to);
const handWho = (h) => h.taker || handTargets(h)[0];

function handoffCard(t) {
  const h = t.handoff;
  if (!h) return "";
  const ids = handTargets(h), many = ids.length > 1;
  const to = person(handWho(h)) || { name: "Someone" };
  const body = {
    pending: [many ? (h.all ? "Asked everyone who can" : `Asked ${namesList(ids)}`) : `Waiting on ${to.name}`,
      h.pebbleFollow ? `${nameOf(h.pebbleFollow.prev)} didn't answer by ${whenWord(h.pebbleFollow.when)}, so Pebble asked ${to.name} (you said it could).` : h.follow ? `If no one says yes by ${whenWord(h.follow.when)}, Pebble asks ${nameOf(h.follow.who)} next. Everyone can see it's being handed off.` : many ? "The first to say yes takes it. Everyone can see it's being handed off." : "Everyone can see it's being handed off.", `<button class="linkish" data-act="cancelHandoff">Cancel</button>`],
    accepted: [`${to.name} said yes`, `${h.when} · it's in ${possessive(to)} jar now${many ? ". The others were told it's covered." : ""}${h.pebbleFollow ? ` · after ${nameOf(h.pebbleFollow.prev)} didn't answer, Pebble asked ${to.name} (you said it could)` : ""}`, ""],
    declined: [`${to.name} can't take it`, `“${h.why}”`, `<button class="pill-btn" data-act="handoff">Ask someone else</button>`],
  }[h.status];
  const pic = h.status === "pending" && many ? `<span class="stack hand-stack">${ids.slice(0, 3).map((id) => avatar(person(id) || { name: "?" }, "s24")).join("")}</span>` : avatar(to, "s36");
  return `<div class="card hand-card ${h.status}">${pic}<span class="tl-txt"><span class="n">${esc(body[0])}</span><span class="m">${esc(body[1])}</span></span>${body[2]}</div>`;
}

SCREENS.task = () => {
  const t = curTask();
  const p = t.who && person(t.who);
  const s = stoneOf(t);
  const st = stateOf(t);
  const stepsDone = t.steps.filter((x) => x.done).length;
  return `${navtop("Back", `<button class="more-btn" data-act="taskMenu" aria-label="More">•••</button>`)}
  <div class="content">
    <div class="badges"><span class="badge plain">${t.kind === "once" ? "One-time" : "Ongoing"}</span>
      ${t.y ? "" : `<button class="badge plain" data-act="sizeSheet" data-id="${t.id}" aria-label="Size: ${WEIGHT_LABEL[t.w || 2]}. Change size">${WEIGHT_LABEL[t.w || 2]}</button>`}
      <button class="badge ${st === "urgent" ? "amber" : ""}" data-act="editTaskDate">${st === "urgent" ? gem("urgent", { size: "xs" }) : ""}${t.kind === "once" ? `Due ${fmtDate(t.date)}` : repeatLabel(t.days)}${t.time ? ` · ${fmtTime(t.time)}` : ""}</button>
      ${t.remote ? `<span class="badge plain">Remote OK</span>` : ""}</div>
    <h1 class="title">${esc(t.n)}</h1>
    <div class="card owner">${p ? avatar(p) : `<img class="none" src="${A("none.svg")}" alt="">`}
      <span class="tl-txt"><span class="n">${p ? esc(p.name) : "Unassigned"}</span><span class="m">${t.done ? "Done · stone resting" : `Stone glows ${STATE[st][1]}`}</span></span>
      ${gemOf(t, { size: "s" })}
      ${hasKit() && s && !t.done ? `<button class="pill-btn" data-act="findStone" data-id="${t.id}">Find</button>` : ""}
    </div>
    ${medCard(t)}
    ${handoffCard(t)}
    ${t.steps.length ? `<div class="card stepsc">
      <div class="meter-top"><b>Steps</b><span class="small">${stepsDone} of ${t.steps.length}</span></div>
      <div class="bar"><i style="width:${(stepsDone / t.steps.length) * 100}%"></i></div>
      ${t.steps.map((x, i) => `<div class="stp">
        <button data-act="toggleStep" data-id="${i}" aria-label="Toggle step">${check(x.done, true)}</button>
        <span class="tl-txt"><span class="n">${esc(x.n)}</span><span class="m">${x.who ? `${esc(nameOf(x.who))}${x.done ? ` · ${x.when || "Today"}` : " is on it"}` : x.ask ? `Asked ${esc(namesList(x.ask))}` : "Open"}</span></span>
        ${x.who && x.who !== "you" ? avatar(person(x.who) || { name: "?" }, "s20") : !x.who && !x.ask ? `<span class="stp-acts"><button class="linkish" data-act="takeStep" data-id="${i}">Take step</button><button class="linkish" data-act="askStep" data-id="${i}">Ask</button></span>` : ""}
      </div>`).join("")}
    </div>` : ""}
    ${t.notes ? `<div class="card notes-card"><p class="eyebrow grey">Notes</p><p>${pebbleTerms(t.notes)}</p><span class="small">Added by you${pebbleOn() && HAS_TERM.test(t.notes) ? " · tap an underlined word to explain it" : ""}</span></div>` : ""}
    ${typeof nurseQsCard === "function" ? nurseQsCard(t) : ""}
    ${pebbleTaskHelp(t)}
  </div>
  ${t.done ? solo("Mark not done", "undoDone", null, `data-id="${t.id}"`) : duo(["Hand off", "handoff"], ["Mark done", "markDone", `data-id="${t.id}"`])}`;
};

SCREENS.handoff = () => {
  const t = curTask(), step = t.steps[S.app.handStep];
  const options = S.people.filter((p) => p.id !== t.who);
  const able = options.filter((p) => canTake(p, t));
  const to = S.app.handTo; // undefined = nothing picked, null = unassigned, else a list of ids
  const picked = Array.isArray(to) ? to : [];
  const all = able.length > 1 && able.every((p) => picked.includes(p.id));
  const target = picked.length === 1 ? person(picked[0]) : null;
  const texts = picked.filter((id) => person(id)?.tier !== "main" || person(id)?.via === "text").length;
  const label = to === undefined || (Array.isArray(to) && !picked.length) ? "Pick someone"
    : to === null ? "Leave it unassigned"
    : target ? `Send request to ${esc(target.name)}`
    : all ? "Ask everyone" : `Ask ${picked.length} people`;
  return `${navtop("Back")}
  <div class="content">
    <h1 class="title">${step ? "Ask for help with a step" : t.who ? "Hand it off" : "Find someone"}</h1>
    <p class="sub">${step ? `Just “${esc(step.n)}”. The rest of the task stays with ${t.who === "you" ? "you" : esc(nameOf(t.who))}.` : "Ask one person, a few, or everyone. The first to say yes takes it, and the task moves to their jar."}</p>
    <div class="card pair-to">${taskLine(t, { act: "noop" })}</div>
    ${typeof pebbleHandPick === "function" ? pebbleHandPick(t) : ""}
    <div class="card tlist pick-list">
      ${able.length > 1 ? `<button class="radio-row" data-act="handTo" data-id="all"><span class="stack hand-stack">${able.slice(0, 3).map((p) => avatar(p, "s24")).join("")}</span>
        <span class="tl-txt"><span class="n">Everyone who can</span><span class="m">${able.length} people · first yes takes it</span></span>${check(all, true)}</button>` : ""}
      ${options.map((p) => {
        const ok = canTake(p, t);
        const n = mine(p.id).filter((x) => !x.done).length;
        return `<button class="radio-row" data-act="handTo" data-id="${p.id}" ${ok ? "" : "disabled"}>${avatar(p, "s36")}
          <span class="tl-txt"><span class="n">${esc(p.name)}</span><span class="m">${ok ? `${n} task${n === 1 ? "" : "s"}${p.remote ? " · remote" : ""}${p.tier === "trusted" ? " · gets a text" : ""}` : p.tier === "kid" ? "Kid tasks only" : "Light tasks only"}</span></span>
          ${check(picked.includes(p.id), true)}</button>`;
      }).join("")}
      ${t.who && !step ? `<button class="radio-row" data-act="handTo" data-id="">${gem("open", { size: "s" })}<span class="tl-txt"><span class="n">Unassigned</span><span class="m">Glows white for whoever is free</span></span>${check(to === null)}</button>` : ""}
    </div>
    <p class="label hand-note">Note <span class="small">optional</span>${pebbleOn() && !S.app.notePebble ? `<button class="peb-chip sm" data-act="pebbleNote">Write it for me</button>` : ""}</p>
    <textarea class="note-input" data-input="handoffNote" placeholder="Anything they should know?">${esc(S.app.note)}</textarea>
    ${typeof pebbleFollowRow === "function" ? pebbleFollowRow(t) : ""}
    ${target ? `<p class="small" style="text-align:center">We'll ${target.tier === "main" && target.via !== "text" ? "send it to the app" : "text"} ${esc(target.name)}.</p>`
      : picked.length > 1 ? `<p class="small" style="text-align:center">${esc(namesList(picked))} each get the request${texts ? ` (${texts === 1 ? "one gets a text" : `${texts} get a text`})` : ""}. Once someone says yes, the rest are told it's covered.</p>` : ""}
  </div>
  ${solo(label, "sendHandoff", null, label === "Pick someone" ? "disabled" : "")}`;
};

/* ---------- Add a task ---------- */

const draft = () => S.tasks.find((t) => t.id === S.app.draft);
// Which kinds of helper a task is open to. Until someone picks, it follows the usual rule: trusted circle for small jobs, kids for kid tasks.
const OPEN_TIERS = [["main", "Main caregivers"], ["trusted", "Trusted circle"], ["kid", "Kids & teens"]];
const openTo = (t) => t.open || ["main", ...(t.w === 1 ? ["trusted"] : []), ...(t.y ? ["kid"] : [])];
function remoteNote(t) {
  const far = S.people.filter((p) => p.remote && openTo(t).includes(p.tier)).map((p) => p.id);
  if (!far.length) return "Phone calls, forms, ordering online";
  return t.remote ? `${namesList(far)} can take it too` : `Lets ${namesList(far)} take it from afar`;
}

SCREENS.newTask = () => {
  const t = draft();
  const helpers = S.people;
  return `${navtop("Cancel")}
  <div class="content">
    <h1 class="title">New task</h1>
    <label class="nt-label" for="draftName">What needs doing?</label>
    <input class="nt-input" id="draftName" data-input="draftName" value="${esc(t.n)}" placeholder="e.g. Pick up shower chair" ${t.n ? "" : "autofocus"}>
    <div class="seg big">${[["once", "One-time"], ["repeat", "Ongoing"]].map(([k, l]) => `<button class="${t.kind === k ? "on" : ""}" aria-pressed="${t.kind === k}" data-act="draftKind" data-id="${k}">${l}</button>`).join("")}</div>
    <button class="card field-row" data-act="editDraftDate"><span>${t.kind === "once" ? "Due date" : "Repeats"} <em>Required</em></span><b>${t.kind === "once" ? fmtDate(t.date) : repeatLabel(t.days)}${t.time ? ` · ${fmtTime(t.time)}` : ""}</b>${chev}</button>
    <button class="card field-row" data-act="sizeSheet" data-id="${t.id}"><span class="fr-txt">Stone size <em>${t.sizeSet || !t.n.trim() || !pebbleOn() ? "" : "Pebble's guess"}</em><small>Bigger stone, bigger job</small></span>${gem("open", { size: "xs", cls: `w${t.w}` })}<b data-size-label>${WEIGHT_LABEL[t.w]}</b>${chev}</button>
    <div data-peb-split>${typeof pebbleSplitBlock === "function" ? pebbleSplitBlock(t) : ""}</div>
    <p class="section-h">Who can help</p>
    <div class="card nt-open">
      <div class="chips">${OPEN_TIERS.map(([k, l]) => `<button class="chip ${openTo(t).includes(k) ? "on" : ""}" aria-pressed="${openTo(t).includes(k)}" data-act="draftOpen" data-id="${k}">${l}</button>`).join("")}</div>
      <div class="srow"><span class="tl-txt"><span class="n">Can be done from anywhere</span><span class="m">${remoteNote(t)}</span></span>${toggle(t.remote, "draftRemote", "", "Can be done from anywhere")}</div>
    </div>
    <p class="section-h">Who takes it</p>
    <div class="card who-card"><div class="pickers wrap">
      ${helpers.map((p) => `<button class="pick ${t.who === p.id ? "on" : ""}" data-act="draftWho" data-who="${p.id}" ${canTake(p, t) && (t.remote || !p.remote) ? "" : "disabled style=\"opacity:.35\""}>
        <span class="ringwrap">${avatar(p, "s36")}<img class="ring" src="${A("selected-ring.svg")}" alt=""></span>${esc(p.name)}</button>`).join("")}
      <button class="pick ${!t.who ? "on" : ""}" data-act="draftWho" data-who=""><span class="ringwrap"><img class="none" src="${A("none.svg")}" alt=""><img class="ring" src="${A("selected-ring.svg")}" alt=""></span>Open</button>
    </div></div>
    <p class="section-h">Notes</p>
    <textarea class="note-input" data-input="draftNote" placeholder="Add a note (optional)">${esc(t.notes)}</textarea>
  </div>
  ${solo("Save task", "saveTask", null, t.n.trim() ? "" : "disabled")}`;
};

SCREENS.newStone = () => {
  const t = S.tasks.find((x) => x.id === S.app.stoneFor);
  return `${navtop("Back")}
  <div class="content">
    <h1 class="title">Link a real stone</h1>
    <p class="sub">Optional. The task already has a stone in the app. Link a real one and it lights up in the jar at home too.</p>
    <div class="stage-card tall">
      ${gem(S.app.heard ? stateOf(t) : "open", { size: "l", dark: t.kind === "repeat", cls: `${S.app.heard ? "" : "breathe"} w${t.w || 2}` })}
      <p class="n" style="margin:4px 0 0">${S.app.heard ? `Stone ${String(freeStone(t.w)?.id || 0).padStart(2, "0")} found · ${WEIGHT_LABEL[freeStone(t.w)?.size || 2]}` : `Hold a ${sizeName(t.w || 2)} stone to your phone`}</p>
      <span class="small">${S.app.heard ? `It will glow ${STATE[stateOf(t)][1]}` : "Looking for a stone…"}</span>
    </div>
    <div class="card pair-to">${taskLine(t, { act: "noop" })}</div>
  </div>
  ${duo(["Not now", "back"], ["Link it", "saveStone", S.app.heard ? "" : "disabled"])}`;
};

/* ---------- People ---------- */

SCREENS.peopleTab = () => {
  const main = S.people.filter((p) => p.tier === "main");
  const circle = S.people.filter((p) => p.tier !== "main");
  const all = S.tasks.filter((t) => t.on);
  const done = all.filter((t) => t.done).length;
  const open = active().filter((t) => !t.who).length;
  return `<div class="content app">
    <div class="apphead"><h1 class="title">People</h1><button class="btn-ghost sm" data-act="inviteSheet">+ Invite</button></div>
    <button class="sub linkline" data-act="go" data-to="recap">October · ${done} of ${all.length} tasks done together ›</button>
    ${pebbleMonthEntry()}
    <div class="shelf">
      <div class="shelf-top"><span class="eyebrow grey">Family jars</span>${open ? `<span class="small">${open} unassigned</span>` : ""}</div>
      ${familyJars()}
    </div>
    <div class="card tlist">${main.map((p) => {
      const ts = mine(p.id), d = ts.filter((t) => t.done).length;
      if (pending(p)) return `<button class="prow" data-act="pendingSheet" data-id="${p.id}">${avatar(p, "s36 pending")}
        <span class="tl-txt"><span class="n">${esc(p.name)}</span><span class="m">${viaShort(p)} · ${ts.length} task${ts.length === 1 ? "" : "s"} waiting</span></span>
        <span class="badge plain">Pending</span>${chev}</button>`;
      return `<button class="prow" data-act="openPerson" data-id="${p.id}">${avatar(p, "s36")}
        <span class="tl-txt"><span class="n">${esc(p.name)}</span><span class="m">${p.remote ? "Remote · " : ""}${d} of ${ts.length} done</span></span>
        <span class="mini-bar"><i style="width:${ts.length ? (d / ts.length) * 100 : 0}%"></i></span>${chev}</button>`;
    }).join("")}</div>
    <p class="section-h">Extended circle</p>
    <div class="card tlist">
      <button class="prow" data-act="toast" data-msg="Trusted circle gets light tasks and a text when one opens up">
        <span class="circle-ico">${icon("peopleTab")}</span>
        <span class="tl-txt"><span class="n">Trusted circle</span><span class="m"><span class="stack">${circle.slice(0, 4).map((p) => avatar(p, "s20")).join("")}</span>${circle.length ? `${esc(circle[0].name)}${circle.length > 1 ? ` + ${circle.length - 1} other${circle.length > 2 ? "s" : ""}` : ""} · ` : "No one yet · "}${((n) => `${n} task${n === 1 ? "" : "s"}`)(circle.reduce((n, p) => n + mine(p.id).length, 0))}</span></span>
        <span class="badge">On</span>${chev}</button>
      ${stageOf() === "final" || S.app.demo ? `<button class="prow" data-act="roleGo" data-to="asNurse"><span class="avatar s36">A</span><span class="tl-txt"><span class="n">Hospice nurse</span><span class="m">Ana · see what she sees</span></span>${chev}</button>` : ""}
      <button class="prow" data-act="go" data-to="care"><span class="circle-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${RES_ICON.heart}</svg></span><span class="tl-txt"><span class="n">${esc(possessive({ name: L() }))} care</span><span class="m">Meds, allergies, needs and preferences</span></span>${chev}</button>
      <button class="prow" data-act="go" data-to="resources"><span class="circle-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${RES_ICON.phone}</svg></span><span class="tl-txt"><span class="n">Help and resources</span><span class="m">Hospice line, social worker, grief support</span></span>${chev}</button>
      <button class="prow" data-act="go" data-to="volunteerCode"><span class="circle-ico"><img src="${A("lock.svg")}" alt=""></span><span class="tl-txt"><span class="n">Volunteer code</span><span class="m">${S.app.prefs.publicCode ? `On · code ${PUBLIC_CODE}` : "Let neighbors and friends help from anywhere"}</span></span><span class="badge ${S.app.prefs.publicCode ? "" : "plain"}">${S.app.prefs.publicCode ? "On" : "Off"}</span>${chev}</button>
    </div>
  </div>
  ${tabbar()}`;
};

SCREENS.person = () => {
  const p = person(S.app.person);
  const ts = mine(p.id).filter((t) => !t.done);
  return `${navtop("People")}
  <div class="content">
    <div class="phead">${avatar(p, "lg")}<h1 class="title">${esc(p.name)}</h1></div>
    <p class="sub">${p.about ? esc(p.about.trim() === "Lives with" ? `Lives with ${L()}` : p.about) : p.tier === "trusted" ? "Trusted circle, light tasks" : p.tier === "kid" ? "Kid tasks, never urgent" : "Main caregiver"}</p>
    ${personGlance(p, ts)}
    <p class="section-h">Their tasks, and why</p>
    <div class="card tlist">${ts.length ? ts.map((t) => taskLine(t, {
      meta: `${avatar(p, "s20")} ${esc(p.name)} · ${dueLabel(t)}</span><span class="why">Why: ${esc(whyOf(t, p))}`,
    })).join("") : `<p class="small empty">Nothing on ${esc(p.name)}'s plate right now.</p>`}</div>
    <div class="card info"><img src="${A("lock.svg")}" alt=""><span><b class="small-b">What Pebble used</b><span class="small">Everyone's answers and ${esc(L())}'s goals. Not notes or medical records.</span></span></div>
  </div>
  ${ts.length ? `<div class="footer"><button class="btn-ghost wide" data-act="moveTask">${p.id === "you" ? "Hand one of yours off" : `Move one of ${esc(p.name)}'s tasks`}</button><p class="small center pf-cap">${p.id === "you" ? "Ask someone else to take it." : `Ask someone else to take it, so ${esc(p.name)} has less to carry.`}</p></div>` : ""}`;
};

// What the rest of the family should know before asking this person for something.
function personGlance(p, ts) {
  const load = loadOf(p.id), f = p.cap ? Math.min(1, load / p.cap) : 0;
  const room = p.cap == null ? "" : `<div class="h-w pg-tile"><span class="k-lab">This week</span>
      <div class="h-num">${kitRing(f, 40, 5, load > p.cap ? "over" : "")}<b>${load}<small>of ${p.cap} hrs</small></b></div>
      <span class="k-note">${load > p.cap ? "More than they said they have" : `${p.cap - load} hr${p.cap - load === 1 ? "" : "s"} of room left`}</span></div>`;
  const best = p.best ? `<div class="h-w pg-tile"><span class="k-lab">Best time to ask</span><b class="k-big">${esc(p.best)}</b><span class="k-note">Prefers ${esc((p.reach || "the app").toLowerCase())}</span></div>` : "";
  const reach = p.id === "you" ? "" : `<div class="card pg-reach">${avatar(p, "s36")}<span class="tl-txt"><span class="n">${p.contact ? esc(p.contact) : "In Shoal"}</span><span class="m">${p.reach ? `${esc(p.reach)} works best` : "Gets asks in the app"}</span></span>
      ${p.contact ? `<button class="pill-btn" data-act="reachOut" data-id="text">Text</button><button class="pill-btn" data-act="reachOut" data-id="call">Call</button>` : ""}</div>`;
  const know = p.know?.length ? `<p class="section-h">Good to know</p><div class="card pg-know">${p.know.map((k) => `<p>${esc(k)}</p>`).join("")}</div>` : "";
  return `${room || best ? `<div class="k-grid pg-grid">${room}${best}</div>` : ""}${reach}${know}`;
}

/* ---------- Settings & stones ---------- */

SCREENS.settings = () => {
  const paired = S.stones.filter((s) => s.task).length;
  const row = (t, d, act, extra = "", attrs = "") => `<button class="srow" data-act="${act}" ${attrs}><span class="tl-txt"><span class="n">${t}</span><span class="m">${d}</span></span>${extra}${chev}</button>`;
  return `<div class="content app">
    <div class="apphead"><h1 class="title">Settings</h1></div>
    <div class="card account">${avatar(person("you"), "s36")}<span class="tl-txt"><span class="n">${esc(person("you").name)}</span><span class="m">${signedInAs()}</span></span></div>
    <p class="section-h">Family</p>
    <div class="card tlist">${row("Help and resources", "Hospice line, grief support, what to do after a death", "go", "", 'data-to="resources"')}${row("Care page lock", "PIN or Face ID · primary caregivers only", "careLockSheet")}${row("Family setup", "Redo with Pebble or by hand", "redoSetup")}</div>
    <p class="section-h">Together</p>
    <div class="card tlist">${row("Thank-yous &amp; recaps", "Weekly recap on Sundays", "go", "", 'data-to="recapSettings"')}${row("Notifications", "Urgent, requests, and thank-yous", "go", "", 'data-to="notifications"')}</div>
    <p class="section-h">My jar</p>
    <div class="card tlist"><div class="srow"><span class="tl-txt"><span class="n">Progress ring</span><span class="m">${S.app.prefs.ring ? "Shows how many of your tasks are done" : "Off · My jar asks how your week feels instead"}</span></span>${toggle(S.app.prefs.ring, "pref", "ring", "Progress ring")}</div></div>
    <p class="section-h">Stones</p>
    <div class="card tlist">${row("Stone colors", colorSummary(), "colorSheet")}${hasKit() ? row("Home kit", "Jars, stones, glow and battery", "go", "", 'data-to="kit"') : row("Home kit", "Not using one · add real jars and glowing stones", "kitSheet")}</div>
    <p class="section-h">Other views</p>
    <div class="card tlist">${row("See Shoal as someone else", "Nurse, trusted circle, kids, volunteers", "roleSheet")}${row("Take the tour again", "A quick look at each page", "tourStart")}</div>
    <p class="section-h">Pebble</p>
    <div class="card tlist"><div class="srow"><span class="tl-txt"><span class="n">Pebble suggestions</span><span class="m">${pebbleOn() ? "Suggests tasks and a fair split, notices what's slipping, writes the note when you ask for help" : "Off · you set things up by hand"}</span></span>${toggle(pebbleOn(), "pebbleToggle", "", "Pebble suggestions")}</div>
      ${row("What Pebble can see", "Answers, goals and what you tell it. No medical advice.", "pebbleSees")}
      ${pebbleOn() ? row("What Pebble did", PB().log.length ? `${PB().log.length} change${PB().log.length === 1 ? "" : "s"} · undo anything, in the Pebble tab` : "Nothing yet · it lives in the Pebble tab", "pebbleLogOpen") : ""}</div>
    <p class="section-h">Account</p>
    <div class="card tlist">${row("Sign out", "Back to the sign-in screen", "signOutSheet")}</div>
    <button class="btn-text center" data-act="restart">Restart prototype</button>
  </div>
  ${tabbar()}`;
};

/* ---------- Help and resources ---------- */

const RES_ICON = {
  phone: `<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>`,
  heart: `<path d="M12 19s-7-4.3-7-9.2A3.8 3.8 0 0 1 12 7.5a3.8 3.8 0 0 1 7 2.3C19 14.7 12 19 12 19z"/>`,
  person: `<circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/>`,
  home: `<path d="M4 11 12 4l8 7"/><path d="M6 10v10h12V10"/>`,
  coin: `<circle cx="12" cy="12" r="8"/><path d="M14.5 9.5c-.5-.9-1.5-1.3-2.5-1.3-1.4 0-2.5.8-2.5 1.9 0 2.6 5 1.4 5 4 0 1.1-1.1 1.9-2.5 1.9-1 0-2-.4-2.5-1.3M12 6.5v1.7M12 15.8v1.7"/>`,
};
const resIcon = (k) => `<span class="res-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${RES_ICON[k]}</svg></span>`;
const HOSPICE = { name: "Valley Hospice", line: "(408) 555-0142" };

// Each topic opens a short sheet: a few gentle lines in Shoal's words, then trusted outside sources
// for the full detail. The end-of-life topics stay folded behind a note until someone chooses to open them.
const RESOURCES = {
  grief: { title: "Grief support", sub: "Before and after, for everyone", icon: "heart",
    intro: "Grief often starts long before a death. Support is there for the whole family, now and later.",
    items: [
      `${HOSPICE.name} offers grief counselling to the family for about a year after a death, at no cost.`,
      "Rosa can point you to support groups nearby or online, and to counsellors who work with kids.",
      "If you or someone in the family is struggling to cope, you can call or text 988 any time.",
    ],
    links: [["988 Suicide & Crisis Lifeline", "Call or text 988, any time", "https://988lifeline.org"], ["CaringInfo", "Grief and caregiving guides from the national hospice association", "https://www.caringinfo.org"], ["The Dougy Center", "Support for children and teens who are grieving", "https://www.dougy.org"]] },
  money: { title: "Help paying for things", sub: "Benefits and local help", icon: "coin",
    intro: "Money worries are common and hard to bring up. Rosa can help you sort out what you might qualify for.",
    items: [
      "Medicare's hospice benefit usually covers the nurse, equipment, and comfort medicines.",
      "Veterans may be able to get help with burial costs.",
      "Some hospices and local charities have small funds for groceries, bills or travel.",
    ],
    links: [["Medicare: hospice care", "What the hospice benefit covers", "https://www.medicare.gov/coverage/hospice-care"], ["BenefitsCheckUp", "Find benefits you may qualify for, from the National Council on Aging", "https://www.benefitscheckup.org"], ["VA burial benefits", "For veterans and their families", "https://www.va.gov/burials-memorials/"]] },
  after: { title: "The days after", sub: "There's no rush. Nothing has to happen right away.", icon: "heart", gentle: true,
    intro: "When the time comes, the hospice nurse will be with you and will help with the first steps. You won't have to figure it out alone.",
    items: [
      "The nurse helps with the next steps and can call the funeral home you chose.",
      "The funeral home can help with the death certificate and with telling Social Security.",
      "When you're ready, one person can let everyone else know. Shoal can share it with the family.",
    ],
    links: [["USA.gov: when a loved one dies", "Plain-language checklist from the U.S. government", "https://www.usa.gov/death-loved-one"], ["Government death benefits", "Social Security and other benefits for survivors", "https://www.usa.gov/government-death-benefits"]] },
  funeral: { title: "Funeral home or cremation", sub: "Some families plan ahead. It's okay if you're not ready.", icon: "home", gentle: true,
    intro: "Thinking about this ahead of time can make things calmer later. Some families do it together, some ask one person to look into it.",
    items: [
      "You can call a few places and ask for their price list. You only pay for what you choose.",
      "There are many ways to say goodbye, simple or traditional. A memorial can be held any time.",
      `Once you choose a place, let ${HOSPICE.name} know.`,
    ],
    links: [["FTC: shopping for funeral services", "Your rights, and the questions to ask", "https://consumer.ftc.gov/articles/shopping-funeral-services"], ["Funeral Consumers Alliance", "A nonprofit guide to choices and costs", "https://funerals.org"]] },
};

SCREENS.resources = () => {
  const call = (n, m, icon, msg) => `<div class="srow">${resIcon(icon)}<span class="tl-txt"><span class="n">${n}</span><span class="m">${m}</span></span><button class="pill-btn" data-act="toast" data-msg="${msg}">Call</button></div>`;
  const row = (k) => `<button class="srow" data-act="resSheet" data-id="${k}">${resIcon(RESOURCES[k].icon)}<span class="tl-txt"><span class="n">${RESOURCES[k].title}</span><span class="m">${RESOURCES[k].sub}</span></span>${chev}</button>`;
  const open = S.app.resOpen;
  return `${navtop("Back")}
  <div class="content res-page">
    <h1 class="title">Help and resources</h1>
    <p class="sub">People to call, and trusted places to learn more. Everyone in the family sees this page.</p>
    <p class="section-h">Call any time</p>
    <div class="card tlist">
      ${call(HOSPICE.name, `${HOSPICE.line} · day or night`, "phone", `Calling ${HOSPICE.name} at ${HOSPICE.line}`)}
      ${call("Rosa, social worker", "Weekdays · money and paperwork", "person", "Calling Rosa at (408) 555-0167")}
      ${call("Ana, hospice nurse", "Visits Tuesday and Friday", "heart", "Calling Ana at (408) 555-0139")}
    </div>
    <p class="section-h">Support</p>
    <div class="card tlist">${row("grief")}${row("money")}</div>
    <p class="section-h">Planning ahead</p>
    ${open ? `<div class="card res-911">
        <h2>If ${esc(L())} dies at home, call hospice first, not 911.</h2>
        <p>Take the time you need. When you're ready, call ${HOSPICE.name} at <b>${HOSPICE.line}</b>. A nurse will come and help with what comes next.</p>
        <p class="res-why">Calling 911 can mean paramedics try to revive ${esc(L())}, which may go against ${esc(possessive({ name: L() }))} wishes.</p>
        <div class="res-actions"><button class="btn-soft" data-act="toast" data-msg="Calling ${HOSPICE.name} at ${HOSPICE.line}">Call hospice</button></div>
      </div>
      <div class="card tlist res-more">${row("after")}${row("funeral")}</div>
      <button class="btn-text center res-hide" data-act="resToggle">Fold this section away</button>`
    : `<div class="card res-gate">
        <p class="res-gate-k">A gentle note</p>
        <p>This part is about the end of life: what to do when ${esc(L())} dies, and planning a funeral. Open it when you feel ready. You can fold it away again any time.</p>
        <p class="small">Rosa can also walk the family through it, in person or on the phone.</p>
        <div class="res-actions"><button class="btn-soft" data-act="resToggle">Open this section</button><button class="btn-soft" data-act="toast" data-msg="Calling Rosa at (408) 555-0167">Talk to Rosa</button></div>
      </div>`}
  </div>`;
};

function signedInAs() {
  const a = S.auth || {};
  if (a.via === "google") return "Signed in with Google";
  if (a.via === "facebook") return "Signed in with Facebook";
  return a.phone ? `Signed in as +1 ${fmtPhone(a.phone)}` : "Signed in with your phone";
}

// The physical side: jars, base, stones and glow, one tap from Home.
SCREENS.kit = () => {
  const P = S.app.prefs, g = P.glow || "on";
  const main = S.people.filter((p) => p.tier === "main");
  const out = notCharging();
  const spares = S.stones.filter((s) => !s.out && !inJar(s));
  const jarRow = (p) => {
    const st = mine(p.id);
    return `<div class="srow kit-row">${avatar(p, "s36")}<span class="tl-txt"><span class="n">${p.id === "you" ? "Your jar" : `${esc(p.name)}'s jar`}</span><span class="m">${st.length} stone${st.length === 1 ? "" : "s"}</span></span><span class="charge">⚡ Charging</span></div>`;
  };
  return `${navtop("Home")}
  <div class="content">
    <h1 class="title">Home kit</h1>
    <div class="kit-hero">${familyJars({ act: false })}
      <div class="base-line"></div>
      <span class="badge ${out.length ? "amber" : ""}">${out.length ? `${out.length} stone off power` : "Base connected · everything charging"}</span>
    </div>
    ${out.map((st) => `<button class="card kit-alert" data-act="openStone" data-id="${st.id}">${gem(taskOf(st) ? stateOf(taskOf(st)) : "open", { size: "s", cls: "faded" })}
      <span class="tl-txt"><span class="n">Stone ${String(st.id).padStart(2, "0")} is ${outLabel(st)}</span><span class="m">${st.battery}% and not charging. Put it back in a jar or on the base.</span></span><span class="pill-btn">Find</span></button>`).join("")}
    <p class="section-h">Glow</p>
    <div class="card kit-glow">
      <div class="seg big">${[["on", "On"], ["dim", "Dim"], ["off", "Off"]].map(([k, l]) => `<button class="${g === k ? "on" : ""}" aria-pressed="${g === k}" data-act="setGlow" data-id="${k}">${l}</button>`).join("")}</div>
      <div class="srow"><span class="tl-txt"><span class="n">Night hours</span><span class="m">${P.night ? `Off ${fmtTime(P.nightFrom)} – ${fmtTime(P.nightTo)}` : "Glows all night"}</span></span>${toggle(P.night, "pref", "night", "Night hours")}</div>
      ${P.night ? `<button class="srow" data-act="nightSheet"><span class="tl-txt"><span class="n">Change hours</span></span>${chev}</button>` : ""}
      <button class="srow" data-act="colorSheet"><span class="tl-txt"><span class="n">Stone colors</span><span class="m">${colorSummary()}</span></span>${chev}</button>
      ${legend()}
    </div>
    <p class="section-h">Jars and base</p>
    <div class="card tlist">${main.map(jarRow).join("")}
      <div class="srow kit-row"><span class="kit-ic">${icon("kit")}</span><span class="tl-txt"><span class="n">Base</span><span class="m">Connected · ${spares.length} spare stone${spares.length === 1 ? "" : "s"}</span></span><span class="charge">⚡ Charging</span></div>
    </div>
    <p class="section-h">Stones</p>
    <div class="card tlist">
      <button class="srow" data-act="go" data-to="stones"><span class="tl-txt"><span class="n">All stones</span><span class="m">${KIT} stones · ${[1, 2, 3].map((w) => `${S.stones.filter((s) => s.size === w).length} ${WEIGHT_LABEL[w][0]}`).join(" · ")} · ${S.stones.filter((s) => s.task).length} paired</span></span>${chev}</button>
      <button class="srow" data-act="pairSheet"><span class="tl-txt"><span class="n">Pair a stone</span><span class="m">Link a spare stone to a task</span></span>${chev}</button>
      <button class="srow" data-act="go" data-to="ready"><span class="tl-txt"><span class="n">Setup guide</span><span class="m">Jars, pairing and charging, step by step</span></span>${chev}</button>
    </div>
    <button class="btn-text center" data-act="kitOff">Stop using the kit</button>
  </div>`;
};

SCREENS.stones = () => {
  const f = S.app.stoneFilter;
  const paired = S.stones.filter((s) => s.task);
  const keep = (s) => (f === "unpaired" ? !s.task : f === "out" ? s.out : true);
  const groups = [];
  const out = S.stones.filter((s) => s.out && keep(s));
  if (out.length) groups.push(["Not charging", out]);
  S.people.filter((p) => p.tier === "main").forEach((p) => {
    const list = S.stones.filter((s) => !s.out && inJar(s) && taskOf(s).who === p.id && keep(s));
    if (list.length) groups.push([p.id === "you" ? "In your jar" : `In ${p.name}'s jar`, list]);
  });
  const base = S.stones.filter((s) => !s.out && !inJar(s) && keep(s));
  if (base.length) groups.push(["On the base", base]);
  const card = (s) => {
    const t = taskOf(s);
    return `<button class="card stone-card" data-act="openStone" data-id="${s.id}">${t ? gemOf(t, { size: "m", w: s.size }) : gem("open", { size: "m", cls: `dim w${s.size}` })}
      <b>Stone ${String(s.id).padStart(2, "0")} <span class="sz">${WEIGHT_LABEL[s.size][0]}</span></b><small>${t ? esc(t.n) : "Not paired"}</small><span class="batt ${s.out ? "low" : ""}">${battLabel(s)}</span></button>`;
  };
  return `${navtop("Home kit", `<button class="btn-soft sm" data-act="pairSheet">Pair a stone</button>`)}
  <div class="content">
    <h1 class="title">Stones</h1>
    <p class="sub">${KIT} stones (S, M and L) · ${paired.length} paired. Stones charge in the jars and on the base.</p>
    <div class="chips">${[["all", "All"], ["unpaired", `Unpaired ${KIT - paired.length}`], ["out", `Not charging ${notCharging().length}`]].map(([id, l]) => chip(l, f === id, "stoneFilter", id)).join("")}</div>
    ${groups.map(([h, list]) => `<p class="section-h">${h}</p><div class="stone-grid">${list.map(card).join("")}</div>`).join("") || `<p class="small empty">No stones here.</p>`}
  </div>`;
};

SCREENS.stoneDetail = () => {
  const s = S.stones.find((x) => x.id === S.app.stone);
  const t = taskOf(s);
  const st = t ? stateOf(t) : "open";
  const where = placeOf(s);
  return `${navtop("Stones", `<button class="btn-soft sm" data-act="toast" data-msg="Renaming is coming soon">Rename</button>`)}
  <div class="content">
    <div class="stage-card tall ${S.app.blink === `s${s.id}` ? "blinking" : ""}">${t ? gemOf(t, { size: "xl", cls: "breathe", w: s.size }) : gem("open", { size: "xl", cls: `dim w${s.size}` })}</div>
    <h1 class="title center">Stone ${String(s.id).padStart(2, "0")}</h1>
    <p class="small center">${where} · last seen 2 min ago</p>
    <div class="badges center">${t ? `<span class="badge ${st === "urgent" ? "amber" : ""}">${st === "done" ? "Resting" : `Glowing · ${STATE[st][0].toLowerCase()}`}</span>` : `<span class="badge plain">Spare</span>`}
      <span class="badge plain ${s.out ? "low" : ""}">${s.out ? `▮ ${s.battery}% · about ${Math.max(1, Math.round(s.battery / 25))} day${s.battery < 38 ? "" : "s"} left` : `⚡ ${s.battery}% · charging`}</span></div>
    ${s.out ? `<div class="card info">${gem("done", { size: "xs" })}<span class="small">Put it back in a jar or on the base and it charges on its own.</span></div>` : ""}
    <button class="btn-ghost wide" data-act="blinkStone" data-id="${s.id}">Make it blink to find it</button>
    <p class="section-h">Paired to</p>
    ${t ? `<div class="card pair-to">${taskLine(t, { trail: chev })}</div>` : `<button class="card give-stone" data-act="pairSheet"><span class="plus-box"><img src="${A("plus.svg")}" alt=""></span><span class="tl-txt"><span class="n">Pair it to a task</span><span class="m">It glows as soon as it's paired</span></span>${chev}</button>`}
    <p class="section-h">About</p>
    <div class="card about">
      <div><span>Model</span><b>Shoal Stone</b></div>
      <div><span>Size</span><b>${WEIGHT_LABEL[s.size]} · for ${sizeName(s.size)} tasks</b></div>
      <div><span>Generation</span><b>Gen 1 · 2026</b></div>
      <div><span>Colorway</span><b>${(t ? t.kind === "once" : s.id % 3) ? "Light · for one-time tasks" : "Dark · for ongoing tasks"}</b></div>
    </div>
    ${t ? `<button class="btn-text danger center" data-act="unpair" data-id="${s.id}">Unpair this stone</button>` : ""}
  </div>`;
};

/* ---------- Celebrations ---------- */

SCREENS.done = () => {
  const t = curTask();
  const helper = t.steps.find((x) => x.done && x.who && x.who !== "you") || t.steps.find((x) => x.who && x.who !== "you");
  return `<div class="topbar"></div>
  <div class="content center-col">
    <div class="hero-gem"><span class="okdot"><img src="${A("check.svg")}" alt=""></span>${gemOf(t, { size: "xl" })}</div>
    <p class="eyebrow">${stoneOf(t) ? "Your stone rests now" : "Off your plate"}</p>
    <h1 class="title">Done. Thank you.</h1>
    <p class="sub">${esc(t.n)} is taken care of.${stoneOf(t) ? " Your stone has dimmed and can rest in your jar." : ""}</p>
    ${helper ? `<p class="eyebrow grey">Also on this task</p>
      <div class="card finished">${avatar(person(helper.who), "s36")}<span class="tl-txt"><span class="n">${esc(nameOf(helper.who))}: ${esc(helper.n.toLowerCase())}</span><span class="m">A step on this task</span></span><button class="pill-btn" data-act="sayThanksStep" data-id="${helper.who}" data-n="${esc(helper.n)}">Say thanks</button></div>` : ""}
  </div>
  <p class="small center">Quiet celebrations for now</p>
  ${solo("Back to your jar", "afterDone")}`;
};

SCREENS.thanks = () => {
  const { who, n, when } = S.app.thankFor;
  const p = person(who);
  const opts = ["Thank you!", `${L()} was so happy`, "Couldn't do it without you"];
  const via = S.app.thankVia || "app";
  return `${navtop("")}
  <div class="content center-col">
    ${avatar(p, "lg")}
    <p class="eyebrow grey">${esc(p.name)} finished something</p>
    <h1 class="title">${esc(n)}</h1>
    <p class="small">${esc(when)} · their stone is off</p>
    <p class="section-h left">Say thanks</p>
    <div class="card tlist left">${opts.map((o, i) => `<button class="radio-row" data-act="thankPick" data-id="${i}"><span class="tl-txt"><span class="n">${esc(o)}</span></span>${check(S.app.thankPick === i)}</button>`).join("")}</div>
    <div class="card tlist left">
      <label class="srow"><img src="${A("plus.svg")}" alt=""><input class="bare" data-input="thanksNote" value="${esc(S.app.thanksNote)}" placeholder="Add a short note (optional)"></label>
      <div class="srow"><span class="tl-txt"><span class="n">Share with the family</span></span>${toggle(S.app.shareThanks, "shareThanks", "", "Share with the family")}</div>
    </div>
    <p class="section-h left">Send it by</p>
    <div class="seg big thank-via">${THANK_VIA.map(([k, l]) => `<button class="${via === k ? "on" : ""}" aria-pressed="${via === k}" data-act="thankVia" data-id="${k}">${l}</button>`).join("")}</div>
  </div>
  <p class="small center">${via === "app" ? `${esc(p.name)}'s jar gives a soft glow. No reply needed.` : via === "text" ? "Opens your messages with the note filled in." : "A quick call. We'll mark it thanked."}</p>
  ${solo(via === "app" ? "Send thanks" : via === "text" ? `Text ${esc(p.name)}` : `Call ${esc(p.name)}`, "sendThanks")}`;
};

SCREENS.clear = () => `${navtop("")}
  <div class="content center-col">
    <div class="clear-jar">${familyJars({ only: "you", act: false })}</div>
    <p class="eyebrow grey">Every stone is resting</p>
    <h1 class="title">Your jar is clear</h1>
    <p class="sub">Everything you took on this week is done. Nothing is waiting on you right now. Take a breath.</p>
    <div class="card info left">${gem("done", { size: "s" })}<span class="small">At home, your jar glows once, slowly, then rests until something new comes in.</span></div>
  </div>
  ${duo(["Offer a hand", "offerHand"], ["Back home", "tab", 'data-to="home"'])}`;

SCREENS.recap = () => {
  const done = S.tasks.filter((t) => t.on && t.done).length + 12;
  const open = active().length;
  const helpers = S.people.filter((p) => p.id !== "you" && (p.remote || p.tier !== "main"));
  const wins = [
    ["urgent", "Every urgent task got covered", "before it was late"],
    ["progress", "Tasks moved easily", "when someone got busy, others stepped in"],
    ["open", helpers.length ? `${listNames(helpers.slice(0, 2))} helped from afar` : "Small things added up", helpers.length ? "5 times this week" : "a few minutes at a time"],
  ];
  return `${navtop("")}
  <div class="content">
    <p class="eyebrow">Oct 12–18 · Sunday recap</p>
    <h1 class="title">Your week together</h1>
    <div class="shelf">${familyJars({ act: false })}
      <div class="recap-meter"><b>${done} things done together</b><div class="bar"><i style="width:${(done / (done + open)) * 100}%"></i></div><span class="small">${open} still open, and ${active().filter((t) => !t.who).length ? "a few need someone" : "all have someone"}</span></div>
    </div>
    <p class="section-h">What went well</p>
    <div class="card tlist">${wins.map(([s, a, b]) => `<div class="tline">${gem(s, { size: "s" })}<span class="tl-txt"><span class="n">${esc(a)}</span><span class="m">${esc(b)}</span></span></div>`).join("")}</div>
    <p class="small center">However this week felt, you all showed up for ${esc(L())}.</p>
  </div>
  ${solo("Send thanks to everyone", "thankAll")}`;
};

// Each kind of notification gets its own badge, so a glance tells you what it is.
const NOTIF = {
  urgent: ["Urgent", `<path d="M12 7v6M12 16.5v.5"/>`],
  request: ["Handoff request", `<path d="M4 9h13l-3.5-3.5M20 15H7l3.5 3.5"/>`],
  done: ["Finished", `<path d="m6 12.5 4 4 8-9"/>`],
  plan: ["Plan", `<path d="M20 4 3 11l7 2.5L12.5 21z"/><path d="m10 13.5 4-4"/>`],
  meds: ["Dose given", `<rect x="4" y="9" width="16" height="7" rx="3.5" transform="rotate(-35 12 12.5)"/><path d="m9.5 9 4.6 6.6"/>`],
  thanks: ["Thank-you", `<path d="M12 19s-7-4.3-7-9.2A3.8 3.8 0 0 1 12 7.5a3.8 3.8 0 0 1 7 2.3C19 14.7 12 19 12 19z"/>`],
};
const nfBadge = (k) => `<span class="nf-badge nb-${k}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">${NOTIF[k][1]}</svg></span>`;

// Things that need you first, then updates.
function notifications() {
  const others = S.people.filter((p) => p.id !== "you");
  const list = [];
  const held = S.app.checkin === "break" && !S.app.heldOpen;
  if (held && S.app.requests.length) list.push({ kind: "request", when: "Today", n: `${S.app.requests.length} ask${S.app.requests.length === 1 ? " is" : "s are"} waiting for you`, m: "Held until Sunday, since you asked for a break", cta: "See", needs: false, act: "showHeld" });
  if (!held) S.app.requests.forEach((r) => list.push({ kind: "request", needs: true, cta: "Review", when: "Today", who: person(r.from), n: `${nameOf(r.from)} asked you to take “${r.n}”`, m: r.note, act: "review", id: r.id }));
  active().filter(isUrgent).slice(0, 2).forEach((t) => list.push({ kind: "urgent", needs: t.who === "you" || !t.who, cta: "Open", when: "Now", gem: gemOf(t, { size: "s" }), n: `${t.n} is ${dueLabel(t)}`, m: t.who ? `${t.who === "you" ? "You have" : `${nameOf(t.who)} has`} it` : "No one has it yet", act: "openTask", id: t.id }));
  S.tasks.filter((t) => t.done && t.doneAt && t.who !== "you").forEach((t) => list.push({ kind: "done", when: t.doneAt.split(",")[0], who: person(t.who), n: `${nameOf(t.who)} finished “${t.n}”`, m: S.app.thanked[t.id] ? "You said thanks" : "Tap to say thanks", act: S.app.thanked[t.id] ? "openTask" : "sayThanks", id: t.id }));
  [...care().doses].sort((a, b) => b.at - a.at).filter((x) => medOf(x.med)?.prn).slice(0, 2).forEach((x) => {
    const m = medOf(x.med);
    const open = careUnlocked(); // locked, it says a dose was logged, not what or how much
    list.push({ kind: "meds", when: cap(ago(x.at)), who: person(x.who), n: open ? `${x.who === "you" ? "You" : nameOf(x.who)} gave ${m.amt} of ${m.name.toLowerCase()} at ${clock(x.at)}` : `${x.who === "you" ? "You" : nameOf(x.who)} logged a dose at ${clock(x.at)}`, m: open ? `Next dose okay after ${clock(x.at + m.every * 36e5)}` : "Unlock the care page to see it", act: "go", to: "care" });
  });
  S.tasks.filter((t) => t.handoff && t.handoff.status !== "pending").forEach((t) => {
    const h = t.handoff, ok = h.status === "accepted";
    const w = handWho(h);
    list.push({ kind: ok ? "done" : "request", needs: !ok, cta: "Open", when: "Today", who: person(w), n: ok ? `${nameOf(w)} said yes to “${t.n}”` : `${nameOf(w)} can't take “${t.n}”`, m: ok ? "Everyone can see it's with them now" : h.why, act: "openTask", id: t.id });
  });
  if (S.planSentAt) {
    const who = others.filter((p) => S.lastSent?.includes(p.id)).map((p) => { const n = mine(p.id).length; return `${p.name}, ${n} task${n === 1 ? "" : "s"}`; });
    list.push({ kind: "plan", when: S.planSentAt, n: S.resent ? "You sent plan changes" : "You sent the plan", m: who.join(" · ") || "No one's tasks changed", gem: gem("progress", { size: "s" }) });
  }
  if (others[1] || others[0]) list.push({ kind: "thanks", when: "Today", who: others[1] || others[0], n: `${(others[1] || others[0]).name} thanked you`, m: "“Thanks for covering the pharmacy call. I owe you one.”" });
  if (others[0]) list.push({ kind: "thanks", when: "Yesterday", who: others[0], n: `${others[0].name} sent you a heart`, m: "For picking up groceries" });
  return list;
}

SCREENS.notifications = () => {
  const list = notifications();
  const row = (x) => {
    const b = `<button class="notif ${x.kind} ${x.needs ? "needs" : ""}" ${x.act ? `data-act="${x.act}" data-id="${x.id || ""}"${x.to ? ` data-to="${x.to}"` : ""}` : "disabled"}>
      <span class="nf-icon">${x.who ? avatar(x.who, "s36") : `<span class="nf-tile">${x.gem}</span>`}${nfBadge(x.kind)}</span>
      <span class="tl-txt"><span class="nf-kind">${NOTIF[x.kind][0]} · ${x.when}</span><span class="n">${esc(x.n)}</span><span class="m">${esc(x.m)}</span></span>
      ${x.needs && x.cta ? `<span class="pill-btn">${x.cta}</span>` : ""}</button>`;
    // A second answer (like Pebble's "Not now") sits under the row, so both are one tap.
    return x.alt ? `<div class="notif-pair">${b}<button class="linkish nf-alt" data-act="${x.alt[1]}" data-id="${x.id || ""}">${x.alt[0]}</button></div>` : b;
  };
  const needs = list.filter((x) => x.needs), rest = list.filter((x) => !x.needs);
  return `${navtop("Home")}
  <div class="content">
    <h1 class="title">Notifications</h1>
    ${needs.length ? `<p class="section-h">Needs you</p><div class="notif-needs">${needs.map(row).join("")}</div>` : ""}
    ${rest.length ? `<p class="section-h">Updates</p><div class="card tlist notif-list">${rest.map(row).join("")}</div>` : ""}
    ${!list.length ? `<div class="card empty-card"><p class="small">Nothing new.</p></div>` : ""}
    <p class="small center">Choose what you get in Settings.</p>
  </div>`;
};

// Instead of a score, My jar asks how the week feels. Nothing is shared unless you choose to.
const THANK_VIA = [["app", "In Shoal"], ["text", "Text"], ["call", "Call"]];
const CHECKIN = [["fine", "Doing okay"], ["stretched", "Stretched thin"], ["break", "I need a break"]];
function checkIn() {
  const c = S.app.checkin;
  const reply = {
    fine: ["Glad to hear it.", "Nothing changes. We'll ask again Sunday.", ""],
    stretched: ["That's a lot to carry.", "Pebble looked for someone with room.", `<button class="btn-soft sm" data-act="checkinHand">Hand one off</button>${pebbleCheckinHint()}`],
    break: ["You're allowed to rest.", "New asks are held until Sunday. The family only knows if you tell them.", S.app.toldFamily ? `<p class="small jc-told">The family knows you could use a hand.</p>` : `<button class="btn-soft sm" data-act="checkinTell">Tell the family</button>`],
  }[c];
  return `<div class="jh-check">
    <p class="eyebrow grey">This week</p>
    ${c ? `<p class="jc-q">${reply[0]}</p><p class="small">${reply[1]}</p>${reply[2]}<button class="linkish" data-act="checkin" data-id="">Change answer</button>`
      : `<p class="jc-q">How's your load feeling?</p><p class="small jc-why">Only you see this. Shoal asks less of you when it's a lot.</p><div class="jc-opts">${CHECKIN.map(([k, l]) => `<button class="chip" data-act="checkin" data-id="${k}">${l}</button>`).join("")}</div>`}
  </div>`;
}

SCREENS.recapSettings = () => {
  const P = S.app.prefs;
  const row = (k, t, d) => `<div class="srow"><span class="tl-txt"><span class="n">${t}</span><span class="m">${d}</span></span>${toggle(P[k], "pref", k, t)}</div>`;
  return `${navtop("Settings")}
  <div class="content">
    <h1 class="title">Thank-yous and recaps</h1>
    <div class="card tlist" style="margin-top:18px">${row("little", "Little thank-yous", "When you or family finish a task")}${row("weekly", "Weekly recap", "Sunday evening")}${row("names", "Name who helped", "Highlights can mention people")}</div>
    <div class="card tlist">${row("quiet", "Quiet for now", "Pause all of these for a while")}
      ${P.quiet ? `<div class="chips quiet">${[["day", "A day"], ["week", "A week"], ["on", "Until I turn it on"]].map(([id, l]) => chip(l, P.quietFor === id, "quietFor", id)).join("")}</div>` : ""}</div>
    <div class="card info">${gem("done", { size: "xs" })}<span class="small">No streaks, no rankings. Recaps only show what went well together.</span></div>
  </div>`;
};

/* ---------- Notes panel ---------- */

Object.assign(NOTES, {
  ready: ["Setup: plan is ready", ["Bridges onboarding to the physical kit: jars, base, stones.", "If onboarding was skipped, a demo family fills in so every screen has something to show."]],
  jars: ["Set up the jars", ["One jar per main caregiver. Trusted circle and kids follow along in the app, no jar."]],
  pick: ["Pick up a stone", ["White glow = ready to pair."]],
  hold: ["Hold it to your phone", ["Only this screen listens for stones, so nothing pairs by accident. Pairing is simulated after ~2 seconds."]],
  paired: ["Paired", ["Pairs to your most urgent task, so the first glow means something."]],
  find: ["Find a stone", ["Tap Find stone and its stone blinks in the jar."]],
  glow: ["What the glow means", ["Yellow = urgent, ice blue = in progress, white = unassigned, off = done. Families can pick their own colors in Settings.", "Light stones are one-time, dark stones are ongoing."]],
  charge: ["Charging", ["The base powers the jars, so stones charge in a jar or on the base. No moving stones around to charge.", "Only a stone left out (on a table, in a bag) runs down, and the app warns you."]],
  pairRest: ["Pair the rest", ["Optional. Anyone can pair their own stones later."]],
  home: ["Home", ["Urgent first, then the family jars and this week. No section labels, so it reads at a glance.", "The week is a bar chart of how much the family has each day. Tap a bar to see that day's tasks.", "Top right: the jar icon opens the home kit (only if the family has one), the bell opens notifications.", "Only urgent stones carry a mark: a ! in the urgent color, so it never looks like a notification on anything else. Done stones go grey. Each jar says how many are left."]],
  myjar: ["My jar", ["A weekly check-in: how's your load feeling? Private, and each answer does something. \"Stretched thin\" finds someone with room. \"I need a break\" holds new asks until Sunday.", "The old progress ring is optional now, under Settings › My jar.", "One list with All, One-time and Ongoing tabs. Urgent tasks sit on top. Tick to mark done."]],
  task: ["A task", ["Med tasks show their meds from the care page: the dose big and bold, who gave the last one, and when the next is okay.", "Shows who has it, its size, steps, and notes. Hand off or mark done from here. Pebble sits under the notes with one thing it can do, like writing the ask for you.", "Hand-offs are asks, not orders: the other person says yes or no, and everyone sees the answer.", "Every task has a stone. Linking a real stone at home is optional."]],
  handoff: ["Hand off", ["Ask one person, a few, or everyone at once. The first to say yes takes it, and the rest are told it's covered.", "Families asked for this: \"anyone free Thursday?\" shouldn't mean asking one by one.", "Trusted circle and kids are limited to the tasks they can take."]],
  newTask: ["Add a task", ["Name, one-time or ongoing, due date, and stone size (bigger stone, bigger job).", "Who can help: main caregivers, trusted circle, kids. Can be done from anywhere lets remote family take it.", "Saving adds its stone to that person's jar."]],
  newStone: ["Link a real stone", ["Every task already has a stone in the app jar. Linking a real one is optional, from the task's ••• menu."]],
  peopleTab: ["People", ["Everyone's jars and progress, plus the extended circle."]],
  person: ["A person's tasks, and why", ["What the family should know before asking: room left this week, best time, how to reach them, and good-to-know notes.", "Each task says why Pebble suggested that person. Move one of their tasks to give them less to carry."]],
  settings: ["Settings", ["Family setup, recaps, notifications, and what Pebble can see. Jars, stones and glow live in the home kit.", "Pebble can be turned off completely; it never gives medical advice. The home kit is optional: the app does everything without it."]],
  kit: ["Home kit", ["Everything physical in one place, opened from the jar icon on Home: glow, night hours, jars, the base, and every stone's battery.", "A dot on the icon means a stone is off power.", "A kit has 36 stones: 12 small, 15 medium and 9 large, so each task gets a stone its size."]],
  stones: ["Stones", ["All the stones by where they are: in a jar, on the base, or out and not charging."]],
  stoneDetail: ["Stone detail", ["Make it blink, see what it's paired to, or unpair it."]],
  done: ["Marked done", ["A quiet celebration, with a prompt to thank whoever helped."]],
  thanks: ["Say thanks", ["One tap, optional note. Send it in Shoal, by text, or as a reminder to call."]],
  clear: ["Jar is clear", ["When everything of yours is done."]],
  recap: ["Weekly recap", ["Sunday recap. No streaks or rankings, only what went well."]],
  notifications: ["Notifications", ["Needs you: handoff requests and your urgent tasks. Each has a button. Stone alerts live in the home kit.", "Updates: things others finished and thank-yous. A badge on each picture shows the kind."]],
  recapSettings: ["Thank-yous and recaps", ["Turn each one off, or go quiet for a while."]],
  resources: ["Help and resources", ["People to call first, then support (grief, money), each with a few gentle lines and links to trusted outside sources: 988, CaringInfo, Medicare, the FTC, USA.gov.", "End-of-life topics (what to do when someone dies, funeral planning) stay folded behind a gentle note until someone chooses to open them, with an offer to talk it through with the social worker instead.", "\"Call hospice first, not 911\" is explained in terms of the loved one's wishes, not as a rule."]],
});

const APP_NAV = ["ready", "home", "myjar", "task", "newTask", "peopleTab", "person", "pebble", "settings", "resources", "kit", "stones", "done", "clear", "recap", "notifications"];

function renderAppNotes() {
  const [title, bullets] = NOTES[S.screen] || ["", []];
  document.getElementById("notes").innerHTML = `
    <p class="eyebrow">Shoal · main app${S.app?.demo ? " · demo family" : ""}</p>
    <h2>${title}</h2>
    <button class="os-open" data-act="osOpen"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="2.5" width="12" height="19" rx="3"/><path d="M10.5 18.5h3"/></svg><span><b>Outside the app</b><small>Lock screen, notifications, home screen</small></span></button>
    <ol>${APP_NAV.map((s) => `<li><button data-act="appJump" data-to="${s}" aria-current="${s === S.screen}">${NOTES[s][0]}</button></li>`).join("")}</ol>
    <div class="why"><strong>About this screen</strong><ul>${bullets.map((b) => `<li>${b}</li>`).join("")}</ul></div>
    <button class="reset" data-act="restart">Restart prototype</button>`;
}

/* ---------- Entering screens ---------- */

let heardTimer;
function appEnter(screen) {
  ensureAppData();
  clearTimeout(heardTimer);
  if (screen === "hold" || screen === "newStone") {
    S.app.heard = false;
    heardTimer = setTimeout(() => { if (S.screen === screen) { S.app.heard = true; render(); } }, 1800);
  }
  if (screen === "hold") firstTask();
  if (screen === "paired") { const t = firstTask(); if (t && !stoneOf(t)) pairStone(t.id); }
  if (screen === "find") S.app.blink = null;
  if (screen === "notifications") S.app.seenNotes = true;
  if (screen === "handoff") { S.app.handTo = undefined; S.app.note = ""; S.app.handStep = null; S.app.notePebble = false; S.app.follow = null; }
}

function tabTo(screen) {
  ensureAppData();
  if (screen === S.screen) return;
  S.history = [];
  S.app.blink = null;
  lastDir = "fade";
  closeSheet();
  appEnter(screen);
  S.screen = screen;
  render();
}

// Jump from the notes panel, filling in whatever context the screen needs.
function appJump(to) {
  ensureAppData();
  if (to === "task" || to === "done") S.app.task = (mine("you").find((t) => !t.done && t.steps.length) || mine("you").find((t) => !t.done) || active()[0] || S.tasks[0]).id;
  if (to === "done") { const t = curTask(); t.done = true; }
  if (to === "person") S.app.person = (S.people.find((p) => p.tier === "main" && p.id !== "you") || S.people[0]).id;
  if (to === "newTask") { ACTIONS.newTask(); return; }
  if (TABS.some(([id]) => id === to) || to === "ready") { tabTo(to); return; }
  S.history = [TABS.find(([id]) => id === S.screen) ? S.screen : "home"];
  lastDir = "fade";
  closeSheet();
  appEnter(to);
  S.screen = to;
  render();
}

/* ---------- Actions ---------- */

function finishDone(t) {
  t.done = true;
  S.app.task = t.id;
  go("done");
}

Object.assign(ACTIONS, {
  noop: () => {},
  signOutSheet: () => openSheet(`<h3>Sign out?</h3><p class="small">You'll go back to the sign-in screen. In this prototype, signing out also clears what you set up.</p>
    <div class="actions"><button class="btn-soft" data-act="closeSheet">Stay signed in</button><button class="btn-soft" data-act="signOut">Sign out</button></div>`),
  signOut: () => { closeSheet(); S = initialState(); S.screen = "signin"; lastDir = "back"; render(); },
  enterApp: () => { ensureAppData(); go("ready"); },
  skipToApp: () => { ensureAppData(); tabTo("home"); },
  setupStep: (d) => {
    const x = SETUP_STEPS.find((y) => y.id === d.id);
    if (x.needs && !S.setup[x.needs]) { toast("Add tasks first"); return; }
    if (d.id === "tasks") {
      if (S.setup.tasks) { S.flowKey = S.path; go("tasks"); } else go("taskStart");
      return;
    }
    if (d.id === "stones") { hasKit() ? go("ready") : kitSheet(); return; }
    S.flowKey = d.id;
    if (d.id === "split") S.sent = false;
    go(flow()[0]);
  },
  finishStones: () => setupDone("stones"),
  kitSheet,
  kitYes: () => { S.kit = "yes"; closeSheet(); go("ready"); },
  kitNo: () => { S.kit = "no"; closeSheet(); render(); toast("Stones stay in the app. Add a kit anytime in Settings."); },
  kitOff: () => { S.kit = "no"; S.app.blink = null; tabTo("settings"); toast("Kit off. Your stones and jars stay in the app."); },
  hideSetup: () => { S.setup.hidden = true; render(); },
  homeFold: (d) => { S.app.shut ||= {}; S.app.shut[d.id] = !S.app.shut[d.id]; render(); },
  appJump: (d) => appJump(d.to),
  setupNext: () => go(SETUP[SETUP.indexOf(S.screen) + 1]),
  tab: (d) => tabTo(d.to),
  go: (d) => go(d.to),
  findStone: (d) => {
    S.app.blink = d.id;
    render();
    const s = stoneOf(S.tasks.find((t) => t.id === d.id));
    toast(s ? `Stone ${String(s.id).padStart(2, "0")} is blinking` : "Its stone is blinking");
    setTimeout(() => { if (S.app.blink === d.id && S.screen !== "find") { S.app.blink = null; render(); } }, 4000);
  },
  pairTask: (d) => {
    const s = pairStone(d.id);
    render();
    toast(pairMsg(s, task(d.id)));
  },
  morePair: () => { S.app.morePair = !S.app.morePair; render(); },
  homeDay: (d) => { S.app.day = d.id; render(); },
  openTask: (d) => { S.app.task = d.id; go("task"); },
  openPerson: (d) => {
    if (d.id === "you") { tabTo("myjar"); return; }
    S.app.person = d.id;
    go("person");
  },
  openStone: (d) => { S.app.stone = +d.id; go("stoneDetail"); },
  jarTab: (d) => { S.app.jarTab = d.id; render(); },
  showDone: () => { S.app.showDone = !S.app.showDone; render(); },
  markDone: (d) => finishDone(S.tasks.find((t) => t.id === d.id)),
  undoDone: (d) => { S.tasks.find((t) => t.id === d.id).done = false; render(); toast("Back on the list"); },
  afterDone: () => tabTo(mine("you").some((t) => !t.done) ? "myjar" : "clear"),
  review: (d) => {
    const r = S.app.requests.find((x) => x.id === d.id);
    S.app.req = r.id;
    openSheet(`<p class="eyebrow">Request from ${esc(nameOf(r.from))}</p><h3>${esc(r.n)}</h3>
      <p class="small">“${esc(r.note)}”</p>
      <div class="actions"><button class="btn-soft" data-act="answerReq" data-id="0">Not this time</button><button class="btn-soft" data-act="answerReq" data-id="1">I'll take it</button></div>
      <button class="btn-primary" data-act="closeSheet">Decide later</button>`);
  },
  answerReq: (d) => {
    const r = S.app.requests.find((x) => x.id === S.app.req);
    S.app.requests = S.app.requests.filter((x) => x !== r);
    if (d.id === "1") S.tasks.push({ id: `r${Date.now()}`, n: r.n, w: 1, k: "phone", y: false, cat: "", on: true, kind: "once", days: ["Sat"], date: addDays(1), time: "", who: "you", done: false, steps: [], notes: r.note, remote: true });
    closeSheet();
    render();
    toast(d.id === "1" ? "Added to your jar" : `${nameOf(r.from)} will see it's back with them`);
  },
  taskMenu: () => {
    const t = curTask();
    openSheet(`<h3>${esc(t.n)}</h3>
      <div class="sheet-list">
        <button data-act="editTaskDate">Change ${t.kind === "once" ? "due date" : "days"}</button>
        ${!hasKit() ? "" : stoneOf(t) ? `<button data-act="findStone" data-id="${t.id}">Find its stone</button>` : `<button data-act="giveStone" data-id="${t.id}">Link a real stone</button>`}
        <button data-act="handoff">Hand off</button>
      </div>
      <button class="btn-primary" data-act="closeSheet">Done</button>`);
  },
  editTaskDate: () => { S._cal = null; dateSheet(curTask()); },
  toggleStep: (d) => { const x = curTask().steps[+d.id]; x.done = !x.done; if (x.done && !x.who) x.who = "you"; render(); },
  takeStep: (d) => { curTask().steps[+d.id].who = "you"; render(); toast("That step is yours"); },
  // Hand off one step, not the whole task.
  askStep: (d) => { go("handoff"); S.app.handStep = +d.id; render(); },
  giveStone: (d) => { closeSheet(); S.app.stoneFor = d.id; go("newStone"); },
  handoff: () => { closeSheet(); go("handoff"); },
  // Pick several people, everyone who can take it, or no one (unassigned).
  handTo: (d) => {
    const t = curTask();
    const able = S.people.filter((p) => p.id !== t.who && canTake(p, t)).map((p) => p.id);
    const cur = Array.isArray(S.app.handTo) ? S.app.handTo : [];
    if (!d.id) S.app.handTo = null;
    else if (d.id === "all") S.app.handTo = able.every((id) => cur.includes(id)) ? undefined : able;
    else { const next = cur.includes(d.id) ? cur.filter((x) => x !== d.id) : [...cur, d.id]; S.app.handTo = next.length ? next : undefined; }
    render();
  },
  // A hand-off is a request. The task stays put until they say yes, and everyone sees how it went.
  sendHandoff: () => {
    const t = curTask(), to = S.app.handTo, step = t.steps[S.app.handStep], note = S.app.note.trim();
    if (S.app.notePebble && note && typeof pebLog === "function") pebLog(`Wrote the note asking for help with “${t.n}”`, "You checked it and sent the request");
    back();
    if (step && to) {
      step.ask = to;
      render();
      toast(`Asked ${to.length > 1 ? namesList(to) : nameOf(to[0])} about “${step.n}”`);
      const taker = to.find((id) => person(id)?.tier === "main") || to[0];
      setTimeout(() => { if (step.who) return; step.who = taker; delete step.ask; render(); toast(`${nameOf(taker)} took “${step.n}”`); }, 4000);
      return;
    }
    if (!to) { t.who = null; t.handoff = null; render(); toast("It glows white for whoever is free"); return; }
    const able = S.people.filter((p) => p.id !== t.who && canTake(p, t));
    const many = to.length > 1;
    t.handoff = { to, from: t.who, status: "pending", all: many && able.every((p) => to.includes(p.id)), note };
    render();
    const stay = t.who === "you" ? "with you" : `with ${nameOf(t.who)}`;
    toast(many ? `Asked ${t.handoff.all ? "everyone" : namesList(to)}. It stays ${stay} until someone says yes.` : `Asked ${nameOf(to[0])}. It stays ${stay} until they say yes.`);
    // With Pebble's follow-up on, the prototype plays the no-answer path instead: Pebble asks the next person, as agreed.
    if (typeof pebbleFollowArm === "function" && pebbleFollowArm(t, to)) return;
    // The prototype answers for them. One person: yes first, then no, so both paths can be shown.
    // Several people: someone always says yes, and the rest are told it's covered.
    const yes = many || (S.app.handReplies = (S.app.handReplies || 0) + 1) % 2 === 1;
    const taker = many ? (to.find((id) => person(id)?.tier === "main") || to[0]) : to[0];
    setTimeout(() => {
      if (t.handoff?.status !== "pending") return;
      t.handoff.status = yes ? "accepted" : "declined";
      t.handoff.when = "Just now";
      t.handoff.taker = taker;
      if (yes) t.who = taker;
      else t.handoff.why = "Can't this week. I'm traveling until Sunday.";
      S.app.seenNotes = false;
      render();
      toast(yes ? `${nameOf(taker)} said yes to “${t.n}”${many ? ". The others were told." : ""}` : `${nameOf(taker)} can't take “${t.n}”`);
    }, 4000);
  },
  resSheet: (d) => {
    const r = RESOURCES[d.id];
    openSheet(`<h3>${r.title}</h3><p class="res-intro">${esc(r.intro)}</p>
      <ul class="res-points">${r.items.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>
      <p class="res-src">Learn more from trusted sources</p>
      <div class="res-links">${r.links.map(([n, m, url]) => `<a class="res-link" href="${url}" target="_blank" rel="noopener"><span class="tl-txt"><span class="n">${esc(n)}</span><span class="m">${esc(m)}</span></span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14 5h5v5M19 5l-8 8M17 14v4a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1h4"/></svg></a>`).join("")}</div>
      <p class="small res-foot">Opens in your browser. Shoal isn't connected to these sites.</p>
      <div class="actions">${r.gentle ? `<button class="btn-soft" data-act="toast" data-msg="Calling Rosa at (408) 555-0167">Talk to Rosa</button>` : ""}<button class="btn-soft" data-act="closeSheet">Done</button></div>`);
  },
  resToggle: () => { S.app.resOpen = !S.app.resOpen; render(); },
  cancelHandoff: () => { curTask().handoff = null; render(); toast("Request canceled"); },
  newTask: () => {
    ensureAppData();
    const id = `n${Date.now()}`;
    S.tasks.push({ id, n: "", w: 2, k: "", y: false, cat: "", on: false, draft: true, kind: "once", days: ["Sat"], date: addDays(4), time: "", who: "you", done: false, steps: [], notes: "", remote: false });
    S.app.draft = id;
    go("newTask");
  },
  draftKind: (d) => { draft().kind = d.id; render(); },
  draftWho: (d) => { draft().who = d.who || null; render(); },
  draftRemote: () => { const t = draft(); t.remote = !t.remote; if (!t.remote && person(t.who)?.remote) t.who = null; render(); },
  draftOpen: (d) => {
    const t = draft(), on = openTo(t), next = on.includes(d.id) ? on.filter((k) => k !== d.id) : [...on, d.id];
    if (!next.length) return toast("At least one group needs to be able to help");
    t.open = OPEN_TIERS.map(([k]) => k).filter((k) => next.includes(k));
    if (t.who && !canTake(person(t.who), t)) t.who = null;
    render();
  },
  editDraftDate: () => { S._cal = null; dateSheet(draft()); },
  saveTask: () => {
    const t = draft();
    t.draft = false;
    t.on = true;
    S.app.draft = null;
    S.app.task = t.id;
    tabTo(t.who === "you" ? "myjar" : "home");
    toast(`Saved. Its ${sizeName(t.w || 2)} stone is in ${t.who ? `${possessive(person(t.who))} jar` : "the open pile"}.`);
  },
  saveStone: () => {
    const s = pairStone(S.app.stoneFor);
    back();
    toast(pairMsg(s, task(S.app.stoneFor), "linked"));
  },
  dismissThanks: (d) => { S.app.dismissed[d.id] = true; render(); },
  nightSheet: () => {
    const P = S.app.prefs;
    openSheet(`<h3>Night hours</h3><p class="small">Stones stop glowing overnight, then come back on.</p>
      <p class="label">Turn off at</p><div class="chips">${["21:00", "22:00", "23:00"].map((t) => chip(fmtTime(t), P.nightFrom === t, "nightTime", `from-${t}`)).join("")}</div>
      <p class="label">Back on at</p><div class="chips">${["06:00", "07:00", "08:00"].map((t) => chip(fmtTime(t), P.nightTo === t, "nightTime", `to-${t}`)).join("")}</div>
      <button class="btn-primary" data-act="closeSheet">Done</button>`);
  },
  nightTime: (d) => {
    const [k, t] = d.id.split("-");
    S.app.prefs[k === "from" ? "nightFrom" : "nightTo"] = t;
    ACTIONS.nightSheet();
    render();
  },
  setGlow: (d) => {
    S.app.prefs.glow = d.id;
    render();
    toast(d.id === "on" ? "Stones glow" : d.id === "dim" ? "Stones dimmed" : "Glow off. Colors still show in the app.");
  },
  showHeld: () => { S.app.heldOpen = true; tabTo("myjar"); },
  reachOut: (d) => toast(d.id === "call" ? "Opens your phone to call" : "Opens your messages"),
  moveTask: () => {
    const p = person(S.app.person);
    openSheet(`<h3>Which one should move?</h3><p class="small">You'll pick who to ask next. ${p.id === "you" ? "It stays yours" : `It stays with ${esc(p.name)}`} until someone says yes.</p><div class="sheet-list">${mine(p.id).filter((t) => !t.done).map((t) => `<button data-act="moveThis" data-id="${t.id}">${esc(t.n)}</button>`).join("")}</div>
      <button class="btn-primary" data-act="closeSheet">Cancel</button>`);
  },
  moveThis: (d) => { S.app.task = d.id; closeSheet(); go("handoff"); },
  redoSetup: () => openSheet(`<h3>Redo family setup?</h3><p class="small">You'll go back through onboarding. This prototype starts fresh.</p>
    <div class="actions"><button class="btn-soft" data-act="closeSheet">Keep it</button><button class="btn-soft" data-act="restart">Start over</button></div>`),
  pebbleToggle: () => {
    S.pebbleOff = !S.pebbleOff;
    if (S.pebbleOff) { if (S.path === "pebble") S.path = "manual"; S.tasks.forEach((t) => { t.pebble = false; }); }
    render(); if (document.getElementById("sheet").classList.contains("open")) ACTIONS.pebbleSees();
    toast(S.pebbleOff ? "Pebble is off. Your tasks stay as they are." : "Pebble is back on");
    if (S.pebbleOff && S.screen === "pebble") { closeSheet(); tabTo("settings"); }
  },
  checkin: (d) => { S.app.checkin = d.id || null; S.app.heldOpen = false; render(); },
  checkinHand: () => {
    const list = active().filter((t) => t.who === "you");
    openSheet(`<h3>Which one could someone else take?</h3><p class="small">They'll get a request and can say yes or no.</p>
      <div class="sheet-list">${list.map((t) => `<button data-act="moveThis" data-id="${t.id}">${esc(t.n)}<small>${WEIGHT_LABEL[t.w || 2]} · ${dueLabel(t)}</small></button>`).join("") || `<p class="small">Nothing in your jar right now.</p>`}</div>
      <button class="btn-primary" data-act="closeSheet">Not now</button>`);
  },
  checkinTell: () => { S.app.toldFamily = true; toast("Sent. The family will see you could use a hand this week."); },
  pebbleSees: () => openSheet(`<h3>What Pebble can see</h3>
    <p class="small">Pebble uses everyone's answers from setup, ${esc(L())}'s goals, task names and dates, and what you tell it when you tap Ask Pebble. It never reads messages, medical records, or calendar event details. Only busy and free. Tap an underlined word in a note and it explains that word only.</p>
    <p class="small"><b>You say yes first.</b> Pebble drafts and suggests. Nothing changes until someone says yes, and Pebble never sends a message or calls anyone itself. What Pebble did, in the Pebble tab, lists every change.</p>
    <p class="small"><b>No clinical role.</b> Pebble doesn't give medical advice, read symptoms, or touch medications. It only helps the family share the work.</p>
    <div class="srow"><span class="tl-txt"><span class="n">Pebble suggestions</span><span class="m">Turn off to set everything up by hand</span></span>${toggle(pebbleOn(), "pebbleToggle", "", "Pebble suggestions")}</div>
    <button class="btn-primary" data-act="closeSheet">Got it</button>`),
  pref: (d) => { S.app.prefs[d.id] = !S.app.prefs[d.id]; render(); },
  quietFor: (d) => { S.app.prefs.quietFor = d.id; render(); },
  stoneFilter: (d) => { S.app.stoneFilter = d.id; render(); },
  pairSheet: () => {
    const list = active().filter((t) => !stoneOf(t));
    openSheet(`<h3>Pair a stone</h3><p class="small">Pick a task. Then hold the stone to your phone.</p>
      <div class="sheet-list">${list.slice(0, 8).map((t) => `<button data-act="pairFromSheet" data-id="${t.id}">${esc(t.n)}<small>${esc(nameOf(t.who))} · ${sizeName(t.w || 2)} stone</small></button>`).join("") || `<p class="small">Every task has a stone.</p>`}</div>
      <button class="btn-primary" data-act="closeSheet">Cancel</button>`);
  },
  pairFromSheet: (d) => {
    closeSheet();
    const s = pairStone(d.id);
    if (S.screen === "stoneDetail" && s) S.app.stone = s.id;
    render();
    toast(pairMsg(s, task(d.id)));
  },
  blinkStone: (d) => {
    S.app.blink = `s${d.id}`;
    render();
    toast(`Stone ${String(d.id).padStart(2, "0")} is blinking`);
    setTimeout(() => { if (S.app.blink === `s${d.id}`) { S.app.blink = null; render(); } }, 3000);
  },
  unpair: (d) => { S.stones.find((s) => s.id === +d.id).task = null; back(); toast("Stone unpaired. Keep it on the base as a spare."); },
  sayThanks: (d) => {
    const t = S.tasks.find((x) => x.id === d.id);
    S.app.thankFor = { who: t.who, n: t.n, when: t.doneAt || "Today", task: t.id };
    S.app.thankPick = 0; S.app.thanksNote = "";
    go("thanks");
  },
  sayThanksStep: (d) => {
    S.app.thankFor = { who: d.id, n: d.n, when: "This week" };
    S.app.thankPick = 0; S.app.thanksNote = "";
    go("thanks");
  },
  thankPick: (d) => { S.app.thankPick = +d.id; render(); },
  shareThanks: () => { S.app.shareThanks = !S.app.shareThanks; render(); },
  sendThanks: () => {
    const f = S.app.thankFor;
    if (f.task) S.app.thanked[f.task] = true;
    back();
    const via = S.app.thankVia || "app";
    toast(via === "text" ? `Opening Messages to ${nameOf(f.who)}` : via === "call" ? `Calling ${nameOf(f.who)}…` : `Thanks sent to ${nameOf(f.who)}`);
  },
  thankVia: (d) => { S.app.thankVia = d.id; render(); },
  thankAll: () => { back(); toast("Thanks sent to everyone"); },
  offerHand: () => { tabTo("peopleTab"); toast("We'll let the family know you have room"); },
});

const APP_INPUT = {
  draftName: (v) => {
    const t = draft();
    t.n = v;
    // Pebble sizes the task as it's typed, until someone picks a size.
    if (!t.sizeSet && pebbleOn()) {
      t.w = t.pw = v.trim() ? guessSize(v) : 2;
      const lab = document.querySelector("[data-size-label]");
      if (lab) { lab.textContent = WEIGHT_LABEL[t.w]; const em = lab.closest(".field-row")?.querySelector("em"); if (em) em.textContent = v.trim() ? "Pebble's guess" : ""; }
    }
    const btn = document.querySelector(".footer .btn-primary");
    if (btn) btn.disabled = !v.trim();
  },
  draftNote: (v) => { draft().notes = v; },
  handoffNote: (v) => { S.app.note = v; },
  thanksNote: (v) => { S.app.thanksNote = v; },
};

