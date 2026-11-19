/* Shoal prototype: onboarding — vanilla JS, one state object, full re-render per change. */

const A = (f) => `assets/${f}`;
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/* ---------- Content ---------- */

// What they're living with. Hospice isn't here: it's a stage of care, not an illness, so it's asked as a stage below.
const CONDITIONS = [
  { id: "dementia", t: "Dementia or memory loss", d: "Alzheimer's, confusion, wandering" },
  { id: "cancer", t: "Cancer", d: "Chemo, radiation, recovery" },
  { id: "aging", t: "Getting older and frail", d: "Needs more help day to day" },
  { id: "other", t: "Something else", d: "Heart or lung illness, stroke, surgery recovery" },
];

// Where things are right now. Each stage has a starter set, picked with hospice nurses and doulas,
// so first-timers see the tasks people usually miss. It's a fixed list, not Pebble, so it works with Pebble off.
const STAGES = [
  { id: "start", t: "Just starting", d: "A new diagnosis, or help is new", s: "families just starting out" },
  { id: "daily", t: "Day to day", d: "Ongoing care, settling into a routine", s: "day-to-day care" },
  { id: "final", t: "In hospice or final months", d: "Comfort care, at home or in a facility", s: "hospice and the final months" },
];
const STARTER = {
  start: ["Doctor appointments", "Keep a list of meds and doses", "Keep the care binder up to date", "Insurance calls", "Set up a meal train", "Keep family updated", "Safety check: rails, rugs, lights"],
  daily: ["Refill prescriptions", "Fill the weekly pill box", "Weekly grocery run", "Rides to appointments", "Visit and keep them company", "Give the main caregiver a night off", "Keep family updated"],
  final: ["Be there for hospice nurse visits", "Comfort meds schedule", "Repositioning for comfort", "Record stories and memories", "Give the main caregiver a night off", "Overnight stays", "Keep family updated", "Set up a meal train"],
};
// Pebble is optional. Off, everything still works by hand: the starter set, sizes and dates stay, the guesses don't.
const pebbleOn = () => !S.pebbleOff;
const stageOf = () => S.stage || "daily";
// "hospice" tasks follow the stage; the rest follow the conditions picked.
const hasCond = (c) => (c === "hospice" ? stageOf() === "final" : S.conditions.includes(c));

// w = weight (1 light, 2 medium, 3 heavy). k = skill tag. r = repeats by default ("Needed" = only as it comes up).
// c = only suggested for these conditions (none = everyone). p = Pebble pre-picks it.
// wishes / far = Pebble pre-picks it when those answers are chosen. Tasks in "Kids & teens" get y (kid task).
const KID_CAT = "Kids & teens";
const TASK_LIBRARY = {
  Medical: [
    { n: "Refill prescriptions", w: 1, k: "meds", p: 1 },
    { n: "Doctor appointments", w: 2, k: "drive", p: 1, r: "Needed" },
    { n: "Keep a list of meds and doses", w: 1, k: "meds" },
    { n: "Track symptoms for the doctor", w: 1, k: "meds", r: "Daily" },
    { n: "Fill the weekly pill box", w: 1, k: "meds", r: "Sun" },
    { n: "Sit in on appointments and take notes", w: 2, k: "there", r: "Needed" },
    { n: "Order medical supplies", w: 1, k: "phone", far: 1, r: "Needed" },
    { n: "Keep the care binder up to date", w: 1, k: "paper" },
    { n: "Be there for hospice nurse visits", w: 2, k: "there", p: 1, r: "Thu", c: ["hospice"] },
    { n: "Comfort meds schedule", w: 2, k: "meds", c: ["hospice"] },
    { n: "Neurologist visits", w: 2, k: "drive", c: ["dementia"] },
    { n: "Rides to chemo", w: 2, k: "drive", p: 1, r: "Tue", c: ["cancer"] },
    { n: "Track side effects", w: 1, k: "meds", r: "Daily", c: ["cancer"] },
    { n: "Wound or port care", w: 2, k: "meds", c: ["cancer", "other"] },
    { n: "Physical therapy exercises", w: 1, k: "there", r: "Mon", c: ["aging", "other"] },
    { n: "Hearing and vision checkups", w: 1, k: "drive", c: ["aging"] },
  ],
  "Care & visits": [
    { n: "Help getting dressed", w: 1, k: "there", r: "Daily" },
    { n: "Help with bathing", w: 2, k: "there", r: "Wed" },
    { n: "Bedtime routine", w: 1, k: "there", r: "Daily" },
    { n: "Help moving around the house", w: 2, k: "there" },
    { n: "Overnight stays", w: 3, k: "there", r: "Fri" },
    { n: "Give the main caregiver a night off", w: 3, k: "there", p: 1, r: "Fri" },
    { n: "Visit and keep them company", w: 1, k: "there", r: "Sun" },
    { n: "Phone or video calls", w: 1, k: "phone", r: "Wed" },
    { n: "Music, reading, old photos", w: 1, k: "there" },
    { n: "Games and puzzles", w: 1, k: "there" },
    { n: "A walk or outing", w: 2, k: "there", r: "Sat" },
    { n: "Keep family updated", w: 1, k: "phone", r: "Fri", far: 1 },
    { n: "Repositioning for comfort", w: 2, k: "there", r: "Daily", c: ["hospice"] },
    { n: "Record stories and memories", w: 1, k: "there", c: ["hospice"] },
    { n: "Watch for wandering", w: 2, k: "there", c: ["dementia"] },
    { n: "Memory activities", w: 1, k: "there", c: ["dementia"] },
    { n: "Chemo day company", w: 2, k: "there", c: ["cancer"] },
  ],
  "Home & meals": [
    { n: "Weekly grocery run", w: 1, k: "drive", p: 1, r: "Sat" },
    { n: "Cook dinners", w: 2, k: "cook", r: "Daily" },
    { n: "Set up a meal train", w: 1, k: "phone" },
    { n: "Order meal delivery", w: 1, k: "phone", far: 1 },
    { n: "Cleaning", w: 2, k: "there", r: "Thu" },
    { n: "Laundry", w: 1, k: "there", r: "Mon" },
    { n: "Trash and recycling", w: 1, k: "there", r: "Tue" },
    { n: "Yard work and snow", w: 2, k: "there" },
    { n: "Safety check: rails, rugs, lights", w: 2, k: "there" },
    { n: "Pet care", w: 1, k: "there", r: "Daily" },
    { n: "Get the mail and water plants", w: 1, k: "there", r: "Wed" },
    { n: "Keep snacks and water nearby", w: 1, k: "cook" },
    { n: "Easy-on-the-stomach meals", w: 2, k: "cook", p: 1, c: ["cancer"] },
    { n: "Soft foods and thickened drinks", w: 1, k: "cook", c: ["hospice", "dementia"] },
    { n: "Set up a hospital bed or equipment", w: 3, k: "there", c: ["hospice", "other"] },
    { n: "Lock up meds and sharp tools", w: 1, k: "there", c: ["dementia"] },
    { n: "Install grab bars", w: 2, k: "there", c: ["aging"] },
  ],
  "Rides & errands": [
    { n: "Rides to appointments", w: 2, k: "drive", p: 1, r: "Needed" },
    { n: "Pharmacy pickups", w: 1, k: "drive", r: "Needed" },
    { n: "Errands and post office", w: 1, k: "drive", r: "Sat" },
    { n: "Rides to church or social events", w: 1, k: "drive", r: "Sun" },
    { n: "Book a ride service or paratransit", w: 1, k: "phone", far: 1 },
    { n: "Get a disability parking placard", w: 1, k: "paper" },
    { n: "Car upkeep", w: 1, k: "drive", r: "Needed" },
    { n: "Pick up visiting family", w: 2, k: "drive", r: "Needed" },
    { n: "Come along to carry bags", w: 1, k: "there" },
    { n: "Day program pickups", w: 2, k: "drive", r: "Tue", c: ["dementia"] },
    { n: "Take over the car keys", w: 2, k: "there", c: ["dementia", "aging"] },
  ],
  "Money & paperwork": [
    { n: "Pay bills", w: 1, k: "paper", r: "Mon" },
    { n: "Insurance calls", w: 2, k: "phone", p: 1, far: 1, r: "Needed" },
    { n: "Sort the mail", w: 1, k: "paper", r: "Wed" },
    { n: "Track medical bills and claims", w: 2, k: "paper" },
    { n: "Medicare or benefits paperwork", w: 2, k: "paper" },
    { n: "Advance directive and wishes", w: 3, k: "paper", wishes: 1 },
    { n: "Power of attorney", w: 3, k: "paper", wishes: 1 },
    { n: "Track shared care costs", w: 1, k: "paper" },
    { n: "Gather passwords and accounts", w: 2, k: "paper" },
    { n: "Will and estate papers", w: 3, k: "paper", c: ["hospice", "aging"] },
    { n: "Memorial plans", w: 3, k: "paper", c: ["hospice"] },
    { n: "Medical leave paperwork for work", w: 2, k: "paper", c: ["cancer", "other"] },
  ],
  // Kids and teens get their own small list. Nice to have: nothing here is ever urgent, and a missed
  // one doesn't weigh on anyone's share. kp = Pebble picks it when a kid or teen is helping.
  "Kids & teens": [
    { n: "Call or video chat", w: 1, k: "there", r: "Sun", kp: 1 },
    { n: "Make a card or drawing", w: 1, k: "there", kp: 1 },
    { n: "Read or play a game together", w: 1, k: "there", r: "Sat", kp: 1 },
    { n: "Bring in the mail", w: 1, k: "there", r: "Daily" },
    { n: "Water the plants", w: 1, k: "there", r: "Wed" },
    { n: "Feed or walk the pets", w: 1, k: "there", r: "Daily" },
    { n: "Help set the table", w: 1, k: "cook", r: "Sun" },
    { n: "Share photos and school news", w: 1, k: "phone", r: "Fri" },
    { n: "Help carry groceries", w: 1, k: "there", r: "Sat" },
    { n: "Look at old photos together", w: 1, k: "there", c: ["dementia", "aging"] },
    { n: "Record a story or song", w: 1, k: "there", c: ["hospice"] },
  ]
};

