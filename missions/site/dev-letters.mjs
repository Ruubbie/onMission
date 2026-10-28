// Sample letters for the local preview (dev.mjs): seven letters in Dutch and English, shaped like the sync server's
// /v1/public/letters answers, with drawn stand-in photos (a sky, mountains and a lake) instead of real ones.

const para = {
  nl: [
    "Wat fijn dat je weer de tijd neemt om deze brief te lezen! De afgelopen weken zijn een achtbaan geweest. Ik ben zo’n drie weken in Queenstown en langzaam begin ik mijn draai te vinden. Het voelt echt als een nieuwe fase, en ik ben dankbaar dat jullie met me meeleven.",
    "De eerste weken stonden vooral in het teken van kennismaken. Ik heb al een paar mooie mensen ontmoet, zowel binnen de YWAM-gemeenschap als daarbuiten. Wat me vooral raakt, is hoe open mensen hier zijn. Er is echt ruimte voor diepere gesprekken, en veel mensen zijn op zoek naar iets groters.",
    "Afgelopen zondag mocht ik voor het eerst meedoen aan een outreach in de stad. We waren met een klein team en gingen de straat op om mensen te bemoedigen, te bidden en gewoon een luisterend oor te bieden. Het was spannend, maar ook heel bijzonder.",
    "Ik merkte dat het niet gaat om grote woorden, maar om echt aanwezig zijn. Soms is een simpel gesprek al genoeg om iemands dag te veranderen.",
    "Ik ben dankbaar dat ik dit mag meemaken en dat God me hier gebruikt, op een manier die ik nog niet had verwacht.",
    "Dankjewel dat jullie deel zijn van deze reis. Jullie gebeden, berichten en steun betekenen zoveel!\n\nGroetjes,\nRuben",
  ],
  en: [
    "It’s so good that you’re taking the time to read this letter again! The last few weeks have been a rollercoaster. I’ve been in Queenstown for about three weeks and I’m slowly finding my feet. It really feels like a new chapter, and I’m grateful you’re following along.",
    "The first weeks were mostly about getting to know people. I’ve already met some lovely people, both in the YWAM community and beyond it. What strikes me most is how open people are here. There is real room for deeper conversations, and many people are looking for something bigger.",
    "Last Sunday I joined an outreach in town for the first time. We were a small team and went out on the street to encourage people, to pray and simply to listen. It was exciting, and very special.",
    "I noticed it isn’t about big words, but about really being there. Sometimes one simple conversation is enough to change someone’s day.",
    "I’m grateful I get to be part of this, and that God is using me here in a way I didn’t expect.",
    "Thank you for being part of this journey. Your prayers, messages and support mean so much!\n\nLove,\nRuben",
  ],
};

const body = (lang, headings) => {
  const p = para[lang];
  return `Hoi lieve mensen,\n\n${p[0]}\n\n## ${headings[0]}\n\n${p[1]}\n\n## ${headings[1]}\n\n${p[2]} ${p[3]}\n\n${p[4]}\n\n${p[5]}`
    .replace("Hoi lieve mensen,", lang === "nl" ? "Hoi lieve mensen," : "Hi everyone,");
};

