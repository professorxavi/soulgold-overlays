let SEGMENTS = [];
let PALETTE = [];

const canvas = document.getElementById("wheel");
const ctx = canvas.getContext("2d");
const winnerBanner = document.getElementById("winnerBanner");
const winnerLabel = document.getElementById("winnerLabel");

function resize() {
  const container = document.getElementById("wheelContainer");
  const size = container.offsetWidth;
  canvas.width = size;
  canvas.height = size;
  draw();
}

let currentAngle = 0;

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3);
}

function getWinner(angle) {
  const count = SEGMENTS.length;
  const arc = (2 * Math.PI) / count;
  const normalized = ((2 * Math.PI) - (angle % (2 * Math.PI))) % (2 * Math.PI);
  const index = Math.floor(normalized / arc) % count;
  return { index, segment: SEGMENTS[index], colors: PALETTE[index % PALETTE.length] };
}

function showWinner(angle) {
  const { segment, colors } = getWinner(angle);
  winnerLabel.textContent = segment.label;
  winnerLabel.style.setProperty("--winner-color-a", colors[0]);
  winnerLabel.style.setProperty("--winner-color-b", colors[0] === "#f4f7fb" ? "#c8d0da" : colors[0]);
  winnerLabel.classList.add("colored");
  winnerBanner.getBoundingClientRect();
  winnerBanner.classList.add("visible");
}

function spin() {
  const duration = 5000;
  const totalRotation = (Math.PI * 2) * 8 + Math.random() * Math.PI * 2;
  const start = performance.now();

  winnerBanner.classList.remove("visible");

  function step(now) {
    const t = Math.min(1, (now - start) / duration);
    currentAngle = easeOutCubic(t) * totalRotation;
    draw();
    if (t < 1) {
      requestAnimationFrame(step);
    } else {
      showWinner(currentAngle);
    }
  }

  requestAnimationFrame(step);
}

function draw() {
  const w = canvas.width;
  const h = canvas.height;
  const cx = w / 2;
  const cy = h / 2;
  const r = Math.min(cx, cy) - 4;
  const count = SEGMENTS.length;
  const arc = (2 * Math.PI) / count;

  ctx.clearRect(0, 0, w, h);

  // Outer ring shadow
  ctx.save();
  ctx.shadowColor = "rgba(0,0,0,0.5)";
  ctx.shadowBlur = 20;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, 2 * Math.PI);
  ctx.fillStyle = "rgba(12, 16, 24, 1)";
  ctx.fill();
  ctx.restore();

  for (let i = 0; i < count; i++) {
    const startAngle = i * arc - Math.PI / 2 + currentAngle;
    const endAngle = startAngle + arc;
    const [bg, fg] = PALETTE[i % PALETTE.length];

    // Segment fill
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, r - 2, startAngle, endAngle);
    ctx.closePath();
    ctx.fillStyle = bg;
    ctx.fill();

    // Segment border
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, r - 2, startAngle, endAngle);
    ctx.closePath();
    ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
    ctx.lineWidth = 2;
    ctx.stroke();

    // Label
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(startAngle + arc / 2);
    ctx.textAlign = "right";
    ctx.textBaseline = "middle";
    ctx.fillStyle = fg;
    ctx.font = `bold ${Math.round(r * 0.09)}px Inter, system-ui, sans-serif`;
    ctx.shadowColor = "rgba(0,0,0,0.4)";
    ctx.shadowBlur = 4;
    ctx.fillText(SEGMENTS[i].label, r * 0.88, 0);
    ctx.restore();
  }

  // Outer border ring
  ctx.beginPath();
  ctx.arc(cx, cy, r - 1, 0, 2 * Math.PI);
  ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
  ctx.lineWidth = 4;
  ctx.stroke();
}

window.addEventListener("resize", resize);

PALETTE = window.WHEEL_PALETTE;
SEGMENTS = window.WHEEL_SEGMENTS;
resize();
spin();