const MATTERS_THEM = [
  { id: "comfort", t: "Comfort at home", d: "Pain managed, in their own bed" },
  { id: "family", t: "Time with family", d: "Visits, calls, meals together" },
  { id: "wishes", t: "Their wishes in order", d: "Paperwork, plans, money" },
  { id: "himself", t: "Staying who they are", d: "Routines, faith, food he loves" },
];
const MATTERS_YOU = [
  { id: "alone", t: "Not carrying it all alone", d: "Sharing the load fairly" },
  { id: "next", t: "Knowing what’s next", d: "Fewer surprises" },
  { id: "inperson", t: "Being there in person", d: "More time at the house" },
  { id: "far", t: "Helping from far away", d: "Calls, orders, paperwork" },
];
const STRENGTHS = [
  { id: "drive", t: "Driving", d: "Appointments, errands, pickups" },
  { id: "phone", t: "Phone calls", d: "Insurance, pharmacies, family updates" },
  { id: "paper", t: "Paperwork & bills", d: "Forms, claims, paying bills" },
  { id: "meds", t: "Meds & pharmacy", d: "Refills, pill boxes, tracking symptoms" },
  { id: "cook", t: "Cooking", d: "Meals, groceries, meal plans" },
  { id: "there", t: "Being there", d: "Visits, personal care, overnights" },
];
const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const DAY_FULL = { Mon: "Monday", Tue: "Tuesday", Wed: "Wednesday", Thu: "Thursday", Fri: "Friday", Sat: "Saturday", Sun: "Sunday" };
// Task size = stone size. Bigger tasks get bigger stones, so a jar shows who's carrying the most.
const WEIGHT_LABEL = { 1: "Small", 2: "Medium", 3: "Large" };
const SIZE_HINT = { 1: "Quick, about an hour or less", 2: "A few hours, or a trip out", 3: "Half a day or more, or overnight" };
// Pebble's guess for a task someone writes in.
const SIZE_WORDS = [
  [3, /overnight|night off|stay|move|moving|install|set up|hospital|renovat|whole day|weekend|trip/i],
  [2, /appointment|doctor|ride|drive|cook|meal|clean|bath|shop|grocer|walk|outing|yard|therapy|visit|repair|errand/i],
];
const guessSize = (n) => (SIZE_WORDS.find(([, re]) => re.test(n)) || [1])[0];
// Drops stones into a jar one at a time, like real ones: each falls to the lowest spot it can reach,
// resting on the curved tops of the stones below (stones are treated as ellipses), and rolls until it
// touches a neighbor or the glass. Ties lean to the middle, with a small fixed wobble so piles don't look ruled.
// sizes: [[w, h], ...] in px. Returns the top-left of each stone, or null once the jar is full to the top.
function packStones(sizes, { left = 6, right = 80, base = 104, top = 18, round = 24 } = {}) {
  const placed = [], mid = (left + right) / 2;
  const arc = (dx, a) => Math.sqrt(Math.max(0, 1 - (dx / a) ** 2));
  // The jar's floor curves up into its rounded bottom corners, so stones near the glass sit a little higher.
  const floor = (c) => { const d = Math.max(left + round - c, c - (right - round), 0); return base - round + Math.sqrt(Math.max(0, round * round - d * d)); };
  return sizes.map(([w, h], i) => {
    const a = w / 2, b = h / 2;
    let best = null;
    for (let x = left; x <= right - w; x++) {
      const cx = x + a;
      let cy = base - b;
      for (let c = cx - a; c <= cx + a; c += 1) cy = Math.min(cy, floor(c) - b * arc(c - cx, a));
      for (const p of placed) {
        if (Math.abs(p.cx - cx) >= p.a + a) continue;
        // Where the two outlines would touch, sampled across their overlap.
        const lo = Math.max(p.cx - p.a, cx - a), hi = Math.min(p.cx + p.a, cx + a);
        for (let c = lo; c <= hi; c += 1) cy = Math.min(cy, p.cy - p.b * arc(c - p.cx, p.a) - b * arc(c - cx, a) + 1.5);
      }
      // A stone rolls until it touches a neighbor or the glass, so open gaps cost a little.
      const gap = Math.min(x - left, right - w - x, ...placed.map((p) => Math.abs(p.cx - cx) - p.a - a).filter((g) => g >= -1));
      const score = cy - Math.max(0, gap) * 0.25 - Math.abs(cx - mid) * 0.03 + Math.sin(i * 2.4 + x * 0.9) * 0.5;
      if (!best || score > best.score) best = { x, cx, cy, score };
    }
    if (!best || best.cy - b < top) return null;
    placed.push({ cx: best.cx, cy: best.cy, a, b });
    return { x: best.x, y: best.cy - b };
  });
}
// A full jar shows what fits, plus a count of the rest.
const jarMore = (n) => (n > 0 ? `<span class="jar-more">+${n}</span>` : "");
const WEIGHT_HOURS = { 1: 1, 2: 3, 3: 6 }; // rough weekly hours, used for the fair split

// Today is Tue Oct 20, 2026 in the prototype. Dates are stored as "YYYY-MM-DD", times as "HH:MM".
const TODAY = new Date(2026, 9, 20);
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
const fromIso = (s) => { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); };
const addDays = (n) => iso(new Date(TODAY.getFullYear(), TODAY.getMonth(), TODAY.getDate() + n));
const fmtDate = (s) => fromIso(s).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
const hour12 = (h) => h % 12 || 12;
const meridiem = (h) => (h % 24 < 12 ? "AM" : "PM");
function fmtTime(t) {
  if (!t) return "";
  const [h, m] = t.split(":").map(Number);
  return `${hour12(h)}${m ? `:${String(m).padStart(2, "0")}` : ""} ${meridiem(h)}`;
}
function repeatLabel(days) {
  const set = DAYS.filter((d) => days.includes(d));
  if (!set.length) return "As needed";
  if (set.length === 7) return "Every day";
  if (set.join() === "Mon,Tue,Wed,Thu,Fri") return "Weekdays";
  if (set.join() === "Sat,Sun") return "Weekends";
  return set.length === 1 ? `Every ${set[0]}` : set.join(", ");
}
const dayKey = (date) => DAYS[(date.getDay() + 6) % 7];
const occurs = (t, date) => (t.kind === "once" ? t.date === iso(date) : t.days.includes(dayKey(date)));
const shift = (s, n) => { const d = fromIso(s); d.setDate(d.getDate() + n); return iso(d); };
const mondayOf = (s) => shift(s, -((fromIso(s).getDay() + 6) % 7));
const whenLabel = (t) => `${t.kind === "once" ? fmtDate(t.date) : repeatLabel(t.days)}${t.time ? ` · ${fmtTime(t.time)}` : ""}`;
function spokenWhen(t) {
  const day = t.kind === "once"
    ? `on ${fromIso(t.date).toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}`
    : t.days.length === 7 ? "every day" : `every ${listWords(DAYS.filter((d) => t.days.includes(d)).map((d) => DAY_FULL[d]))}`;
  return t.time ? `${day} at ${fmtTime(t.time)}` : day;
}

/* ---------- State ---------- */

// Week grids are 7 days x 24 hourly cells. Blocks are [startHour, endHour).
const HOURS = { from: 6, to: 22 };
function weekOf(blocks) {
  return DAYS.map((d) => {
    const row = Array(24).fill(false);
    (blocks[d] || []).forEach(([a, b]) => { for (let h = a; h < b; h++) row[h] = true; });
    return row;
  });
}
// Pretend busy times each calendar brings in when connected.
const SAMPLE_BUSY = {
  "Google Calendar": { Mon: [[18, 19]], Sat: [[10, 12]] },
  "Apple Calendar": { Wed: [[19, 21]], Sun: [[9, 11]] },
  Outlook: { Mon: [[9, 17]], Tue: [[9, 17]], Wed: [[9, 17]], Thu: [[9, 17]], Fri: [[9, 13]] },
};
const busyFrom = (cals) => weekOf(Object.fromEntries(DAYS.map((d) => [d, cals.flatMap((c) => SAMPLE_BUSY[c][d] || [])])));
function fmtRange(a, b) {
  return meridiem(a) === meridiem(b) && b - a < 12 ? `${hour12(a)}–${hour12(b)} ${meridiem(b)}` : `${hour12(a)} ${meridiem(a)}–${hour12(b)} ${meridiem(b)}`;
}
function blocksOf(row) {
  const out = [];
  for (let h = 0; h < 24; h++) if (row[h] && !row[h - 1]) { let e = h; while (row[e]) e++; out.push([h, e]); }
  return out;
}

const initialState = () => ({
  path: null, // "pebble" | "manual"
  kit: null, // "yes" | "no" | null (not decided). The app works fully without the physical kit.
  screen: "splash",
  history: [],
  lovedOne: "",
  conditions: [],
  stage: null, // "start" | "daily" | "final"
  pebbleOff: false,
  them: [],
  own: { cond: [], them: [], you: [], strengths: [], avoid: [] }, // write-in answers per question
  you: [],
  tasks: [], // {id, n, w (size 1-3), pw (Pebble's size), k, cat, on, pebble, kind:"once"|"repeat", days, date, time, who}
  taskTab: null,
  dv: { view: "week", week: mondayOf(iso(TODAY)), month: [TODAY.getFullYear(), TODAY.getMonth()], sel: iso(TODAY) },
  people: [
    { id: "you", name: "You", img: "avatar-you.png", tier: "main", note: "Main caregiver · your jar", cap: null },
  ],
  cals: [], // connected calendar names
  availDay: 0,
  busy: weekOf({}),
  free: weekOf({}),
  strengths: [],
  avoid: [], // task kinds "you" would rather not get; Pebble steers them elsewhere
  splitTouched: false,
  sent: false,
  flowKey: "onboard", // which section the step screens belong to
  setup: null, // Home checklist: which sections are done, set when onboarding ends
});
let S = initialState();
let lastDir = "fwd";

/* ---------- Flow ---------- */

// Onboarding is three quick steps. Everything else is a section run from the Home checklist.
const FLOWS = {
  onboard: ["about", "people", "colors"],
  pebble: ["them", "you", "tasks"],
  manual: ["tasks"],
  calendar: ["calendar", "avail"],
  schedule: ["dates"],
  split: ["strengths", "split", "review"],
};
const SECTION_OF = { pebble: "tasks", manual: "tasks", calendar: "calendar", schedule: "schedule", split: "split" };
const flow = () => FLOWS[S.flowKey || "onboard"];
const stepIndex = () => flow().indexOf(S.screen);

function go(screen, dir = "fwd") {
  if (screen === S.screen) return;
  if (dir === "fwd") S.history.push(S.screen);
  lastDir = dir;
  closeSheet();
  onEnter(screen);
  S.screen = screen;
  render();
}
function next() {
  const f = flow();
  const i = f.indexOf(S.screen);
  // A connected calendar already knows when you're busy, so the free-time step is skipped.
  if (S.screen === "calendar" && S.cals.length) { freeFromCalendar(); finishSection(); return; }
  if (i < f.length - 1) go(f[i + 1]);
  else finishSection();
}
function finishSection() {
  if (S.flowKey === "onboard") { finishOnboarding(); return; }
  // A side trip (like adding your free time from the split) comes back where it started.
  if (S.returnTo) { const r = S.returnTo; S.returnTo = null; if (S.setup) S.setup[SECTION_OF[S.flowKey]] = true; S.flowKey = r.flow; S.splitTouched = false; go(r.screen); return; }
  setupDone(SECTION_OF[S.flowKey]);
}
// Daytime hours the calendar doesn't mark busy count as free.
function freeFromCalendar() {
  S.free = S.free.map((row, day) => row.map((on, h) => on || (h >= 9 && h < 19 && !S.busy[day][h])));
}
function back() {
  const prev = S.history.pop();
  if (prev) { lastDir = "back"; closeSheet(); S.screen = prev; render(); return; }
  // Screens opened like a tab have no history; Back still has to go somewhere.
  if (APP_SCREENS.has(S.screen) && S.screen !== "home") tabTo("home");
}

