/* Shoal outside the app: the lock screen, a notification you can answer without opening Shoal,
   and the home screen with its widgets and app icon. Opened from the side panel. Uses the same
   family data as the app, so what's shown here matches what's inside. Loaded after care.js. */

const OS_STEPS = [["osLock", "Lock screen"], ["osNotif", "Answer a notification"], ["osHome", "Home screen"]];
OS_STEPS.forEach(([s]) => APP_SCREENS.add(s));
const isOs = (s) => OS_STEPS.some(([k]) => k === s);

// The family's real state: the next as-needed dose, an open task someone could take, your tasks.
function osData() {
  const prn = care().meds.filter((m) => m.prn).map((m) => ({ m, next: nextOk(m), l: lastDose(m.id) })).sort((a, b) => b.next - a.next)[0];
  const ask = S.app.osAsk ? task(S.app.osAsk) : active().filter((t) => !t.who && t.kind === "once").sort((a, b) => a.date.localeCompare(b.date))[0];
  if (ask) S.app.osAsk = ask.id;
  const all = mine("you"), left = all.filter((t) => !t.done);
  const doneBy = S.tasks.find((t) => t.done && t.who && t.who !== "you");
  // Pebble's notice shows up as a Shoal notification out here too, with the same one-tap answer inside.
  const peb = typeof pebbleNotice === "function" ? pebbleNotice() : null;
  return { prn, ask, all, left, doneBy, peb };
}

const osIcon = (size = 60) => `<span class="os-app shoal" style="--sz:${size}px" aria-hidden="true">${shoalMark(Math.round(size * 0.8))}</span>`;
const osTime = () => clock(Date.now()).replace(/ [AP]M$/, "");
const osDate = () => new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" });
const osNote = ({ title, body, when = "now", act = "", id = "", to = "", cls = "" }) => `<button class="os-note ${cls}" ${act ? `data-act="${act}"` : ""} ${id ? `data-id="${id}"` : ""} ${to ? `data-to="${to}"` : ""}>
  ${osIcon(38)}<span class="os-note-txt"><span class="os-note-top"><b>${esc(title)}</b><em>${when}</em></span><span class="os-note-body">${body}</span></span></button>`;

function doseLine(prn) {
  if (!prn) return null;
  const early = prn.next > Date.now();
  return { early, txt: early ? `${prn.m.name} okay after ${clock(prn.next)}` : `${prn.m.name} okay now if needed`,
    f: prn.l ? Math.min(1, (Date.now() - prn.l.at) / (prn.m.every * 36e5)) : 1 };
}

const osBottom = `<div class="os-bottom"><span class="os-round" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3h8l-1 6h-6zM9 9h6v12H9zM12 13v3"/></svg></span>
  <span class="os-round" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3l2-3h6l2 3h3v11H4zM12 10a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z"/></svg></span></div>`;

function lockTop(D) {
  const d = doseLine(D.prn);
  return `<p class="os-date">${osDate()}</p>
    <p class="os-clock">${osTime()}</p>
    <div class="os-lw">
      ${d ? `<button class="os-lw-rect" data-act="osOpenApp" data-to="care">${kitRing(d.f, 40, 4)}<span><b>${esc(D.prn.m.name)}</b><span>${d.early ? `Okay after ${clock(D.prn.next)}` : "Okay now"}</span></span></button>` : ""}
      <button class="os-lw-circ" data-act="osOpenApp" data-to="myjar">${kitRing(D.all.length ? (D.all.length - D.left.length) / D.all.length : 0, 52, 4)}<b>${D.left.length}</b><small>to do</small></button>
    </div>`;
}

SCREENS.osLock = () => {
  const D = osData(), d = doseLine(D.prn);
  return `<div class="os os-lock">
    ${lockTop(D)}
    <div class="os-stack">
      ${d && d.early ? `<button class="os-live" data-act="osOpenApp" data-to="care">
        <span class="os-live-top">${osIcon(26)}<b>${esc(D.prn.m.name)} ${esc(D.prn.m.amt)}</b><em>${esc(cap(whoName(D.prn.l.who)))} gave it ${clock(D.prn.l.at)}</em></span>
        <span class="os-live-bar"><i style="width:${Math.round(d.f * 100)}%"></i></span>
        <span class="os-live-foot"><span>Next dose okay</span><b>${clock(D.prn.next)}</b></span></button>` : ""}
      ${D.ask ? osNote({ title: "Can someone take this?", body: `<b>${esc(D.ask.n)}</b> · ${esc(cap(dueLabel(D.ask)))}. Hold to answer.`, act: "go", to: "osNotif" }) : ""}
      ${D.peb ? osNote({ title: "Pebble noticed", body: `<b>${esc(D.peb.title)}</b> · ${esc(D.peb.body)}. Tap to ${esc(D.peb.cta.replace(/^(Ask|Find)/, (w) => w.toLowerCase()))}.`, act: "osPebble", id: D.peb.key, when: "2m ago" }) : ""}
      ${D.doneBy ? osNote({ title: `${person(D.doneBy.who).name.split(" ")[0]} finished a task`, body: `${esc(D.doneBy.n)}. Say thanks?`, when: "12m ago", act: "osOpenApp", to: "home", cls: "back" }) : ""}
    </div>
    ${osBottom}
    <span class="os-bar" aria-hidden="true"></span>
  </div>`;
};

