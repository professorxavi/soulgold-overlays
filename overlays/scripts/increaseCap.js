const fs = require("fs");
const path = require("path");
const caps = require("./levelCaps.json");

const file = path.join(__dirname, "runData.json");
const data = JSON.parse(fs.readFileSync(file, "utf8"));

const index = caps.findIndex((c) => c.lvl === data.levelCap);
const next = caps[index + 1];

if (index === -1 || !next) process.exit(0);

data.levelCap = next.lvl;

fs.writeFileSync(file, JSON.stringify(data, null, 2), "utf8");
