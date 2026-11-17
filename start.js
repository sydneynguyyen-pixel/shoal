/* Shoal: first open. Logo splash → sign in (phone, Google, Facebook) → text code → intro to Shoal → welcome. */

const PRE_SCREENS = ["splash", "signin", "verify", "intro"];
const auth = () => (S.auth ||= { phone: "", code: "", via: null, sentAt: 0 });

/* ---------- Logo ---------- */

// Five stones of the Shoal mark, placed as in Figma: [piece, center x %, center y %, width %, height %, rotation].
const MARK = [
  ["top", 50, 18, 29, 18, 0],
  ["right", 79.48, 40.42, 25, 16, 72],
  ["bottom-right", 69.1, 76.3, 30, 19, 144],
  ["bottom-left", 32.07, 74.68, 23, 15, -144],
  ["lit", 20.05, 40.27, 37.53, 27.53, -72],
];
const shoalMark = (size, cls = "") => `<span class="mark ${cls}" style="width:${size}px;height:${size}px" aria-hidden="true">${MARK.map(([n, x, y, w, h, r], i) =>
  `<i class="m-${n}" style="--x:${x}%;--y:${y}%;width:${w}%;height:${h}%;--r:${r}deg;--i:${i}"><img src="${A(`brand/mark-${n}.svg`)}" alt=""></i>`).join("")}</span>`;
const lockup = (size = 26) => `<span class="lockup" style="--s:${size}px">${shoalMark(size)}<span class="wm">shoal</span></span>`;
const brandRings = (cls = "") => `<div class="brand-rings ${cls}" aria-hidden="true">
  <img class="r1" src="${A("brand/ring-1.svg")}" alt=""><img class="r2" src="${A("brand/ring-2.svg")}" alt="">
  <img class="r3" src="${A("brand/ring-3.svg")}" alt=""><img class="cream" src="${A("brand/cream-glow.svg")}" alt=""></div>`;

/* ---------- Splash ---------- */

SCREENS.splash = () => `<div class="splash" data-act="splashDone">
  ${brandRings("sp")}
  <div class="sp-center">
    ${shoalMark(104, "assemble")}
    <p class="sp-word">shoal</p>
    <p class="sp-tag">Share caregiving with your family</p>
  </div>
</div>`;

let splashTimer;
function scheduleSplash() {
  clearTimeout(splashTimer);
  splashTimer = setTimeout(() => { if (S.screen === "splash") ACTIONS.splashDone(); }, 3400);
}

/* ---------- Sign in ---------- */

const fmtPhone = (d) => d.length < 4 ? d : d.length < 7 ? `(${d.slice(0, 3)}) ${d.slice(3)}` : `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`;
const GOOGLE_G = `<svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.6 5.4 2.7 13.2l7.9 6.2C12.5 13.6 17.8 9.5 24 9.5z"/><path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.7c-.6 3-2.3 5.5-4.8 7.2l7.7 6c4.5-4.2 6.9-10.3 6.9-17.7z"/><path fill="#FBBC05" d="M10.6 28.6c-.5-1.4-.8-3-.8-4.6s.3-3.2.8-4.6l-7.9-6.2C1 16.6 0 20.2 0 24s1 7.4 2.7 10.8l7.9-6.2z"/><path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.7-6c-2.2 1.5-5 2.3-8.2 2.3-6.2 0-11.5-4.1-13.4-9.9l-7.9 6.2C6.6 42.6 14.6 48 24 48z"/></svg>`;
const FACEBOOK_F = `<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="12" fill="#1877F2"/><path fill="#fff" d="M15.1 12.6l.4-2.7h-2.6V8.1c0-.8.4-1.5 1.6-1.5h1.2V4.3s-1.1-.2-2.1-.2c-2.2 0-3.6 1.3-3.6 3.7v2.1H7.6v2.7H10V19h2.9v-6.4h2.2z"/></svg>`;

