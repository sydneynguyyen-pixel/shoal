/* Shoal: Home as an overview, like a phone's home screen. A bright ombre, the family jars sitting
   straight on it, and a few widgets in different sizes that each open the screen with the detail.
   The old Home stays one tap away (the "Old look" pill). Uses helpers from main-app.js and kit.js. */

const homeOld = SCREENS.home;

function homeNew() {
  const urgent = active().filter(isUrgent).sort((a, b) => a.date.localeCompare(b.date));
  const finished = S.tasks.find((t) => t.done && t.doneAt && t.who !== "you" && !S.app.thanked[t.id] && !S.app.dismissed[t.id]);
  const week = mondayOf(iso(TODAY)), day = fromIso(S.app.day);
  const today = active().filter((t) => occurs(t, day)).sort((a, b) => (a.time || "99").localeCompare(b.time || "99"));
  const all = mine("you"), left = all.filter((t) => !t.done), myUrgent = left.filter(isUrgent).length;
  const helpers = S.people.filter((p) => p.id !== "you"), invited = helpers.filter((p) => typeof pending === "function" && pending(p)).length;
  const go = `<span class="k-go" aria-hidden="true">${chev}</span>`;
  const head = (lab) => `<div class="k-tile-top"><span class="k-lab">${lab}</span>${go}</div>`;

  const jarW = `<button class="h-w" data-act="tab" data-to="myjar">${head("Your jar")}
    <div class="h-num">${kitRing(all.length ? (all.length - left.length) / all.length : 0, 46, 4)}<b>${left.length}</b></div>
    <p class="k-note">${left.length === 1 ? "task" : "tasks"} to do${myUrgent ? ` · <span class="st-urgent">${myUrgent} urgent</span>` : ""}</p></button>`;

  const out = hasKit() ? notCharging() : [];
  const charging = S.stones.length - out.length;
  const kitW = hasKit()
    ? `<button class="h-w h-kit" data-act="go" data-to="kit">${head("Home kit")}
        <div class="h-num">${kitRing(charging / S.stones.length, 46, 4)}<b>${charging}<small>/${S.stones.length}</small></b></div>
        <p class="k-note">${out.length ? `<span class="h-warn">${out.length} stone${out.length === 1 ? "" : "s"} off power</span>` : `Glow ${S.app.prefs.glow || "on"} · charging`}</p></button>`
    : `<button class="h-w" data-act="tab" data-to="peopleTab">${head("People")}
        <div class="h-avs">${helpers.slice(0, 4).map((p) => avatar(p, "s36")).join("")}</div>
        <p class="k-note">${helpers.length - invited} helping${invited ? ` · ${invited} invited` : ""}</p></button>`;

  return `<div class="home2">
  <div class="content app">
    <div class="apphead">${shoalMark(30)}<span class="head-btns">
      <button class="k-look" data-act="homeLook">Old look</button>
      <button class="bell" data-act="go" data-to="notifications" aria-label="Notifications">${icon("bell")}${unread() ? `<i class="dot"></i>` : ""}</button></span></div>
    ${notifStack(urgent, finished)}
    <p class="eyebrow grey">${TODAY.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}</p>
    <h1 class="title">Good morning</h1>
    ${setupCard()}

    <section class="h-jars" aria-label="Family jars">${familyJars()}</section>

    <div class="k-grid">${jarW}${kitW}</div>

    <section class="h-w wide" aria-label="This week">
      <div class="k-tile-top"><span class="k-lab">This week</span></div>
      ${active().length ? `${loadChart(week)}
        <div class="tlist flat">${today.length ? today.slice(0, S.app.weekAll ? 99 : 3).map((t) => taskLine(t)).join("") : `<p class="small empty">Nothing on ${DAY_FULL[dayKey(day)]}.</p>`}</div>
        ${today.length > 3 ? `<button class="k-link" data-act="weekAll">${S.app.weekAll ? "Show less" : `${today.length - 3} more`}</button>` : ""}`
        : `<p class="small empty">No tasks yet. Once you add some, your family's week shows here.</p>`}
    </section>
  </div>
  ${tabbar()}</div>`;
}

/* ---------- Notifications: iOS banners at the top, not widgets ---------- */

// Each one shows until you open it or clear it, then lives on in the bell. Two or more stack like iOS;
// tap the stack to fan them out. They drop in once, the first time Home shows them.
let notesSeen = new Set();
function notifStack(urgent, finished) {
  const items = [];
  const u = urgent[0];
  if (u && !S.app.dismissed[`u${u.id}`]) items.push({ key: `u${u.id}`, act: "openTask", id: u.id, cls: "urgent", style: `--u:${urgentHex()}`,
    icon: gemOf(u, { size: "s" }), title: `${u.n}`, body: `${cap(dueLabel(u))} · ${nameOf(u.who)}${urgent.length > 1 ? ` · +${urgent.length - 1} urgent` : ""}`, cta: "View" });
  // Pebble's notice is a banner like the others (pearl, so it reads as a suggestion), with its two answers right there.
  const peb = typeof pebbleBanner === "function" && pebbleBanner();
  if (peb) items.push(peb);
  if (finished) items.push({ key: finished.id, act: "sayThanks", id: finished.id, cls: "done",
    icon: avatar(person(finished.who), "s28"), title: `${person(finished.who).name.split(" ")[0]} finished ${finished.n}`, body: finished.doneAt || "Today", cta: "Thank" });
  if (!items.length) return "";
  const open = S.app.stackOpen || items.length === 1, fresh = items.some((n) => !notesSeen.has(n.key));
  items.forEach((n) => notesSeen.add(n.key));
  return `<div class="h-stack ${open ? "open" : "stacked"} ${fresh ? "fresh" : ""}" style="--n:${items.length}">
    ${!open ? `<button class="h-stack-hit" data-act="stackOpen" aria-label="Show ${items.length} notifications"></button>` : ""}
    ${items.map((n, i) => `<div class="h-ios ${n.cls}" style="--i:${i};${n.style || ""}" data-key="${n.key}">
      <button class="h-ios-main" data-act="${n.act}" data-id="${n.id}" ${!open && i ? 'tabindex="-1" aria-hidden="true"' : ""}>
        <span class="h-ios-thumb">${n.icon}</span>
        <span class="h-ios-txt"><span class="n">${esc(n.title)}</span><span class="m">${esc(n.body)}</span></span>
        ${n.alt ? "" : `<span class="h-ios-cta">${n.cta}</span>`}</button>
      ${n.alt ? `<div class="h-ios-acts"><button class="h-ios-cta" data-act="${n.act}" data-id="${n.id}">${esc(n.cta)}</button><button class="h-ios-cta soft" data-act="${n.alt[1]}" data-id="${n.id}">${n.alt[0]}</button></div>` : ""}
      <button class="h-ios-x" data-act="clearNote" data-key="${n.key}" aria-label="Clear"><span aria-hidden="true">×</span></button></div>`).join("")}
    ${open && items.length > 1 ? `<button class="h-stack-less" data-act="stackOpen">Show less</button>` : ""}
  </div>`;
}

// Clearing slides the banner off to the side, then the space closes up.
function clearNote(key, el) {
  const card = el || document.querySelector(`.h-ios[data-key="${key}"]`);
  // Pebble's banner clears the Pebble way: "Not now" means not now.
  const done = () => { if (key.startsWith("peb:")) PB().dismissed[key.slice(4)] = true; else S.app.dismissed[key] = true; render(); };
  if (!card) return done();
  card.classList.add("gone");
  setTimeout(done, 280);
}

// Swipe a banner left to clear it, like iOS.
let nSwipe = null, nSwallow = false;
document.addEventListener("pointerdown", (e) => {
  const card = e.target.closest(".h-stack.open .h-ios");
  if (!card || e.button || e.target.closest(".h-ios-x")) return;
  nSwipe = { card, x: e.clientX, y: e.clientY, dx: 0, on: false, style: card.getAttribute("style") };
});
document.addEventListener("pointermove", (e) => {
  if (!nSwipe) return;
  const dx = e.clientX - nSwipe.x, dy = e.clientY - nSwipe.y;
  if (!nSwipe.on) {
    if (Math.abs(dy) > 10 && Math.abs(dy) > Math.abs(dx)) { nSwipe = null; return; }
    if (dx > -10) return;
    nSwipe.on = true;
    nSwipe.card.classList.add("dragging");
  }
  nSwipe.dx = Math.min(0, dx);
  nSwipe.card.style.transform = `translateX(${nSwipe.dx}px)`;
  nSwipe.card.style.opacity = 1 - Math.min(0.6, -nSwipe.dx / 400);
});
const endNSwipe = () => {
  if (!nSwipe) return;
  const s = nSwipe; nSwipe = null;
  if (!s.on) return;
  nSwallow = true; setTimeout(() => { nSwallow = false; }, 50);
  s.card.classList.remove("dragging");
  s.card.setAttribute("style", s.style);
  if (s.dx < -s.card.offsetWidth * 0.3) clearNote(s.card.dataset.key, s.card);
};
document.addEventListener("pointerup", endNSwipe);
document.addEventListener("pointercancel", endNSwipe);
window.addEventListener("click", (e) => { if (nSwallow) { e.stopPropagation(); e.preventDefault(); nSwallow = false; } }, true);

SCREENS.home = () => (S.app.homeLook === "old"
  ? homeOld().replace(`<span class="head-btns">`, `<span class="head-btns"><button class="k-look" data-act="homeLook">New look</button>`)
  : homeNew());

Object.assign(ACTIONS, {
  stackOpen: () => { S.app.stackOpen = !S.app.stackOpen; render(); },
  clearNote: (d) => clearNote(d.key),
  weekAll: () => { S.app.weekAll = !S.app.weekAll; render(); },
  homeLook: () => { S.app.homeLook = S.app.homeLook === "old" ? "new" : "old"; render(); },
});

NOTES.home = ["Home", ["An overview, like a phone's home screen: a bright ombre, the family jars, and widgets that each open the screen with the detail.",
  "Urgent and finished-task alerts are iOS-style notifications at the very top. They drop in once, stack when there are two (tap to fan them out), and clear with a swipe left or the × on hover. Once cleared, they live in the bell. Tap a jar to see that person.", "Widgets: your jar (how many left, ring is how much is done), the home kit (charging, and any stone off power), and this week (tap a day).",
  "The home kit widget is night blue like the kit screen, so you know where it goes. Without a kit, that spot shows who's helping.",
  "The pill at the top right switches to the old look to compare.",
  "Pebble: when Pebble notices something (an urgent step no one has, a task with no one, a hand-off that was declined), it's a banner in this same stack, on the pearl surface so it reads as a suggestion. Two answers, one tap each: Ask [name] opens Hand off with that person picked and the note written, so what's left is Send; Not now means not now. Swiping it away is Not now too. Pebble asks no one itself."]];
