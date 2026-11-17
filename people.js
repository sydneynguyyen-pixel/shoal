/* Shoal: inviting people. One sheet for every invite: who they are, how they know the person you care
   for, what they can do, and how the invite gets to them (text, email, or a link with a code).
   Until they accept, they're "Pending": you can plan with them, but they haven't joined yet. */

const RELS = ["Son or daughter", "Sibling", "Spouse or partner", "Grandchild", "Friend", "Neighbor", "Other"];
const ROLE_LINE = {
  main: "Gets the app, a jar, and the whole plan. Can take and hand off tasks.",
  trusted: "Gets a text when a light task opens up. No medical details.",
  kid: "Their own small jobs in plain words. Never urgent.",
};
const pending = (p) => p.id !== "you" && p.invited && !p.joined;
const inviteCode = (p) => (p.code ||= Math.random().toString(36).slice(2, 6).toUpperCase().replace(/[O0I1]/g, "7"));
const viaShort = (p) => (p.via === "email" ? "Email sent" : p.via === "link" ? "Link to share" : "Text sent");
const viaLine = (p) => (p.via === "email" ? `by email to ${p.contact}` : p.via === "link" ? "with a link" : p.contact ? `by text to ${p.contact}` : "by text");

// Only the name is required. The phone is optional: with it, Messages opens already addressed.
const inviteReady = () => !!S.draftInv.name.trim();
const syncInviteBtn = () => { const b = document.querySelector('.sheet [data-act="sendInvite"]'); if (b) b.disabled = !inviteReady(); };
const inviteText = (name, code) => `Hi ${name}, join ${L()}'s plan on Shoal so we can share the care: https://shoal.app/j/${code}`;

function inviteSheet() {
  const d = S.draftInv;
  openSheet(`<h3>Invite someone</h3>
    <p class="small">Send them a link to join ${esc(possessive({ name: L() }))} plan.</p>
    <div class="inv-form">
      <label class="card field"><span class="eyebrow">Name</span><input data-input="invName" value="${esc(d.name)}" placeholder="First name" autocomplete="off" aria-label="Their name"></label>
      <p class="label">How do they know ${esc(L())}? <span class="small">Optional</span></p>
      <div class="chips">${RELS.map((r) => chip(r, d.rel === r, "invRel", r)).join("")}</div>
      <p class="label">What can they do?</p>
      <div class="seg wide">${PEOPLE_GROUPS.map((g) => `<button class="${d.tier === g.tier ? "on" : ""}" aria-pressed="${d.tier === g.tier}" data-act="invTier" data-id="${g.tier}">${g.t.replace("Main caregivers", "Main caregiver")}</button>`).join("")}</div>
      <p class="small inv-role">${ROLE_LINE[d.tier]}</p>
      <label class="card field"><span class="eyebrow">Phone <span class="opt">Optional</span></span><input data-input="invContact" value="${esc(fmtPhone(d.contact))}" type="tel" inputmode="tel" placeholder="(555) 555-0123" autocomplete="off" aria-label="Their phone number"></label>
    </div>
    <button class="btn-primary" data-act="sendInvite" ${inviteReady() ? "" : "disabled"}>Send invite</button>
    <p class="small center">They show as pending until they accept.</p>`);
}

// Send invite opens Messages with the invite filled in. In the prototype it's a stand-in for the phone's
// Messages compose screen: nothing is actually sent. Cancel goes back to where you were.
function inviteMsgSheet({ to, body, send, cancel }) {
  S.msgDraft = { body, send, cancel };
  openSheet(`<div class="msg-compose">
    <div class="mc-head"><button class="linkish" data-act="msgCancel">Cancel</button><b>New Message</b><span></span></div>
    <div class="mc-to"><span>To:</span>${to ? `<span class="mc-chip">${esc(to)}</span>` : `<span class="mc-empty">Pick a contact</span>`}</div>
    <div class="mc-body"><div class="mc-bubble">${esc(body)}</div></div>
    <div class="mc-bar"><span class="mc-field">iMessage</span><button class="mc-send" data-act="msgSend" aria-label="Send"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V5M5 12l7-7 7 7"/></svg></button></div>
    <p class="small center">A stand-in for Messages. Nothing is sent from the prototype.</p>
  </div>`);
}

function pendingSheet(p) {
  const g = PEOPLE_GROUPS.find((x) => x.tier === p.tier);
  openSheet(`<div class="pend-head">${avatar(p, "s36 pending")}<span class="tl-txt"><span class="n">${esc(p.name)} hasn't joined yet</span><span class="m">Invited as ${g.t.replace("Main caregivers", "main caregiver").toLowerCase()} ${viaLine(p)}${p.rel ? ` · ${esc(p.rel)}` : ""}</span></span></div>
    <p class="small">You can still give ${esc(p.name)} tasks. They'll say yes or no to each one when they join.</p>
    <div class="card inv-code"><span class="tl-txt"><span class="m">Invite code</span><span class="code">${inviteCode(p)}</span><span class="m">shoal.app/j/${inviteCode(p)}</span></span></div>
    <div class="actions col">
      <button class="btn-soft" data-act="resendInvite" data-id="${p.id}">Resend invite</button>
      ${S.app && p.tier === "main" && !document.body.classList.contains("test") ? `<button class="btn-soft" data-act="invitePreview" data-id="${p.id}">See what ${esc(p.name)} sees</button>` : ""}
      <button class="btn-text danger" data-act="cancelInvite" data-id="${p.id}">Cancel invite</button>
    </div>`);
}