SCREENS.signin = () => {
  const a = auth();
  const busy = a.via && a.via !== "phone";
  return `<div class="content signin ${S._fromSplash ? "from-splash" : ""}">
    <div class="si-hero">${brandRings("si")}${lockup(40)}</div>
    <h1 class="title rise" style="--d:1">Sign in to get started</h1>
    <p class="sub rise" style="--d:2">Enter your phone number and we'll text you a code. You don't need a password.</p>
    <label class="phone-field rise" style="--d:3">
      <span class="cc">🇺🇸 +1</span>
      <input type="tel" inputmode="numeric" autocomplete="tel-national" placeholder="(555) 123-4567" data-input="phone" value="${fmtPhone(a.phone)}" aria-label="Phone number">
    </label>
    <button class="btn-primary rise" style="--d:4" data-act="sendCode" ${a.phone.length < 10 ? "disabled" : ""}>Text me a code</button>
    <div class="or rise" style="--d:5"><span>or</span></div>
    <div class="social rise" style="--d:6">
      <button class="btn-social" data-act="social" data-via="Google" ${busy ? "disabled" : ""}>${a.via === "Google" ? `<i class="spin"></i>Connecting…` : `${GOOGLE_G}Continue with Google`}</button>
      <button class="btn-social" data-act="social" data-via="Facebook" ${busy ? "disabled" : ""}>${a.via === "Facebook" ? `<i class="spin"></i>Connecting…` : `${FACEBOOK_F}Continue with Facebook`}</button>
    </div>
    <p class="fine rise" style="--d:7">By continuing, you agree to Shoal's Terms and Privacy Policy. Your carrier may charge for texts.</p>
    <button class="skip-onboarding rise" style="--d:7" data-act="skipSignin">Skip sign-in (testing) →</button>
  </div>`;
};

/* ---------- Verify ---------- */

SCREENS.verify = () => {
  const a = auth();
  const done = a.code.length === 6;
  return `${navtop("Back")}
  <div class="content verify">
    <p class="eyebrow">Verify your number</p>
    <h1 class="title">Enter the 6-digit code</h1>
    <p class="sub">Sent to +1 ${fmtPhone(a.phone)}. <button class="linkish" data-act="back">Change number</button></p>
    <label class="code-boxes ${done ? "ok" : ""}">
      ${Array.from({ length: 6 }, (_, i) => `<span class="cb ${i === a.code.length ? "cur" : ""} ${a.code[i] ? "has" : ""}">${a.code[i] || ""}</span>`).join("")}
      <input type="text" inputmode="numeric" autocomplete="one-time-code" maxlength="6" data-input="code" value="${a.code}" aria-label="6-digit code" ${done ? "disabled" : "autofocus"}>
    </label>
    <p class="code-status">${done ? `<i class="spin"></i>Checking the code…` : `<span data-resend>${resendLabel()}</span>`}</p>
    <p class="fine center">Prototype: any 6 digits work, or tap the text that comes in.</p>
  </div>
  <button class="sms-banner" data-act="fillCode" aria-label="Text message with your code">
    <span class="sms-app">${shoalMark(20)}</span>
    <span class="sms-txt"><b>Messages <em>now</em></b><span>Your Shoal code is 482913. Don't share it with anyone.</span></span>
  </button>`;
};

const RESEND_S = 30;
function resendLabel() {
  const left = Math.max(0, RESEND_S - Math.floor((Date.now() - auth().sentAt) / 1000));
  return left ? `No text yet? You can resend in 0:${String(left).padStart(2, "0")}` : `No text yet? <button class="linkish" data-act="resend">Resend code</button>`;
}
let smsTimer, resendTimer;
function startCodeTimers() {
  auth().sentAt = Date.now();
  clearTimeout(smsTimer); clearInterval(resendTimer);
  smsTimer = setTimeout(() => {
    document.querySelector(".sms-banner")?.classList.add("show");
    smsTimer = setTimeout(() => document.querySelector(".sms-banner")?.classList.remove("show"), 7000);
  }, 1400);
  resendTimer = setInterval(() => {
    const el = document.querySelector("[data-resend]");
    if (!el || S.screen !== "verify") { clearInterval(resendTimer); return; }
    el.innerHTML = resendLabel();
  }, 1000);
}
function codeEntered() {
  clearTimeout(smsTimer);
  render();
  setTimeout(() => { if (S.screen === "verify") signedIn("Number verified"); }, 1100);
}
function signedIn(msg) {
  S.history = [];
  S.introI = 0;
  lastDir = "fade";
  S.screen = "intro";
  render();
  toast(msg);
}

/* ---------- Intro to Shoal ---------- */

const introJar = (name, states) => {
  const pos = jarSlots(states.length);
  return `<div class="rjar"><div class="glassbox"><img class="glass" src="${A("jar.png")}" alt="">
    ${states.map((s, i) => gem(s.replace("*", ""), { size: "s", dark: s.endsWith("*"), cls: `w${sampleW(i)}`, style: `left:${pos[i].x}px;top:${pos[i].y}px` })).join("")}
  </div><span class="who">${name}</span></div>`;
};

const PRIVACY = [
  ["Only people you invite can see your plan", "Not other users, and not advertisers."],
  ["Calendars only show when you're busy", "Shoal never sees what your events are."],
  ["Sign-in uses a code sent to your phone", "No password to guess or steal."],
  ["You can delete your data anytime", "Your account and plan are removed for good."],
];

