/* Shoal: what someone sees the first time they open their invite. A text with a link, a short
   "here's what you can do", the tasks they were asked to take (yes or "can't"), optional free time,
   then their own view of the plan. Uses state and helpers from app.js, main-app.js and roles.js. */

const INVITE_SCREENS = ["inviteText", "inviteJoin", "inviteTasks", "inviteTime", "inviteDone", "asHelper"];
INVITE_SCREENS.forEach((s) => APP_SCREENS.add(s));
APP_NAV.push("inviteText");

// Who the preview is for: the first helper who hasn't joined yet, else the first helper.
function invitee() {
  const helpers = S.people.filter((p) => p.id !== "you" && p.tier === "main");
  return person(S.app.inv?.who) || helpers.find((p) => !p.joined) || helpers[0] || S.people.find((p) => p.id !== "you");
}
const inviter = () => { const n = person("you").name; return n && n !== "You" ? n : "Dana"; };
const invTasks = (p) => S.tasks.filter((t) => t.on && !t.done && (t.who === p.id || S.app.inv?.cant.includes(t.id)) && !t.y);
const TIER_CAN = {
  main: [["See the whole plan", "Every jar, task and stone in the family"], ["Take, finish and hand off tasks", "Anyone you hand one to can say yes or no"], ["Add tasks", "They land in the family plan"]],
  trusted: [["See your own tasks", "And light ones you could pick up"], ["Mark them done", "The family sees it right away"]],
  kid: [["See your own small jobs", "In plain words, never urgent"], ["Mark them done", "Your stone goes dark so everyone knows"]],
};

function inviteBar(p) {
  return `<div class="rolebar">
    <span class="rb-who">${avatar(p, "s20")}<span>Preview · <b>${esc(p.name)}</b> opens the invite</span></span>
    <button class="x-btn" data-act="roleExit" aria-label="Back to your view">×</button>
  </div>`;
}

SCREENS.inviteText = () => {
  const p = invitee(), n = invTasks(p).length;
  return `<div class="content app invite-lock">
    ${inviteBar(p)}
    <p class="il-time">9:41</p><p class="il-date">Tuesday, October 20</p>
    <button class="card il-msg" data-act="go" data-to="inviteJoin">
      <span class="il-app">Messages · now</span>
      <b>${esc(inviter())}</b>
      <span>Hi ${esc(p.name)}, I'm using Shoal so we can share ${esc(L())}'s care. I put you down for ${n || "a few"} thing${n === 1 ? "" : "s"}. Have a look? <u>shoal.app/j/7KQ2</u></span>
    </button>
    <p class="small center il-hint">Tap the message to open the link</p>
  </div>`;
};

SCREENS.inviteJoin = () => {
  const p = invitee(), can = TIER_CAN[p.tier] || TIER_CAN.main;
  return `${navtop("Messages")}
  <div class="content">
    <div class="tc-top">${lockup(22)}</div>
    <h1 class="title">${esc(inviter())} invited you to help with ${esc(L())}</h1>
    <p class="sub">Shoal is how the family shares the work. Everyone has a jar, and every task is a stone in it.</p>
    <p class="section-h">You can</p>
    <div class="card tlist">${can.map(([t, d]) => `<div class="srow"><span class="sc-check on"><img src="${A("check.svg")}" alt=""></span><span class="tl-txt"><span class="n">${t}</span><span class="m">${d}</span></span></div>`).join("")}</div>
    <p class="section-h">Only ${esc(inviter())} can</p>
    <div class="card tlist"><div class="srow"><span class="tl-txt"><span class="n">Change the family setup</span><span class="m">Invite or remove people, and change who sees what</span></span></div></div>
    <p class="small lock-line"><img src="${A("lock.svg")}" width="14" height="14" alt="">Your free time and calendar stay private. ${esc(inviter())} only sees busy or free.</p>
  </div>
  ${solo(`Join ${esc(possessive({ name: L() }))} family`, "invJoin", ["Not now", "invLater"])}`;
};

