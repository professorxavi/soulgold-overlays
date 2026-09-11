const fs = require("fs");
const path = require("path");

const file = path.join(__dirname, "runData.json");
const data = JSON.parse(fs.readFileSync(file, "utf8"));

data.deaths += 1;

fs.writeFileSync(file, JSON.stringify(data, null, 2), "utf8");