const SLIDES = [
  {
    eyebrow: "Welcome to Shoal",
    title: "Share caregiving with your family",
    sub: "Shoal is a shared to-do list for taking care of someone. Everyone can see what needs to be done and who is doing it.",
    visual: () => `<div class="iv-rings">
      <div class="iv-circle">${shoalMark(72, "float")}
        ${[["avatar-you.png", "You"], ["avatar-nora.png", "Nora"], ["avatar-bill.png", "Bill"], ["avatar-sam.png", "Sam"]].map(([img, n], k) =>
          `<span class="orb o${k}"><span class="avatar"><img src="${A(img)}" alt=""></span><b>${n}</b></span>`).join("")}
      </div></div>`,
  },
  {
    eyebrow: "Tasks",
    title: "Each task is a stone",
    sub: "Every task, like a ride or a refill, gets a stone. Its color tells you if it's urgent, someone is doing it, it's open, or it's done.",
    visual: () => `<div class="iv-stones">
      <div class="st s1">${gem("urgent", { size: "l", cls: "breathe" })}<span class="tag"><i class="d urgent"></i>Refill prescription · urgent</span></div>
      <div class="st s2">${gem("progress", { size: "l", cls: "breathe" })}<span class="tag"><i class="d progress"></i>Drive to PT · Bill is doing it</span></div>
      <div class="st s3">${gem("open", { size: "l" })}<span class="tag"><i class="d open"></i>Weekly groceries · open</span></div>
      <div class="st s4">${gem("done", { size: "l" })}<span class="tag"><i class="d done"></i>Call hospice · done</span></div>
    </div>`,
  },
  {
    eyebrow: "Your family",
    title: "Each person has a jar",
    sub: "Your jar holds the tasks you've taken on. You can see who has a lot and who has room for more.",
    visual: () => `<div class="iv-jars"><div class="shelf-jars">
      ${introJar("You", ["done", "done*", "progress", "open*", "urgent"])}
      ${introJar("Nora", ["done", "done", "done*", "progress*", "progress", "open"])}
      ${introJar("Bill", ["done*", "progress", "open"])}
    </div><div class="shelf"></div></div>`,
  },
  {
    eyebrow: "At home",
    title: "Real stones light up at home",
    sub: "You can link a real stone to a task and keep it in a jar at home. It lights up in the same colors, so anyone can check without a phone.",
    visual: () => `<div class="iv-hold">${gem("progress", { size: "xl", cls: "breathe" })}
      <span class="status-pill">Blue · someone is doing it</span></div>`,
  },
  {
    eyebrow: "Privacy and security",
    title: "Your family's info stays private",
    sub: "We only use what you share to run your family's plan. We never sell it.",
    visual: () => `<div class="iv-privacy"><div class="lock-badge"><img src="${A("lock.svg")}" alt=""></div>
      <div class="card priv-list">${PRIVACY.map(([t, d]) => `<div class="priv-row"><span class="pr-check"><img src="${A("check.svg")}" alt=""></span><span><b>${t}</b><small>${d}</small></span></div>`).join("")}</div>
    </div>`,
  },
];

SCREENS.intro = () => {
  const i = S.introI || 0;
  const last = i === SLIDES.length - 1;
  return `<div class="intro">
    <div class="intro-top">${lockup(24)}<button class="intro-skip" data-act="introDone" ${last ? "hidden" : ""}>Skip</button></div>
    <div class="intro-viewport">
      <div class="intro-track" style="transform:translateX(${-100 * i}%)">
        ${SLIDES.map((s, k) => `<section class="intro-slide ${k === i ? "on" : ""}" aria-hidden="${k !== i}">
          <div class="iv">${s.visual()}</div>
          <div class="it"><p class="eyebrow">${s.eyebrow}</p><h1 class="title">${s.title}</h1><p class="sub">${s.sub}</p></div>
        </section>`).join("")}
      </div>
    </div>
    <div class="intro-foot">
      <div class="dots">${SLIDES.map((_, k) => `<button class="${k === i ? "on" : ""}" data-act="introTo" data-i="${k}" aria-label="Slide ${k + 1}"></button>`).join("")}</div>
      <button class="btn-primary" data-act="introNext">${last ? "Set up your family's plan" : "Next"}</button>
    </div>
  </div>`;
};

// Slides move in place so the slide transition can play; a full render would cut it.
function introGo(i) {
  S.introI = Math.max(0, Math.min(SLIDES.length - 1, i));
  const track = document.querySelector(".intro-track");
  if (!track) { render(); return; }
  const last = S.introI === SLIDES.length - 1;
  track.style.transform = `translateX(${-100 * S.introI}%)`;
  track.querySelectorAll(".intro-slide").forEach((s, k) => { s.classList.toggle("on", k === S.introI); s.setAttribute("aria-hidden", k !== S.introI); });
  document.querySelectorAll(".intro .dots button").forEach((d, k) => d.classList.toggle("on", k === S.introI));
  document.querySelector(".intro-foot .btn-primary").textContent = last ? "Set up your family's plan" : "Next";
  document.querySelector(".intro-skip").hidden = last;
}

