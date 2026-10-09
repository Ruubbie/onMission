// Builds OnMission/Resources/seed-records.json from the server's starter data, so the app shows your plan
// before you log in. Same ids and timestamp as server/seed/seed.mjs, so nothing doubles when you sync.
//   node tools/make-seed.mjs        (from the ios folder, after the server seed data changes)
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildRecords } from "../../server/seed/seed.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const items = JSON.parse(readFileSync(resolve(here, "../../server/seed/seed-data.json"), "utf8"));
const { records, errors } = buildRecords(items);
if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}
writeFileSync(resolve(here, "../OnMission/Resources/seed-records.json"), JSON.stringify({ records }));
const counts = {};
for (const r of records) counts[r.collection] = (counts[r.collection] ?? 0) + 1;
console.log(records.length, "records", counts);