// Long-press: the notification grows, with its answers right there.
SCREENS.osNotif = () => {
  const D = osData(), t = D.ask;
  const done = t && t.who === "you";
  return `<div class="os os-lock os-dim">
    ${lockTop(D)}
    <div class="os-expanded">
      ${t ? `<div class="os-x-card">
        <span class="os-note-top">${osIcon(26)}<b>Shoal</b><em>now</em></span>
        <p class="os-x-title">${done ? "You've got it" : "Can someone take this?"}</p>
        <p class="os-x-task">${esc(t.n)}</p>
        <p class="os-x-meta">${esc(cap(dueLabel(t)))}${t.notes ? ` · ${esc(t.notes.split(".")[0])}` : ""}</p>
        ${done ? `<p class="os-x-done">${CHECK_SVG}The family can see it's yours.</p>` : ""}
      </div>
      <div class="os-x-acts">${done
        ? `<button data-act="osOpenApp" data-to="task" data-id="${t.id}">Open in Shoal</button><button data-act="osJump" data-to="osHome">Done</button>`
        : `<button data-act="osTake" data-id="${t.id}">I'll take it</button><button data-act="osPass">Not this time</button><button data-act="osOpenApp" data-to="task" data-id="${t.id}">Open in Shoal</button>`}</div>`
      : `<p class="os-x-meta">Nothing open right now.</p>`}
    </div>
    <span class="os-bar" aria-hidden="true"></span>
  </div>`;
};

