const STARTERS = [
  "Chespin", "Fennekin", "Froakie",
  "Chikorita", "Cyndaquil", "Totodile",
  "Sprigatito", "Torchic", "Popplio"
];

// 18 segments: each starter appears twice
window.WHEEL_SEGMENTS = [...STARTERS, ...STARTERS].map((label) => ({ label }));
