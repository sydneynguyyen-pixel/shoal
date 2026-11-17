/* Shoal: a short spotlight tour of the main app. Runs the first time someone lands on Home after
   onboarding, and again from Settings. Uses state and helpers from app.js and main-app.js. */

// sel: what to spotlight (skipped if it isn't on screen). No sel: a centered card with no spotlight.
const TOUR = [
  { t: "Welcome to Shoal", d: "A quick look around before you start. It takes about 30 seconds." },
  { sel: ".content.app > .title", pad: 10, t: "This is Home", d: "Start here each day: what's urgent, who finished what, and how the week looks." },
  { sel: '[data-sec="jars"] .card', t: "Everyone's jars", d: "Each person has a jar. Every stone is a task, and its glow shows where that task stands." },
  { sel: '[data-sec="week"] .card', t: "Your family's week", d: () => active().length ? "Taller bars are busier days. Tap a day to see what's on it." : "Once you add tasks, this shows which days are busiest so no one gets swamped." },
  { sel: '.tabbar [data-to="myjar"]', t: "My jar", d: "Just your tasks. Check one off when it's done, or hand it to someone else." },
  { sel: '.tabbar [data-to="peopleTab"]', t: "People", d: "Invite family, add friends and neighbors, or share a volunteer code." },
  { sel: '.tabbar [data-to="settings"]', t: "Settings", d: "Stone colors, reminders, and your account. You can replay this tour here too." },
  { sel: '.head-btns [aria-label="Notifications"]', pad: 4, t: "Updates", d: "When someone finishes a task or asks for help, you'll see it here." },
  { sel: '[data-sec="setup"] .sc-row.next, [data-sec="setup"] .sc-peek', t: "Start here", d: "When you're ready to add your first tasks, begin here. Each step takes a few minutes." },
];

let tourI = -1;
const tourSteps = () => TOUR.filter((s) => !s.sel || document.querySelector(s.sel));

function startTour() {
  if (S.screen !== "home") tabTo("home");
  // Open folded sections so every stop has something to point at.
  if (S.app.shut) { S.app.shut = {}; render(); }
  tourI = 0;
  drawTour();
}
function endTour() {
  tourI = -1;
  const el = document.getElementById("tour");
  el.classList.remove("open");
  setTimeout(() => { if (tourI < 0) el.innerHTML = ""; }, 250);
  S.app.toured = true;
}

function drawTour() {
  const steps = tourSteps(), step = steps[tourI];
  if (!step) { endTour(); return; }
  const el = document.getElementById("tour"), phone = document.getElementById("phone");
  const box = phone.getBoundingClientRect(), scale = box.width / phone.offsetWidth;
  const target = step.sel && document.querySelector(step.sel);
  if (target) target.scrollIntoView({ block: "center" });
  const last = tourI === steps.length - 1;
  const card = `<div class="tour-tip" role="dialog" aria-live="polite" aria-label="${esc(step.t)}">
      <p class="eyebrow">${tourI + 1} of ${steps.length}</p>
      <h3>${step.t}</h3><p>${typeof step.d === "function" ? step.d() : step.d}</p>
      <div class="tour-btns">
        ${last ? "<span></span>" : `<button class="btn-text" data-act="tourEnd">Skip tour</button>`}
        <span class="tour-nav">${tourI ? `<button class="btn-soft" data-act="tourMove" data-id="-1">Back</button>` : ""}
          <button class="btn-primary sm" data-act="tourMove" data-id="1">${last ? "Got it" : "Next"}</button></span>
      </div></div>`;
  if (!target) {
    el.innerHTML = `<div class="tour-dim"></div>${card}`;
    el.querySelector(".tour-tip").classList.add("center");
  } else {
    const r = target.getBoundingClientRect(), pad = step.pad ?? 6;
    const x = (r.left - box.left) / scale - pad, y = (r.top - box.top) / scale - pad;
    const w = r.width / scale + pad * 2, h = r.height / scale + pad * 2;
    el.innerHTML = `<div class="tour-spot" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px"></div>${card}`;
    // Put the card on whichever side of the spotlight has more room.
    const tip = el.querySelector(".tour-tip"), H = phone.offsetHeight;
    if (y + h / 2 > H / 2) tip.style.bottom = `${H - y + 14}px`;
    else tip.style.top = `${y + h + 14}px`;
  }
  requestAnimationFrame(() => el.classList.add("open"));
  el.querySelector('[data-act="tourMove"][data-id="1"]').focus();
}

Object.assign(ACTIONS, {
  tourMove: (d) => { tourI += +d.id; tourI >= tourSteps().length ? endTour() : drawTour(); },
  tourEnd: endTour,
  tourStart: () => startTour(),
});

// First time on Home after onboarding, the tour starts on its own. Not in test links (the Swift app has no tour);
// it's still in Settings.
const finishOnboardingBase = finishOnboarding;
finishOnboarding = function () {
  finishOnboardingBase();
  if (document.body.classList.contains("test")) return;
  setTimeout(() => { if (S.screen === "home" && !S.app.toured) startTour(); }, 450);
};

document.addEventListener("keydown", (e) => {
  if (tourI < 0) return;
  if (e.key === "Escape") endTour();
  if (e.key === "ArrowRight") ACTIONS.tourMove({ id: 1 });
  if (e.key === "ArrowLeft" && tourI > 0) ACTIONS.tourMove({ id: -1 });
});
