// Money sums shared by People, Budget, Selling and Move. Amounts are kept in cents; the mission's
// NZD rate turns NZD into euros (Settings).

import { store } from "../store.js";
import { toEurCents } from "../util.js";

/** Whole euros with a dot for thousands, like the app: €1,240. */
export function euroWhole(cents) {
  const v = Math.round((cents ?? 0) / 100);
  return `€${v.toLocaleString("en-GB")}`;
}

/** Monthly support: what committed and giving partners give, against the mission's target. */
export function supportTotals() {
  const s = store.settings();
  const total = store.list("partners")
    .filter((p) => p.stage === "committed" || p.stage === "giving")
    .reduce((sum, p) => sum + toEurCents(p.monthlyCents ?? 0, p.currency, s.nzdPerEur), 0);
  const target = s.supportTargetMonthlyCents ?? 0;
  return { total, target, pct: target ? Math.round((total / target) * 100) : 0 };
}

/** EUR per month for one budget line: monthly counts as is, yearly as a twelfth, one-off not at all. */
export function monthlyEur(line, rate) {
  const eur = toEurCents(line.amountCents ?? 0, line.currency, rate);
  if (line.recurrence === "monthly") return eur;
  if (line.recurrence === "yearly") return eur / 12;
  return 0;
}