const letters = [
  {
    number: 7, sentAt: "2026-10-20", place: "Queenstown, NZ",
    nl: { title: "Een nieuw hoofdstuk", subtitle: "Van de bergen, naar de mensen.", headings: ["Nieuwe mensen, nieuwe verhalen", "De eerste outreach"],
      prayers: ["Voor de mensen die ik hier mag ontmoeten.", "Voor wijsheid in de keuzes die ik maak.", "Dat ik mag blijven groeien in mijn relatie met God."],
      note: "Soms zijn het de kleine dingen die het meest doen.", nextTime: "In de volgende brief neem ik je mee naar de base, waar ik de komende maanden zal wonen en werken." },
    en: { title: "A new chapter", subtitle: "From the mountains, to the people.", headings: ["New people, new stories", "The first outreach"],
      prayers: ["For the people I get to meet here.", "For wisdom in the choices I make.", "That I keep growing in my relationship with God."],
      note: "Sometimes it’s the small things that matter most.", nextTime: "Next time I’ll take you to the base, where I’ll live and work for the coming months." },
    photos: [
      { seed: 0, caption: { nl: "Queenstown vanaf de heuvel achter de base.", en: "Queenstown from the hill behind the base." } },
      { seed: 1, caption: { nl: "Eerste keer op de top van Ben Lomond.", en: "My first time on top of Ben Lomond." }, tall: true },
      { seed: 2, caption: { nl: "Zonsondergang boven het meer.", en: "Sunset over the lake." } },
    ],
  },
  {
    number: 6, sentAt: "2026-09-22", place: "Auckland, NZ",
    nl: { title: "Geland", subtitle: "Dertig uur onderweg, en toen ineens hier.", headings: ["De lange vlucht", "Eerste dagen"], prayers: ["Voor een goede start met het team."],
      note: "Thuis is waar je verwacht wordt.", nextTime: "Volgende keer: mijn eerste week in Queenstown." },
    en: { title: "Landed", subtitle: "Thirty hours of travel, and then suddenly here.", headings: ["The long flight", "First days"], prayers: ["For a good start with the team."],
      note: "Home is where you are expected.", nextTime: "Next time: my first week in Queenstown." },
    photos: [
      { seed: 3, caption: { nl: "Uitzicht vanuit het vliegtuig.", en: "The view from the plane." } },
      { seed: 1, caption: { nl: "De eerste wandeling.", en: "The first walk." }, tall: true },
      { seed: 2, caption: { nl: "Het meer bij de base.", en: "The lake by the base." } },
    ],
    // Arranged by hand, as the web app's Arrange page saves it: s0 is the opening, s1 and s2 the parts under each
    // heading, p<seed> a photo.
    arranged: { cover: 3, columns: [["s0", "s1", "prayers"], ["p1", "s2"], ["note", "p2"]], footer: ["next", "funds"] },
  },
  {
    number: 5, sentAt: "2026-08-25", place: "Utrecht",
    nl: { title: "Afscheid nemen", headings: ["Het laatste etentje", "Wat ik meeneem"] },
    en: { title: "Saying goodbye", headings: ["The last dinner", "What I take with me"] },
    photos: [{ seed: 4 }],
  },
  {
    number: 4, sentAt: "2026-07-28", place: "Utrecht",
    nl: { title: "Het visum is binnen", headings: ["Wachten", "Groen licht"] },
    en: { title: "The visa came through", headings: ["Waiting", "Green light"] },
    photos: [],
  },
  {
    number: 3, sentAt: "2026-06-30", place: "Utrecht",
    nl: { title: "Eén koffer", headings: ["Wat mee moet", "Wat weg mag"] },
    en: { title: "One suitcase", headings: ["What has to come", "What can go"] },
    photos: [{ seed: 5 }],
  },
  {
    number: 2, sentAt: "2026-05-26", place: "Utrecht",
    nl: { title: "Ja zeggen tegen Queenstown", headings: ["De vraag", "Het antwoord"] },
    en: { title: "Saying yes to Queenstown", headings: ["The question", "The answer"] },
    photos: [{ seed: 6 }],
  },
  {
    number: 1, sentAt: "2025-12-15", place: "Utrecht",
    nl: { title: "Waarom ik ga", headings: ["Een roeping", "Wat ik ga doen"] },
    en: { title: "Why I’m going", headings: ["A calling", "What I’ll do"] },
    photos: [],
  },
];