function onEnter(screen) {
  if (APP_SCREENS.has(screen)) { appEnter(screen); return; }
  if (screen === "tasks" && !S.tasks.some((t) => t.cat)) seedTasks();
  // Pebble proposes a split; manual starts unassigned so you can pick, or ask Pebble.
  if (screen === "split" && S.path === "pebble" && !S.splitTouched) suggestSplit();
}

// Suggests every general task plus the ones for the picked conditions.
// Library tasks have a category; anything else (like tasks from the other views) is kept.
const clearLibrary = () => { S.tasks = S.tasks.filter((t) => !t.cat); };
function seedTasks() {
  let id = 0;
  clearLibrary();
  S.splitTouched = false;
  Object.entries(TASK_LIBRARY).forEach(([cat, items]) => {
    items.forEach((t) => {
      if (t.c && !t.c.some(hasCond)) return;
      const kids = S.people.some((p) => p.tier === "kid");
      const starter = STARTER[stageOf()].includes(t.n);
      const pebble = !starter && S.path === "pebble" && pebbleOn()
        && (!!t.p || (t.wishes && S.them.includes("wishes")) || (t.far && S.you.includes("far")) || (t.kp && kids));
      S.tasks.push({
        id: `t${id++}`, n: t.n, w: t.w, pw: t.w, k: t.k, y: cat === KID_CAT, cat, on: starter || pebble, pebble, starter,
        kind: t.r ? "repeat" : "once",
        days: t.r === "Daily" ? [...DAYS] : t.r === "Needed" ? [] : [t.r || "Sat"],
        date: addDays(1 + (id % 9)),
        time: "",
        who: null,
      });
    });
  });
  S.taskTab = Object.keys(TASK_LIBRARY)[0];
}
const picked = () => S.tasks.filter((t) => t.on);
const person = (id) => S.people.find((p) => p.id === id);
const yourCap = () => S.free.flat().filter(Boolean).length;
// No free time set yet? Guess you have about what the others have, so you're not left out of the split.
const guessYourCap = () => {
  const others = S.people.filter((p) => p.tier === "main" && p.id !== "you" && p.cap);
  return others.length ? Math.round(others.reduce((n, p) => n + p.cap, 0) / others.length) : 6;
};
const capOf = (p) => (p.id === "you" ? yourCap() || guessYourCap() : p.cap);

function loads() {
  const out = {};
  S.people.forEach((p) => (out[p.id] = 0));
  picked().forEach((t) => { if (t.who) out[t.who] += hoursOf(t); });
  return out;
}
function hoursOf(t) {
  if (t.y) return 0; // nice to have; never part of the fair split
  const base = WEIGHT_HOURS[t.w];
  if (t.kind === "once") return base * 0.5;
  return base * (0.6 + 0.4 * t.days.length);
}

// Trusted circle only gets light tasks; kids and teens only get kid tasks.
const tierFits = (p, t) => (t.open ? t.open.includes(p.tier) : p.tier === "trusted" ? t.w === 1 : p.tier === "kid" ? t.y : true);
// Driving, cooking and being there need someone close by.
const nearTask = (t) => !t.remote && ["drive", "there", "cook"].includes(t.k);
const canTake = (p, t) => tierFits(p, t) && !(nearTask(t) && p.remote);
const TIER_NOTE = { main: "Invite sent by text", trusted: "Invite sent by text", kid: "Kid tasks only" };

// Greedy fair split: heaviest first, to whoever has the most room left. Preferences nudge "You" toward or away.
function suggestSplit() {
  const load = {};
  S.people.forEach((p) => (load[p.id] = 0));
  const kids = S.people.filter((p) => p.tier === "kid");
  picked().filter((t) => t.y).forEach((t, i) => { t.who = kids.length ? kids[i % kids.length].id : null; });
  const tasks = picked().filter((t) => !t.y).sort((a, b) => hoursOf(b) - hoursOf(a));
  tasks.forEach((t) => {
    let best = null, bestScore = Infinity;
    S.people.forEach((p) => {
      if (!canTake(p, t)) return;
      const cap = capOf(p) || 0.1;
      let score = (load[p.id] + hoursOf(t)) / cap;
      if (p.id === "you" && S.strengths.includes(t.k)) score -= 0.25;
      if (p.id === "you" && S.avoid.includes(t.k)) score += 0.6;
      if (score < bestScore) { bestScore = score; best = p; }
    });
    if (best && bestScore <= 1.05) { t.who = best.id; load[best.id] += hoursOf(t); }
    else t.who = null;
  });
  S.splitTouched = true;
}

/* ---------- Shared pieces ---------- */

// Round for pick-one, square for pick-many (box = true), so the shape says how many you can choose.
const check = (on, box = false) => box
  ? `<span class="check box ${on ? "on" : "off"}">${on ? `<img src="${A("check.svg")}" alt="">` : ""}</span>`
  : on
    ? `<span class="check on"><img src="${A("check.svg")}" alt=""></span>`
    : `<span class="check off"><img src="${A("radio-empty.svg")}" alt=""></span>`;
const weightPill = (w) => `<span class="weight" title="${WEIGHT_LABEL[w]} task"><span class="wt-stone">${gem("open", { size: "xs", cls: `w${w}` })}</span>${WEIGHT_LABEL[w]}</span>`;
const hasKit = () => S.kit === "yes";
// How big is this task? Pebble's pick is tagged so people can see what it guessed.
function sizeSheet(t) {
  openSheet(`<h3>How big is this task?</h3><p class="small">Bigger tasks get bigger stones, so everyone can see who's carrying what.</p>
    <div class="size-opts">${[1, 2, 3].map((w) => `<button class="size-opt ${t.w === w ? "on" : ""}" aria-pressed="${t.w === w}" data-act="setSize" data-id="${t.id}" data-w="${w}">
      <span class="so-stone">${gem("open", { cls: `w${w}` })}</span>
      <span class="tl-txt"><span class="n">${WEIGHT_LABEL[w]}${pebbleOn() && (t.pw || 0) === w ? `<em class="peb-pick">Pebble's pick</em>` : ""}</span><span class="m">${SIZE_HINT[w]}</span></span>
      ${t.w === w ? `<span class="check on"><img src="${A("check.svg")}" alt=""></span>` : ""}</button>`).join("")}</div>
    ${hasKit() ? `<p class="small center">Your home kit has small, medium and large stones to match.</p>` : ""}`);
}
const avatar = (p, cls = "") => p.img
  ? `<span class="avatar ${cls}"><img src="${A(p.img)}" alt=""></span>`
  : `<span class="avatar ${cls}">${esc(p.name[0])}</span>`;
const stone = (assigned) => `<img class="stone" src="${A(assigned ? "stone-progress.svg" : "stone-unassigned.svg")}" alt="">`;

function topbar({ skip = true } = {}) {
  const f = flow();
  const i = stepIndex();
  const total = f.filter((s) => s !== "review").length; // review isn't a counted step
  return `<div class="topbar">
    <button class="back" data-act="back" aria-label="Back"><img src="${A("back.svg")}" alt=""></button>
    <div class="progress">${Array.from({ length: total }, (_, k) => `<span class="${k <= i ? "on" : ""}"></span>`).join("")}</div>
    ${skip ? `<button class="skip" data-act="next">Skip</button>` : ""}
  </div>`;
}
const eyebrow = (section) => {
  const n = flow().filter((s) => s !== "review").length;
  return `<p class="eyebrow">${section}${n > 1 ? ` · Step ${stepIndex() + 1} of ${n}` : ""}</p>`;
};
function footer(label = "Next", { disabled = false, act = "next", backBtn = true } = {}) {
  return `<div class="footer">
    <button class="btn-primary" data-act="${act}" ${disabled ? "disabled" : ""}>${label}</button>
    ${backBtn ? `<button class="btn-text" data-act="back">Back</button>` : `<span style="height:44px"></span>`}
  </div>`;
}

/* ---------- Screens ---------- */

const SCREENS = {};

SCREENS.welcome = () => {
  // Four family jars, drawn with the same stones as the rest of the app. Done stones sit at the bottom.
  const fill = [
    ["done", "done", "done", "open", "progress", "urgent", "progress"],
    ["done", "done", "open", "open", "progress", "progress", "urgent", "open"],
    ["done", "done", "open", "progress", "open"],
    ["done", "done", "open"],
  ];
  const jars = `<div class="shelf-jars">${fill.map((ts) => {
    const pos = jarSlots(ts.length);
    return `<div class="rjar"><div class="glassbox"><img class="glass" src="${A("jar.png")}" alt="">
      ${ts.map((st, i) => gem(st, { size: "s", cls: `w${sampleW(i)}`, style: `left:${pos[i].x}px;top:${pos[i].y}px` })).join("")}</div></div>`;
  }).join("")}</div>`;
  const steps = [["Who you're caring for", "Their name and what they're facing"], ["Who's helping", "Invite family now, or later"], ["Your stone colors", "What each glow means to you"]];
  return `<div class="content no-top">
    <h1 class="title xl">Let's get you set up</h1>
    <p class="sub" style="margin-top:10px">Three quick things, about 2 minutes. Tasks and the stones can wait until you're ready.</p>
    <div class="card hero">
      <div class="jars-illus" aria-label="Four jars with glowing stones">${jars}</div>
    </div>
    <div class="card steps-list welcome-steps">${steps.map(([t, d], i) => `<div class="step"><span class="num">${i + 1}</span><span><b>${t}</b><small>${d}</small></span></div>`).join("")}</div>
    <button class="skip-onboarding" data-act="skipToApp">Skip onboarding (testing) →</button>
  </div>
  <div class="footer"><button class="btn-primary" data-act="begin">Start</button><span style="height:20px"></span></div>`;
};

// First stop of "Add what needs doing" on the Home checklist.
SCREENS.taskStart = () => `${navtop("Home")}
  <div class="content">
    <h1 class="title">How do you want to start your list?</h1>
    <p class="sub">Either way, you pick every task and can change it later.</p>
    <button class="path ${pebbleOn() ? "rec" : "off"}" data-act="${pebbleOn() ? "start" : "pebbleToggle"}" data-path="pebble">
      <img class="path-pebble" src="${A("pebble/pebble_base_front.png")}" alt="">
      <span><span class="t">Start from suggestions</span><span class="d">${pebbleOn() ? "Faster. Two quick questions, then a starter list to trim." : "Pebble is off. Tap to turn it back on."}</span></span>
      <img class="chev" src="${A("chevron.svg")}" alt="">
    </button>
    <button class="path" data-act="start" data-path="manual">
      <span class="ico"><img src="${A("checklist.svg")}" width="20" height="18" alt=""></span>
      <span><span class="t">Write my own list</span><span class="d">Pick from the full list yourself.</span></span>
      <img class="chev" src="${A("chevron.svg")}" alt="">
    </button>
    <button class="whats-pebble" data-act="go" data-to="pebbleInfo">Who suggests the tasks?</button>
  </div>`;

