/* Shoal: Pebble, the family's AI helper, after setup.
   Pebble notices, drafts and suggests. A person always says yes before anything changes,
   and a person always sends. Everything Pebble proposes goes through propose → yes → commit,
   and lands in "What Pebble did" so the family can see it and undo it.
   Turned off (Settings › Pebble), every surface here disappears and Shoal works by hand.
   This prototype has no AI backend: Pebble's "understanding" is a few plain rules, so the flows can be tested.
   Uses state and helpers from app.js and main-app.js. */

const PEBBLE_SCREENS = ["pebbleTalk", "pebbleCosts", "pebbleLog", "pebbleMonth", "pebbleVisit"];
PEBBLE_SCREENS.forEach((s) => APP_SCREENS.add(s));
APP_NAV.push("pebbleTalk", "pebbleCosts", "pebbleMonth", "pebbleVisit", "pebbleLog");

/* ---------- State ---------- */

// Pebble's states match the Motion Lab, so the character and the logic share one vocabulary.
// Each state shows one of the production poses.
const PEB_POSE = {
  idle: "base_front",
  listening: "base_front",
  organizing: "think_01",
  researching: "research_glasses_focused",
  awaiting_confirmation: "offer_open_hands",
  confirmed: "carry_03",
  noticing: "peer_down",
  sensitive: "sensitive_01",
};
const pebFig = (state, cls = "") => `<img class="peb-fig ${cls}" src="${A(`pebble/pebble_${PEB_POSE[state] || PEB_POSE.idle}.png`)}" alt="">`;

function PB() {
  S.app.pebble ??= { log: [], dismissed: {}, asked: {}, talk: { text: "", phase: "listen", props: [], skipped: [] }, draft: null, costs: {}, month: null };
  return S.app.pebble;
}
const nowLabel = () => new Date().toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
// Questions for the hospice nurse, saved by the family. Plain data on the plan, so they stay even with Pebble off.
const nurseQs = () => (S.app.nurseQs ??= []);
const isNurseVisit = (t) => /nurse visit/i.test(t.n);
// On the next nurse-visit task: what the family wants to ask Ana. Tick one off once it's asked.
function nurseQsCard(t) {
  const qs = nurseQs();
  if (!isNurseVisit(t) || !qs.length) return "";
  const asked = qs.filter((q) => q.asked).length;
  return `<div class="card stepsc nurse-qs"><div class="meter-top"><b>Questions for Ana</b><span class="small">${asked} of ${qs.length} asked</span></div>
    ${qs.map((q) => `<div class="stp"><button data-act="nurseQAsked" data-id="${q.id}" aria-label="${q.asked ? "Not asked yet" : "Mark asked"}">${check(q.asked, true)}</button>
      <span class="tl-txt"><span class="n">${esc(q.q)}</span><span class="m">${q.asked ? "Asked" : `Saved ${esc(q.when)}`}</span></span></div>`).join("")}
    <p class="small nq-foot">Saved from a plain-words term. Pebble only wrote the question down; Ana answers it.</p></div>`;
}
// Every change Pebble makes is logged with how to undo it.
function pebLog(what, how, undo = null) { PB().log.unshift({ id: `l${Date.now()}${Math.random().toString(36).slice(2, 5)}`, when: `Today, ${nowLabel()}`, what, how, undo }); }

const pebTask = (n, who, extra = {}) => {
  const t = { id: `pb${Date.now()}${Math.random().toString(36).slice(2, 5)}`, n, w: guessSize(n), k: "", y: false, cat: "", on: true, pebble: true,
    kind: "once", days: ["Sat"], date: addDays(7), time: "", who, done: false, steps: [], notes: "", remote: false, ...extra };
  S.tasks.push(t);
  return t;
};

/* ---------- Listening: turning what someone says into draft changes ---------- */

// Signs of an emergency. Pebble doesn't triage. It stops and points to the hospice team.
const PEB_URGENT = /\b(can'?t wake|won'?t wake|not waking|breathing (strange|different|hard)|stopp?ed breathing|not breathing|unresponsive|seizure|bleeding|chest pain|fell|a fall|passed away|is dying)\b/i;
// Medicine and symptoms. Pebble leaves these out and says so.
const PEB_MEDS = /\b(dose|doses|mg|ml|morphine|lorazepam|pill|pills|medication|medicine|symptom|pain level)\b/i;
const PEB_TIRED = /\b(tired|wiped|exhausted|overwhelmed|burn(ed|t) out|need a break|running on empty)\b/i;
const STOP = new Set("the a an and or but so to of for in on at with about his her their dad's mom's is was be it this that i i'm we he she they said might need needs soon can't cant do have has had runs out again my our your just really call ask get take make help need want going go said says told tell".split(" "));
const words = (s) => s.toLowerCase().replace(/[^a-z' ]/g, " ").split(/\s+/).map((w) => w.replace(/'s$/, "")).filter((w) => w.length > 2 && !STOP.has(w));
const stem = (w) => w.slice(0, 6);
function overlap(a, b) {
  const B = new Set(words(b).map(stem));
  return words(a).map(stem).filter((w) => B.has(w)).length;
}
// The task whose name shares the most words with what was said.
function matchTask(s, list) {
  let best = null, score = 0;
  list.forEach((t) => { const o = overlap(s, t.n); if (o > score) { best = t; score = o; } });
  return best ? { t: best, score } : null;
}
const WEEKDAY = { monday: "Mon", tuesday: "Tue", wednesday: "Wed", thursday: "Thu", friday: "Fri", saturday: "Sat", sunday: "Sun" };
function dateIn(s) {
  const m = s.toLowerCase().match(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/);
  if (!m) return null;
  const want = DAYS.indexOf(WEEKDAY[m[1]]);
  for (let i = 1; i <= 7; i++) { const d = fromIso(addDays(i)); if ((d.getDay() + 6) % 7 === want) return addDays(i); }
  return null;
}
const cap1 = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const tidy = (s) => cap1(s.trim().replace(/^(and|so|but|also|oh|plus)\s+/i, "").replace(/\b(his|her)\b/i, `${L()}'s`).replace(/[,;.!?]+\s*$/, ""));

