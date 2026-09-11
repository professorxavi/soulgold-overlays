const fs = require("fs");
const path = require("path");
const caps = require("./levelCaps.json");

const file = path.join(__dirname, "runData.json");
const data = JSON.parse(fs.readFileSync(file, "utf8"));

data.attempt += 1;
data.deaths = 0;
data.levelCap = caps[0].lvl;

fs.writeFileSync(file, JSON.stringify(data, null, 2), "utf8");