// Explains Pebble before anyone picks the Pebble path: what it is, how it works, and what it can see.
SCREENS.pebbleInfo = () => {
  const steps = [
    ["think_01", "You answer a few questions", "What they're facing, what matters to them and to you, and who's helping."],
    ["research_glasses_focused", "Pebble drafts a plan", "Starter tasks for the situation, then a fair split by task size, free time, and strengths."],
    ["carry_03", "You decide", "Change, remove, or reassign anything. Nothing goes to your family until you send it."],
  ];
  const can = ["Suggest tasks you might not think of", "Balance the load so no one burns out", "Explain why it picked someone"];
  const wont = ["Give medical advice or make care decisions", "Contact anyone without you", "Read notes, messages, or medical records"];
  const privacy = [
    ["Only what you tell it", "Your setup answers and their goals. Calendars share busy or free, never event details."],
    ["Your family sees the plan, not your answers", "Private answers, like what matters to you, stay with you."],
    ["Off anytime", "Turn Pebble off and set things up by hand. You can clear its suggestions in Settings."],
  ];
  return `${navtop("Back")}
  <div class="content pebble-page">
    <div class="card pebble-hero" aria-label="Pebble, a little stone character, suggesting a task">
      <div class="ph-glow"></div>
      <img class="ph-pebble" src="${A("pebble/pebble_offer_open_hands.png")}" alt="">
      <div class="ph-bubble b1"><span>Bill lives 10 min away. Want him on Thursday's drive?</span></div>
      <div class="ph-bubble b2"><span class="ph-chip on">Yes, ask Bill</span><span class="ph-chip">Change</span></div>
    </div>
    <p class="eyebrow">Meet Pebble</p>
    <h1 class="title">An AI helper for the planning part</h1>
    <p class="sub">Pebble turns a few answers into a starter plan, so you don't have to build one from a blank page. You stay in charge of every choice.</p>

    <p class="section-h">How it works</p>
    <div class="card steps-list">${steps.map(([img, t, d], i) => `<div class="step"><img class="step-pebble" src="${A(`pebble/pebble_${img}.png`)}" alt=""><span><b>${i + 1}. ${t}</b><small>${d}</small></span></div>`).join("")}</div>

    <div class="can-grid">
      <div class="card can"><p class="eyebrow">Pebble can</p>${can.map((x) => `<p class="ci yes">${x}</p>`).join("")}</div>
      <div class="card can"><p class="eyebrow grey">Pebble won't</p>${wont.map((x) => `<p class="ci no">${x}</p>`).join("")}</div>
    </div>

    <p class="section-h">Safety and privacy</p>
    <div class="privacy-hero"><img src="${A("pebble/pebble_sensitive_01.png")}" alt=""><p>Care details are personal. Pebble only uses what you share during setup, and it treats it gently.</p></div>
    <div class="card tlist">${privacy.map(([t, d]) => `<div class="tline"><span class="circle-ico"><img src="${A("lock.svg")}" alt=""></span><span class="tl-txt"><span class="n">${t}</span><span class="m">${d}</span></span></div>`).join("")}</div>
    <div class="card info caution"><img class="warn-pebble" src="${A("pebble/pebble_peer_down.png")}" alt=""><span class="small"><b>Pebble can make mistakes.</b> Check dates, doses, and medical details with the care team. In an emergency, call 911.</span></div>
  </div>
  <div class="footer">
    <button class="btn-primary" data-act="start" data-path="pebble">Start with Pebble</button>
    <button class="btn-text" data-act="start" data-path="manual">Set it up myself instead</button>
  </div>`;
};

SCREENS.about = () => `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("About them")}
    <h1 class="title">Who are you caring for?</h1>
    <p class="sub">This picks the starter tasks. You can change any of them.</p>
    <label class="card cond-name"><span>Name</span><input data-input="lovedOne" value="${esc(S.lovedOne)}" maxlength="20" aria-label="Their name"></label>
    <p class="label">Where are things right now?</p>
    ${STAGES.map((g) => `<button class="option ${S.stage === g.id ? "on" : ""}" data-act="stage" data-id="${g.id}">
      <span class="txt"><span class="t">${g.t}</span><span class="d">${g.d}</span></span>${check(S.stage === g.id)}</button>`).join("")}
    <p class="label">What are they living with? <span class="small">Optional · pick any</span></p>
    ${CONDITIONS.map((c) => {
      const on = S.conditions.includes(c.id);
      return `<button class="option ${on ? "on" : ""}" data-act="condition" data-id="${c.id}">
      <span class="txt"><span class="t">${c.t}</span></span>${check(on, true)}
    </button>`;
    }).join("")}
    ${writeIns("cond", "Write your own")}
  </div>
  ${footer("Next", { disabled: !S.lovedOne.trim() })}`;

SCREENS.them = () => `${topbar()}
  <div class="content">
    ${eyebrow("Suggestions")}
    <h1 class="title">What matters most to ${esc(S.lovedOne)} right now?</h1>
    <p class="sub">Pick any, or write your own.</p>
    ${MATTERS_THEM.map((m) => `<button class="option ${S.them.includes(m.id) ? "on" : ""}" data-act="toggleThem" data-id="${m.id}">
      <span class="txt"><span class="t">${m.t}</span></span>${check(S.them.includes(m.id), true)}
    </button>`).join("")}
    ${writeIns("them", "Write your own")}
  </div>
  ${footer()}`;

// Your own answers sit with the others as picked options. Tap one to remove it.
function writeIns(key, placeholder) {
  const list = S.own[key];
  return `${list.map((v, i) => `<button class="option on own" data-act="dropOwn" data-key="${key}" data-i="${i}" aria-label="Remove ${esc(v)}">
      <span class="txt"><span class="t">${esc(v)}</span></span>${check(true, true)}</button>`).join("")}
    <form class="write-own" data-form="own" data-key="${key}"><img src="${A("plus.svg")}" alt=""><input name="v" placeholder="${placeholder}" aria-label="${placeholder}"><button class="go">Add</button></form>`;
}

SCREENS.you = () => `${topbar()}
  <div class="content">
    ${eyebrow("Suggestions")}
    <h1 class="title">What matters most to you?</h1>
    <p class="sub lock"><img src="${A("lock.svg")}" width="14" height="14" alt="">Only you see this answer.</p>
    ${MATTERS_YOU.map((m) => `<button class="option ${S.you.includes(m.id) ? "on" : ""}" data-act="toggleYou" data-id="${m.id}">
      <span class="txt"><span class="t">${m.t}</span></span>${check(S.you.includes(m.id), true)}
    </button>`).join("")}
    ${writeIns("you", "Write your own")}
  </div>
  ${footer("See suggested tasks")}`;

SCREENS.tasks = () => {
  const cats = Object.keys(TASK_LIBRARY);
  const tab = S.taskTab;
  const items = S.tasks.filter((t) => t.cat === tab);
  const nextCat = cats[cats.indexOf(tab) + 1];
  const pebbleCount = S.tasks.filter((t) => t.pebble).length, starterCount = S.tasks.filter((t) => t.starter).length;
  const stage = STAGES.find((g) => g.id === stageOf());
  // The starter set, Pebble's picks and your own sit on top; the rest of the library folds away so the list isn't a wall.
  const top = items.filter((t) => t.starter || t.pebble || t.mine);
  const rest = items.filter((t) => !top.includes(t)), restOn = rest.filter((t) => t.on).length;
  const open = !top.length || S.moreOpen?.[tab];
  const taskRow = (t) => `<div class="row ${t.on ? "on" : ""}">
        <button data-act="toggleTask" data-id="${t.id}" style="display:flex;align-items:center;gap:12px;flex:1;text-align:left">${check(t.on, true)}<span class="name">${esc(t.n)}${t.pebble ? `<span class="tag">Pebble</span>` : ""}</span></button>
        ${t.y ? "" : `<button data-act="sizeSheet" data-id="${t.id}" aria-label="Size: ${WEIGHT_LABEL[t.w]}. Change size">${weightPill(t.w)}</button>`}
      </div>`;
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("Tasks")}
    <h1 class="title">What needs doing?</h1>
    <p class="sub">Check the picks in each tab. Open More suggestions if something's missing. Tap a size to change it.</p>
    <div class="card r20 starter-note"><span class="sn-ic">${icon("myjar")}</span><span class="small" style="color:var(--ink)"><b>${starterCount} starter tasks</b> for ${stage.s}, put together with hospice nurses and doulas.${pebbleCount ? ` Pebble added <b>${pebbleCount}</b> from your answers.` : ""} Uncheck anything that doesn't fit.</span></div>
    <div class="tabs" role="tablist">${cats.map((c) => {
      const n = S.tasks.filter((t) => t.cat === c && t.on).length;
      return `<button role="tab" class="${c === tab ? "on" : ""}" aria-selected="${c === tab}" data-act="taskTab" data-id="${esc(c)}">${esc(c)}${n ? `<b>${n}</b>` : ""}</button>`;
    }).join("")}</div>
    ${tab === KID_CAT ? `<div class="card r20 kid-note"><b>Small ways kids and teens can help</b><span class="small">Nice to have, never urgent. If one gets missed, it doesn't count against anyone.</span></div>` : ""}
    <div class="group-head"><p class="eyebrow grey">${top.length ? "Suggested" : esc(tab)}</p><span class="count">${items.filter((t) => t.on).length} of ${items.length} picked</span></div>
    ${top.length ? `<div class="card r20"><div class="list">${top.map(taskRow).join("")}</div></div>` : ""}
    ${rest.length ? (top.length ? `<button class="more-toggle" data-act="moreTasks" aria-expanded="${open}">
        <span>${open ? "Fewer suggestions" : `More suggestions <small>${rest.length}${restOn ? ` · ${restOn} picked` : ""}</small>`}</span><span class="hs-chev" aria-hidden="true"></span>
      </button>` : "") + (open ? `<div class="card r20"><div class="list">${rest.map(taskRow).join("")}</div></div>` : "") : ""}
    <form class="write-own" data-form="task"><img src="${A("plus.svg")}" alt=""><input name="v" placeholder="Add your own to ${esc(tab)}"><button class="go">Add</button></form>
    ${nextCat ? `<button class="next-tab" data-act="taskTab" data-id="${esc(nextCat)}">Next: ${esc(nextCat)}<img src="${A("chevron.svg")}" alt=""></button>` : ""}
  </div>
  ${footer(picked().length ? `Save ${picked().length} task${picked().length > 1 ? "s" : ""}` : "Pick at least one task", { disabled: !picked().length })}`;
};

const taskPill = (t) => `<button class="tpill ${t.kind}" data-act="editDate" data-id="${t.id}">${esc(t.n)}${t.time ? `<small>${fmtTime(t.time)}</small>` : ""}</button>`;

// Pebble guesses when each task happens, so the screen is a check, not a quiz. Tasks are grouped
// by how they happen, which also teaches the three kinds before anyone opens a sheet.
const byFriday = () => { const f = shift(mondayOf(iso(TODAY)), 4); return f < iso(TODAY) ? addDays(3) : f; };
const howOf = (t) => (t.kind === "once" ? "once" : t.days.length ? "repeat" : "needed");
const HOW = [
  ["repeat", "Repeats", "On the calendar every week"],
  ["once", "One time", "Done once, by a date"],
  ["needed", "As needed", "Stays off the calendar until it comes up"],
];
const whenLine = (t) => ({ once: `By ${fmtDate(t.date)}`, repeat: repeatLabel(t.days), needed: "When it comes up" })[howOf(t)] + (t.time ? ` · ${fmtTime(t.time)}` : "");

SCREENS.dates = () => {
  const tasks = picked();
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("Tasks")}
    <h1 class="title">When does each happen?</h1>
    <p class="sub">${S.path === "pebble" ? "Pebble made a guess for each. Tap any that look wrong." : "Tap a task to say when it happens."}</p>
    ${HOW.map(([k, label, hint]) => {
      const list = tasks.filter((t) => howOf(t) === k);
      return list.length ? `<div class="pg-head when-head"><b>${label}</b><span>${hint}</span></div>
      <div class="card tlist when-card">${list.map((t) => `<button class="when-item" data-act="editDate" data-id="${t.id}">
          <span class="tl-txt"><span class="n">${esc(t.n)}</span><span class="m">${esc(whenLine(t))}</span></span>${chev}</button>`).join("")}</div>` : "";
    }).join("")}
    <button class="next-tab" data-act="weekPreview">Preview the week${chev}</button>
  </div>
  ${footer("Looks right")}`;
};