SCREENS.inviteTasks = () => {
  const p = invitee(), ts = invTasks(p), cant = S.app.inv.cant;
  const yes = ts.filter((t) => !cant.includes(t.id)).length;
  return `${navtop("Back")}
  <div class="content">
    <p class="eyebrow">Step 1 of 2</p>
    <h1 class="title">${esc(inviter())} asked if you could take these</h1>
    <p class="sub">Say yes to what works. Anything you can't do goes back to the family, no explaining needed.</p>
    <div class="card tlist">${ts.map((t) => {
      const no = cant.includes(t.id);
      return `<div class="tline inv-task ${no ? "is-no" : ""}"><div class="tl-main">${gemOf(t)}
        <span class="tl-txt"><span class="n">${esc(t.n)}</span><span class="m">${WEIGHT_LABEL[t.w || 2]} · ${t.kind === "once" ? dueLabel(t) : repeatLabel(t.days)}</span></span></div>
        <div class="seg yn">${[["yes", "Yes"], ["no", "Can't"]].map(([k, l]) => `<button class="${(k === "no") === no ? "on" : ""}" aria-pressed="${(k === "no") === no}" data-act="invYes" data-id="${t.id}" data-v="${k}">${l}</button>`).join("")}</div></div>`;
    }).join("") || `<p class="small empty">Nothing yet. ${esc(inviter())} will send tasks soon.</p>`}</div>
  </div>
  ${solo(yes ? `Take ${yes} task${yes === 1 ? "" : "s"}` : "Continue", "invTasksDone")}`;
};

const FREE_CHIPS = ["Weekday mornings", "Weekday evenings", "Weekends", "It changes week to week"];
SCREENS.inviteTime = () => {
  const f = S.app.inv.free;
  return `${navtop("Back")}
  <div class="content">
    <p class="eyebrow">Step 2 of 2 · Optional</p>
    <h1 class="title">When are you usually free?</h1>
    <p class="sub">It helps the family ask at good times. Only "busy" or "free" is shared.</p>
    <div class="chips wrap">${FREE_CHIPS.map((c) => `<button class="chip ${f.includes(c) ? "on" : ""}" aria-pressed="${f.includes(c)}" data-act="invFree" data-id="${c}">${c}</button>`).join("")}</div>
  </div>
  ${solo("Done", "go", ["Skip", "go", 'data-to="inviteDone"'], 'data-to="inviteDone"')}`;
};

SCREENS.inviteDone = () => {
  const p = invitee(), n = mine(p.id).filter((t) => !t.done).length;
  return `<div class="content center-col">
    <div class="stage-card">${familyJars({ only: p.id, act: false })}</div>
    <h1 class="title">You're in, ${esc(p.name)}</h1>
    <p class="sub">${n ? `${n} task${n === 1 ? " is" : "s are"} in your jar.` : "Your jar is ready."} ${esc(inviter())} can see you joined${S.app.inv.cant.length ? `, and that ${S.app.inv.cant.length} went back to the family` : ""}.</p>
  </div>
  ${solo("Go to my jar", "go", null, 'data-to="asHelper"')}`;
};