// Who's helping? (onboarding). Joined people and pending invites sit in the group they'll belong to.
SCREENS.people = () => {
  const line = (p) => p.id === "you" || !pending(p)
    ? `<div class="person">${avatar(p, "s36")}
      <span class="main"><span class="n">${esc(p.name)}</span><span class="m">${p.id === "you" ? "That's you" : esc(p.rel || p.about || "Joined")}</span></span></div>`
    : `<button class="person pend" data-act="pendingSheet" data-id="${p.id}">${avatar(p, "s36 pending")}
      <span class="main"><span class="n">${esc(p.name)}</span><span class="m">${viaShort(p)} · waiting to join</span></span><span class="badge plain">Pending</span></button>`;
  return `${topbar({ skip: false })}
  <div class="content">
    ${eyebrow("People")}
    <h1 class="title">Who's helping?</h1>
    <p class="sub">Invite the people who'll share the work. Send the link by text, email, or any app.</p>
    ${PEOPLE_GROUPS.map((g) => `<div class="pgroup">
      <div class="pg-head"><b>${g.t}</b><span>${g.hint}</span></div>
      <div class="card pg-card">${S.people.filter((p) => p.tier === g.tier).map(line).join("")}
        <button class="pg-add" data-act="addPerson" data-tier="${g.tier}"><span class="pg-plus" aria-hidden="true">+</span>${g.add}</button>
      </div>
    </div>`).join("")}
  </div>
  ${footer()}`;
};

Object.assign(ACTIONS, {
  addPerson: (d) => {
    S.draftInv = { name: "", rel: "", tier: d.tier || "main", via: "text", contact: "", code: Math.random().toString(36).slice(2, 6).toUpperCase().replace(/[O0I1]/g, "7") };
    inviteSheet();
  },
  inviteSheet: () => ACTIONS.addPerson({ tier: "main" }),
  invRel: (d) => { S.draftInv.rel = S.draftInv.rel === d.id ? "" : d.id; inviteSheet(); },
  invTier: (d) => { S.draftInv.tier = d.id; inviteSheet(); },
  sendInvite: () => {
    if (!inviteReady()) return;
    const d = S.draftInv, name = d.name.trim();
    inviteMsgSheet({
      to: d.contact ? fmtPhone(d.contact) : "", body: inviteText(name, d.code),
      cancel: inviteSheet,
      send: () => {
        S.people.push({ id: `p${Date.now()}`, name, rel: d.rel, about: d.rel, tier: d.tier, via: "text", contact: d.contact ? fmtPhone(d.contact) : "", code: d.code,
          note: TIER_NOTE[d.tier], cap: d.tier === "main" ? 5 : 2, invited: true, joined: false });
        closeSheet(); render();
        toast(`Invite sent to ${name}`);
      },
    });
  },
  msgSend: () => S.msgDraft?.send(),
  msgCancel: () => S.msgDraft?.cancel(),
  pendingSheet: (d) => pendingSheet(person(d.id)),
  resendInvite: (d) => {
    const p = person(d.id);
    inviteMsgSheet({
      to: p.contact || "", body: inviteText(p.name, inviteCode(p)),
      cancel: () => pendingSheet(p),
      send: () => { p.via = "text"; closeSheet(); render(); toast(`Sent ${p.name} the invite again`); },
    });
  },
  cancelInvite: (d) => {
    const p = person(d.id);
    S.tasks.forEach((t) => { if (t.who === p.id) t.who = null; });
    S.people = S.people.filter((x) => x.id !== p.id);
    closeSheet(); render();
    toast(`Invite canceled. ${possessive(p)} tasks are open again.`);
  },
});

Object.assign(APP_INPUT, {
  invName: (v) => { S.draftInv.name = v; syncInviteBtn(); },
  invContact: (v) => {
    S.draftInv.contact = v.replace(/\D/g, "").replace(/^1(?=\d{10})/, "").slice(0, 10);
    const el = document.querySelector('[data-input="invContact"]');
    if (el) el.value = fmtPhone(S.draftInv.contact);
  },
});

NOTES.people = ["Who's helping", ["Each Add opens one invite sheet: name, how they know the person you care for, what they can do, and an optional phone. Send invite opens Messages with the link filled in.",
  "Invited people show as Pending in the group they'll join. You can plan with them now; they say yes or no to their tasks when they accept.", "Tap a pending invite to resend, copy the link, or cancel it."]];