function weekPreview() {
  const days = DAYS.map((_, i) => fromIso(shift(S.dv.week, i))), end = days[6];
  const fmt = (d, month) => d.toLocaleDateString("en-US", { month: month ? "short" : undefined, day: "numeric" });
  const loose = picked().filter((t) => howOf(t) === "needed");
  openSheet(`<h3>Your week</h3>
    <div class="cal-head"><button data-act="pvMove" data-id="-1" ${S.dv.week <= mondayOf(iso(TODAY)) ? "disabled" : ""} aria-label="Previous week"><img src="${A("chevron.svg")}" alt="" style="transform:scaleX(-1)"></button>
      <b>${fmt(days[0], true)} – ${fmt(end, days[0].getMonth() !== end.getMonth())}</b>
      <button data-act="pvMove" data-id="1" aria-label="Next week"><img src="${A("chevron.svg")}" alt=""></button></div>
    <div class="card r20 week-list">${days.map((d) => {
      const items = d < TODAY ? [] : picked().filter((t) => occurs(t, d));
      return `<div class="wl-day ${iso(d) === iso(TODAY) ? "today" : ""}"><span class="wl-date"><b>${dayKey(d)}</b>${d.getDate()}</span>
        <span class="wl-items">${items.map(taskPill).join("") || `<span class="small">Nothing yet</span>`}</span></div>`;
    }).join("")}</div>
    ${loose.length ? `<p class="small" style="margin-top:12px">As needed: ${esc(listWords(loose.map((t) => t.n)))}</p>` : ""}
    <button class="btn-primary" data-act="closeSheet">Done</button>`);
}

// One card per group, each with its own "Add" row, so where a person lands is never a second question.
const PEOPLE_GROUPS = [
  { tier: "main", t: "Main caregivers", hint: "Get the app, a jar, and stones", add: "Add a caregiver" },
  { tier: "trusted", t: "Trusted circle", hint: "Friends and neighbors · light tasks", add: "Add a friend or neighbor" },
  { tier: "kid", t: "Kids & teens", hint: "Their own small tasks, never urgent", add: "Add a kid or teen" },
];
SCREENS.people = () => {
  const line = (p) => `<div class="person">${avatar(p, "s36")}
      <span class="main"><span class="n">${esc(p.name)}</span>${p.id === "you" ? `<span class="m">That's you</span>` : ""}</span>
      ${p.id === "you" || p.joined ? "" : `<span class="badge">Invited</span>`}
    </div>`;
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("People")}
    <h1 class="title">Who's helping?</h1>
    <p class="sub">We'll text each person a link. You can add more later.</p>
    ${PEOPLE_GROUPS.map((g) => `<div class="pgroup">
      <div class="pg-head"><b>${g.t}</b><span>${g.hint}</span></div>
      <div class="card pg-card">${S.people.filter((p) => p.tier === g.tier).map(line).join("")}
        ${S._adding === g.tier
          ? `<form class="pg-form" data-form="person"><input name="v" placeholder="Name or phone number" aria-label="Name or phone number" autofocus><button class="go">Invite</button><button type="button" class="x-btn" data-act="cancelAdd" aria-label="Cancel"><span aria-hidden="true">×</span></button></form>`
          : `<button class="pg-add" data-act="addPerson" data-tier="${g.tier}"><span class="pg-plus" aria-hidden="true">+</span>${g.add}</button>`}
      </div>
    </div>`).join("")}
  </div>
  ${footer()}`;
};

const CALENDARS = [
  { n: "Google Calendar", m: "Your Google account", logo: "logo-google-calendar.svg" },
  { n: "Apple Calendar", m: "iCloud calendars on this phone", logo: "logo-apple-calendar.svg" },
  { n: "Outlook", m: "Work or personal Microsoft account", logo: "logo-outlook.svg" },
];

SCREENS.calendar = () => `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("Your week")}
    <h1 class="title">Bring in your calendars?</h1>
    <p class="sub">Connect as many as you use. Pebble fills in when you’re busy, so you only have to add free time.</p>
    <div class="card r20">${CALENDARS.map(({ n, m, logo }) => {
      const on = S.cals.includes(n);
      return `<button class="cal-opt ${on ? "on" : ""}" data-act="connectCal" data-id="${n}">
        <span class="ic"><img src="${A(logo)}" alt=""></span>
        <span class="main"><span class="n">${n}</span><span class="m">${on ? "Busy times added" : m}</span></span>
        <span class="go">${on ? `<img src="${A("chip-check.svg")}" alt="" width="14" height="11">Connected` : "Connect"}</span>
      </button>`;
    }).join("")}</div>
    <p class="sub lock" style="margin-top:16px"><img src="${A("lock.svg")}" width="14" height="14" alt="">Shoal only sees busy or free, never what your events are.</p>
    <p class="small">Tap a connected calendar to disconnect it.</p>
  </div>
  ${footer(S.cals.length ? "Done" : "Fill in free time by hand")}`;

const DAY_PARTS = [["Morning", 6, 12], ["Afternoon", 12, 17], ["Evening", 17, 22]];
const hourLabel = (h) => `${hour12(h)} ${meridiem(h)}`;

SCREENS.avail = () => {
  const i = S.availDay, day = DAYS[i];
  const hrs = (k) => S.free[k].filter(Boolean).length;
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("Your week")}
    <h1 class="title">When are you free?</h1>
    <p class="sub">Pick a day, then tap the hours you could help.</p>
    <div class="day-tabs">${DAYS.map((d, k) => `<button class="${k === i ? "on" : ""} ${hrs(k) ? "has" : ""}" data-act="availDay" data-id="${k}">${d}<small>${hrs(k) ? `${hrs(k)}h` : "–"}</small></button>`).join("")}</div>
    <div class="card r20 focus-day">
      <div class="fd-head"><b>${DAY_FULL[day]}</b><span class="small">${hrs(i) ? `${hrs(i)}h free` : "No time yet"}</span></div>
      ${DAY_PARTS.map(([label, a, b]) => {
        const open = [];
        for (let h = a; h < b; h++) if (!S.busy[i][h]) open.push(h);
        const all = open.length && open.every((h) => S.free[i][h]);
        const slots = [];
        for (let h = a; h < b; h++) {
          const busy = S.busy[i][h];
          slots.push(`<button class="slot ${busy ? "busy" : S.free[i][h] ? "on" : ""}" data-act="toggleHour" data-id="${h}" ${busy ? "disabled" : ""}>${hourLabel(h)}${busy ? "<small>Busy</small>" : ""}</button>`);
        }
        return `<div class="fd-part"><div class="fd-part-head"><span>${label}</span>${open.length ? `<button class="linkish" data-act="togglePart" data-id="${a}-${b}">${all ? "Clear" : "Select all"}</button>` : ""}</div>
          <div class="slots">${slots.join("")}</div></div>`;
      }).join("")}
      <div class="fd-copy"><span class="small">Same hours on</span><button class="chip" data-act="copyDay" data-id="weekdays">Weekdays</button><button class="chip" data-act="copyDay" data-id="all">Every day</button></div>
    </div>
    <p class="eyebrow grey" style="margin:20px 0 10px">Your week · ${yourCap()}h</p>
    <div class="card r20 ranges">${DAYS.map((d, k) => {
      const bl = blocksOf(S.free[k]);
      return `<button data-act="availDay" data-id="${k}"><b>${d}</b><span class="${bl.length ? "" : "none"}">${bl.length ? bl.map(([a, b]) => fmtRange(a, b)).join(", ") : "Not set"}</span></button>`;
    }).join("")}</div>
    ${S.cals.length ? `<p class="small" style="margin-top:10px">Hours marked busy come from your connected calendar${S.cals.length > 1 ? "s" : ""}.</p>` : ""}
    <p class="sub lock" style="margin-top:12px"><img src="${A("lock.svg")}" width="14" height="14" alt="">Private. Everyone sets their own when they join.</p>
  </div>
  ${footer("Done")}`;
};

// Asked as preference, not skill, so no one has to claim they're good at something to answer.
SCREENS.strengths = () => {
  const any = S.strengths.includes("any");
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("Your preferences")}
    <h1 class="title">What do you like helping with?</h1>
    <p class="sub">Pick any. Pebble leans toward giving you these.</p>
    ${STRENGTHS.map((s) => {
      const on = S.strengths.includes(s.id);
      return `<button class="option ${on ? "on" : ""}" data-act="strength" data-id="${s.id}"><span class="txt"><span class="t">${s.t}</span></span>${check(on, true)}</button>`;
    }).join("")}
    ${writeIns("strengths", "Something else you'd like to do")}
    <button class="option opt-none ${any ? "on" : ""}" data-act="strength" data-id="any"><span class="txt"><span class="t">No preference, split it evenly</span></span>${check(any, true)}</button>
    <div class="pref-avoid">
      <p class="label">Anything you'd rather avoid? <span class="small">Optional</span></p>
      <div class="chips">${STRENGTHS.map((s) => chip(s.t, S.avoid.includes(s.id), "avoid", s.id)).join("")}${S.own.avoid.map((v, i) => `<button class="chip on" data-act="dropOwn" data-key="avoid" data-i="${i}" aria-label="Remove ${esc(v)}"><img src="${A("chip-check.svg")}" alt="">${esc(v)}</button>`).join("")}</div>
      <form class="write-own" data-form="own" data-key="avoid"><img src="${A("plus.svg")}" alt=""><input name="v" placeholder="Something else, like medical care" aria-label="Something else to avoid"><button class="go">Add</button></form>
    </div>
    <p class="small" style="margin-top:14px">Only Pebble sees this. Others just see the plan.</p>
  </div>
  ${footer(S.path === "pebble" ? "See Pebble's split" : "Next: split it up")}`;
};