// The helper's everyday view: their jar first, then the whole family.
SCREENS.asHelper = () => {
  const p = invitee(), ts = mine(p.id);
  return `<div class="content app">
    <div class="rolebar"><button class="rb-who" data-act="roleSheet">${avatar(p, "s20")}<span>Viewing as <b>${esc(p.name)}</b> · Family helper</span><em>Switch</em></button>
      <button class="x-btn" data-act="roleExit" aria-label="Back to your view">×</button></div>
    <h1 class="title">Hi, ${esc(p.name)}</h1>
    <p class="sub">Here's your part of ${esc(possessive({ name: L() }))} plan.</p>
    <p class="section-h">Your jar</p>
    <div class="card tlist">${ts.length ? ts.map((t) => `<div class="tline ${t.done ? "is-done" : ""}"><div class="tl-main">${gemOf(t)}
      <span class="tl-txt"><span class="n">${esc(t.n)}</span><span class="m">${t.done ? "Done. The family can see it." : `${WEIGHT_LABEL[t.w || 2]} · ${t.kind === "once" ? dueLabel(t) : repeatLabel(t.days)}`}</span></span></div>
      ${t.done ? "" : `<button class="pill-btn" data-act="roleDone" data-id="${t.id}">Mark done</button>`}</div>`).join("") : `<p class="small empty">Nothing in your jar yet.</p>`}</div>
    <p class="section-h">The whole family</p>
    <div class="shelf">${familyJars({ act: false })}</div>
    ${sees(`${esc(p.name)} sees the whole plan and can hand off tasks. Only ${esc(inviter())} can change the setup or invite people.`)}
  </div>`;
};

function startInvite(who) {
  ensureAppData();
  const p = person(who) || invitee();
  if (!p) { toast("Add a helper in People first"); return; }
  S.app.inv = { who: p.id, cant: [], free: [], joined: false };
  tabTo("inviteText");
}

Object.assign(ACTIONS, {
  invitePreview: (d) => { closeSheet(); startInvite(d.id); },
  invJoin: () => go("inviteTasks"),
  invLater: () => { roleSwitch("home"); toast(`${invitee().name} said “not now”. The invite stays open.`); },
  invYes: (d) => {
    const c = S.app.inv.cant, i = c.indexOf(d.id);
    if (d.v === "no" && i < 0) c.push(d.id);
    if (d.v === "yes" && i >= 0) c.splice(i, 1);
    render();
  },
  invTasksDone: () => {
    const p = invitee();
    // What they can't do goes back to the family as open, and the main caregiver hears about it.
    S.app.inv.cant.forEach((id) => { const t = task(id); if (t.who === p.id) t.who = null; });
    p.joined = true; S.app.inv.joined = true; S.app.seenNotes = false;
    go("inviteTime");
  },
  invFree: (d) => { const f = S.app.inv.free, i = f.indexOf(d.id); i >= 0 ? f.splice(i, 1) : f.push(d.id); render(); },
});

// The main caregiver hears that they joined, and about anything they couldn't take.
const invNotifications = notifications;
notifications = function () {
  const inv = S.app.inv, list = [];
  if (inv?.joined) {
    const p = person(inv.who), took = mine(p.id).filter((t) => !t.done).length;
    inv.cant.forEach((id) => { const t = task(id); list.push({ kind: "request", needs: !t.who, cta: "Open", when: "Today", who: p, n: `${p.name} can't take “${t.n}”`, m: "It's open again for whoever's free", act: "openTask", id }); });
    list.push({ kind: "done", when: "Today", who: p, n: `${p.name} joined`, m: `Said yes to ${took} task${took === 1 ? "" : "s"}${inv.free.length ? ` · usually free ${inv.free.join(", ").toLowerCase()}` : ""}`, act: "", id: "" });
  }
  return [...list, ...invNotifications()];
};

Object.assign(NOTES, {
  inviteText: ["Invite: the text", ["A helper gets a plain text with a link. No app store first; the link opens Shoal."]],
  inviteJoin: ["Invite: what you can do", ["Says who invited them and what their role allows, and what only the main caregiver can do.", "Free time stays private."]],
  inviteTasks: ["Invite: your tasks", ["Each task is a yes or a \"can't\". No reason needed. Anything declined goes back to the family as open."]],
  inviteTime: ["Invite: free time", ["Optional. Rough times are enough, or connect a calendar."]],
  inviteDone: ["Invite: you're in", ["Their jar, and a note that the main caregiver can see they joined."]],
  asHelper: ["View: family helper", ["Their own jar first, then the whole family's jars.", "They can finish and hand off tasks, but not change setup."]],
});