function pebbleHear(text) {
  const T = PB().talk;
  T.props = []; T.skipped = [];
  const sentences = text.split(/(?<=[.!?])\s+|\n+/).map((s) => s.trim()).filter(Boolean);
  if (sentences.some((s) => PEB_URGENT.test(s))) { T.phase = "sensitive"; return; }
  const mineNow = active().filter((t) => t.who === "you");
  sentences.forEach((s) => {
    if (PEB_MEDS.test(s)) { T.skipped.push(s); return; }
    if (PEB_TIRED.test(s)) { T.props.push({ kind: "checkin", on: true, n: "Tell My jar you're stretched thin", m: "Only you see this · it helps Pebble suggest a hand-off" }); return; }
    // "I can't do Thursday's visit" frees something up, or asks the circle to cover it.
    const cant = s.match(/\b(?:can'?t|cannot|won'?t be able to)\s+(?:do|make|cover|go to|get to)\s+(.+?)(?:,|\.|$)/i);
    if (cant) {
      const mt = matchTask(s, mineNow);
      if (mt && mt.score >= 1) T.props.push({ kind: "release", on: true, task: mt.t.id, n: mt.t.n, m: "Leaves your jar · ask the circle, first yes takes it" });
      else T.props.push({ kind: "open", on: true, n: `Cover ${cant[1].replace(/^the\s+/i, "")}${/with|for/.test(cant[1]) ? "" : ` with ${L()}`}`, date: dateIn(s), m: "Ask the circle · first yes takes it" });
      return;
    }
    const mt = matchTask(s, active());
    if (mt && mt.score >= 2) { T.props.push({ kind: "dup", on: false, task: mt.t.id, n: mt.t.n, m: `Already in ${mt.t.who === "you" ? "your jar" : mt.t.who ? `${nameOf(mt.t.who)}'s jar` : "the shared jar"} · nothing new to add` }); return; }
    if (mt && mt.score === 1) {
      const owner = mt.t.who === "you" ? "your jar" : mt.t.who ? `${nameOf(mt.t.who)}'s jar` : "the shared jar";
      T.props.push({ kind: "step", on: true, task: mt.t.id, n: mt.t.n, step: tidy(s), m: `Already in ${owner} · I'll add a step, not a new stone` });
      return;
    }
    const need = s.match(/\bneed(?:s)?\s+(?:to\s+)?(?:(a|an|the|some)\s+)?(.+?)(?:\s+soon|\s+this week|\s+by\s+\w+)?[.!?]?$/i);
    if (need) {
      const item = need[2].replace(/[.!?]$/, "");
      const isVerb = /^to\s/i.test(need[0].replace(/^needs?\s+/i, "")) || /^(call|book|ask|get|pick|find|order|schedule|fix|pay)\b/i.test(item);
      const n = isVerb ? cap1(item) : /hospice|nurse|doctor/i.test(s) ? `Ask hospice about ${need[1] ? `${need[1].toLowerCase()} ` : ""}${item}` : `Get ${need[1] ? `${need[1].toLowerCase()} ` : ""}${item}`;
      T.props.push({ kind: "new", on: true, n, date: dateIn(s), m: "New task · your jar · this week" });
      return;
    }
    const todo = s.match(/\b(?:have to|got to|should|remember to|don't forget to|we need to)\s+(.+?)[.!?]?$/i);
    if (todo) { T.props.push({ kind: "new", on: true, n: cap1(todo[1]), date: dateIn(s), m: "New task · your jar · this week" }); return; }
    T.skipped.push(s);
  });
  T.phase = "review";
}

function pebbleCommit() {
  const T = PB().talk, done = [];
  T.props.filter((p) => p.on).forEach((p) => {
    if (p.kind === "new") {
      const t = pebTask(p.n, "you", p.date ? { date: p.date } : {});
      if (hasKit()) S.app.pebNew = t.id;
      pebLog(`Added “${t.n}” to your jar`, "From what you told Pebble · you said yes", { type: "task", id: t.id });
      done.push({ n: t.n, m: "New stone for your jar", st: "progress" });
    } else if (p.kind === "step") {
      const t = S.tasks.find((x) => x.id === p.task);
      t.steps.push({ n: p.step, who: null, done: false });
      pebLog(`Added a step to “${t.n}”`, `“${p.step}” · you said yes`, { type: "step", id: t.id, n: p.step });
      done.push({ n: t.n, m: "Added as a step · same stone", st: stateOf(t) });
    } else if (p.kind === "release") {
      const t = S.tasks.find((x) => x.id === p.task);
      t.who = null;
      pebLog(`Moved “${t.n}” to the shared jar`, "Asked the circle · you said yes", { type: "who", id: t.id, who: "you" });
      done.push({ n: t.n, m: "Asked the circle · waiting for a yes", st: "open" });
    } else if (p.kind === "open") {
      const t = pebTask(p.n, null, p.date ? { date: p.date } : {});
      pebLog(`Asked the circle to cover “${t.n}”`, "From what you told Pebble · you said yes", { type: "task", id: t.id });
      done.push({ n: t.n, m: "Asked the circle · waiting for a yes", st: "open" });
    } else if (p.kind === "checkin") {
      S.app.checkin = "stretched";
      pebLog("Noted that you're stretched thin", "Private to you · you said yes");
      done.push({ n: "You're stretched thin", m: "Saved privately in My jar", st: "done" });
    }
  });
  T.done = done;
  T.phase = "done";
}

/* ---------- Noticing ---------- */

// Pebble is "active" when it's on and the family hasn't asked for quiet days. Noticing, suggesting,
// pulsing and following up all pause on quiet days; the family's own tasks and Something's wrong stay.
const pebbleActive = () => pebbleOn() && !PB().quiet;

// What Pebble raises. One at a time, and "Not now" means not now. It comes to you: a banner on Home,
// a notification, the lock screen, and the stone itself, each with the same one-tap answer.
// The answer is always Hand off with Pebble's pick already made and the note written, so what's left is Send.
function pebbleNotice() {
  if (!pebbleActive()) return null;
  const P = PB(), seen = (k) => P.dismissed[k] || P.asked[k];
  const withPick = (x, t) => {
    const pick = pebblePick(t);
    x.pick = pick;
    x.cta = pick ? `Ask ${pick.p.name}` : "Find someone";
    x.body += pick ? ` · ${pick.p.name} has room` : "";
    return x;
  };
  for (const t of active().filter(isUrgent).sort((a, b) => a.date.localeCompare(b.date))) {
    const step = t.steps.find((x) => !x.done && !x.who);
    if (t.who === "you" && step && !seen(`step:${t.id}`)) {
      return withPick({ key: `step:${t.id}`, task: t.id, step: step.n, title: `A step on “${t.n}” needs someone`, body: `“${step.n}” · ${dueLabel(t)}`,
        text: `“${t.n}” is ${dueLabel(t)}, and “${step.n.toLowerCase()}” still needs someone.` }, t);
    }
    if (!t.who && !seen(`open:${t.id}`)) return withPick({ key: `open:${t.id}`, task: t.id, title: `“${t.n}” has no one yet`, body: cap1(dueLabel(t)), text: `“${t.n}” is ${dueLabel(t)} and no one has it yet.` }, t);
  }
  const declined = S.tasks.find((t) => t.handoff?.status === "declined" && !seen(`declined:${t.id}`));
  if (declined) return withPick({ key: `declined:${declined.id}`, task: declined.id, handoff: true, title: `${nameOf(handWho(declined.handoff))} can't take “${declined.n}”`, body: "Still needs someone", text: `${nameOf(handWho(declined.handoff))} can't take “${declined.n}”.` }, declined);
  return null;
}
// The stone for a task Pebble has a notice about pulses gently in the jar at home, while the notice is up.
const pebblePulse = (t) => hasKit() && S.app.prefs?.glow !== "off" && pebbleNotice()?.task === t.id;

// The same notice as a card, for the Pebble tab (and the old Home look).
function pebbleHomeCard() {
  const x = pebbleNotice();
  if (!x) return "";
  return `<div class="card peb-notice">
    <div class="pn-row">${pebFig("noticing", "s44")}<span class="tl-txt"><span class="eyebrow">Pebble noticed</span><span class="pn-txt">${esc(x.text)}${x.pick ? ` ${esc(x.pick.p.name)} has ${esc(x.pick.why)}.` : ""}</span></span></div>
    <div class="pn-btns"><button class="btn-primary sm" data-act="pebbleAskFor" data-id="${x.key}">${esc(x.cta)}</button>
      <button class="btn-ghost sm" data-act="pebbleNotNow" data-id="${x.key}">Not now</button></div>
  </div>`;
}
// Pebble's banners for the iOS-style stack in home.js: the notice, and anything it did on the family's say-so.
function pebbleBanners() {
  const out = [];
  const x = pebbleNotice();
  if (x) out.push({ key: `peb:${x.key}`, id: x.key, act: "pebbleAskFor", cls: "pebble", icon: pebFig("noticing", "s28"), title: x.title, body: x.body, cta: x.cta, alt: ["Not now", "pebbleNotNow"] });
  const vb = visitBanner();
  if (vb) out.push(vb);
  followedTasks().filter((t) => !PB().dismissed[`follow:${t.id}`]).forEach((t) => out.push({ key: `peb:follow:${t.id}`, id: t.id, act: "openTask", cls: "pebble", icon: pebFig("confirmed", "s28"), title: followLine(t), body: `“${t.n}” · you said it could · undo in What Pebble did`, cta: "View" }));
  return out;
}

/* ---------- Helping with a hand-off ---------- */

// Asking for help is always Hand off. Pebble only suggests who, and can word the note.
const MINUTES = { 1: "20 minutes", 2: "an hour or so", 3: "a few hours" };
// Everyone who could take this task and has room for it, most room first.
function pebblePicks(t, exclude = []) {
  if (!pebbleActive()) return [];
  const hrs = WEIGHT_HOURS[t.w || 2] || 1;
  const near = !t.remote && ["drive", "there", "cook"].includes(t.k);
  const ok = S.people.filter((p) => p.id !== "you" && p.id !== t.who && !exclude.includes(p.id) && p.cap != null && canTake(p, t) && !(near && p.remote) && roomOf(p) >= hrs);
  return ok.sort((a, b) => roomOf(b) - roomOf(a)).map((p) => ({ p, why: `${roomOf(p)} hour${roomOf(p) === 1 ? "" : "s"} of room this week${near && !p.remote ? ", and close by" : ""}` }));
}
const pebblePick = (t) => pebblePicks(t)[0] || null;
// The note names the task and the date. Never notes, never health details.
function pebbleNoteText(t, step) {
  const due = t.kind === "once" ? dueLabel(t) : repeatLabel(t.days).toLowerCase();
  return step ? `Could you take “${step.toLowerCase()}” for “${t.n}”? It's ${due}. Thank you!` : `Could you take this one? It's ${due} and takes about ${MINUTES[t.w || 2]}. Thank you!`;
}
function pebbleHandPick(t) {
  const x = pebblePick(t);
  if (!x) return "";
  const on = Array.isArray(S.app.handTo) && S.app.handTo.includes(x.p.id);
  return `<div class="peb-hint peb-pick">${pebFig("awaiting_confirmation", "s28")}<span class="small"><b>${esc(x.p.name)}</b> has ${esc(x.why)}.</span>${on ? "" : `<button class="linkish" data-act="handTo" data-id="${x.p.id}">Ask ${esc(x.p.name)}</button>`}</div>`;
}
// Opens Hand off with Pebble's pick already made and the note written, so the only step left is Send.
// Step asks are for that step only.
function pebbleHandoff(taskId, step = null, key = null) {
  if (key) PB().asked[key] = true;
  S.app.task = taskId;
  go("handoff");
  const t = S.tasks.find((x) => x.id === taskId);
  if (step) S.app.handStep = t.steps.findIndex((x) => x.n === step);
  const x = pebblePick(t);
  if (x) S.app.handTo = [x.p.id];
  S.app.note = pebbleNoteText(t, step);
  S.app.notePebble = true;
  render();
}

/* ---------- Following up, without being asked again ---------- */

// One optional line on Hand off: "If no one says yes by [time], ask [next person] next." Off by default.
// If it's on and the first person doesn't answer, Pebble sends the same ask to the next person with room,
// says so in a notification, and logs it with Undo. It never asks anyone the family didn't agree to.
const FOLLOW_WHEN = ["In 2 hours", "6 PM", "Tonight", "Tomorrow morning"];
const whenWord = (w) => (/\d/.test(w) ? w : w.toLowerCase()); // "by 6 PM", "by tonight"
function pebbleFollow(t) {
  const picked = Array.isArray(S.app.handTo) ? S.app.handTo : [];
  const next = pebblePicks(t, picked)[0];
  S.app.follow ??= { on: false, who: null, when: FOLLOW_WHEN[1] };
  const F = S.app.follow;
  if (!F.who || picked.includes(F.who)) F.who = next ? next.p.id : null;
  return F;
}
function pebbleFollowRow(t) {
  if (!pebbleActive() || t.steps[S.app.handStep]) return "";
  const picked = Array.isArray(S.app.handTo) ? S.app.handTo : [];
  if (picked.length !== 1) return "";
  const F = pebbleFollow(t);
  if (!F.who) return "";
  return `<div class="peb-hint peb-follow">${pebFig("awaiting_confirmation", "s28")}<span class="small">If no one says yes by <button class="linkish" data-act="pebbleFollowWhen">${esc(whenWord(F.when))}</button>, ask <button class="linkish" data-act="pebbleFollowWho">${esc(nameOf(F.who))}</button> next.</span>${toggle(F.on, "pebbleFollowOn", "", "Follow up if no one answers")}</div>`;
}
// Called by sendHandoff. True means Pebble's follow-up runs the prototype's pretend replies instead.
function pebbleFollowArm(t, to) {
  const F = S.app.follow;
  if (!pebbleActive() || !F?.on || !F.who || !Array.isArray(to) || to.length !== 1) return false;
  t.handoff.follow = { who: F.who, when: F.when };
  const first = to[0];
  // No answer from the first person. Pebble asks the next one, as agreed, and says so.
  setTimeout(() => {
    if (t.handoff?.status !== "pending" || t.handoff.to[0] !== first || !pebbleActive()) return;
    const prev = t.handoff;
    t.handoff = { to: [F.who], from: prev.from, status: "pending", note: prev.note, pebbleFollow: { prev: first, when: F.when } };
    pebLog(`Asked ${nameOf(F.who)} about “${t.n}” after ${nameOf(first)} didn't answer`, `You said it could, by ${whenWord(F.when)} · set on Hand off`, { type: "handoff", id: t.id, handoff: prev });
    PB().followNew = t.id;
    S.app.seenNotes = false;
    render(); toast(`${nameOf(first)} didn't answer, so Pebble asked ${nameOf(F.who)} (you said it could)`);
    // Then the next person says yes.
    setTimeout(() => {
      if (t.handoff?.status !== "pending" || !t.handoff.pebbleFollow) return;
      Object.assign(t.handoff, { status: "accepted", when: "Just now", taker: F.who });
      t.who = F.who; S.app.seenNotes = false;
      render(); toast(`${nameOf(F.who)} said yes to “${t.n}”`);
    }, 4000);
  }, 4000);
  return true;
}
// The follow-up, once it happened, as a notification and a Home banner.
const followedTasks = () => S.tasks.filter((t) => t.handoff?.pebbleFollow);
const followLine = (t) => `${nameOf(t.handoff.pebbleFollow.prev)} didn't answer, so Pebble asked ${nameOf(handWho(t.handoff))}`;

/* ---------- The nurse's visit note becomes tasks ---------- */

// After Ana sends a visit note, Pebble turns the plain-logistics parts into proposed tasks for the main caregiver,
// with the same review → "Yes, add these" as Talk it through. Anything about medicine or symptoms is not a task:
// it's shown as "ask her about this". Nothing opens on its own; a banner on Home says the note has things to add.
const PEB_SYMPTOM = /\b(pain|breath|breathing|restless|nausea|nauseous|fever|swelling|swollen|confus\w*|sleep\w*|agitat\w*|dose|doses|mg|ml|morphine|lorazepam|pill|pills|medication|medicine|meds|symptom\w*)\b/i;
const PEB_LOGISTIC = /\b(needs?|get|pick up|order|buy|bring|replace|more|supplies|pads|pillows|sheets|call me|deliver\w*)\b/i;
function visitProposal(s) {
  const need = s.match(/\bneeds?\s+(?:to\s+)?(.+)$/i);
  if (need) return /^(more|new|another|a|an|some)\b/i.test(need[1]) ? `Get ${need[1]}` : cap1(need[1]);
  const low = s.match(/\b(?:running low on|low on|out of|running out of)\s+(.+)$/i);
  if (low) return `Get more ${low[1]}`;
  const me = s.match(/\bcall me\b(.*)$/i);
  if (me) return `Call Ana${me[1] ? ` ${me[1].trim()}` : ""}`;
  return cap1(s);
}
function pebbleVisitNote(v) {
  if (!pebbleActive() || !v?.note) return;
  const sentences = v.note.split(/(?<=[.!?])\s+|\n+/).map((s) => s.trim().replace(/[.!?]+$/, "")).filter(Boolean);
  const props = [], asks = [];
  sentences.forEach((s) => {
    if (PEB_SYMPTOM.test(s)) asks.push(s);
    else if (PEB_LOGISTIC.test(s)) props.push({ n: visitProposal(s), on: true, from: s });
  });
  if (!props.length && !asks.length) return;
  PB().visit = { id: v.id, note: v.note, props, asks, phase: "new", done: [] };
}
const visitOpen = () => { const V = PB().visit; return pebbleActive() && V && V.phase !== "done" && !PB().dismissed["visit"] ? V : null; };
function visitBanner() {
  const V = visitOpen();
  if (!V) return null;
  const n = V.props.length, title = n ? `Ana's visit note has ${n} thing${n === 1 ? "" : "s"} to add` : "Ana's visit note has something to ask her about";
  const body = [n ? V.props.map((p) => p.n).join(", ") : "", V.asks.length ? `${V.asks.length} thing${V.asks.length === 1 ? "" : "s"} to ask her, not tasks` : ""].filter(Boolean).join(" · ");
  return { key: "peb:visit", id: "visit", act: "pebbleVisitOpen", cls: "pebble", icon: pebFig("organizing", "s28"), title, body, cta: "Review", alt: ["Not now", "pebbleNotNow"] };
}
SCREENS.pebbleVisit = () => {
  const V = PB().visit;
  if (!V) return `${navtop("Back")}<div class="content"><p class="small">Nothing from Ana's note right now.</p></div>`;
  if (V.phase === "done") return `${navtop("Close")}
  <div class="content">
    <div class="peb-stage">${pebFig("confirmed", "xl")}</div>
    <h1 class="title center">Added to your jar.</h1>
    <div class="card tlist peb-done">${V.done.map((x) => `<div class="srow">${gem("progress", { size: "s" })}<span class="tl-txt"><span class="n">${esc(x)}</span><span class="m">From Ana's visit note · your jar</span></span></div>`).join("") || `<p class="small empty">Nothing added.</p>`}</div>
    <p class="small center">Undo anything from What Pebble did, in the Pebble tab.</p>
  </div>
  ${solo("Done", "back")}`;
  const on = V.props.filter((p) => p.on).length;
  return `${navtop("Back")}
  <div class="content">
    <div class="peb-head">${pebFig("awaiting_confirmation", "s56")}<div><span class="badge amber">Waiting for your yes</span><h1 class="title sm">From Ana's visit note</h1></div></div>
    <div class="card info left"><span class="avatar s36">A</span><span class="small"><b>Ana wrote:</b> “${esc(V.note)}”</span></div>
    ${V.props.length ? `<p class="section-h">Tasks I'd add to your jar</p>
    ${V.props.map((p, i) => `<button class="card peb-prop ${p.on ? "" : "off"}" data-act="pebbleVisitProp" data-id="${i}" aria-pressed="${p.on}">${check(p.on)}<span class="tl-txt"><span class="n">${esc(p.n)}</span><span class="m">From “${esc(p.from)}” · this week</span></span></button>`).join("")}
    <p class="small">Tap a card to leave it out.</p>` : ""}
    ${V.asks.length ? `<p class="section-h">From Ana's note: ask her about this</p>
    <div class="card info peb-skip">${pebFig("sensitive", "s36")}<span class="small">${V.asks.map((a) => `“${esc(a)}”`).join(" ")}<br><b>Not a task.</b> Anything about medicine or symptoms is for Ana to answer, so I left it as something to ask her.</span></div>` : ""}
  </div>
  ${duo(["Not now", "pebbleVisitNotNow"], [on ? `Yes, add ${on === 1 ? "this" : `these ${on}`}` : "Nothing to add", on ? "pebbleVisitYes" : "back"])}`;
};
Object.assign(ACTIONS, {
  pebbleVisitOpen: () => go("pebbleVisit"),
  pebbleVisitProp: (d) => { const p = PB().visit.props[+d.id]; p.on = !p.on; render(); },
  pebbleVisitNotNow: () => { PB().dismissed.visit = true; back(); toast("Okay. Ana's note stays in notifications."); },
  pebbleVisitYes: () => {
    const V = PB().visit;
    V.props.filter((p) => p.on).forEach((p) => {
      const t = pebTask(p.n, "you", { date: addDays(2), w: 1, k: /call/i.test(p.n) ? "phone" : "drive", notes: `From Ana's visit note: “${p.from}.”` });
      pebLog(`Added “${t.n}” to your jar`, "From Ana's visit note · you said yes", { type: "task", id: t.id });
      V.done.push(t.n);
    });
    V.phase = "done"; render();
  },
});
// Hooks Ana's "Send to the family" (roles.js). The note still goes to the family as before; Pebble only reads it for logistics.
if (ACTIONS.visitSend) {
  const roleVisitSend = ACTIONS.visitSend;
  ACTIONS.visitSend = () => {
    const R = S.app.roles, id = R.visitFor;
    roleVisitSend();
    const v = R.visits.find((x) => x.id === id);
    if (v?.done) { delete PB().dismissed.visit; pebbleVisitNote(v); }
  };
}
// Jumping here from the side panel with no note yet shows a sample one, so the screen always has something to review.
const appJumpBase = ACTIONS.appJump;
ACTIONS.appJump = (d) => {
  if (d.to === "pebbleVisit" && !PB().visit) pebbleVisitNote({ id: "sample", note: "Comfortable today. Needs more pillows. Running low on chux pads. Pain seemed worse at night." });
  appJumpBase(d);
};
NOTES.pebbleVisit = ["Pebble: from Ana's visit note", ["Opened from the Home banner (“Ana's visit note has 2 things to add”), never on its own.", "Plain logistics in the note (“Needs more pillows”, “Running low on chux pads”, “Call me tonight”) become proposed tasks for the main caregiver, with the same review → Yes, add these as Talk it through. Tap a card to leave it out.", "Anything about medicine or symptoms is not turned into a task. It's shown as “ask her about this”, in Ana's words.", "Every task added is in What Pebble did, with Undo."]];
NOTES.asNurse[1].push("Pebble: once Ana sends the note, Pebble (if the family has it on) offers the logistics in it as tasks on the family's Home. Nothing is added until the family says yes, and medicine or symptom lines are never tasks.");

/* ---------- Big tasks split into steps ---------- */

// On Add a task: once a Medium or Large task has a name, Pebble can offer 2–4 steps from a small rule table.
// One tap adds them all, each can be removed, and steps can then be handed off one at a time.
const STEP_RULES = [
  [/hospital bed|bed deliver|delivery|deliver/i, ["Confirm the delivery window with hospice", "Clear a space and a path to the room", "Be home when it arrives", "Try the controls and check the mattress"]],
  [/refill|prescription|pharmacy/i, ["Call the pharmacy", "Check insurance covers it", "Pick up or get it delivered"]],
  [/appointment|checkup|check-up|chemo|dialysis|ride to|drive .* to/i, ["Confirm the time and the address", "Plan the ride and parking", "Pack the care binder and a water bottle", "Drive, wait and bring them home"]],
  [/paperwork|forms?\b|directive|power of attorney|insurance|claim|medicare|medi-?cal|benefits/i, ["Gather the papers and ID", "Fill in the form", "Sign, copy and send it", "Note the date in the care binder"]],
  [/equipment|wheelchair|walker|commode|oxygen|shower chair|grab bar/i, ["Ask hospice what they can supply", "Order it or pick it up", "Set it up and show everyone how it works"]],
  [/overnight|night off|stay the night|sleep over/i, ["Agree the night and time", "Go over the evening routine together", "Stay the night", "Hand back in the morning"]],
  [/grocer|shopping|supplies|stock up/i, ["Make the list together", "Shop, or order online", "Put it away and note what's low"]],
  [/\bmove\b|moving|rearrange|set up the room/i, ["Decide what goes where", "Line up a second pair of hands", "Do the move", "Check nothing's in the way at night"]],
];
const pebbleSplitFor = (t) => (pebbleActive() && (t.w || 2) >= 2 && t.n.trim() ? (STEP_RULES.find(([re]) => re.test(t.n)) || [])[1] || null : null);
function pebbleSplitBlock(t) {
  if (!t) return "";
  const x = (act, i) => `<button class="x-btn" data-act="${act}" data-id="${i}" aria-label="Remove step"><span aria-hidden="true">×</span></button>`;
  if (t.steps.length) return `<div class="card stepsc peb-steps"><div class="meter-top"><b>Steps</b><span class="small">${t.pebSteps ? "Pebble's suggestion · remove any" : `${t.steps.length}`}</span></div>
    ${t.steps.map((s, i) => `<div class="stp"><span class="num">${i + 1}</span><span class="tl-txt"><span class="n">${esc(s.n)}</span></span>${x("pebbleStepDrop", i)}</div>`).join("")}
    <p class="small nq-foot">Each step can be handed off on its own once the task is saved.</p></div>`;
  const sug = pebbleSplitFor(t);
  if (!sug) return "";
  const list = S.app.splitSug;
  if (S.app.splitOpen && list) return `<div class="card stepsc peb-steps"><div class="peb-term-head">${pebFig("awaiting_confirmation", "s36")}<div><p class="eyebrow">Split into steps</p><b>${list.length} step${list.length === 1 ? "" : "s"} I'd add</b></div></div>
    ${list.map((n, i) => `<div class="stp"><span class="num">${i + 1}</span><span class="tl-txt"><span class="n">${esc(n)}</span></span>${x("pebbleSplitDrop", i)}</div>`).join("")}
    <div class="actions"><button class="btn-soft" data-act="pebbleSplitClose">Keep it whole</button><button class="btn-soft" data-act="pebbleSplitAdd">Add ${list.length === 1 ? "this step" : `these ${list.length} steps`}</button></div></div>`;
  return `<div class="peb-aside peb-split">${pebFig("idle", "s44")}<div class="pa-btns"><button class="peb-chip" data-act="pebbleSplit">Split into steps</button><span class="small">${sug.length} steps you could hand off one at a time</span></div></div>`;
}
Object.assign(ACTIONS, {
  pebbleSplit: () => { S.app.splitSug = [...(pebbleSplitFor(draft()) || [])]; S.app.splitOpen = true; render(); },
  pebbleSplitDrop: (d) => { S.app.splitSug.splice(+d.id, 1); if (!S.app.splitSug.length) S.app.splitOpen = false; render(); },
  pebbleSplitClose: () => { S.app.splitOpen = false; render(); },
  pebbleSplitAdd: () => { const t = draft(); t.steps = S.app.splitSug.map((n) => ({ n, who: null, done: false })); t.pebSteps = true; S.app.splitOpen = false; render(); toast(`${t.steps.length} steps added. Remove any you don't need.`); },
  pebbleStepDrop: (d) => { const t = draft(); t.steps.splice(+d.id, 1); if (!t.steps.length) t.pebSteps = false; render(); },
});
// Pebble sizes the task as it's typed; the split offer follows the same keystrokes.
const draftNameBase = APP_INPUT.draftName;
APP_INPUT.draftName = (v) => {
  draftNameBase(v);
  const box = document.querySelector("[data-peb-split]");
  if (box) { S.app.splitOpen = false; box.innerHTML = pebbleSplitBlock(draft()); }
};
const newTaskBase = ACTIONS.newTask;
ACTIONS.newTask = () => { S.app.splitOpen = false; S.app.splitSug = null; newTaskBase(); };
// The split is logged once the task is really saved, so Undo has something to undo.
const saveTaskBase = ACTIONS.saveTask;
ACTIONS.saveTask = () => {
  const t = draft();
  if (t?.pebSteps && t.steps.length) pebLog(`Split “${t.n}” into ${t.steps.length} steps`, "On Add a task · you said yes", { type: "steps", id: t.id });
  saveTaskBase();
};
NOTES.newTask[1].push("Pebble: once a Medium or Large task has a name that matches something Pebble knows how to break down (a bed delivery, a refill, a ride to an appointment, hospice paperwork, equipment, an overnight), one chip appears: Split into steps. It shows 2–4 steps; one tap adds them all, and each can be removed. Steps can then be handed off one at a time from the task (Ask, next to Take step). No match, no chip.");

/* ---------- Talking to Pebble ---------- */

const PEB_SAMPLES = [
  ["A busy week", `The hospice nurse said ${L()} might need a hospital bed soon. And his refill runs out Friday. I can't do Thursday's visit, I have a work thing.`],
  ["Things around the house", "Mom said the stair rail is loose again. We need to call about the hospital bill. I'm honestly wiped out this week."],
  ["A hard moment", `${L()} is breathing strangely and I can't wake him.`],
];
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
let rec = null;

SCREENS.pebbleTalk = () => {
  const T = PB().talk;
  if (T.phase === "sensitive") return `${navtop("Close")}
  <div class="content peb-talk">
    <div class="peb-stage quiet">${pebFig("sensitive", "xl")}</div>
    <h1 class="title center">That sounds really hard.</h1>
    <p class="sub center">I can't help with symptoms or medicine. ${esc(L())}'s hospice team can, any time of day or night.</p>
    <div class="card info"><img src="${A("lock.svg")}" alt=""><span class="small">Pebble didn't save anything you said. It never contacts hospice on its own. You decide.</span></div>
  </div>
  ${solo("Call hospice", "pebbleCallHospice", ["Go back", "pebbleRelisten"])}`;

  if (T.phase === "review") {
    const on = T.props.filter((p) => p.on && p.kind !== "dup").length;
    return `${navtop("Close")}
    <div class="content">
      <div class="peb-head">${pebFig("awaiting_confirmation", "s56")}<div><span class="badge amber">Waiting for your yes</span><h1 class="title sm">${T.props.length ? "Here's what I'd add. Change anything." : "I didn't find anything to add."}</h1></div></div>
      ${T.props.map((p, i) => `<button class="card peb-prop ${p.on ? "" : "off"}" data-act="pebbleProp" data-id="${i}" ${p.kind === "dup" ? "disabled" : ""} aria-pressed="${p.on}">
        ${p.kind === "dup" ? gem("done", { size: "s" }) : check(p.on)}<span class="tl-txt"><span class="n">${esc(p.n)}</span><span class="m ${p.kind === "step" || p.kind === "dup" ? "amber" : ""}">${esc(p.m)}</span>${p.step ? `<span class="m">Step: ${esc(p.step)}</span>` : ""}</span></button>`).join("")}
      ${T.skipped.length ? `<div class="card info peb-skip">${pebFig("noticing", "s36")}<span class="small"><b>I left ${T.skipped.length === 1 ? "one thing" : `${T.skipped.length} things`} out.</b> ${T.skipped.some((s) => PEB_MEDS.test(s)) ? `Anything about medicine or symptoms is a question for ${esc(L())}'s hospice nurse. ` : ""}“${esc(T.skipped[0])}”</span></div>` : ""}
      <p class="small">Tap a card to leave it out.</p>
    </div>
    ${duo(["Say a change", "pebbleRelisten"], [on ? `Yes, add ${on === 1 ? "this" : `these ${on}`}` : "Nothing to add", on ? "pebbleYes" : "pebbleClose"])}`;
  }

  if (T.phase === "done") return `${navtop("Close")}
  <div class="content">
    <div class="peb-stage">${pebFig("confirmed", "xl")}</div>
    <h1 class="title center">Done. Here's where they went.</h1>
    <div class="card tlist peb-done">${T.done.map((x) => `<div class="srow">${gem(x.st, { size: "s" })}<span class="tl-txt"><span class="n">${esc(x.n)}</span><span class="m">${esc(x.m)}</span></span></div>`).join("")}</div>
    <p class="small center">Undo anything from What Pebble did, in the Pebble tab.</p>
  </div>
  ${S.app.pebNew && hasKit() ? duo(["Later", "pebbleClose"], ["Pair a stone now", "pebblePair"]) : solo("Done", "pebbleClose")}`;

  return `${navtop("Close")}
  <div class="content peb-talk">
    <div class="peb-stage ${T.listening ? "live" : ""}">${pebFig("listening", "xl")}</div>
    <p class="center"><span class="badge ${T.listening ? "live" : "plain"}">${T.listening ? "● Listening" : "Talk or type"}</span></p>
    <textarea class="peb-say" data-input="pebbleSay" placeholder="What's going on? Say it however it comes out." aria-label="Tell Pebble what's going on">${esc(T.text)}</textarea>
    <p class="eyebrow grey peb-try">Try a sample</p>
    <div class="chips">${PEB_SAMPLES.map(([l], i) => `<button class="chip" data-act="pebbleSample" data-id="${i}">${l}</button>`).join("")}</div>
  </div>
  <div class="footer">
    ${SR ? `<button class="peb-mic ${T.listening ? "on" : ""}" data-act="pebbleMic" aria-label="${T.listening ? "Stop listening" : "Talk to Pebble"}">${T.listening ? "<i class='sq'></i>" : `<svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/></svg>`}</button>` : ""}
    <button class="btn-primary" data-act="pebbleHearIt" ${T.text.trim() ? "" : "disabled"}>That's everything</button>
    <span class="small center peb-foot">Nothing is added until you say yes.</span>
  </div>`;
};

/* ---------- Task help: explain a word, costs ---------- */

// Plain-words explanations for terms that show up in care notes. Each one cites where it comes from.
// Pebble explains words. It never says when or how much.
const PEB_TERMS = {
  prn: ["PRN", "It means “as needed.” A PRN medicine isn't on a schedule. It's there if it's needed, for example if pain or breathing gets harder at night.", "MedlinePlus, U.S. National Library of Medicine", true],
  hospice: ["Hospice", "Care that focuses on comfort and quality of life when a cure is no longer the goal. A team of nurses, aides, social workers and chaplains supports the person and the family, usually at home.", "MedlinePlus, U.S. National Library of Medicine"],
  palliative: ["Palliative care", "Care that eases symptoms and stress during a serious illness. It can happen alongside treatment, at any stage.", "MedlinePlus, U.S. National Library of Medicine"],
  respite: ["Respite care", "Short-term care that gives a family caregiver a break, for a few hours or a few days.", "National Institute on Aging"],
  polst: ["POLST", "A medical order, signed by a doctor and the patient, that says what treatments the person wants in an emergency. It travels with them.", "National POLST"],
  dnr: ["DNR", "Do-not-resuscitate order. It tells medical staff not to do CPR if breathing or the heart stops.", "MedlinePlus, U.S. National Library of Medicine"],
  ihss: ["IHSS", "In-Home Supportive Services, a California program that pays for help at home for people on Medi-Cal.", "California Department of Social Services"],
};
const TERM_RE = new RegExp(`\\b(${["PRN", "hospice", "palliative care", "palliative", "respite care", "respite", "POLST", "DNR", "IHSS"].join("|")})\\b`, "gi");
const HAS_TERM = new RegExp(TERM_RE.source, "i"); // no "g": .test() on a global regex alternates true/false
const termKey = (w) => w.toLowerCase().split(" ")[0];
// Escapes the note, then turns known terms into tappable words. Matching is local; no AI reads the note.
function pebbleTerms(notes) {
  const safe = esc(notes);
  if (!pebbleOn()) return safe;
  return safe.replace(TERM_RE, (w) => `<button class="peb-term" data-act="pebbleTerm" data-id="${termKey(w)}">${w}</button>`);
}

const MONEY = /\b(bill|bills|insurance|pay|paying|cost|costs|medi-?cal|medicare|claim|grant|money|copay|afford)\b/i;
function pebbleTaskHelp(t) {
  if (!pebbleOn() || t.done) return "";
  const money = MONEY.test(t.n) || t.cat === "Money & paperwork";
  if (!money) return "";
  return `<div class="peb-aside">${pebFig("idle", "s44")}<div class="pa-btns"><button class="peb-chip" data-act="pebbleCostsFor" data-id="${t.id}">Find help paying</button></div></div>`;
}

// Programs Pebble found for a California family caring at home. Sample data; a real version looks them up and cites each one.
// Each one comes with the first step, so "help with costs" does the first bit of work instead of adding a new task to do.
const PEB_PROGRAMS = [
  { id: "ihss", n: "In-Home Supportive Services (IHSS)", d: "Pays for help at home for people on Medi-Cal. A family member can sometimes be the paid helper.", src: "cdss.ca.gov",
    step: "Call the county IHSS office", detail: () => `Phone: (___) ___-____ (your county's IHSS line) · Have ready: ${L()}'s Medi-Cal number, his address, and a short list of what he needs help with · Source: cdss.ca.gov` },
  { id: "pfl", n: "California Paid Family Leave", d: "Partial pay for up to 8 weeks while you care for a seriously ill family member.", src: "edd.ca.gov",
    step: "Start the Paid Family Leave claim online", detail: () => `edd.ca.gov › Paid Family Leave · Have ready: your last pay stub, the name of ${L()}'s doctor, and the dates you'll be off · Source: edd.ca.gov` },
  { id: "fcsp", n: "Family Caregiver Support Program", d: "Respite care, counseling and training through your local Area Agency on Aging.", src: "aging.ca.gov",
    step: "Call the Area Agency on Aging", detail: () => `Phone: (___) ___-____ (find yours at aging.ca.gov) · Ask for the Family Caregiver Support Program · Have ready: ${L()}'s age, your county, and a sentence about his care · Source: aging.ca.gov` },
];
SCREENS.pebbleCosts = () => {
  const C = PB().costs, t = S.tasks.find((x) => x.id === PB().costsFor);
  const added = (p) => (t ? t.steps.some((s) => s.n === p.step) : C[p.id]);
  return `${navtop("Back")}
  <div class="content">
    <div class="peb-head">${pebFig("researching", "s56")}<div><p class="eyebrow">Help with costs</p><h1 class="title sm">${PEB_PROGRAMS.length} programs that may fit</h1></div></div>
    <p class="small">Based on: California · care at home · sample answers${t ? ` · for “${esc(t.n)}”` : ""}</p>
    ${PEB_PROGRAMS.map((p) => `<div class="card peb-prog"><p class="n">${p.n}</p><p class="small">${p.d}</p>
      ${t ? `<p class="small pp-step"><b>First step:</b> ${esc(p.step)}</p>` : ""}
      <div class="pp-foot"><span class="small">Source · ${p.src}</span>${added(p) ? `<span class="badge plain">${t ? "Step added" : "Task added"}</span>` : `<button class="pill-btn" data-act="${t ? "pebbleCostStep" : "pebbleCostTask"}" data-id="${p.id}">${t ? "Add the first step" : "Make a task"}</button>`}</div></div>`).join("")}
    <p class="small center">Pebble finds and explains. Only the program can say if you qualify.</p>
  </div>`;
};

/* ---------- What Pebble did ---------- */

SCREENS.pebbleLog = () => {
  const log = PB().log;
  return `${navtop("Back")}
  <div class="content">
    <h1 class="title">What Pebble did</h1>
    <p class="sub">Everything Pebble suggested that you said yes to. Undo anything here.</p>
    ${log.length ? `<div class="card tlist">${log.map((x) => `<div class="srow peb-log"><span class="tl-txt"><span class="m">${esc(x.when)}</span><span class="n">${esc(x.what)}</span><span class="m">${esc(x.how)}</span></span>
      ${x.undo && !x.undone ? `<button class="linkish" data-act="pebbleUndo" data-id="${x.id}">Undo</button>` : x.undone ? `<span class="small">Undone</span>` : ""}</div>`).join("")}</div>
      <button class="btn-text center" data-act="pebbleClearLog">Clear this list</button>`
    : `<div class="card empty-card">${pebFig("idle", "s56")}<p class="small">Nothing yet. When Pebble adds a task or a step, or writes a note you send, it shows up here.</p></div>`}
  </div>`;
};

/* ---------- My jar check-in ---------- */

// Hours each main caregiver is carrying this week, and how much room they set (their rings). Room shows, never why.
const loadOf = (id) => mine(id).filter((t) => !t.done).reduce((n, t) => n + (WEIGHT_HOURS[t.w || 2] || 1), 0);
const roomOf = (p) => (p.cap == null ? null : p.cap - loadOf(p.id));

// "Stretched thin": Pebble picks one of your tasks someone with room could take.
function pebbleLighten() {
  if (!pebbleOn()) return null;
  const ppl = S.people.filter((p) => p.tier === "main" && p.id !== "you" && roomOf(p) > 0).sort((a, b) => roomOf(b) - roomOf(a));
  const mineNow = active().filter((t) => t.who === "you" && !t.handoff).sort((a, b) => isUrgent(a) - isUrgent(b) || (a.w || 2) - (b.w || 2));
  for (const t of mineNow) for (const p of ppl) if (canTake(p, t) && (!p.remote || t.remote || ["phone", "paper"].includes(t.k))) return { t, p };
  return null;
}
function pebbleCheckinHint() {
  const x = pebbleLighten();
  if (!x) return "";
  return `<div class="peb-hint">${pebFig("awaiting_confirmation", "s28")}<span class="small">${esc(x.p.name)} has room for “${esc(x.t.n)}”.</span>
    <button class="linkish" data-act="pebbleAskPerson" data-id="${x.t.id}" data-who="${x.p.id}">Ask ${esc(x.p.name)}</button></div>`;
}

/* ---------- Monthly check-in ---------- */

// Patterns are raised once a month, with everyone, never as a nudge to one person.
function monthNotes() {
  const main = S.people.filter((p) => p.tier === "main");
  const out = [];
  main.filter((p) => p.cap != null && roomOf(p) < 0).forEach((p) => out.push({ st: "urgent", n: `${p.name} is carrying more than the room they set`, m: `About ${loadOf(p.id)} hours a week · their rings say about ${p.cap}` }));
  const open = active().filter((t) => !t.who);
  if (open.length) out.push({ st: "open", n: `${open.length} task${open.length === 1 ? "" : "s"} still ${open.length === 1 ? "has" : "have"} no one`, m: "They glow white in the shared jar" });
  const late = active().filter((t) => t.kind === "once" && t.date < addDays(0));
  out.push(late.length ? { st: "urgent", n: `${late.length} task${late.length === 1 ? "" : "s"} ran past ${late.length === 1 ? "its" : "their"} date`, m: "Worth a look together" } : { st: "progress", n: "Nothing slipped past its date", m: "Everyone kept the plan going" });
  return out;
}
// One move that evens things out: from whoever is most over their room to whoever has the most.
function monthMove() {
  const main = S.people.filter((p) => p.tier === "main" && p.cap != null);
  const from = main.filter((p) => roomOf(p) < 0).sort((a, b) => roomOf(a) - roomOf(b))[0];
  if (!from) return null;
  const tos = main.filter((p) => p.id !== from.id && roomOf(p) > 0).sort((a, b) => roomOf(b) - roomOf(a));
  const ts = mine(from.id).filter((t) => !t.done && !isUrgent(t)).sort((a, b) => (a.w || 2) - (b.w || 2));
  for (const t of ts) for (const p of tos) if (roomOf(p) >= (WEIGHT_HOURS[t.w || 2] || 1) && canTake(p, t) && (!p.remote || t.remote)) return { t, from, to: p };
  return null;
}
SCREENS.pebbleMonth = () => `${navtop("People")}
  <div class="content">
    <div class="peb-head">${pebFig("organizing", "s56")}<div><p class="eyebrow">${TODAY.toLocaleDateString("en-US", { month: "long" })} check-in</p><h1 class="title sm">A few things I noticed this month</h1></div></div>
    <div class="card tlist peb-said">${monthNotes().map((x) => `<div class="srow">${gem(x.st, { size: "s" })}<span class="tl-txt"><span class="n">${esc(x.n)}</span><span class="m">${esc(x.m)}</span></span></div>`).join("")}</div>
    <div class="card info">${gem("progress", { size: "xs" })}<span class="small">Pebble only raises this at the check-in, with everyone. Never as a nudge to one person. Rings show how much room someone has, never why.</span></div>
  </div>
  ${duo(["Not this month", "pebbleMonthSkip"], ["Move stones together", "pebbleMonthMove"])}`;

function pebbleMonthEntry() {
  if (!pebbleOn() || PB().month === "skipped") return "";
  return `<button class="card peb-month" data-act="go" data-to="pebbleMonth">${pebFig("organizing", "s44")}<span class="tl-txt"><span class="n">Monthly check-in</span><span class="m">Pebble has a few things for when you're all together</span></span>${chev}</button>`;
}

/* ---------- Notes ---------- */

Object.assign(NOTES, {
  pebbleTalk: ["Pebble: talk it through", ["Opened from Talk it through on the Pebble tab. Talk or type; the samples show each path.", "Pebble turns it into draft changes: a new task, a step on a task you already have, or asking the circle to cover something. It spots tasks you already have, so nothing doubles up.", "Medicine and symptoms are left out, and Pebble says so. Emergency words stop everything and point to hospice.", "Nothing changes until “Yes, add these.” Every change can be undone in What Pebble did."]],
  pebbleCosts: ["Pebble: help with costs", ["Only from a money or paperwork task (Find help paying).", "Programs that may fit, each with its source and its first step. “Add the first step” puts that step on the task you came from, not a new task: the phone-number placeholder, what to have ready, and the source sit in the step's detail.", "Pebble finds and explains. Only the program decides who qualifies."]],
  pebbleMonth: ["Pebble: monthly check-in", ["From People, for the monthly reset everyone does together.", "Patterns only: who's carrying more than the room they set, what has no one, what slipped.", "Rings show room, never why. The one suggested move only happens when the family says yes."]],
  pebbleLog: ["What Pebble did", ["Lives in one place: the Pebble tab (What I did). The Settings › Pebble row just links here.", "A record of every change Pebble proposed and you said yes to, with Undo."]],
});

// Pebble's bits on existing screens, noted where they show up.
NOTES.home[1].push("Pebble: a “Pebble noticed” card shows one thing at a time, like an urgent step no one has, with Find someone or Not now. Find someone opens Hand off with Pebble's pick. Talking to Pebble lives in its tab.");
NOTES.task[1].push("Pebble: asking for help is always Hand off, where Pebble suggests who has room and can write the note. Money tasks also get Find help paying. Underlined words in the notes open a plain-words explanation with its source; on a medicine word, “Ask the nurse” saves the question for Ana's next visit.", "On the nurse-visit task, “Questions for Ana” lists what the family saved. Tick one off once it's asked.");
NOTES.myjar[1].push("Pebble: answering “Stretched thin” gets one suggestion of a task someone with room could take. Only you see it.");
NOTES.peopleTab[1].push("Pebble: the monthly check-in lives here, and only here. It opens what Pebble noticed this month, for the whole family to look at together.");
NOTES.settings[1].push("Pebble: the What Pebble did row opens the list in the Pebble tab, where every change Pebble made after someone said yes can be undone.");
NOTES.asNurse[1].push("Pebble: questions the family saved from plain-words terms (“Ask the nurse”) show up here as Questions from the family, so Ana sees them before the visit.");
NOTES.notifications[1].push("Pebble: anything Pebble noticed is a notification here too, with the same two answers as the Home banner: Ask [name], which opens Hand off with the pick made and the note written, or Not now. When a follow-up ran (“Nora didn't answer, so Pebble asked Bill”), that's here as well.");
NOTES.handoff[1].push("Pebble: suggests who has room and writes the note. With one person picked, one optional line: “If no one says yes by [time], ask [next person] next.” Off by default, one tap to turn on; the time and the person are tappable. In the prototype, turning it on plays the no-answer path: the first person doesn't reply, Pebble sends the same ask to the next person, a notification says so (“you said it could”), and What Pebble did has Undo, which puts the ask back with the first person.");

/* ---------- Pebble in notifications ---------- */

// The notice is a notification as well, so it reaches you wherever you look. Same two answers.
NOTIF.pebble = ["Pebble noticed", `<path d="M12 5.5c5 0 8.5 3 8.5 7S17 19 12 19s-8.5-2.5-8.5-6.5S7 5.5 12 5.5z"/><path d="M9.5 11.5v.6M14.5 11.5v.6M10 14.6c1.2.8 2.8.8 4 0"/>`];
const pebNotifications = notifications;
notifications = function () {
  const x = pebbleNotice();
  const list = x ? [{ kind: "pebble", needs: true, cta: x.cta, when: "Now", gem: pebFig("noticing", "s28"), n: x.title, m: `${x.body} · you decide, Pebble asks no one`, act: "pebbleAskFor", id: x.key, alt: ["Not now", "pebbleNotNow"] }] : [];
  const vb = visitBanner();
  if (vb) list.push({ kind: "pebble", needs: true, cta: "Review", when: "Today", gem: pebFig("organizing", "s28"), n: vb.title, m: `${vb.body} · nothing is added until you say yes`, act: "pebbleVisitOpen", id: "visit", alt: ["Not now", "pebbleNotNow"] });
  followedTasks().forEach((t) => list.push({ kind: "pebble", when: "Today", gem: pebFig("confirmed", "s28"), n: followLine(t), m: `“${t.n}” · you said it could on Hand off · undo in What Pebble did`, act: "openTask", id: t.id }));
  return [...list, ...pebNotifications()];
};

Object.assign(APP_INPUT, {
  pebbleSay: (v) => {
    PB().talk.text = v;
    const b = document.querySelector('[data-act="pebbleHearIt"]');
    if (b) b.disabled = !v.trim();
  },
});

/* ---------- Actions ---------- */

function stopMic() { if (rec) { try { rec.stop(); } catch (e) { /* already stopped */ } rec = null; } PB().talk.listening = false; }

Object.assign(ACTIONS, {
  pebbleAsk: () => { const T = PB().talk; Object.assign(T, { text: "", phase: "listen", props: [], skipped: [], done: [] }); S.app.pebNew = null; go("pebbleTalk"); },
  pebbleSample: (d) => { PB().talk.text = PEB_SAMPLES[+d.id][1]; render(); },
  pebbleMic: () => {
    const T = PB().talk;
    if (T.listening) { stopMic(); render(); return; }
    rec = new SR();
    rec.lang = "en-US"; rec.interimResults = true; rec.continuous = true;
    const start = T.text ? `${T.text.trim()} ` : "";
    rec.onresult = (e) => {
      T.text = start + [...e.results].map((r) => r[0].transcript).join(" ");
      const el = document.querySelector(".peb-say"); if (el) el.value = T.text;
      const b = document.querySelector('[data-act="pebbleHearIt"]'); if (b) b.disabled = !T.text.trim();
    };
    rec.onerror = () => { stopMic(); render(); toast("Couldn't hear you. You can type instead."); };
    rec.onend = () => { if (T.listening) { T.listening = false; render(); } };
    T.listening = true; rec.start(); render();
  },
  pebbleHearIt: () => {
    stopMic();
    const T = PB().talk;
    if (!T.text.trim()) return;
    pebbleHear(T.text);
    render();
  },
  pebbleProp: (d) => { const p = PB().talk.props[+d.id]; if (p.kind !== "dup") p.on = !p.on; render(); },
  pebbleRelisten: () => { PB().talk.phase = "listen"; render(); },
  pebbleYes: () => { pebbleCommit(); render(); },
  pebbleClose: () => { stopMic(); tabTo("home"); },
  pebblePair: () => { const id = S.app.pebNew; S.app.pebNew = null; S.app.stoneFor = id; S.history = ["home"]; lastDir = "fwd"; S.screen = "newStone"; appEnter("newStone"); render(); },
  pebbleCallHospice: () => toast("In the real app this calls the hospice number the family saved."),

  pebbleNotNow: (d) => { PB().dismissed[d.id] = true; render(); toast("Okay. Pebble won't bring this up again."); },
  // One tap from any surface the notice shows on: Hand off, pick made, note written.
  pebbleAskFor: (d) => { const x = pebbleNotice(); if (x && x.key === d.id) pebbleHandoff(x.task, x.step || null, x.key); else render(); },
  pebbleFollowOn: () => { const F = pebbleFollow(curTask()); F.on = !F.on; render(); },
  pebbleFollowWhen: () => {
    const F = pebbleFollow(curTask());
    openSheet(`<h3>Ask the next person by</h3><p class="small">If no one has said yes by then, Pebble sends the same ask on. You'll see it when it does.</p>
      <div class="chips">${FOLLOW_WHEN.map((w) => chip(w, F.when === w, "pebbleFollowSetWhen", w)).join("")}</div>
      <button class="btn-primary" data-act="closeSheet">Done</button>`);
  },
  pebbleFollowSetWhen: (d) => { pebbleFollow(curTask()).when = d.id; closeSheet(); render(); },
  pebbleFollowWho: () => {
    const t = curTask(), F = pebbleFollow(t), picked = Array.isArray(S.app.handTo) ? S.app.handTo : [];
    const list = S.people.filter((p) => p.id !== "you" && p.id !== t.who && !picked.includes(p.id) && canTake(p, t));
    openSheet(`<h3>Who should Pebble ask next?</h3><p class="small">Only if the first person doesn't answer. Pebble suggests whoever has the most room.</p>
      <div class="card tlist">${list.map((p) => `<button class="radio-row" data-act="pebbleFollowSetWho" data-id="${p.id}">${avatar(p, "s36")}<span class="tl-txt"><span class="n">${esc(p.name)}</span><span class="m">${roomOf(p) == null ? "Room not set" : roomOf(p) <= 0 ? "No room this week" : `${roomOf(p)} hour${roomOf(p) === 1 ? "" : "s"} of room this week`}</span></span>${check(F.who === p.id)}</button>`).join("")}</div>`);
  },
  pebbleFollowSetWho: (d) => { pebbleFollow(curTask()).who = d.id; closeSheet(); render(); },
  pebbleNote: () => {
    const t = curTask(), step = t.steps[S.app.handStep]?.n;
    S.app.note = pebbleNoteText(t, step);
    S.app.notePebble = true;
    render();
  },

  pebbleTerm: (d) => {
    const [term, def, src, med] = PEB_TERMS[d.id];
    openSheet(`<div class="peb-term-head">${pebFig("idle", "s44")}<div><p class="eyebrow grey">In plain words</p><h3>${term}</h3></div></div>
      <p class="peb-def">${def}</p><p class="small">Source: ${src}</p>
      ${med ? `<div class="card info peb-caution"><span class="small">I can explain words. <b>When and how much</b> is a question for ${esc(L())}'s hospice nurse.</span></div>` : ""}
      <div class="actions">${med ? `<button class="btn-soft" data-act="pebbleAskNurse" data-id="${d.id}">Ask the nurse</button>` : ""}<button class="btn-soft" data-act="closeSheet">Got it</button></div>`);
  },
  // The question is saved to the family's plan, not sent anywhere. It shows on the next nurse-visit task and in Ana's view.
  pebbleAskNurse: (d) => {
    const term = PEB_TERMS[d.id][0];
    const q = { id: `q${Date.now()}`, term, q: `${term}: when, and how much?`, asked: false, when: `Today, ${nowLabel()}` };
    nurseQs().push(q);
    pebLog(`Saved a question about ${term} for Ana's next visit`, "From a plain-words term · you said yes", { type: "nurseQ", id: q.id });
    closeSheet(); render(); toast(`Saved for Ana's next visit`);
  },
  nurseQAsked: (d) => { const q = nurseQs().find((x) => x.id === d.id); if (q) q.asked = !q.asked; render(); },

  pebbleCostsFor: (d) => { PB().costsFor = d.id; go("pebbleCosts"); },
  // Adds the first step to the task you came from, with the number placeholder, what to have ready, and the source in its detail.
  pebbleCostStep: (d) => {
    const p = PEB_PROGRAMS.find((x) => x.id === d.id), t = S.tasks.find((x) => x.id === PB().costsFor);
    if (!t || t.steps.some((s) => s.n === p.step)) return;
    t.steps.push({ n: p.step, who: null, done: false, detail: p.detail() });
    pebLog(`Added a step to “${t.n}”`, `“${p.step}” · from Help with costs · source ${p.src}`, { type: "step", id: t.id, n: p.step });
    render(); toast(`First step added to “${t.n}”`);
  },
  pebbleCostTask: (d) => {
    const p = PEB_PROGRAMS.find((x) => x.id === d.id);
    const t = pebTask(`Look into ${p.n.replace(/\s*\(.*\)/, "")}`, "you", { w: 1, k: "paper", cat: "Money & paperwork", notes: `Source: ${p.src}. Only the program can say if ${L()} qualifies.` });
    PB().costs[d.id] = t.id;
    pebLog(`Added “${t.n}” to your jar`, `From Help with costs · source ${p.src}`, { type: "task", id: t.id });
    render(); toast("Added to your jar");
  },

  pebbleAskPerson: (d) => {
    S.app.task = d.id;
    pebLog(`Suggested ${nameOf(d.who)} for “${S.tasks.find((x) => x.id === d.id).n}”`, "From your check-in · you sent the request");
    go("handoff"); S.app.handTo = [d.who]; render();
  },

  pebbleMonthSkip: () => { PB().month = "skipped"; back(); toast("Okay. Pebble will check in next month."); },
  pebbleMonthMove: () => {
    const m = monthMove();
    if (!m) { openSheet(`<h3>Nothing to move</h3><p class="small">Everyone is within the room they set. Move stones by hand from People if you like.</p><button class="btn-primary" data-act="closeSheet">Got it</button>`); return; }
    openSheet(`<h3>One move that evens things out</h3>
      <p class="small">Decide together. Everyone sees the same jars after.</p>
      <div class="card tlist">${taskLine(m.t, { act: "noop", meta: `${esc(m.from.name)} → ${esc(m.to.name)} · ${WEIGHT_LABEL[m.t.w || 2].toLowerCase()}` })}</div>
      <div class="actions"><button class="btn-soft" data-act="closeSheet">Not this one</button><button class="btn-soft" data-act="pebbleMonthApply" data-id="${m.t.id}" data-who="${m.to.id}">Move it</button></div>`);
  },
  pebbleMonthApply: (d) => {
    const t = S.tasks.find((x) => x.id === d.id), from = t.who;
    t.who = d.who;
    pebLog(`Moved “${t.n}” from ${nameOf(from)} to ${nameOf(d.who)}`, "At the monthly check-in · the family said yes", { type: "who", id: t.id, who: from });
    closeSheet(); render(); toast(`Moved to ${nameOf(d.who)}'s jar`);
  },

  pebbleLogOpen: () => go("pebbleLog"),
  pebbleUndo: (d) => {
    const x = PB().log.find((y) => y.id === d.id), u = x.undo, t = S.tasks.find((y) => y.id === u.id);
    if (u.type === "task") S.tasks = S.tasks.filter((y) => y.id !== u.id);
    if (u.type === "step" && t) { const i = t.steps.findIndex((s) => s.n === u.n); if (i >= 0) t.steps.splice(i, 1); }
    if (u.type === "who" && t) t.who = u.who;
    if (u.type === "nurseQ") S.app.nurseQs = nurseQs().filter((q) => q.id !== u.id);
    if (u.type === "steps" && t) { t.steps = []; t.pebSteps = false; }
    // Undoing a follow-up puts the ask back with the first person, still waiting on them.
    if (u.type === "handoff" && t) { t.handoff = u.handoff; t.who = u.handoff.from; }
    x.undone = true; render(); toast("Undone");
  },
  pebbleClearLog: () => { PB().log = []; render(); },
});

/* ---------- Pebble's own tab ---------- */

// Everything Pebble does, in one place. The tab shows only while Pebble is on in Settings.
SCREENS.pebble = () => {
  const n = PB().log.length;
  return `<div class="content app peb-page">
    <div class="peb-hero">${pebFig("idle", "xl")}
      <h1 class="title">Hi, I'm Pebble</h1>
      <p class="sub">Tell me what's going on. I'll sort it into tasks.</p>
      <button class="btn-primary" data-act="pebbleAsk">Talk it through</button></div>
    ${pebbleHomeCard()}
    ${(() => { const vb = visitBanner(); return vb ? `<button class="card peb-month" data-act="pebbleVisitOpen">${pebFig("organizing", "s44")}<span class="tl-txt"><span class="n">${esc(vb.title)}</span><span class="m">${esc(vb.body)}</span></span>${chev}</button>` : ""; })()}
    <button class="h-w wide peb-sees" data-act="pebbleLogOpen">${pebFig("confirmed", "s36")}<span class="tl-txt"><span class="k-lab">What I did</span><span class="k-note">${n ? `${n} change${n === 1 ? "" : "s"} · undo any` : "Nothing yet"}</span></span><span class="k-go" aria-hidden="true">${chev}</span></button>
    <button class="h-w wide peb-sees" data-act="pebbleSees"><span class="k-lab">What Pebble can see</span><span class="k-go" aria-hidden="true">${chev}</span></button>
  </div>
  ${tabbar()}`;
};
NOTES.pebble = ["Pebble", ["Pebble's own tab, slimmed down: Talk it through, anything Pebble noticed right now, and What I did, the one place every change can be undone. It's in the tab bar only while Pebble is on (Settings › Pebble).", "Everything else Pebble does happens inside the flow you're already in: Hand off, a task, My jar, People, Home banners. The tab is no longer somewhere you have to go.", "Asking for help starts from a task or from a notice, never from a random open task, so there's no Find someone tile. Help with costs lives on money tasks. The monthly check-in lives in People only.", "Pebble never sees Dad's care page and never gives medical advice."]];