let swipeX = null;
document.addEventListener("pointerdown", (e) => { swipeX = e.target.closest(".intro-viewport") ? e.clientX : null; });
document.addEventListener("pointerup", (e) => {
  if (swipeX === null) return;
  const dx = e.clientX - swipeX;
  swipeX = null;
  if (Math.abs(dx) > 40) introGo((S.introI || 0) + (dx < 0 ? 1 : -1));
});

/* ---------- Actions and hooks ---------- */

function toWelcome() {
  S.history = [];
  lastDir = "fwd";
  S.screen = "welcome";
  render();
}

Object.assign(ACTIONS, {
  splashDone: () => {
    if (S.screen !== "splash") return;
    clearTimeout(splashTimer);
    const sp = document.querySelector(".splash");
    sp?.classList.add("out");
    setTimeout(() => {
      if (S.screen !== "splash") return;
      S._fromSplash = true;
      lastDir = "fade";
      S.screen = "signin";
      render();
      S._fromSplash = false;
    }, 420);
  },
  sendCode: () => { auth().code = ""; go("verify"); startCodeTimers(); },
  resend: () => { startCodeTimers(); document.querySelector(".sms-banner")?.classList.remove("show"); toast("New code sent"); },
  fillCode: () => { auth().code = "482913"; codeEntered(); },
  social: (d) => {
    auth().via = d.via;
    render();
    setTimeout(() => { if (S.screen === "signin") { auth().via = null; signedIn(`Signed in with ${d.via}`); } }, 1200);
  },
  skipSignin: () => signedIn("Skipped sign-in"),
  introNext: () => ((S.introI || 0) < SLIDES.length - 1 ? introGo((S.introI || 0) + 1) : toWelcome()),
  introTo: (d) => introGo(+d.i),
  introDone: toWelcome,
});

const restartPrototype = ACTIONS.restart;
ACTIONS.restart = () => { restartPrototype(); scheduleSplash(); };
const jumpTo = ACTIONS.jump;
ACTIONS.jump = (d) => {
  if (d.to === S.screen) return;
  if (d.to === "splash") { ACTIONS.restart(); return; }
  if (d.to === "welcome" || PRE_SCREENS.includes(d.to)) {
    S = initialState();
    S.screen = d.to;
    lastDir = "back";
    render();
    return;
  }
  jumpTo(d);
};

APP_INPUT.phone = (v) => {
  const a = auth();
  a.phone = v.replace(/\D/g, "").replace(/^1(?=\d{10})/, "").slice(0, 10);
  const el = document.querySelector('[data-input="phone"]');
  el.value = fmtPhone(a.phone);
  document.querySelector('[data-act="sendCode"]').disabled = a.phone.length < 10;
};
APP_INPUT.code = (v) => {
  const a = auth();
  a.code = v.replace(/\D/g, "").slice(0, 6);
  if (a.code.length === 6) { codeEntered(); return; }
  document.querySelectorAll(".code-boxes .cb").forEach((b, i) => {
    b.textContent = a.code[i] || "";
    b.classList.toggle("has", !!a.code[i]);
    b.classList.toggle("cur", i === a.code.length);
  });
  document.querySelector('[data-input="code"]').value = a.code;
};

Object.assign(NOTES, {
  splash: ["Logo splash", ["The five stones of the mark circle into place, the lit stone glows, then the wordmark fades in.", "Moves on by itself after about 3 seconds. Tap to skip."]],
  signin: ["Sign in", ["Phone number first: no password, just a texted code.", "Google and Facebook as the two other options. Both are simulated here."]],
  verify: ["Text code", ["Six boxes that fill as you type, with the phone's one-time-code autofill.", "A fake text slides in after a moment; tap it to fill the code. Resend unlocks after 30 seconds."]],
  intro: ["Meet Shoal", ["Five swipeable slides before setup: what Shoal is, stones, jars, real stones at home, and privacy and security.", "Pebble isn't introduced here, since it's optional. It's offered on the next screen."]],
});

// Links for user testing. ?start=family opens the full sample family's Home (onboarded, kit on).
// ?start=new, or no start, opens first open. Any start link, or ?test=1, hides the notes panel.
const URLQ = new URLSearchParams(location.search);
const START = URLQ.get("start");
if (START || URLQ.get("test") === "1") document.body.classList.add("test");

fit();
if (START === "family") {
  // Wait for the rest of the scripts (Home, roles, kit), then open Home.
  document.addEventListener("DOMContentLoaded", () => {
    S.kit = "yes";
    appEnter("home");
    S.screen = "home";
    render();
  });
} else {
  scheduleSplash();
  render();
}
