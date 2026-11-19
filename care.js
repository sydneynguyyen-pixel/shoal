/* Shoal: the loved one's care page. One place for what everyone needs to know: allergies and wishes,
   every medication with a shared dose log, needs, and preferences. Anyone in the family can update it.
   Med tasks (Morning meds, Comfort meds) show their own meds from here. Loaded after main-app.js and home.js. */

APP_SCREENS.add("care");
APP_NAV.splice(APP_NAV.indexOf("resources"), 0, "care");

/* ---------- Data ---------- */

const clock = (ms) => new Date(ms).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
function ago(ms) {
  const m = Math.max(0, Math.round((Date.now() - ms) / 6e4));
  if (m < 1) return "just now";
  if (m < 60) return `${m} min ago`;
  const h = Math.floor(m / 60), r = m % 60;
  return `${h} hr${r ? ` ${r} min` : ""} ago`;
}
// Today at a clock time, or yesterday if that hasn't happened yet.
const todayAt = (h, m) => { const d = new Date(); d.setHours(h, m, 0, 0); return d > Date.now() ? +d - 864e5 : +d; };

// What he likes lives on his profile page now (loved.js).
const CARE_SECTIONS = [["key", "Most important"], ["needs", "Needs"]];

function makeCare() {
  if (!S.app.demo) return { meds: [], doses: [], key: [], needs: [], prefs: [] };
  const l = L();
  return {
    // prn: as needed, at least `every` hours apart. Otherwise a daily med, given `at` a set time.
    meds: [
      { id: "morphine", name: "Morphine", amt: "5 mg", how: "0.25 mL under the tongue", why: "for pain or hard breathing", prn: true, every: 4 },
      { id: "lorazepam", name: "Lorazepam", amt: "0.5 mg", how: "1 tablet, dissolved under the tongue", why: "for anxiety or restlessness", prn: true, every: 6 },
      { id: "metoprolol", name: "Metoprolol", amt: "25 mg", how: "1 tablet with breakfast", why: "for his heart", at: "8 AM", every: 20 },
      { id: "senna", name: "Senna", amt: "2 tablets", how: "with water at bedtime", why: "morphine can cause constipation", at: "9 PM", every: 20 },
    ],
    doses: [
      { med: "morphine", who: "bill", at: Date.now() - 7.2 * 36e5 },
      { med: "lorazepam", who: "mom", at: Date.now() - 6.5 * 36e5 },
      { med: "metoprolol", who: "mom", at: todayAt(8, 10) },
      { med: "morphine", who: "mom", at: Date.now() - 2.4 * 36e5 },
    ],
    key: [
      { k: "Allergies", v: "Penicillin (hives). Codeine makes him sick to his stomach.", s: "Penicillin, codeine", by: "mom", when: "Sep 30", alert: true },
      { k: "Wishes", v: `Comfort care only. ${l} doesn't want CPR (DNR). The signed form is on the fridge.`, s: "DNR · comfort care only", by: "mom", when: "Sep 30" },
      { k: "Pharmacy", v: "CVS on Saratoga Ave · (408) 555-0110. Hospice delivers the comfort kit.", s: "CVS, Saratoga Ave", by: "you", when: "Oct 2" },
    ],
    needs: [
      { k: "Moving", v: "Needs two people to get out of bed. The gait belt is in the hall closet.", s: "Two people to get up", by: "mom", when: "Mon" },
      { k: "Eating and drinking", v: "Soft foods, small bites. Thickened water only, small sips.", s: "Soft food, thick water", by: "mom", when: "Tue" },
      { k: "Skin", v: "Turn him every 2 to 3 hours. Lotion on his heels and elbows.", s: "Turn every 2 to 3 hours", by: "bill", when: "Sun" },
      { k: "Bathroom", v: "Wears briefs. Supplies are under the bathroom sink.", s: "Briefs, under the sink", by: "mom", when: "Sep 30" },
    ],
    prefs: [
      { k: "Likes", v: "Jazz on the radio, the window open a crack, cold ginger ale.", s: "Jazz, ginger ale", by: "sam", when: "Sat" },
      { k: "Doesn't like", v: "Loud TV. Being rushed in the morning.", s: "Loud TV, rushing", by: "mom", when: "Mon" },
      { k: "Comfort", v: "A cool cloth on his forehead. Someone holding his hand.", s: "Cool cloth, hand held", by: "mom", when: "Tue" },
      { k: "Visits", v: "Sam's video call at 7 PM. Pastor Jim on Sundays after church.", s: "Sam 7 PM, Pastor Sun", by: "you", when: "Oct 4" },
    ],
  };
}
const care = () => (S.app.care ??= makeCare());
const medOf = (id) => care().meds.find((m) => m.id === id);
const lastDose = (id) => care().doses.filter((x) => x.med === id).sort((a, b) => b.at - a.at)[0];
const nextOk = (m) => { const l = lastDose(m.id); return l ? l.at + m.every * 36e5 : 0; };
const whoName = (id) => (id === "you" ? "you" : nameOf(id));