const chip = (label, on, act, id) => `<button class="chip ${on ? "on" : ""}" data-act="${act}" data-id="${esc(id)}">${on ? `<img src="${A("chip-check.svg")}" alt="">` : ""}${esc(label)}</button>`;

SCREENS.split = () => {
  const L = loads();
  const helpers = S.people;
  const unassigned = picked().filter((t) => !t.who && !t.y);
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("Split")}
    <h1 class="title">Who takes each one?</h1>
    <p class="sub">${S.path === "pebble" && S.splitTouched ? "Pebble's suggestion, weighted by task size and free time. Change anything." : "Leave any unassigned. They glow white."}</p>
    <div class="card loads">
      ${S.people.filter((p) => p.tier === "main" || L[p.id]).map((p) => {
        const cap = capOf(p), pct = Math.min(100, (L[p.id] / cap) * 100);
        return `<div class="load ${L[p.id] > cap ? "over" : ""}">${avatar(p, "s20")}<span class="who">${esc(p.name)}</span><span class="bar"><i style="width:${pct}%"></i></span><span class="v">${fmtH(L[p.id])} of ~${cap}h</span></div>`;
      }).join("")}
      <p class="small" style="margin:8px 0 0">Heavier tasks count for more. ${yourCap() ? "Others' free time is a guess until they join." : `Free time is a guess for now, about ${guessYourCap()}h for you. <button class="linkish" data-act="yourTime">Add your free time</button>`}</p>
    </div>
    ${S.path !== "pebble" ? `<div style="display:flex;justify-content:center;margin:0 0 14px"><button class="btn-soft" data-act="suggest"><img src="${A("pebble-icon.svg")}" alt="">Ask Pebble for a fair split</button></div>` : ""}
    ${unassigned.length ? `<div class="card helpcard">
        <b style="font-size:15px">${unassigned.length} stone${unassigned.length > 1 ? "s" : ""} still glow white</b>
        <p class="small" style="margin:4px 0 0">No one has room for ${unassigned.length > 1 ? "these" : "this"} yet. You can still share ${unassigned.length > 1 ? "them" : "it"}:</p>
        <div class="chips"><button class="chip" data-act="toast" data-msg="Shared with the trusted circle">Ask trusted circle</button></div>
      </div>` : ""}
    ${picked().map((t) => `<div class="card task-card">
      <div class="head">${stone(!!t.who)}<span class="n">${esc(t.n)}</span>${weightPill(t.w)}</div>
      <p class="meta">${t.kind === "once" ? "Once · " : ""}${whenLabel(t)} · ${t.who ? esc(person(t.who).name) : "Unassigned"}</p>
      <div class="pickers">
        ${helpers.map((p) => {
          const blocked = !canTake(p, t);
          return `<button class="pick ${t.who === p.id ? "on" : ""}" data-act="assign" data-id="${t.id}" data-who="${p.id}" ${blocked ? `disabled style="opacity:.35" title="${p.tier === "kid" ? "Kids and teens get kid tasks only" : "Trusted circle gets light tasks only"}"` : ""}>
            <span class="ringwrap">${avatar(p, "s36")}<img class="ring" src="${A("selected-ring.svg")}" alt=""></span>${esc(p.name)}</button>`;
        }).join("")}
        <button class="pick ${!t.who ? "on" : ""}" data-act="assign" data-id="${t.id}" data-who="">
          <span class="ringwrap"><img class="none" src="${A("none.svg")}" alt=""><img class="ring" src="${A("selected-ring.svg")}" alt=""></span>None</button>
      </div>
    </div>`).join("")}
  </div>
  ${footer("Review the plan")}`;
};
const fmtH = (h) => `${Math.round(h * 10) / 10}h`;

SCREENS.review = () => {
  const main = S.people.filter((p) => p.tier === "main");
  // Review stones are pictures, sized by task: small, medium, large.
  const PEB = { 1: [26, 20], 2: [32, 25], 3: [40, 31] };
  const slots = (ts) => packStones(ts.map((t) => PEB[t.w]), { left: 1, right: 83, base: 109 });
  const trustedTasks = picked().filter((t) => t.who && person(t.who).tier !== "main");
  const loose = picked().filter((t) => !t.who);
  let delay = 0;
  const peb = (t, pos) => `<button class="pebble-btn w${t.w}" data-act="stone" data-id="${t.id}" style="${pos ? `left:${pos.x}px;top:${pos.y}px;` : ""}animation-delay:${(delay += 0.07)}s" aria-label="${esc(t.n)}, ${WEIGHT_LABEL[t.w].toLowerCase()}"><img src="${A(t.who ? "stone-progress.svg" : "stone-unassigned.svg")}" alt=""></button>`;
  if (S.sent) return planSent();
  const ch = planChanges(), resend = !!S.planSnap;
  return `<div class="topbar"><button class="back" data-act="back" aria-label="Back"><img src="${A("back.svg")}" alt=""></button></div>
  <div class="content">
    <p class="eyebrow">Last look</p>
    <h1 class="title">${esc(S.lovedOne)}'s plan is ready</h1>
    <p class="sub">${hasKit() ? "Tap any stone to hear it, or to make the real one glow so you can find it." : "Tap any stone to hear it. Bigger stones are bigger tasks."}</p>
    <div class="shelf">
      <div class="shelf-jars">${main.map((p) => {
        const mine = picked().filter((t) => t.who === p.id).sort((a, b) => b.w - a.w);
        const pos = slots(mine);
        return `<div class="rjar"><div class="glassbox"><img class="glass" src="${A("jar.png")}" alt="">${mine.map((t, i) => (pos[i] ? peb(t, pos[i]) : "")).join("")}${jarMore(pos.filter((x) => !x).length)}</div>
          <span class="who">${esc(p.name)}</span><span class="cnt">${mine.length} task${mine.length === 1 ? "" : "s"}</span></div>`;
      }).join("")}</div>
      ${trustedTasks.length ? `<div class="loose">Trusted &amp; kids ${trustedTasks.map((t) => peb(t)).join("")}</div>` : ""}
      ${loose.length ? `<div class="loose">Unassigned ${loose.map((t) => peb(t)).join("")}</div>` : ""}
      <div class="legend"><span><img src="${A("stone-progress.svg")}" alt="">Assigned</span><span><img src="${A("stone-unassigned.svg")}" alt="">Needs someone</span></div>
    </div>
    ${ch.length ? `<p class="small">${resend ? "Only people whose tasks changed" : "Everyone"} gets a notification with their tasks${resend ? "" : ". Anyone who hasn't joined yet gets it with their invite"}.</p>` : `<p class="small">No one's tasks changed, so there's nothing to send.</p>`}
  </div>
  ${ch.length
    ? footer(`${resend ? "Send changes to" : "Send plan to"} ${listNames(ch)}`, { act: "send" })
    : footer("Done")}`;
};

// What each person has, so a re-send only pings the people whose list changed.
const planKey = (p) => picked().filter((t) => t.who === p.id).map((t) => t.id).sort().join();
const planOthers = () => S.people.filter((p) => p.id !== "you");
const planChanges = () => planOthers().filter((p) => !S.planSnap || S.planSnap[p.id] !== planKey(p));

function planSent() {
  const sent = S.lastSent || [];
  const row = (p) => {
    const n = picked().filter((t) => t.who === p.id).length, got = sent.includes(p.id);
    const status = !got ? "No changes" : S.resent ? "Changes sent" : p.joined ? "Notified" : "Invite and tasks sent";
    return `<div class="person">${avatar(p, "s36")}
      <span class="main"><span class="n">${esc(p.name)}</span><span class="m">${n ? `${n} task${n === 1 ? "" : "s"}` : "No tasks yet"} · ${status}</span></span>
      ${got && !p.joined ? `<button class="btn-soft sm" data-act="resendInvite" data-id="${p.id}">Resend</button>` : ""}
    </div>`;
  };
  return `<div class="topbar"></div>
  <div class="content">
    <p class="eyebrow">Sent</p>
    <h1 class="title">${S.resent ? "Changes sent" : "Everyone has their tasks"}</h1>
    <p class="sub">${S.resent ? "Only people whose tasks changed got a notification." : "Each person got a notification with their tasks. They can accept them or say they can't."}</p>
    <div class="card pg-card plan-sent">${planOthers().map(row).join("")}</div>
    <p class="small">You'll get an update when someone accepts, finishes, or hands back a task.</p>
  </div>
  ${footer("Back to Home", { backBtn: false })}`;
}
const listWords = (n) => (n.length <= 2 ? n.join(" and ") : `${n.slice(0, -1).join(", ")}, and ${n.at(-1)}`);
const listNames = (ps) => listWords(ps.map((p) => p.name));

/* ---------- Sheets ---------- */

let sheetFrame;
function openSheet(html) {
  const el = document.getElementById("sheet");
  el.innerHTML = `<div class="scrim" data-act="closeSheet"></div><div class="sheet" role="dialog"><div class="grab"></div>${html}</div>`;
  if (!el.classList.contains("open")) sheetFrame = requestAnimationFrame(() => el.classList.add("open"));
}
function closeSheet() {
  const el = document.getElementById("sheet");
  cancelAnimationFrame(sheetFrame);
  el.classList.remove("open");
  setTimeout(() => { if (!el.classList.contains("open")) el.innerHTML = ""; }, 300);
}

function monthGrid(t) {
  const [y, m] = S._cal;
  const first = new Date(y, m, 1);
  const offset = (first.getDay() + 6) % 7; // Monday-first
  const count = new Date(y, m + 1, 0).getDate();
  const cells = Array.from({ length: offset }, () => `<span></span>`);
  for (let d = 1; d <= count; d++) {
    const date = new Date(y, m, d), id = iso(date);
    const cls = [id === t.date && "on", id === iso(TODAY) && "today"].filter(Boolean).join(" ");
    cells.push(`<button class="${cls}" data-act="pickDate" data-id="${id}" ${date < TODAY ? "disabled" : ""}>${d}</button>`);
  }
  const atStart = y === TODAY.getFullYear() && m === TODAY.getMonth();
  return `<div class="cal">
    <div class="cal-head">
      <button data-act="calMove" data-id="-1" ${atStart ? "disabled" : ""} aria-label="Previous month"><img src="${A("chevron.svg")}" alt="" style="transform:scaleX(-1)"></button>
      <b>${first.toLocaleDateString("en-US", { month: "long", year: "numeric" })}</b>
      <button data-act="calMove" data-id="1" aria-label="Next month"><img src="${A("chevron.svg")}" alt=""></button>
    </div>
    <div class="cal-grid">${["M", "T", "W", "T", "F", "S", "S"].map((d) => `<i>${d}</i>`).join("")}${cells.join("")}</div>
  </div>`;
}

function dateSheet(t) {
  S._sheetTask = t.id;
  if (!S._cal) { const d = fromIso(t.date); S._cal = [d.getFullYear(), d.getMonth()]; }
  const how = howOf(t);
  const quick = [["Today", addDays(0)], ["Tomorrow", addDays(1)], ["This week", byFriday()]];
  const detail = {
    once: `<p class="label" style="margin-top:16px">Due by</p>
      <div class="row-opts">${quick.map(([l, d]) => chip(l, t.date === d, "pickDate", d)).join("")}</div>
      ${monthGrid(t)}`,
    repeat: `<p class="label" style="margin-top:16px">Which days? <button class="linkish" data-act="allDays">${t.days.length === 7 ? "Just one day" : "Every day"}</button></p>
      <div class="day-pick">${DAYS.map((d) => `<button class="${t.days.includes(d) ? "on" : ""}" data-act="toggleDay" data-id="${d}">${d[0]}<small>${d}</small></button>`).join("")}</div>`,
    needed: `<p class="small" style="margin-top:14px">It won't go on the calendar. Whoever has it does it when it comes up, like a doctor calling to book a visit.</p>`,
  }[how];
  openSheet(`<h3>${esc(t.n)}</h3>
    <div class="seg big how-seg">${HOW.map(([k, l]) => `<button class="${how === k ? "on" : ""}" aria-pressed="${how === k}" data-act="setHow" data-id="${k}">${l}</button>`).join("")}</div>
    ${detail}
    ${how !== "needed" ? `<p class="label" style="margin-top:16px">Time <span class="small">Optional</span></p>
    <div class="row-opts" style="align-items:center">
      ${chip("Any time", !t.time, "anyTime", "")}
      <label class="time-input ${t.time ? "on" : ""}"><input type="time" step="900" value="${t.time}" data-input="taskTime" aria-label="Time"></label>
    </div>` : ""}
    <button class="btn-primary" data-act="closeSheet">Done</button>`);
}

