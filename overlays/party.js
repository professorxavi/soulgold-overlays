const WS_URL = "ws://127.0.0.1:8080";


function hpPercent(mon) {
  if (!mon.maxHP || mon.maxHP <= 0) return 0;
  const pct = (mon.hp / mon.maxHP) * 100;
  return Math.max(0, Math.min(100, Math.floor(pct)));
}

function hpColors(percent) {
  if (percent >= 100) return ["var(--ring-high-2)", "var(--ring-high-2)"];
  if (percent >= 51) return ["var(--ring-high-2)", "var(--ring-high-1)"];
  if (percent >= 21) return ["var(--ring-mid-2)", "var(--ring-mid-1)"];
  if (percent >= 1) return ["var(--ring-low-2)", "var(--ring-low-1)"];
  return ["var(--ring-low-2)", "var(--ring-low-1)"];
}

const SPRITE_BASE = "https://eemeliri.github.io/soulgold/sprites/pokemon";

// Soulgold internal species id -> sprite slug (generated from the ROM source's species.h + docs/data/species.json)
let speciesSlugs = {};
const speciesReady = fetch("./species.json")
  .then((res) => res.json())
  .then((map) => { speciesSlugs = map; })
  .catch((err) => console.error("Failed to load species.json", err));

function spriteUrl(species, shiny) {
  const slug = speciesSlugs[species];
  if (!slug) {
    console.warn("No sprite mapping for species", species);
    return "";
  }
  return `${SPRITE_BASE}/${slug}${shiny ? "_shiny" : ""}.png`;
}

function monKey(mon, index) {
  return String(mon?.personality ?? `${mon?.species ?? 0}-${index}`);
}

function animateHpRing(el, fromPercent, toPercent) {
  if (!el) return;
  if (fromPercent === undefined || fromPercent === null || Number.isNaN(fromPercent)) {
    el.style.setProperty("--hp", toPercent);
    return;
  }

  const start = performance.now();
  const duration = 300;
  const from = fromPercent;
  const to = toPercent;

  function easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  }

  function step(now) {
    const t = Math.min(1, (now - start) / duration);
    const eased = easeOutCubic(t);
    const current = from + (to - from) * eased;
    el.style.setProperty("--hp", current);
    if (t < 1) requestAnimationFrame(step);
  }

  el.style.setProperty("--hp", from);
  requestAnimationFrame(step);
}

function statusMeta(status) {
  switch (status) {
    case "poison": return { label: "PSN", glyph: "P", icon: "O", className: "status-poison" };
    case "toxic": return { label: "TOX", glyph: "T", icon: "O", className: "status-toxic" };
    case "burn": return { label: "BRN", glyph: "B", icon: "*", className: "status-burn" };
    case "freeze": return { label: "FRB", glyph: "F", icon: "*", className: "status-freeze" }; // Soulgold: frostbite replaces freeze
    case "paralyze": return { label: "PAR", glyph: "P", icon: "!", className: "status-paralyze" };
    case "sleep": return { label: "SLP", glyph: "Z", icon: "Z", className: "status-sleep" };
    default: return null;
  }
}

function createEmptySlotHTML() {
  return `<div class="empty-slot"></div>`;
}

function displayNickname(mon) {
  return String(mon?.nickname ?? "").trim();
}

// Eggs: local egg sprite, full ring, no HP/status, and no species or nickname so nothing is spoiled
function createEggSlotHTML(mon, index) {
  const [colorA, colorB] = hpColors(100);
  return `
    <div class="slot">
      <div class="disc" data-key="${monKey(mon, index)}" style="--hp:100; --ring-color-a:${colorA}; --ring-color-b:${colorB};">
        <div class="inner-disc"></div>
        <img class="sprite" src="./egg.png" alt="Egg" loading="lazy" onerror="this.style.visibility='hidden'" />
        <div class="mon-text">
          <div class="nickname-text">Egg</div>
        </div>
      </div>
    </div>
  `;
}

