const BADGES_WS_URL = "ws://127.0.0.1:8080";
const NUM_BADGES = 8;

// Build the row once, then only toggle classes so an update never re-creates the masked elements
function renderBadgesInto(container, badges) {
  if (container.children.length !== NUM_BADGES) {
    container.className = "badge-row";
    container.innerHTML = Array.from({ length: NUM_BADGES }, (_, i) =>
      `<div class="badge" style="--i:${i}"></div>`
    ).join("");
  }
  Array.from(container.children).forEach((el, i) => {
    el.classList.toggle("earned", Boolean(badges[i]));
    el.classList.toggle("missing", !badges[i]);
  });
}

function mountBadges({ containerId = "badgeContainer", demoBadges = null } = {}) {
  const container = document.getElementById(containerId);
  if (!container) throw new Error(`Missing container #${containerId}`);

  let socket = null;
  let reconnectTimer = null;

  function handleEvent(eventData) {
    if ((eventData?.type === "badges_init" || eventData?.type === "badges_changed") &&
        Array.isArray(eventData.payload?.badges)) {
      renderBadgesInto(container, eventData.payload.badges);
    }
  }

  function connect() {
    clearTimeout(reconnectTimer);
    if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    socket = new WebSocket(BADGES_WS_URL);

    socket.addEventListener("message", (event) => {
      try {
        handleEvent(JSON.parse(event.data));
      } catch (err) {
        console.error("Failed to parse relay message", err, event.data);
      }
    });

    socket.addEventListener("close", () => {
      reconnectTimer = setTimeout(connect, 1500);
    });
  }

  connect();

  if (demoBadges) {
    setTimeout(() => {
      if (container.classList.contains("empty")) renderBadgesInto(container, demoBadges);
    }, 1200);
  }
}

window.BadgeOverlay = { mountBadges, renderBadgesInto };