const sheetTask = () => S.tasks.find((x) => x.id === S._sheetTask);
function sheetEdit(fn) {
  const t = sheetTask();
  fn(t);
  render();
  dateSheet(t);
}

function stoneSheet(t) {
  const p = t.who && person(t.who);
  openSheet(`<div style="display:flex;align-items:center;gap:10px">${stone(!!t.who)}<h3 style="margin:0">${esc(t.n)}</h3></div>
    <p class="small" style="margin:8px 0 0">${WEIGHT_LABEL[t.w]} task · ${t.kind === "once" ? "due " : ""}${whenLabel(t)} · ${p ? esc(p.name) : "Unassigned"}</p>
    <div class="actions">
      <button class="btn-soft" data-act="speak" data-id="${t.id}">▶ Play on pebble</button>
      ${hasKit() ? `<button class="btn-soft" data-act="locate" data-id="${t.id}">Make it glow</button>` : ""}
    </div>
    <button class="btn-primary" data-act="closeSheet">Done</button>`);
}

/* ---------- Render ---------- */

const NOTES = {
  pebbleInfo: ["What's Pebble?", ["Linked from the Pebble card so people know what they're opting into.", "Shows what Pebble does, how it works, what it can't do, and what it can see.", "Says plainly that it can be wrong, and to call 911 in an emergency."]],
  welcome: ["Welcome", ["Onboarding is now three steps, about 2 minutes: who you're caring for, who's helping, and stone colors.", "Testers felt the old 11-step setup was too much while grieving. Tasks, calendar, the split, and the stones moved to a checklist on Home."]],
  taskStart: ["Start your list", ["First stop of “Add what needs doing” on the Home checklist.", "No “Recommended” badge and no AI up front: “Start from suggestions” is described as faster. “Who suggests the tasks?” explains Pebble for anyone who wants to know."]],
  colors: ["Stone colors", ["Last onboarding step. Families pick colors that mean something to them, so the glow is explained once, with their own colors.", "Changeable anytime in Settings or the Home kit."]],
  about: ["Care situation", ["Starts blank: no name, stage or condition filled in.", "Stage comes first: just starting, day to day, or in hospice. Hospice is a stage of care, not an illness, so it isn't in the condition list.", "Conditions are optional and you can pick more than one; general tasks are always suggested, plus ones for each condition."]],
  them: ["What matters to them", ["Pebble path only. Starts blank. Answers pre-pick tasks (e.g. “Their wishes in order” adds the advance-directive task)."]],
  you: ["What matters to you", ["Pebble path only. “Helping from far away” leans Pebble toward phone and paperwork tasks."]],
  tasks: ["Tasks before people", ["Six category tabs: Medical, Care & visits, Home & meals, Rides & errands, Money & paperwork, and Kids & teens.", "A starter set for the stage you're in (just starting, day to day, final months), put together with hospice nurses and doulas, sits on top with Pebble's picks; the rest fold under More suggestions. Kid tasks are their own tab and never urgent.", "Each task has a size (small, medium, large). Pebble picks one, even for write-ins; tap it to change. The size sets the stone: bigger tasks get bigger stones in the jar and in the real kit, and it feeds the fair split."]],
  dates: ["Check Pebble's guesses", ["Pebble guesses when each task happens; you only fix the wrong ones.", "Grouped as Repeats, One time, As needed, so the three kinds are clear before you tap.", "The sheet asks one thing at a time: which kind, then only the detail it needs. The week grid is a preview."]],
  calendar: ["Calendar sync", ["Optional. Connect any mix of Google, Apple, and Outlook; busy times merge.", "Only busy/free is read, never event details. Connecting here is simulated."]],
  people: ["Who's helping", ["Starts with just you. Each main caregiver gets the app and a link by text.", "Trusted circle: light tasks only.", "Kids & teens get their own task list (calls, cards, pets, the mail). Never urgent, and missing one doesn't count against anyone."]],
  avail: ["Free time, one day at a time", ["Pick a day, then tap big hour buttons, grouped into morning, afternoon, and evening.", "Copy a day to weekdays or every day. A summary shows the whole week.", "Starts blank. Busy calendar hours can’t be picked."]],
  strengths: ["Preferences, not skills", ["Asks what you like helping with, so no one has to claim they're good at something.", "“No preference” is a real answer. The optional avoid list steers Pebble away, e.g. medical care.", "Write-ins for both."]],
  split: ["The split, last", ["Totals stay pinned at the top while the tasks scroll.", "Load bars count heavier tasks as more hours. Pebble path arrives pre-split.", "If you haven't added your free time, it guesses yours from the others so you still get a fair share.", "If no one has room, it suggests the trusted circle or paid help instead of overloading someone."]],
  review: ["Send the plan", ["Jars fill with the tasks you just made. Tap a stone to hear it or make it glow.", "Sending notifies each person with their tasks; people not yet joined get it with their invite.", "Redoing the split only notifies people whose tasks changed."]],
};

function renderNotes() {
  if (APP_SCREENS.has(S.screen)) { renderAppNotes(); return; }
  const all = [...PRE_SCREENS, "welcome", ...FLOWS.onboard, ...(S.flowKey === "onboard" ? [] : flow())];
  const seen = new Set([S.screen, ...S.history]);
  const [title, bullets] = NOTES[S.screen];
  document.getElementById("notes").innerHTML = `
    <p class="eyebrow">Shoal · onboarding v4 · ${S.flowKey === "onboard" ? "3 quick steps" : "Home checklist"}</p>
    <h2>${title}</h2>
    <ol>${all.map((s) => `<li><button data-act="jump" data-to="${s}" aria-current="${s === S.screen}" ${seen.has(s) || s === "welcome" || PRE_SCREENS.includes(s) ? "" : "disabled"}>${NOTES[s][0]}</button></li>`).join("")}</ol>
    <div class="why"><strong>What changed here</strong><ul>${bullets.map((b) => `<li>${b}</li>`).join("")}</ul></div>
    <button class="reset" data-act="restart">Restart prototype</button>
    <button class="reset" data-act="skipToApp">Skip to the main app →</button>`;
}

// Matches nodes by tag (and data-id / data-key when they have one) and updates them in place.
const nodeKey = (n) => n.nodeType === 1 ? `${n.nodeName}#${n.getAttribute("data-key") ?? n.getAttribute("data-id") ?? ""}` : `#${n.nodeType}`;
function patchNode(a, b) {
  if (a.nodeType !== 1) { if (a.nodeValue !== b.nodeValue) a.nodeValue = b.nodeValue; return; }
  for (const { name } of [...a.attributes]) if (!b.hasAttribute(name)) a.removeAttribute(name);
  for (const { name, value } of b.attributes) if (a.getAttribute(name) !== value) a.setAttribute(name, value);
  if (a.nodeName === "TEXTAREA" || a.nodeName === "INPUT") {
    if (a !== document.activeElement) a.value = a.nodeName === "TEXTAREA" ? b.textContent : b.getAttribute("value") ?? "";
    if (a.type === "checkbox" || a.type === "radio") a.checked = b.hasAttribute("checked");
    if (a.nodeName === "TEXTAREA") return;
  }
  patchChildren(a, b);
}
function patchChildren(a, b) {
  const old = [...a.childNodes], used = new Set();
  [...b.childNodes].forEach((n, i) => {
    const k = nodeKey(n);
    let m = old[i] && !used.has(old[i]) && nodeKey(old[i]) === k ? old[i] : old.find((o) => !used.has(o) && nodeKey(o) === k);
    if (m) { used.add(m); patchNode(m, n); } else m = n;
    if (a.childNodes[i] !== m) a.insertBefore(m, a.childNodes[i] || null);
  });
  old.forEach((o) => { if (!used.has(o)) o.remove(); });
}

function render() {
  const el = document.getElementById("screen");
  const prevScreen = el.dataset.s;
  const keepScroll = prevScreen === S.screen ? el.querySelector(".content")?.scrollTop : 0;
  if (S.app) S.tasks.forEach(normTask);
  // A new screen is drawn fresh so it can animate in. The same screen is patched in place,
  // so a tab or toggle only moves what changed instead of replaying the whole page.
  if (prevScreen === S.screen) patchChildren(el, Object.assign(document.createElement("template"), { innerHTML: SCREENS[S.screen]() }).content);
  else el.innerHTML = SCREENS[S.screen]();
  el.dataset.s = S.screen;
  if (prevScreen !== S.screen) {
    el.classList.remove("enter-fwd", "enter-back", "enter-fade");
    void el.offsetWidth;
    el.classList.add(`enter-${lastDir}`);
  }
  const c = el.querySelector(".content");
  if (c && keepScroll) c.scrollTop = keepScroll;
  el.querySelector("[autofocus]")?.focus();
  const tabs = el.querySelector(".tabs"), tab = tabs?.querySelector(".on");
  if (tab) tabs.scrollLeft = tab.offsetLeft - (tabs.clientWidth - tab.offsetWidth) / 2;
  renderNotes();
}

let toastTimer;
function toast(msg) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("show"), 2200);
}

/* ---------- Events ---------- */