function createSlotHTML(mon, index) {
  if (mon.egg) return createEggSlotHTML(mon, index);

  const percent = hpPercent(mon);
  const [colorA, colorB] = hpColors(percent);
  const fainted = Number(mon.hp) === 0;
  const critical = percent >= 1 && percent <= 20;
  const species = mon.species ?? 0;
  const key = monKey(mon, index);
  const status = statusMeta(mon.status);
  const nickname = displayNickname(mon);

  return `
    <div class="slot">
      <div class="disc" data-key="${key}" style="--hp:${percent}; --ring-color-a:${colorA}; --ring-color-b:${colorB};">
        <div class="inner-disc"></div>
        <img
          class="sprite ${fainted ? "fainted" : ""} ${critical ? "critical" : ""}"
          src="${spriteUrl(species, mon.shiny)}"
          alt="Pokemon ${species}"
          loading="lazy"
          onerror="if (this.src.endsWith('_shiny.png')) this.src = this.src.replace('_shiny.png', '.png'); else this.style.visibility='hidden'"
        />
        ${status ? `<div class="status-icon ${status.className}" title="${status.label}" aria-label="${status.label}"><span class="status-label">${status.label}</span></div>` : ""}
        <div class="mon-text">
          <div class="nickname-text">${nickname}</div>
          <div class="hp-text">${mon.hp ?? "?"} / ${mon.maxHP ?? "?"}</div>
        </div>
      </div>
    </div>
  `;
}

function renderPartyInto(partyContainer, party, hpTracker = {}) {
  if (!Array.isArray(party) || party.length === 0) {
    partyContainer.className = "empty";
    partyContainer.innerHTML = "";
    return;
  }

  console.log("Rendering party overlay data", party);

  const filled = [];
  for (let i = 0; i < 6; i += 1) filled.push(party[i] || null);

  const nextPercentByKey = {};
  const cards = filled.map((mon, index) => {
    if (!mon || !mon.species || mon.species === 0) {
      return createEmptySlotHTML();
    }
    const key = monKey(mon, index);
    nextPercentByKey[key] = mon.egg ? 100 : hpPercent(mon);
    return createSlotHTML(mon, index);
  }).join("");

  partyContainer.className = "party-row";
  partyContainer.innerHTML = cards;

  partyContainer.querySelectorAll(".disc[data-key]").forEach((disc) => {
    const key = disc.getAttribute("data-key");
    if (!key || !(key in nextPercentByKey)) return;
    const toPercent = nextPercentByKey[key];
    const fromPercent = hpTracker[key];
    animateHpRing(disc, fromPercent, toPercent);
    hpTracker[key] = toPercent;
  });
}

function mountOverlay({ containerId = "partyContainer", demoParty = null } = {}) {
  const partyContainer = document.getElementById(containerId);
  if (!partyContainer) throw new Error(`Missing container #${containerId}`);

  const previousHpPercentByKey = {};
  let socket = null;
  let reconnectTimer = null;
  let shouldReconnect = true;

  function handleEvent(eventData) {
    if (!eventData || !eventData.type) return;
    if ((eventData.type === "party_init" || eventData.type === "party_changed") &&
        eventData.payload &&
        Array.isArray(eventData.payload.party)) {
      speciesReady.then(() => renderPartyInto(partyContainer, eventData.payload.party, previousHpPercentByKey));
    }
  }

  function scheduleReconnect() {
    if (!shouldReconnect) return;
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connect, 1500);
  }

  function connect() {
    clearTimeout(reconnectTimer);
    if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    socket = new WebSocket(WS_URL);

    socket.addEventListener("message", (event) => {
      try {
        handleEvent(JSON.parse(event.data));
      } catch (err) {
        console.error("Failed to parse relay message", err, event.data);
      }
    });

    socket.addEventListener("close", () => {
      scheduleReconnect();
    });
  }

  connect();

  if (demoParty) {
    setTimeout(() => {
      if (partyContainer.classList.contains("empty")) {
        speciesReady.then(() => renderPartyInto(partyContainer, demoParty, previousHpPercentByKey));
      }
    }, 1200);
  }
}

window.EmeraldOverlay = {
  mountOverlay,
  renderPartyInto,
  statusMeta,
};