// Stand-in apps around Shoal, drawn like iOS icons, so Shoal's icon and widgets read in context.
const fillSvg = (d, vb = "0 0 24 24") => `<svg viewBox="${vb}" aria-hidden="true">${d}</svg>`;
const OS_ICONS = {
  Calendar: () => { const d = new Date(); return `<span class="ic ic-cal"><b>${d.toLocaleDateString("en-US", { weekday: "short" }).toUpperCase()}</b><i>${d.getDate()}</i></span>`; },
  Photos: () => `<span class="ic ic-photos">${[0, 45, 90, 135, 180, 225, 270, 315].map((r, i) => `<i style="--r:${r}deg;--c:${["#f7c23c", "#f5913a", "#ec5464", "#c260d8", "#7f6ce6", "#4a9ef0", "#4ec3c9", "#7fcf5a"][i]}"></i>`).join("")}</span>`,
  Camera: () => `<span class="ic ic-camera">${fillSvg(`<rect x="3" y="7" width="18" height="12.5" rx="3" fill="#1d1d1f"/><path d="M8.5 7l1.4-2.2h4.2L15.5 7z" fill="#1d1d1f"/><circle cx="12" cy="13.2" r="3.9" fill="#3a3a3c" stroke="#d1d1d6" stroke-width="1.2"/><circle cx="17.6" cy="9.6" r=".9" fill="#f5c84b"/>`)}</span>`,
  Maps: () => `<span class="ic ic-maps">${fillSvg(`<path d="M0 15 24 9v4L0 19z" fill="#fff" opacity=".9"/><path d="M13 0h4v24h-4z" fill="#3b8df5" opacity=".9"/><circle cx="12" cy="13" r="5" fill="#fff"/><circle cx="12" cy="13" r="4" fill="#2f7bf0"/><path d="M12 10l2.2 5.2-2.2-1.2-2.2 1.2z" fill="#fff"/>`)}</span>`,
  Clock: () => { const d = new Date(), h = (d.getHours() % 12) * 30 + d.getMinutes() / 2, m = d.getMinutes() * 6;
    return `<span class="ic ic-clock">${fillSvg(`<circle cx="12" cy="12" r="10" fill="#fff"/>${Array.from({ length: 12 }, (_, i) => `<rect x="11.6" y="2.8" width=".8" height="1.8" fill="#1d1d1f" transform="rotate(${i * 30} 12 12)"/>`).join("")}<rect x="11.4" y="6.6" width="1.2" height="6" rx=".6" fill="#1d1d1f" transform="rotate(${h} 12 12)"/><rect x="11.55" y="4.2" width=".9" height="8.3" rx=".45" fill="#1d1d1f" transform="rotate(${m} 12 12)"/><circle cx="12" cy="12" r="1" fill="#f19a37"/>`)}</span>`; },
  Notes: () => `<span class="ic ic-notes"><i></i></span>`,
  Weather: () => `<span class="ic ic-weather">${fillSvg(`<circle cx="9" cy="9" r="4" fill="#ffd34d"/><path d="M8 19h9a3.5 3.5 0 0 0 .3-7 5 5 0 0 0-9.4 1.3A2.9 2.9 0 0 0 8 19z" fill="#fff"/>`)}</span>`,
  Messages: () => `<span class="ic ic-green">${fillSvg(`<path d="M12 4.5c4.7 0 8.5 3 8.5 6.8s-3.8 6.8-8.5 6.8c-.9 0-1.8-.1-2.6-.3L5 19.5l1.2-3.4C4.5 14.9 3.5 13.2 3.5 11.3 3.5 7.5 7.3 4.5 12 4.5z" fill="#fff"/>`)}</span>`,
  Phone: () => `<span class="ic ic-green">${fillSvg(`<path d="M7.3 3.6c.5-.2 1 0 1.3.4l1.8 2.9c.3.5.2 1.1-.2 1.5L8.9 9.6a11 11 0 0 0 5.5 5.5l1.2-1.3c.4-.4 1-.5 1.5-.2l2.9 1.8c.4.3.6.8.4 1.3l-.7 2c-.3.8-1.1 1.3-2 1.2C10.5 19.4 4.6 13.5 4.1 6.3c-.1-.9.4-1.7 1.2-2z" fill="#fff"/>`)}</span>`,
  Browser: () => `<span class="ic ic-browser">${fillSvg(`<circle cx="12" cy="12" r="9" fill="url(#bz)"/><defs><linearGradient id="bz" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4fc3ff"/><stop offset="1" stop-color="#1a6fe0"/></linearGradient></defs>${Array.from({ length: 24 }, (_, i) => `<rect x="11.8" y="3.6" width=".4" height="1.2" fill="#fff" opacity=".8" transform="rotate(${i * 15} 12 12)"/>`).join("")}<path d="M15.8 8.2 13 13l-4.8 2.8L11 11z" fill="#ff3b30"/><path d="M8.2 15.8 11 11l2 2z" fill="#fff"/>`)}</span>`,
  Music: () => `<span class="ic ic-music">${fillSvg(`<path d="M9.5 16.5V7.2l9-2v9.6" stroke="#fff" stroke-width="1.8" fill="none" stroke-linejoin="round"/><circle cx="7.6" cy="16.6" r="2.2" fill="#fff"/><circle cx="16.6" cy="14.8" r="2.2" fill="#fff"/>`)}</span>`,
};
const osApp = (n, label = true) => `<span class="os-cell">${OS_ICONS[n]()}${label ? `<em>${n}</em>` : ""}</span>`;
const osShoal = (badge) => `<button class="os-cell" data-act="osOpenApp" data-to="home" aria-label="Open Shoal">${osIcon(62)}${badge ? `<i class="os-badge">${badge}</i>` : ""}<em>Shoal</em></button>`;

