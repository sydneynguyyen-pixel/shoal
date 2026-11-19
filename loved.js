/* Shoal: the loved one's profile. Who he is, what he likes, and who cares for him. He has no jar.
   His meds, allergies and needs stay on the locked care page. Loaded after care.js. */

APP_SCREENS.add("loved");
APP_NAV.splice(APP_NAV.indexOf("care"), 0, "loved");

const LV_ICON = {
  music: `<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>`,
  food: `<path d="M7 2v8M4 2v5a3 3 0 0 0 6 0V2M7 10v12M17 22V2c-2.5 1.5-3.5 4-3.5 7v4H17"/>`,
  temp: `<path d="M14 14.8V4a2 2 0 0 0-4 0v10.8a4 4 0 1 0 4 0z"/><path d="M12 9v7"/>`,
  leaf: `<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.5 19 2c1 2 2 4.2 2 8 0 5.5-4.8 10-10 10z"/><path d="M2 21c0-3 1.9-5.4 5.1-6"/>`,
  talk: `<path d="M14 9a2 2 0 0 1-2 2H6l-3 3V4a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2z"/><path d="M18 9h1a2 2 0 0 1 2 2v10l-3-3h-6a2 2 0 0 1-2-2v-1"/>`,
  moon: `<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>`,
  cal: `<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>`,
  care: `<rect x="3" y="7" width="18" height="14" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M12 11v6M9 14h6"/>`,
  phone: `<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z"/>`,
  no: `<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>`,
  x: `<path d="M6 6l12 12M18 6L6 18"/>`,
  lock: `<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>`,
};
const lvIcon = (k, size = 16, w = 2.2) => `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${LV_ICON[k]}</svg>`;

// The same items and colors as demoLikes() in the Swift app.
function makeLikes() {
  if (!S.app.demo) return [];
  return [
    { id: "music", cat: "Music", icon: "music", hue: "#7a5af5", loves: ["Jazz on the radio", "Ella Fitzgerald", "Hymns on Sunday"], nots: ["Loud TV"] },
    { id: "food", cat: "Food and drink", icon: "food", hue: "#e0793a", loves: ["Cold ginger ale", "Vanilla pudding", "Canned peaches"], nots: ["Anything spicy"] },
    { id: "temp", cat: "Temperature", icon: "temp", hue: "#2f9bd6", big: "68°", loves: ["Window open a crack", "Light cotton blanket"], nots: ["Heavy covers"] },
    { id: "do", cat: "Things to do", icon: "leaf", hue: "#3f9b8c", loves: ["Watching the bird feeder", "Old photo albums", "Crossword read aloud"], nots: [] },
    { id: "talk", cat: "Things to talk about", icon: "talk", hue: "#d4708a", loves: ["The Giants", "Fishing at Lake Tahoe", "The grandkids"], nots: ["Money"] },
    { id: "comfort", cat: "Comfort", icon: "moon", hue: "#5b6fd6", loves: ["Cool cloth on his forehead", "Someone holding his hand", "Lights low after 8"], nots: ["Being rushed in the morning"] },
    { id: "visits", cat: "Visits", icon: "cal", hue: "#c98a1b", loves: ["Sam's video call, 7 PM", "Pastor Jim, Sundays"], nots: ["More than 2 people at once"] },
  ];
}
const likes = () => (S.app.likes ??= makeLikes());
const likeOf = (id) => likes().find((l) => l.id === id);
// A hex color at some opacity, for the tinted squares and chips.
const tint = (hex, a) => `rgba(${parseInt(hex.slice(1, 3), 16)}, ${parseInt(hex.slice(3, 5), 16)}, ${parseInt(hex.slice(5, 7), 16)}, ${a})`;

// Dad's face. There's no photo, so a warm initial.
// The sample family has Dad's photo; a new account shows a warm initial.
const lovedAvatar = (size) => S.app?.demo
  ? `<img class="lv-av" src="assets/avatar-dad.png" alt="" style="width:${size}px;height:${size}px;object-fit:cover">`
  : `<span class="lv-av" style="width:${size}px;height:${size}px;font-size:${Math.round(size * 0.44)}px" aria-hidden="true">${esc(L().slice(0, 1))}</span>`;

// The card at the top of People.
function lovedCard() {
  return `<button class="card lv-card" data-act="go" data-to="loved">${lovedAvatar(54)}
    <span class="tl-txt"><span class="n">${esc(L())}</span><span class="m">Hospice care at home</span>
      <span class="lv-dots">${likes().slice(0, 5).map((l) => `<i style="color:${l.hue};background:${tint(l.hue, 0.13)}">${lvIcon(l.icon, 11, 2.4)}</i>`).join("")}</span></span>${chev}</button>`;
}