const ACTIONS = {
  next, back,
  begin: () => { S.flowKey = "onboard"; S.stage ??= "final"; go("about"); },
  start: (d) => {
    S.path = S.flowKey = d.path;
    if (!S.tasks.some((t) => t.on && t.cat)) clearLibrary();
    go(flow()[0]);
  },
  yourTime: () => { S.returnTo = { flow: S.flowKey, screen: "split" }; S.flowKey = "calendar"; go(FLOWS.calendar[1]); },
  stage: (d) => { S.stage = d.id; clearLibrary(); render(); },
  condition: (d) => {
    const i = S.conditions.indexOf(d.id);
    i >= 0 ? S.conditions.splice(i, 1) : S.conditions.push(d.id);
    clearLibrary();
    render();
  },
  toggleThem: (d) => {
    const i = S.them.indexOf(d.id);
    i >= 0 ? S.them.splice(i, 1) : S.them.push(d.id);
    clearLibrary();
    render();
  },
  toggleYou: (d) => { const i = S.you.indexOf(d.id); i >= 0 ? S.you.splice(i, 1) : S.you.push(d.id); clearLibrary(); render(); },
  dropOwn: (d) => { S.own[d.key].splice(+d.i, 1); render(); },
  toggleTask: (d) => { const t = S.tasks.find((x) => x.id === d.id); t.on = !t.on; if (!t.on) t.who = null; render(); },
  moreTasks: () => { S.moreOpen ||= {}; S.moreOpen[S.taskTab] = !S.moreOpen[S.taskTab]; render(); },
  sizeSheet: (d) => sizeSheet(S.tasks.find((x) => x.id === d.id)),
  setSize: (d) => { const t = S.tasks.find((x) => x.id === d.id); t.w = +d.w; t.sizeSet = true; closeSheet(); render(); },
  dvView: (d) => { S.dv.view = d.id; render(); },
  dvSel: (d) => { S.dv.sel = d.id; render(); },
  dvMove: (d) => {
    const n = +d.id;
    if (S.dv.view === "week") S.dv.week = shift(S.dv.week, 7 * n);
    else { const [y, m] = S.dv.month; const x = new Date(y, m + n, 1); S.dv.month = [x.getFullYear(), x.getMonth()]; }
    render();
  },
  taskTab: (d) => {
    S.taskTab = d.id;
    render();
    document.querySelector(".content").scrollTop = 0;
  },
  weekPreview,
  pvMove: (d) => { S.dv.week = shift(S.dv.week, 7 * +d.id); weekPreview(); },
  editDate: (d) => { S._cal = null; dateSheet(S.tasks.find((x) => x.id === d.id)); },
  setHow: (d) => sheetEdit((t) => {
    if (d.id === "once") t.kind = "once";
    else { t.kind = "repeat"; t.days = d.id === "needed" ? [] : t.days.length ? t.days : ["Sat"]; }
  }),
  pickDate: (d) => sheetEdit((t) => { t.date = d.id; }),
  calMove: (d) => { const [y, m] = S._cal; const n = new Date(y, m + +d.id, 1); S._cal = [n.getFullYear(), n.getMonth()]; dateSheet(sheetTask()); },
  toggleDay: (d) => sheetEdit((t) => {
    const i = t.days.indexOf(d.id);
    if (i < 0) t.days.push(d.id);
    else if (t.days.length > 1) t.days.splice(i, 1);
    else toast("Pick at least one day");
  }),
  allDays: () => sheetEdit((t) => { t.days = t.days.length === 7 ? ["Mon"] : [...DAYS]; }),
  anyTime: () => sheetEdit((t) => { t.time = ""; }),
  closeSheet,
  addPerson: (d) => { S._adding = S._addTier = d.tier || "main"; render(); },
  cancelAdd: () => { S._adding = false; render(); },
  addTier: (d) => {
    const v = document.querySelector('[data-form="person"] input')?.value || "";
    S._addTier = d.tier; render();
    const inp = document.querySelector('[data-form="person"] input'); if (inp) { inp.value = v; inp.focus(); }
  },
  connectCal: (d) => {
    const i = S.cals.indexOf(d.id);
    i >= 0 ? S.cals.splice(i, 1) : S.cals.push(d.id);
    S.busy = busyFrom(S.cals);
    S.free = S.free.map((row, day) => row.map((on, h) => on && !S.busy[day][h]));
    render();
    toast(`${d.id} ${i >= 0 ? "disconnected" : "connected"}`);
  },
  availDay: (d) => { S.availDay = +d.id; render(); },
  toggleHour: (d) => { const row = S.free[S.availDay]; row[+d.id] = !row[+d.id]; render(); },
  togglePart: (d) => {
    const [a, b] = d.id.split("-").map(Number), i = S.availDay;
    const open = [];
    for (let h = a; h < b; h++) if (!S.busy[i][h]) open.push(h);
    const on = !open.every((h) => S.free[i][h]);
    open.forEach((h) => (S.free[i][h] = on));
    render();
  },
  copyDay: (d) => {
    const from = S.availDay, targets = d.id === "weekdays" ? [0, 1, 2, 3, 4] : [0, 1, 2, 3, 4, 5, 6];
    let skipped = false;
    targets.filter((k) => k !== from).forEach((k) => {
      S.free[k] = S.free[from].map((on, h) => { if (on && S.busy[k][h]) skipped = true; return on && !S.busy[k][h]; });
    });
    render();
    toast(`Copied ${DAY_FULL[DAYS[from]]} to ${d.id === "weekdays" ? "weekdays" : "every day"}${skipped ? ", skipping busy hours" : ""}`);
  },
  strength: (d) => {
    // "No preference" and specific picks rule each other out.
    if (d.id === "any") S.strengths = S.strengths.includes("any") ? [] : ["any"];
    else { S.strengths = S.strengths.filter((x) => x !== "any"); S.avoid = S.avoid.filter((x) => x !== d.id); const i = S.strengths.indexOf(d.id); i >= 0 ? S.strengths.splice(i, 1) : S.strengths.push(d.id); }
    render();
  },
  avoid: (d) => { S.strengths = S.strengths.filter((x) => x !== d.id); const i = S.avoid.indexOf(d.id); i >= 0 ? S.avoid.splice(i, 1) : S.avoid.push(d.id); render(); },
  assign: (d) => { const t = S.tasks.find((x) => x.id === d.id); t.who = d.who || null; S.splitTouched = true; render(); },
  suggest: () => { suggestSplit(); render(); toast("Pebble balanced it by size and free time"); },
  stone: (d) => stoneSheet(S.tasks.find((x) => x.id === d.id)),
  speak: (d) => {
    const t = S.tasks.find((x) => x.id === d.id);
    const p = t.who && person(t.who);
    const line = `${t.n}. ${t.kind === "once" ? "Due " : ""}${spokenWhen(t)}.${p ? (p.id === "you" ? "This one is yours." : `${p.name} has this one.`) : "No one has this yet."}`;
    if ("speechSynthesis" in window) { speechSynthesis.cancel(); speechSynthesis.speak(new SpeechSynthesisUtterance(line)); }
    toast(`🔊 “${line}”`);
  },
  locate: (d) => {
    closeSheet();
    const b = document.querySelector(`.pebble-btn[data-id="${d.id}"]`);
    if (b) { b.classList.remove("pulse"); void b.offsetWidth; b.classList.add("pulse"); }
    toast("Your pebble is glowing");
  },
  send: () => {
    S.resent = !!S.planSnap;
    S.lastSent = planChanges().map((p) => p.id);
    S.planSnap = Object.fromEntries(planOthers().map((p) => [p.id, planKey(p)]));
    S.planSentAt = "Today";
    S.sent = true; render();
  },
  resendInvite: (d) => toast(`Sent ${person(d.id).name} another link`),
  restart: () => { S = initialState(); lastDir = "back"; render(); },
  jump: (d) => {
    if (d.to === S.screen) return;
    if (d.to === "welcome") { ACTIONS.restart(); return; }
    const i = S.history.indexOf(d.to);
    if (i >= 0) { S.history = S.history.slice(0, i); lastDir = "back"; S.screen = d.to; render(); }
    else go(d.to);
  },
  toast: (d) => toast(d.msg),
};

document.addEventListener("click", (e) => {
  const b = e.target.closest("[data-act]");
  if (!b || b.disabled) return;
  e.preventDefault();
  ACTIONS[b.dataset.act]?.(b.dataset);
});

document.addEventListener("submit", (e) => {
  const f = e.target.closest("form[data-form]");
  if (!f) return;
  e.preventDefault();
  const v = f.elements.v.value.trim();
  const kind = f.dataset.form;
  if (kind === "own") {
    if (!v) return;
    S.own[f.dataset.key].push(v);
    render();
    document.querySelector(`[data-form="own"][data-key="${f.dataset.key}"] input`)?.focus();
    return;
  }
  if (!v) return;
  if (kind === "task") {
    const w = S.taskTab === KID_CAT ? 1 : pebbleOn() ? guessSize(v) : 2;
    S.tasks.push({ id: `c${Date.now()}`, n: v, w, pw: w, k: "", y: S.taskTab === KID_CAT, cat: S.taskTab, on: true, mine: true, kind: "once", days: ["Sat"], date: addDays(2), time: "", who: null });
    render();
    const c = document.querySelector(".content"); c.scrollTop = c.scrollHeight;
    toast(S.taskTab === KID_CAT ? "Added" : pebbleOn() ? `Added. Pebble sized it ${WEIGHT_LABEL[w]}, tap to change.` : "Added as medium. Tap the size to change it.");
  }
  if (kind === "person") {
    const tier = S._addTier || "main";
    S.people.push({ id: `p${Date.now()}`, name: v, tier, note: TIER_NOTE[tier], cap: tier === "main" ? 5 : 2, invited: true });
    S._adding = false;
    render();
    toast(`Invite sent to ${v}`);
  }
});

document.addEventListener("input", (e) => {
  const hook = APP_INPUT[e.target.dataset.input];
  if (hook) { hook(e.target.value); return; }
  if (e.target.dataset.input === "taskTime") {
    // Update the task and the screen behind the sheet, but leave the sheet alone so the picker keeps focus.
    sheetTask().time = e.target.value;
    e.target.parentElement.classList.toggle("on", !!e.target.value);
    document.querySelector('.sheet [data-act="anyTime"]')?.classList.toggle("on", !e.target.value);
    render();
    return;
  }
  const t = e.target.closest("[data-input]");
  if (t) {
    S[t.dataset.input] = t.value;
    const btn = document.querySelector(".footer .btn-primary");
    if (btn) btn.disabled = !t.value.trim();
  }
});

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") closeSheet();
});

/* ---------- Fit phone to window on desktop ---------- */

function fit() {
  const wrap = document.getElementById("phoneWrap");
  const phone = document.getElementById("phone");
  if (window.innerWidth <= 500) return;
  const s = Math.min(1, (window.innerHeight - 60) / 900);
  phone.style.transform = `scale(${s})`;
  document.getElementById("phoneFrame").style.transform = `scale(${s})`;
  wrap.style.width = `${402 * s}px`;
  wrap.style.height = `${874 * s}px`;
}
window.addEventListener("resize", fit);
// First render happens at the end of start.js, once every screen is defined.