const slug = (s) => s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
// The second paragraph: the first is the greeting, which the server skips too.
const excerpt = (md) => md.split(/\n\s*\n/).filter((p) => p && !/^#/.test(p))[1]?.replace(/\s+/g, " ").slice(0, 320) ?? null;

function letterIn(l, lang) {
  const t = l[lang];
  const md = body(lang, t.headings);
  const ref = (r) => (/^p\d$/.test(r) ? `p:sample-${r.slice(1)}` : /^s\d$/.test(r) ? `s:${r}` : r);
  const arranged = l.arranged && {
    sections: md.split(/\n\n(?=## )/).map((part, i) => {
      const [, title, text] = part.match(/^(?:## (.+)\n\n)?([\s\S]*)$/);
      return { id: `s${i}`, title: title ?? null, body: text };
    }),
    layout: { cover: `sample-${l.arranged.cover}`, columns: l.arranged.columns.map((c) => c.map(ref)), footer: l.arranged.footer.map(ref) },
  };
  return {
    ...arranged,
    key: `${l.number}-${slug(t.title)}`, number: l.number, title: t.title, subtitle: t.subtitle ?? null, place: l.place,
    sentAt: l.sentAt, webUrl: null, excerpt: excerpt(md), body: md, note: t.note ?? null, nextTime: t.nextTime ?? null,
    funds: t.funds ?? null, prayers: t.prayers ?? [],
    photos: l.photos.map((p) => ({ id: `sample-${p.seed}`, url: `/v1/public/photos/sample-${p.seed}`, caption: p.caption?.[lang] ?? null, width: p.tall ? 1200 : 1600, height: p.tall ? 1500 : 1067 })),
  };
}

const all = (lang) => letters.map((l) => letterIn(l, lang));

export function sampleList(lang) {
  return { letters: all(lang).map(({ body, note, nextTime, funds, prayers, photos, sections, layout, ...l }) => ({ ...l, photo: photos[0] ?? null })) };
}

export function sampleLetter(lang, key) {
  const list = all(lang);
  const i = list.findIndex((l) => l.key.split("-")[0] === key.split("-")[0]);
  if (i < 0) return null;
  const brief = (l) => (l ? { key: l.key, title: l.title, sentAt: l.sentAt } : null);
  return { letter: list[i], newer: brief(list[i - 1]), older: brief(list[i + 1]), support: { percentOfTarget: 62 } };
}

export function sampleSummaryLetters(lang) {
  return all(lang).slice(0, 5).map((l) => ({ key: l.key, title: l.title, sentAt: l.sentAt, webUrl: null, excerpt: l.excerpt }));
}

// A stand-in photo: a sky, two ranges of mountains and a lake, in colours picked by the seed.
const skies = [["#9DB8CF", "#E9D9C0"], ["#C9B8C8", "#F2D4B0"], ["#E59A62", "#F4D59B"], ["#8FB3D6", "#DCE7EE"], ["#B7C4C9", "#EFE3CF"], ["#A3BFD9", "#F1E6D2"], ["#D7A487", "#F0DAB8"]];
export function samplePhoto(seed) {
  const [top, bottom] = skies[seed % skies.length];
  const tall = seed === 1;
  const w = tall ? 1200 : 1600, h = tall ? 1500 : 1067;
  const r = (n) => Math.round(((Math.sin(seed * 97 + n * 13) + 1) / 2) * 1000) / 1000;
  const ridge = (base, amp, n) => {
    let d = `M0 ${h}L0 ${base}`;
    for (let i = 1; i <= n; i++) d += `L${(w / n) * i} ${base - amp * r(i + base)}`;
    return `${d}L${w} ${h}Z`;
  };
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">
  <defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient></defs>
  <rect width="${w}" height="${h}" fill="url(#s)"/>
  <path d="${ridge(h * 0.52, h * 0.3, 9)}" fill="#7E8A9A" opacity=".75"/>
  <path d="${ridge(h * 0.62, h * 0.22, 7)}" fill="#5D6B5A"/>
  <rect y="${h * 0.66}" width="${w}" height="${h * 0.16}" fill="#7FA3B5"/>
  <path d="${ridge(h * 0.84, h * 0.08, 12)}" fill="#46553F"/>
</svg>`;
}
