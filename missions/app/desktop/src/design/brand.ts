// Mirrors brand + accentFor in design/tokens.json. The app name is still open: change it here only.
export const brand = { appName: "OnMission", logo: "/logo.svg" };

export type Accent = "yellow" | "pink" | "green" | "lime" | "purple" | "sand" | "grey";

export const accentFor = {
  today: "yellow", tasks: "yellow", checklists: "lime", partners: "pink", gifts: "pink",
  documents: "purple", budget: "green", sellItems: "sand", packing: "lime", notes: "sand",
  prayer: "purple", newsletters: "pink", contacts: "grey", settings: "grey",
} as const satisfies Record<string, Accent>;

export const areaAccent: Record<string, Accent> = {
  visa: "purple", admin: "grey", finance: "green", support: "pink", newsletter: "pink", selling: "sand",
  packing: "lime", housing: "sand", health: "pink", insurance: "purple", church: "yellow", travel: "lime",
  ywam: "yellow", personal: "sand", other: "grey",
};

/** Text on an accent is ink, except on purple. */
export const onAccent = (a: Accent) => (a === "purple" ? "#fff" : "var(--ink)");
export const accentVar = (a: Accent) => `var(--accent-${a})`;
