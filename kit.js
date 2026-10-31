/* Shoal: a cleaner Home kit. Readings sit flat on the background, alerts are notifications, and
   tiles of different sizes are the things you change. The old screen stays one
   tap away (the "Old look" pill) so the two can be compared. Uses helpers from main-app.js and colors.js. */

const kitOld = SCREENS.kit;

// A thin progress ring. It fills in from empty when it first draws.
function kitRing(f, size, w, cls = "") {
  const r = (size - w) / 2, c = 2 * Math.PI * r, m = size / 2;
  return `<svg class="k-ring ${cls}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true">
    <circle class="trk" cx="${m}" cy="${m}" r="${r}" stroke-width="${w}"/>
    <circle class="val" cx="${m}" cy="${m}" r="${r}" stroke-width="${w}" stroke-dasharray="${c}" stroke-dashoffset="${c * (1 - Math.max(0, Math.min(1, f)))}" style="--c:${c}" transform="rotate(-90 ${m} ${m})"/></svg>`;
}
const reading = (f, val, lab, cls = "") => `<span class="k-r ${cls}">${kitRing(f, 72, 5)}<b><span>${val}</span></b><em>${lab}</em></span>`;

// Three sizes, one rule. Readings sit flat on the background (nothing to tap). Tiles are things you
// change: the jars sit up top with their Glow control, two tiles are night hours and colors, and
// every tile has its control in the top right corner. Rarely used things are plain rows at the bottom.
function kitNew() {
  const P = S.app.prefs, g = P.glow || "on";
  const out = notCharging(), spares = S.stones.filter((s) => !s.out && !inJar(s));
  const charging = S.stones.length - out.length, paired = S.stones.filter((s) => s.task).length;
  const avg = Math.round(S.stones.reduce((n, s) => n + s.battery, 0) / S.stones.length);
  const c = stoneColors();
  const txt = (n, m) => `<span class="tl-txt"><span class="n">${n}</span>${m ? `<span class="m">${m}</span>` : ""}</span>`;
  const row = (inner, act, attrs = "") => `<button class="k-set" data-act="${act}" ${attrs}>${inner}${chev}</button>`;
  const [from, fromAm] = fmtTime(P.nightFrom).split(" "), to = fmtTime(P.nightTo);
  return `<div class="kit2">
  ${navtop("Home", `<button class="k-look" data-act="kitLook">Old look</button>`)}
  <div class="content">
    <h1 class="title">Home kit</h1>
    <p class="k-status"><i></i>Base connected</p>

    ${out.map((st) => `<button class="k-alert" data-act="openStone" data-id="${st.id}">
      <span class="k-alert-ic" aria-hidden="true">${kitRing(st.battery / 100, 34, 3)}<i>!</i></span>
      ${txt(`Stone ${String(st.id).padStart(2, "0")} is ${outLabel(st)}`, `${st.battery}% · not charging`)}
      <span class="k-pill dark">Find</span></button>`).join("")}

    <section class="k-hero" data-glow="${g}" aria-label="Your jars">
      <div class="k-tile-top"><span class="k-lab">Glow</span>
        <div class="k-seg" role="radiogroup" aria-label="Glow"><i class="seg-thumb" style="--i:${["on", "dim", "off"].indexOf(g)}" aria-hidden="true"></i>${[["on", "On"], ["dim", "Dim"], ["off", "Off"]].map(([k, l]) => `<button role="radio" class="${g === k ? "on" : ""}" aria-checked="${g === k}" data-act="setGlow" data-id="${k}">${l}</button>`).join("")}</div>
      </div>
      ${familyJars({ act: false })}
    </section>

    <div class="k-read" aria-label="Kit status">
      ${reading(charging / S.stones.length, `${charging}<small>/${S.stones.length}</small>`, "charging")}
      ${reading(avg / 100, `${avg}<small>%</small>`, "avg battery", avg < 30 ? "low" : "")}
      ${reading(spares.length / KIT, spares.length, "spares ready")}
    </div>

    <div class="k-grid">
      <div class="k-tile">
        <div class="k-tile-top"><span class="k-lab">Night hours</span>${toggle(P.night, "pref", "night", "Night hours")}</div>
        ${P.night
          ? `<p class="k-big">${from}<small>${fromAm}</small></p><p class="k-note">until ${to}</p>
             <button class="k-link" data-act="nightSheet">Change ${chev}</button>`
          : `<p class="k-big">Off</p><p class="k-note">Stones glow all night</p>`}
      </div>
      <button class="k-tile" data-act="colorSheet">
        <div class="k-tile-top"><span class="k-lab">Stone colors</span><span class="k-go" aria-hidden="true">${chev}</span></div>
        <span class="k-stones">${COLOR_STATES.map((s) => gem(s, { size: "s" })).join("")}</span>
        <p class="k-note">${COLOR_STATES.map((s) => cap(PALETTE[c[s]].name)).join(" · ")}</p>
      </button>
    </div>

    <div class="k-group">
      ${row(txt("All stones", `${paired} paired · ${KIT - paired} spare`), "go", 'data-to="stones"')}
      ${row(txt("Pair a stone"), "pairSheet")}
      ${row(txt("Setup guide"), "go", 'data-to="ready"')}
    </div>
    <button class="btn-text center" data-act="kitOff">Stop using the kit</button>
  </div></div>`;
}

SCREENS.kit = () => (S.app.kitLook === "old" ? kitOld().replace(navtop("Home"), navtop("Home", `<button class="k-look" data-act="kitLook">New look</button>`)) : kitNew());

// On the kit, Glow changes the jars in place so the stones fade up or down instead of snapping.
const setGlowApp = ACTIONS.setGlow;
Object.assign(ACTIONS, {
  setGlow: (d) => {
    const hero = document.querySelector(".kit2 .k-hero");
    if (!hero) return setGlowApp(d);
    S.app.prefs.glow = d.id;
    hero.dataset.glow = d.id;
    hero.querySelector(".shelf-jars").className = `shelf-jars glow-${d.id}`;
    hero.querySelector(".seg-thumb").style.setProperty("--i", ["on", "dim", "off"].indexOf(d.id));
    hero.querySelectorAll(".k-seg button").forEach((b) => { const on = b.dataset.id === d.id; b.classList.toggle("on", on); b.setAttribute("aria-checked", on); });
    toast(d.id === "on" ? "Stones glow" : d.id === "dim" ? "Stones dimmed" : "Glow off. Colors still show in the app.");
  },
  kitLook: () => { S.app.kitLook = S.app.kitLook === "old" ? "new" : "old"; render(); },
});

NOTES.kit = ["Home kit", ["A test of a cleaner look. Readings (charging, battery, spares) sit flat on the background with nothing to tap. The off-power alert is a notification.",
  "Readings are rings: how much of the kit is charging, average battery, and spares ready.", "The kit is a device screen, so it is dark night blue, like the room the jars sit in. The jars sit right on it at the top, under Glow, and the glow shows. Overview and detail screens keep their own backgrounds. Changing Glow fades the stones live.", "White tiles are things you change, in three sizes: the jars with their glow, then night hours and colors, then plain rows for what you rarely need. Every tile has its control in the top right.",
  "The pill at the top right switches to the old look to compare.", "Everything physical lives here: glow, night hours, colors, the base, jars and every stone's battery.",
  "Pebble: while Pebble has a notice about a task, that task's stone pulses gently in its jar (the same slow glow as Find stone), here and on Home. It stops when someone answers the notice or says Not now, and never when the glow is off or on quiet days."]];