function likesCard(l) {
  return `<button class="card lv-likes" data-act="likesEdit" data-id="${l.id}">
    <span class="lv-lh"><i class="lv-sq" style="color:${l.hue};background:${tint(l.hue, 0.14)}">${lvIcon(l.icon)}</i><b>${esc(l.cat)}</b>${l.big ? `<span class="lv-big" style="color:${l.hue}">${esc(l.big)}</span>` : ""}</span>
    ${l.loves.length || l.nots.length ? `<span class="lv-chips">${l.loves.map((s) => `<span class="lv-chip" style="background:${tint(l.hue, 0.12)}">${esc(s)}</span>`).join("")}${l.nots.map((s) => `<span class="lv-chip not">${lvIcon("no", 11, 2.4)}${esc(s)}</span>`).join("")}</span>` : ""}
  </button>`;
}

SCREENS.loved = () => {
  const team = (ico, t, m, act, extra = "") => `<button class="prow" data-act="${act}" ${extra}><span class="circle-ico">${ico}</span><span class="tl-txt"><span class="n">${t}</span><span class="m">${m}</span></span>${chev}</button>`;
  return `${navtop("People")}
  <div class="content">
    <div class="lv-head">${lovedAvatar(88)}<h1 class="title">${esc(L())}</h1><p class="small">82 · Hospice care at home since September</p></div>
    <div class="card tlist"><button class="prow" data-act="go" data-to="care"><span class="circle-ico">${lvIcon("care", 17, 1.9)}</span>
      <span class="tl-txt"><span class="n">Care info</span><span class="m">Meds, allergies and needs</span></span>${careUnlocked() ? "" : `<span class="lv-lock">${lvIcon("lock", 13, 2.4)}</span>`}${chev}</button></div>
    <p class="section-h">What he likes</p>
    ${likes().map(likesCard).join("") || `<p class="small empty">Nothing yet.</p>`}
    <p class="section-h">Care team</p>
    <div class="card tlist">
      ${team(`<b class="lv-letter">A</b>`, "Ana", "Hospice nurse", "roleGo", `data-to="asNurse"`)}
      ${team(lvIcon("phone", 16, 2), "Hospice office", "(408) 555-0199 · day or night", "callHospiceOffice")}
    </div>
  </div>`;
};

// Edit one kind: remove a chip, or add a like or a don't.
function likesSheet(id) {
  const l = likeOf(id);
  if (!l) return;
  const not = !!S.app.likeNot;
  const group = (title, list, liked) => list.length ? `<p class="lv-gt">${title}</p><div class="lv-chips">${list.map((s, j) => `<button class="lv-chip x" style="background:${liked ? tint(l.hue, 0.12) : "rgba(255,255,255,0.8)"}" data-act="likeRemove" data-id="${id}:${liked ? "l" : "n"}:${j}" aria-label="Remove ${esc(s)}">${esc(s)}${lvIcon("x", 10, 2.6)}</button>`).join("")}</div>` : "";
  openSheet(`<div class="lv-sh"><i class="lv-sq" style="color:${l.hue};background:${tint(l.hue, 0.14)}">${lvIcon(l.icon)}</i><h3>${esc(l.cat)}</h3></div>
    ${group("Likes", l.loves, true)}${group("Doesn't like", l.nots, false)}
    <div class="lv-seg" role="group"><button class="${not ? "" : "on"}" data-act="likeKind" data-id="${id}:0">Likes</button><button class="${not ? "on" : ""}" data-act="likeKind" data-id="${id}:1">Doesn't like</button></div>
    <div class="lv-add"><input id="lv-new" placeholder="Add something" aria-label="Add something"><button class="pc-pill" data-act="likeAdd" data-id="${id}">Add</button></div>
    <button class="btn-ghost wide lv-done" data-act="closeSheet">Done</button>`);
}

Object.assign(ACTIONS, {
  likesEdit: (d) => { S.app.likeNot = false; likesSheet(d.id); },
  likeKind: (d) => { const [id, n] = d.id.split(":"); const v = document.getElementById("lv-new")?.value || ""; S.app.likeNot = n === "1"; likesSheet(id); document.getElementById("lv-new").value = v; },
  likeRemove: (d) => {
    const [id, k, j] = d.id.split(":"), l = likeOf(id);
    (k === "l" ? l.loves : l.nots).splice(+j, 1);
    const v = document.getElementById("lv-new")?.value || "";
    render(); likesSheet(id); document.getElementById("lv-new").value = v;
  },
  likeAdd: (d) => {
    const el = document.getElementById("lv-new"), v = (el?.value || "").trim();
    if (!v) { toast("Write something first"); return; }
    const l = likeOf(d.id), s = v[0].toUpperCase() + v.slice(1);
    (S.app.likeNot ? l.nots : l.loves).push(s);
    render(); likesSheet(d.id); toast("Added. Everyone sees it.");
  },
  callHospiceOffice: () => toast("Calling hospice, (408) 555-0199"),
});

// Enter in the add field adds it.
document.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && e.target.id === "lv-new") document.querySelector('.sheet [data-act="likeAdd"]')?.click();
});

NOTES.loved = [`${"Dad"}'s profile`, [
  "Who he is, what he likes, and who cares for him. He has no jar.",
  "Tap a kind of thing he likes to add to it or take something off. Things he doesn't like show with a no sign.",
  "Care info opens the locked care page: meds, allergies and needs.",
]];