/* ---------- Lock: a PIN or Face ID, primary caregivers only ---------- */

// Only the main caregivers can open the care page; the trusted circle, kids and volunteers never see it.
// It stays open for 5 minutes after unlocking, then locks again. The demo family's PIN is 1234.
const LOCK_MS = 5 * 6e4;
const carePin = () => S.app.carePin ?? (S.app.demo ? "1234" : null);
const careUnlocked = () => S.app.careAt && Date.now() - S.app.careAt < LOCK_MS;
const primaries = () => namesList(S.people.filter((p) => p.tier === "main" && p.id !== "you").map((p) => p.id).concat("you")).replace(/\bYou\b/, "you");

function pinPad() {
  const setting = !carePin() || S.app.pinMode === "set";
  const keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "face", "0", "del"];
  return `<div class="pin">
    <p class="pin-msg" aria-live="polite">${setting ? "Choose a 4-digit PIN" : "Enter your PIN"}</p>
    <div class="pin-dots" aria-hidden="true">${[0, 1, 2, 3].map(() => "<i></i>").join("")}</div>
    <div class="pin-keys">${keys.map((k) => k === "face"
      ? (setting ? "<span></span>" : `<button class="pin-face" data-act="faceId" aria-label="Use Face ID"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M9 9.5v1M15 9.5v1M12 9.5V13h-1M9.5 15.5a3.5 3.5 0 0 0 5 0"/></svg></button>`)
      : k === "del" ? `<button class="pin-del" data-act="pinKey" data-id="del" aria-label="Delete">⌫</button>`
      : `<button data-act="pinKey" data-id="${k}">${k}</button>`).join("")}</div>
  </div>`;
}
function unlockCare(how) {
  S.app.careAt = Date.now();
  S.app.pinIn = "";
  closeSheet();
  render();
  toast(how === "face" ? "Unlocked with Face ID" : "Unlocked for 5 minutes");
}

/* ---------- Medications ---------- */

// Each med shows its dose big and bold, when it was last given and by whom, and when the next is okay.
function medRow(m) {
  const l = lastDose(m.id), next = nextOk(m), early = next > Date.now();
  const status = m.prn
    ? (l ? `Last given <b>${clock(l.at)}</b> by ${esc(whoName(l.who))} · ${ago(l.at)}<br>${early ? `Next dose okay after <b>${clock(next)}</b>` : "Okay to give now if needed"}` : "Not given yet")
    : (early ? `Given today at <b>${clock(l.at)}</b> by ${esc(whoName(l.who))}` : `Due at <b>${m.at}</b>`);
  return `<div class="med">
    <p class="med-dose">${esc(m.amt)} <span>${esc(m.name)}</span></p>
    <p class="med-how">${esc(m.how)} · ${esc(m.why)} · ${m.prn ? `as needed, at least ${m.every} hours apart` : `every day at ${m.at}`}</p>
    <p class="med-last ${early && m.prn ? "wait" : ""} ${early && !m.prn ? "given" : ""}">${status}</p>
    <button class="btn-soft med-btn" data-act="logDose" data-id="${m.id}">I gave ${esc(m.amt)} of ${esc(m.name.toLowerCase())}</button>
  </div>`;
}

// On a med task, just that task's meds, with a way to the full care page.
function medCard(t) {
  const meds = (t.medIds || []).map(medOf).filter(Boolean);
  if (!meds.length) return "";
  if (!careUnlocked()) return `<div class="card med-card med-locked">
    <span class="lock-ico" aria-hidden="true">${LOCK_SVG}</span>
    <span class="tl-txt"><span class="n">Doses are locked</span></span>
    <button class="pill-btn" data-act="unlockSheet">Unlock</button></div>`;
  return `<div class="card med-card">
    <div class="meter-top"><b>Doses</b><button class="linkish" data-act="doseLog">Full log</button></div>
    ${meds.map(medRow).join("")}
    <button class="srow care-link" data-act="go" data-to="care"><span class="tl-txt"><span class="n">All of ${esc(possessive({ name: L() }))} care</span><span class="m">Every med, allergies and needs</span></span>${chev}</button>
  </div>`;
}

function saveDose(id) {
  const m = medOf(id);
  care().doses.push({ med: id, who: "you", at: Date.now() });
  closeSheet();
  render();
  const others = S.people.filter((p) => p.id !== "you" && p.tier === "main").map((p) => p.id);
  toast(`Logged ${m.amt} ${m.name.toLowerCase()} at ${clock(Date.now())}.${others.length ? ` ${namesList(others)} ${others.length === 1 ? "was" : "were"} told.` : ""}`);
}

/* ---------- The care page: widgets, like Home and the kit ---------- */

// Tiles show a short summary; the full note opens on tap. Ana, the hospice nurse, sees meds,
// allergies and wishes, view only, without the PIN.
const nurseView = () => S.app.careAs === "nurse";
const LOCK_SVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/></svg>`;
const CARE_ICO = {
  wishes: "M7 3h7l5 5v13H7zM14 3v5h5M10 13h6M10 17h4",
  pharmacy: "M10.5 3.5a5 5 0 0 1 7 7l-7 7a5 5 0 0 1-7-7zM7 7l7 7",
  moving: "M13 5.5a1.5 1.5 0 1 0 0-.01M10 21l2-6 3 3v3M8 12l3-3 3 2 3 1M11 9l-1 6",
  "eating and drinking": "M5 8h12v5a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5zM17 10h1a2.5 2.5 0 0 1 0 5h-1M9 3v2M13 3v2",
  skin: "M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z",
  bathroom: "M4 11h16v2a6 6 0 0 1-6 6h-4a6 6 0 0 1-6-6zM7 11V6a2 2 0 0 1 4 0M8 19l-1 2M16 19l1 2",
  likes: "M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z",
  "doesn't like": "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM6 6l12 12",
  comfort: "M20 14A8 8 0 1 1 10 4a6 6 0 0 0 10 10z",
  visits: "M4 6h16v14H4zM4 10h16M8 3v4M16 3v4",
};
const careIco = (k) => `<span class="cw-ico" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="${CARE_ICO[k.toLowerCase()] || "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z"}"/></svg></span>`;
const short = (x) => x.s || x.v.split(/[.·]/)[0];
const CHECK_SVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>`;

// As-needed meds: the ring fills until the next dose is okay.
function prnTile(m) {
  const l = lastDose(m.id), next = nextOk(m), early = next > Date.now();
  const f = l ? Math.min(1, (Date.now() - l.at) / (m.every * 36e5)) : 1;
  const [t, ap] = clock(next).split(" ");
  const tag = nurseView() ? "div" : "button";
  return `<${tag} class="h-w cw-prn ${early ? "wait" : "ok"}" ${nurseView() ? "" : `data-act="logDose" data-id="${m.id}"`}>
    <div class="k-tile-top"><span class="k-lab">${esc(m.name)}</span><span class="cw-amt">${esc(m.amt)}</span></div>
    <div class="h-num">${kitRing(f, 46, 4)}<span class="cw-when"><small>${early ? "Okay after" : "Okay"}</small><b>${early ? `${t}<small>${ap}</small>` : "Now"}</b></span></div>
    <p class="k-note">${l ? `${esc(cap(whoName(l.who)))} · ${ago(l.at)}` : "Not given yet"}</p></${tag}>`;
}
function dailyRow(m) {
  const l = lastDose(m.id), given = nextOk(m) > Date.now();
  const tag = nurseView() ? "div" : "button";
  return `<${tag} class="cw-row" ${nurseView() ? "" : `data-act="logDose" data-id="${m.id}"`}>
    <span class="cw-ck ${given ? "on" : ""}" aria-hidden="true">${given ? CHECK_SVG : ""}</span>
    <span class="n">${esc(m.name)} <small>${esc(m.amt)}</small></span>
    <span class="cw-st ${given ? "on" : ""}">${given ? clock(l.at) : m.at}</span></${tag}>`;
}
const careTile = (sec, x, i) => nurseView()
  ? `<div class="h-w cw-tile">${careIco(x.k)}<span class="k-lab">${esc(x.k)}</span><span class="cw-s">${esc(x.v)}</span></div>`
  : `<button class="h-w cw-tile" data-act="careEdit" data-id="${sec}:${i}">${careIco(x.k)}<span class="k-lab">${esc(x.k)}</span><span class="cw-s">${esc(short(x))}</span></button>`;
const plusBtn = (sec, label) => nurseView() ? "" : `<button class="cw-plus" data-act="careEdit" data-id="${sec}:new" aria-label="${label}">+</button>`;

SCREENS.care = () => {
  if (!nurseView() && (!careUnlocked() || S.app.pinMode === "set")) return `${navtop("Back")}
  <div class="content care-lock">
    <span class="lock-big" aria-hidden="true">${LOCK_SVG}</span>
    <h1 class="title">${S.app.pinMode === "set" ? "New PIN" : `${esc(possessive({ name: L() }))} care`}</h1>
    <p class="sub">Primary caregivers only</p>
    ${pinPad()}
  </div>`;
  const c = care(), ro = nurseView();
  const prn = c.meds.filter((m) => m.prn), daily = c.meds.filter((m) => !m.prn);
  const alerts = c.key.map((x, i) => [x, i]).filter(([x]) => x.alert), keys = c.key.map((x, i) => [x, i]).filter(([x]) => !x.alert);
  return `${navtop("Back", ro ? `<span class="ro-pill">View only</span>` : `<button class="pill-btn lock-btn" data-act="lockCare">${LOCK_SVG}Lock</button>`)}
  <div class="content care2">
    <h1 class="title">${esc(possessive({ name: L() }))} care</h1>
    ${alerts.map(([x, i]) => `<${ro ? "div" : "button"} class="cw-alert" ${ro ? "" : `data-act="careEdit" data-id="key:${i}"`}><i class="care-flag" aria-hidden="true">!</i><span><b>${esc(x.k)}</b>${esc(ro ? x.v : short(x))}</span>${ro ? "" : chev}</${ro ? "div" : "button"}>`).join("")}
    <p class="section-h">Medications<span class="cw-acts">${c.doses.length ? `<button class="linkish" data-act="doseLog">Log</button>` : ""}${plusBtn("meds", "Add a medication")}</span></p>
    ${prn.length ? `<div class="k-grid">${prn.map(prnTile).join("")}</div>` : ""}
    ${daily.length ? `<section class="h-w wide cw-daily"><div class="k-tile-top"><span class="k-lab">Every day</span></div>${daily.map(dailyRow).join("")}</section>` : ""}
    ${c.meds.length ? "" : `<p class="small empty">No medications yet.</p>`}
    ${keys.length || !ro ? `<p class="section-h">Most important${plusBtn("key", "Add something important")}</p>
    <div class="k-grid cw-grid">${keys.map(([x, i]) => careTile("key", x, i)).join("")}</div>` : ""}
    ${ro ? "" : CARE_SECTIONS.slice(1).map(([k, t]) => `<p class="section-h">${t}${plusBtn(k, `Add to ${t.toLowerCase()}`)}</p>
    <div class="k-grid cw-grid">${c[k].map((x, i) => careTile(k, x, i)).join("") || `<p class="small empty">Nothing yet.</p>`}</div>`).join("")}
  </div>`;
};

// The next as-needed doses and the allergy, for Home and the nurse's view.
function careGlance() {
  const prn = care().meds.filter((m) => m.prn), allergy = care().key.find((x) => x.alert);
  return `${prn.map((m) => { const n = nextOk(m), early = n > Date.now(); return `<div class="hc-med"><b>${esc(m.name)} ${esc(m.amt)}</b><span class="${early ? "wait" : ""}">${early ? `Okay after ${clock(n)}` : "Okay now if needed"}</span></div>`; }).join("")}
    ${allergy ? `<p class="hc-alert"><i class="care-flag" aria-hidden="true">!</i>Allergic: ${esc(short(allergy))}</p>` : ""}`;
}
function careWidget() {
  const top = `<div class="k-tile-top"><span class="k-lab">${esc(possessive({ name: L() }))} care</span><span class="k-go" aria-hidden="true">${chev}</span></div>`;
  if (!S.app.demo && !care().meds.length && !care().key.length) return `<button class="h-w wide h-care" data-act="go" data-to="care">${top}
    <p class="k-note">Add meds, allergies and needs, so everyone has them.</p></button>`;
  if (!careUnlocked()) return `<button class="h-w wide h-care" data-act="go" data-to="care">${top}
    <p class="hc-locked"><span class="lock-ico" aria-hidden="true">${LOCK_SVG}</span>Locked</p></button>`;
  return `<button class="h-w wide h-care" data-act="go" data-to="care">${top}${careGlance()}</button>`;
}
// Dad's care lives at the top of People now, not on Home.

// Ana's view gets the same glance, view only.
const nurseHome = SCREENS.asNurse;
SCREENS.asNurse = () => {
  S.app.careAs = null;
  return nurseHome().replace(`<p class="section-h">Notes from the family</p>`, `<p class="section-h">${esc(possessive({ name: L() }))} care</p>
    <button class="h-w wide h-care nurse-care" data-act="nurseCare"><div class="k-tile-top"><span class="ro-pill">View only</span><span class="k-go" aria-hidden="true">${chev}</span></div>${careGlance()}</button>
    <p class="section-h">Notes from the family</p>`);
};

/* ---------- Actions ---------- */

Object.assign(ACTIONS, {
  unlockSheet: () => { S.app.pinIn = ""; openSheet(`<h3>Unlock doses</h3>${pinPad()}`); },
  pinKey: (d) => {
    const pad = document.querySelector("#sheet .pin") || document.querySelector(".pin");
    let v = S.app.pinIn || "";
    v = d.id === "del" ? v.slice(0, -1) : (v + d.id).slice(0, 4);
    S.app.pinIn = v;
    pad.querySelectorAll(".pin-dots i").forEach((dot, i) => dot.classList.toggle("on", i < v.length));
    if (v.length < 4) return;
    if (!carePin() || S.app.pinMode === "set") {
      S.app.carePin = v; S.app.pinMode = null;
      setTimeout(() => { unlockCare(); toast("PIN saved. Share it only with the primary caregivers."); }, 200);
      return;
    }
    if (v === carePin()) { setTimeout(() => unlockCare(), 200); return; }
    S.app.pinIn = "";
    pad.classList.remove("shake"); void pad.offsetWidth; pad.classList.add("shake");
    pad.querySelector(".pin-msg").textContent = "That's not it. Try again.";
    setTimeout(() => pad.querySelectorAll(".pin-dots i").forEach((dot) => dot.classList.remove("on")), 350);
  },
  faceId: () => {
    const pad = document.querySelector("#sheet .pin") || document.querySelector(".pin");
    pad.querySelector(".pin-msg").textContent = "Looking for your face…";
    setTimeout(() => unlockCare("face"), 700);
  },
  nurseCare: () => { S.app.careAs = "nurse"; go("care"); },
  lockCare: () => { S.app.careAt = 0; render(); toast("Locked"); },
  careLockSheet: () => openSheet(`<h3>Care page lock</h3>
    <p class="small">Only ${esc(primaries())} can open it. Locks after 5 minutes. Ana, the hospice nurse, can see meds and allergies.</p>
    <div class="actions col"><button class="btn-soft" data-act="changePin">${carePin() ? "Change PIN" : "Set a PIN"}</button><button class="btn-soft" data-act="lockNow">Lock now</button></div>`),
  changePin: () => { S.app.pinMode = "set"; S.app.pinIn = ""; closeSheet(); go("care"); },
  lockNow: () => { S.app.careAt = 0; closeSheet(); toast("Locked"); },
  // Logging a dose checks the last one first, so two people don't both give it.
  logDose: (d) => {
    const m = medOf(d.id), l = lastDose(m.id), next = nextOk(m);
    if (next > Date.now()) {
      openSheet(m.prn
        ? `<p class="eyebrow">Check before giving</p><h3>${esc(m.name)} was given ${ago(l.at)}</h3>
          <p class="small">${esc(cap(whoName(l.who)))} gave it at ${clock(l.at)}. Next dose okay after ${clock(next)}. Call hospice before giving more.</p>
          <div class="actions col"><button class="btn-soft" data-act="closeSheet">Don't log it</button><button class="btn-soft" data-act="go" data-to="resources">Call hospice</button><button class="linkish" data-act="saveDose" data-id="${m.id}">Hospice said okay, log it anyway</button></div>`
        : `<p class="eyebrow">Already given</p><h3>${esc(m.name)} was given today</h3>
          <p class="small">${esc(cap(whoName(l.who)))} gave it at ${clock(l.at)}. Once a day.</p>
          <div class="actions col"><button class="btn-soft" data-act="closeSheet">Okay</button><button class="linkish" data-act="saveDose" data-id="${m.id}">Log another dose anyway</button></div>`);
      return;
    }
    openSheet(`<p class="eyebrow">Log a dose</p><h3>${esc(m.amt)} of ${esc(m.name.toLowerCase())}</h3>
      <p class="small">${esc(cap(m.how))} · ${esc(m.why)}</p>
      <div class="actions"><button class="btn-soft" data-act="closeSheet">Cancel</button><button class="btn-soft" data-act="saveDose" data-id="${m.id}">I gave it</button></div>`);
  },
  saveDose: (d) => saveDose(d.id),
  doseLog: () => {
    const list = [...care().doses].sort((a, b) => b.at - a.at);
    openSheet(`<h3>Dose log</h3>
      <div class="dose-log">${list.map((x) => { const m = medOf(x.med); return `<div class="dl-row">${avatar(person(x.who) || { name: "?" }, "s28")}<span class="tl-txt"><span class="n">${esc(m.amt)} ${esc(m.name.toLowerCase())}</span><span class="m">${esc(cap(whoName(x.who)))} · ${clock(x.at)} · ${ago(x.at)}</span></span>${x.who === "you" && !nurseView() ? `<button class="linkish" data-act="undoDose" data-id="${x.at}">Remove</button>` : ""}</div>`; }).join("") || `<p class="small empty">No doses logged yet.</p>`}</div>
      <div class="actions"><button class="btn-soft" data-act="closeSheet">Done</button></div>`);
  },
  undoDose: (d) => { care().doses = care().doses.filter((x) => String(x.at) !== d.id); ACTIONS.doseLog(); render(); toast("Removed. Everyone sees the change."); },

  // Edit a row, or add one. Meds get their own short form.
  careEdit: (d) => {
    const [sec, i] = d.id.split(":");
    if (sec === "meds") {
      S.app.medKind = "prn";
      openSheet(`<h3>Add a medication</h3>
        <div class="care-form">
          <label>Name<input id="cm-name" placeholder="Morphine"></label>
          <label>Dose<input id="cm-amt" placeholder="5 mg"></label>
          <label>How to give it<input id="cm-how" placeholder="0.25 mL under the tongue"></label>
          <span class="care-kind"><button class="chip on" data-act="medKind" data-id="prn">As needed</button><button class="chip" data-act="medKind" data-id="daily">Every day</button></span>
          <label class="cm-every">Hours apart, at least<input id="cm-every" type="number" inputmode="numeric" value="4" min="1"></label>
        </div>
        <div class="actions"><button class="btn-soft" data-act="closeSheet">Cancel</button><button class="btn-soft" data-act="saveMed">Add</button></div>`);
      return;
    }
    const x = i === "new" ? null : care()[sec][+i];
    openSheet(`<h3>${x ? esc(x.k) : "Add to " + CARE_SECTIONS.find(([k]) => k === sec)[1].toLowerCase()}</h3>
      ${x ? `<p class="small">${esc(cap(whoName(x.by)))} · ${esc(x.when)}</p>` : ""}
      <div class="care-form">${x ? "" : `<label>Title<input id="ce-k" placeholder="${sec === "prefs" ? "Music" : sec === "needs" ? "Sleep" : "Doctor"}"></label>`}
        <label>${x ? "Details" : "What should everyone know?"}<textarea id="ce-v" rows="4">${x ? esc(x.v) : ""}</textarea></label></div>
      <div class="actions">${x && !x.alert ? `<button class="btn-soft" data-act="careRemove" data-id="${d.id}">Remove</button>` : `<button class="btn-soft" data-act="closeSheet">Cancel</button>`}<button class="btn-soft" data-act="careSave" data-id="${d.id}">Save</button></div>`);
  },
  careSave: (d) => {
    const [sec, i] = d.id.split(":");
    const v = document.getElementById("ce-v").value.trim(), k = document.getElementById("ce-k")?.value.trim();
    if (!v || (i === "new" && !k)) { toast(i === "new" && !k ? "Add a title first" : "Write something first"); return; }
    if (i === "new") care()[sec].push({ k, v, by: "you", when: "Just now" });
    else { Object.assign(care()[sec][+i], { v, by: "you", when: "Just now" }); delete care()[sec][+i].s; }
    closeSheet(); render(); toast("Saved. Everyone sees the change.");
  },
  careRemove: (d) => {
    const [sec, i] = d.id.split(":");
    care()[sec].splice(+i, 1);
    closeSheet(); render(); toast("Removed");
  },
  medKind: (d) => {
    S.app.medKind = d.id;
    document.querySelectorAll(".care-kind .chip").forEach((b) => b.classList.toggle("on", b.dataset.id === d.id));
    document.querySelector(".cm-every").innerHTML = d.id === "prn"
      ? `Hours apart, at least<input id="cm-every" type="number" inputmode="numeric" value="4" min="1">`
      : `Time of day<input id="cm-at" placeholder="8 AM">`;
  },
  saveMed: () => {
    const val = (id) => document.getElementById(id)?.value.trim() || "";
    const name = val("cm-name"), amt = val("cm-amt");
    if (!name || !amt) { toast("Add the name and dose"); return; }
    const prn = S.app.medKind === "prn";
    care().meds.push({ id: `m${Date.now()}`, name: cap(name), amt, how: val("cm-how") || "as directed", why: "added by you", prn, every: prn ? +val("cm-every") || 4 : 20, at: prn ? "" : val("cm-at") || "8 AM" });
    closeSheet(); render(); toast(`${cap(name)} added. Everyone sees it.`);
  },
});

NOTES.care = [`${"Dad"}'s care`, [
  "Widgets, like Home and the kit. Allergies sit on top as a red strip. As-needed meds are big tiles: the ring fills until the next dose is okay. Daily meds are one card with a check when given.",
  "Needs are small tiles with a short summary. Tap one for the full note, who changed it last, and to edit it.",
  "Tap a med to log a dose. Logging too soon asks you to check with hospice first, so no one doubles up.",
  "Private: primary caregivers open it with a PIN or Face ID; it locks after 5 minutes. Demo PIN: 1234. Ana, the hospice nurse, sees meds, allergies and wishes, view only.",
  "Pebble never reads this page.",
]];
