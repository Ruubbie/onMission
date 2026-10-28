// hesent.me: serves the zine from ./public and picks a language for the bare domain.
//   "/"  → /nl/ or /en/: the "lang" cookie (set by the NL/EN switch) wins, then the browser's languages.
//   anything else → the static files.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/index.html") {
      const lang = pickLang(request);
      return new Response(null, {
        status: 302,
        headers: { Location: `/${lang}/${url.search}`, Vary: "Accept-Language, Cookie", "Cache-Control": "private, max-age=0" },
      });
    }
    return env.ASSETS.fetch(request);
  },
};

function pickLang(request) {
  const cookie = request.headers.get("Cookie") || "";
  const chosen = cookie.match(/(?:^|;\s*)lang=(nl|en)\b/);
  if (chosen) return chosen[1];
  // Accept-Language: "en-GB,en;q=0.9,nl;q=0.8" → the highest-ranked of nl/en.
  const ranked = (request.headers.get("Accept-Language") || "")
    .split(",")
    .map((part) => {
      const [tag, ...params] = part.trim().toLowerCase().split(";");
      const q = params.find((p) => p.trim().startsWith("q="));
      return { tag, q: q ? Number(q.trim().slice(2)) || 0 : 1 };
    })
    .filter((x) => x.tag)
    .sort((a, b) => b.q - a.q);
  for (const { tag } of ranked) {
    if (tag.startsWith("nl")) return "nl";
    if (tag.startsWith("en")) return "en";
  }
  return "nl";
}