SCREENS.osHome = () => {
  const D = osData(), d = doseLine(D.prn), next = D.left.filter((t) => t.date).sort((a, b) => (a.date + (a.time || "")).localeCompare(b.date + (b.time || "")))[0] || D.left[0];
  const badge = notifications().length;
  const [t, ap] = D.prn ? clock(D.prn.next).split(" ") : [];
  return `<div class="os os-home">
    <div class="os-hgrid">
      ${d ? `<button class="os-wsq" data-act="osOpenApp" data-to="care">
        <span class="os-wsq-top">${kitRing(d.f, 54, 6)}<span class="os-wsq-name">${esc(D.prn.m.name)}<small>${esc(D.prn.m.amt)}</small></span></span>
        <span class="os-wsq-lab">${d.early ? "Okay after" : "Okay"}</span>
        <b class="os-wsq-big">${d.early ? `${t}<small>${ap}</small>` : "Now"}</b>
        <em>Shoal</em></button>` : ""}
      ${["Calendar", "Photos", "Camera", "Maps"].map((n) => osApp(n)).join("")}
      ${["Clock", "Notes", "Weather"].map((n) => osApp(n)).join("")}${osShoal(badge)}
      <button class="os-wmed" data-act="osOpenApp" data-to="${next ? "task" : "myjar"}" ${next ? `data-id="${next.id}"` : ""}>
        <span class="os-wmed-l"><span class="os-wmed-head">${shoalMark(14)}Up next for you</span>
          ${next ? `<b>${esc(next.n)}</b><span class="os-wmed-when">${esc(cap(dueLabel(next)))}</span>` : `<b>Nothing on your plate</b>`}</span>
        <span class="os-wmed-r">${kitRing(D.all.length ? (D.all.length - D.left.length) / D.all.length : 0, 58, 6)}<b>${D.left.length}</b><small>to do</small></span>
        <em>Shoal</em></button>
    </div>
    <span class="os-search" aria-hidden="true">${fillSvg(`<circle cx="10.5" cy="10.5" r="6" fill="none" stroke="currentColor" stroke-width="2.4"/><path d="M15 15l4.5 4.5" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/>`)}Search</span>
    <div class="os-dock">${["Phone", "Browser", "Messages", "Music"].map((n) => osApp(n, false)).join("")}</div>
    <span class="os-bar" aria-hidden="true"></span>
  </div>`;
};

Object.assign(ACTIONS, {
  osOpen: () => { S.app.osFrom = isOs(S.screen) ? S.app.osFrom : S.screen; S.app.osAsk = null; S.history = []; lastDir = "fade"; closeSheet(); S.screen = "osLock"; render(); },
  osJump: (d) => { S.history = []; lastDir = "fade"; closeSheet(); S.screen = d.to; render(); },
  osClose: () => { const to = S.app.osFrom && !isOs(S.app.osFrom) ? S.app.osFrom : "home"; S.history = []; lastDir = "fade"; S.screen = to; render(); },
  // Opening Shoal from outside lands on Home, then the screen that was tapped, so Back works.
  osOpenApp: (d) => {
    S.history = []; lastDir = "fade"; S.screen = "home";
    if (d.to === "home") { render(); return; }
    if (d.to === "task") { ACTIONS.openTask({ id: d.id }); return; }
    if (d.to === "myjar") { render(); tabTo("myjar"); return; }
    S.history = ["home"]; S.screen = d.to; render();
  },
  osTake: (d) => { const t = task(d.id); t.who = "you"; render(); },
  // Tapping Pebble's notification opens Shoal straight into Hand off, pick made and note written.
  osPebble: (d) => { S.history = []; lastDir = "fade"; S.screen = "home"; render(); ACTIONS.pebbleAskFor({ id: d.id }); },
  osPass: () => { toast("Okay. The family will ask someone else."); setTimeout(() => ACTIONS.osJump({ to: "osHome" }), 600); },
});

// The side panel while you're outside the app: the three steps, and a way back in.
const appNotesBase = renderAppNotes;
renderAppNotes = function () {
  if (!isOs(S.screen)) { appNotesBase(); return; }
  const N = {
    osLock: ["Lock screen", ["Glanceable without unlocking. The rectangle widget shows when the next as-needed dose is okay; the circle shows your tasks left.", "A Live Activity counts down to the next dose after anyone logs one, so no one doubles up.", "Notifications: a task someone could take, and a thank-you. Tap the first one to answer it.", "Pebble: anything Pebble noticed is a Shoal notification here as well. Tapping it opens Shoal straight into Hand off with Pebble's pick and note ready, so the whole answer is one more tap: Send.", "Only primary caregivers get dose widgets, like the care page."]],
    osNotif: ["Answer a notification", ["Hold a notification and it opens up with its answers, so taking a task doesn't mean opening the app.", "\"I'll take it\" really assigns it. Open Shoal afterwards and it's in your jar."]],
    osHome: ["Home screen", ["A small widget: when the next dose is okay. A medium one: what's up next for you.", "The Shoal icon carries a badge for unread updates. Tap it, or any widget, to open the app right there.", "The other apps are stand-ins, there for context."]],
  }[S.screen];
  document.getElementById("notes").innerHTML = `
    <p class="eyebrow">Shoal · outside the app</p>
    <h2>${N[0]}</h2>
    <ol>${OS_STEPS.map(([s, t]) => `<li><button data-act="osJump" data-to="${s}" aria-current="${s === S.screen}">${t}</button></li>`).join("")}</ol>
    <div class="why"><strong>About this screen</strong><ul>${N[1].map((b) => `<li>${b}</li>`).join("")}</ul></div>
    <button class="os-open" data-act="osClose">Back to the app</button>`;
};
