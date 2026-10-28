// Line drawings in the Tomato Flood grammar: one 2.4 stroke, round caps and joins,
// closed shapes filled with the flood colour (.bgf) or with cream (.crf).
// Every drawing is decorative (aria-hidden); the text around it carries the meaning.

export const icon = {
  arrow: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>',
  check: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path pathLength="1" d="M4 12 9 17L20 6"/></svg>',
  flame: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path pathLength="1" d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/></svg>',
  copy: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><rect width="14" height="14" x="8" y="8" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>',
  back: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg>',
  chev: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 18 6-6-6-6"/></svg>',
  up: '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path d="m18 15-6-6-6 6"/></svg>',
};

// Today poster: a mountain with a flag and a dotted flight path ending in a paper plane.
export const summit = `<svg class="art summit" viewBox="0 0 170 182" aria-hidden="true"><g class="ln">
  <path class="dots" d="M8 84 C 2 52, 40 38, 52 58 C 62 74, 36 84, 40 64 C 44 40, 90 28, 118 34"/>
  <path class="crf" d="M120 34 L162 14 L148 46 L142 34 Z"/><path d="M142 34 L162 14"/>
  <path d="M2 178 L44 120 L62 140 L96 86 L150 178"/>
  <path d="M33 135 L38 131 L42 136 L47 129 L52 134"/>
  <path d="M84 104 L89 99 L96 105 L102 98 L108 104"/>
  <path d="M96 86 L96 62"/><path class="tof" d="M96 62 L114 68 L96 75"/>
  <path d="M2 178 L164 178"/>
</g></svg>`;

// Stand-in for a photo that hasn't arrived yet: drawn, framed, clearly a placeholder.
export function pending(kind, label) {
  const scenes = {
    portrait: `<circle cx="120" cy="112" r="40"/>
      <path d="M52 300 C 56 222, 86 186, 120 186 S 184 222, 188 300"/>
      <path d="M104 110 h0.01 M136 110 h0.01" style="stroke-width:5"/>
      <path d="M108 132 C 114 138, 126 138, 132 132"/>`,
    queenstown: `<path d="M0 200 L48 130 L70 154 L110 92 L150 150 L176 120 L240 200"/>
      <path d="M100 104 L106 98 L112 104 L118 97"/>
      <path class="crf" d="M0 232 C 50 214, 100 236, 150 222 C 190 212, 220 226, 240 220 L240 300 L0 300 Z"/>
      <path d="M30 256 C 44 250, 58 262, 72 256 M128 270 C 142 264, 156 276, 170 270"/>`,
    team: `<circle cx="70" cy="128" r="24"/><path d="M26 236 C 30 192, 46 166, 70 166 S 110 192, 114 236"/>
      <circle cx="170" cy="128" r="24"/><path d="M126 236 C 130 192, 146 166, 170 166 S 210 192, 214 236"/>
      <circle cx="120" cy="98" r="22"/><path d="M84 168 C 88 138, 102 128, 120 128 S 152 138, 156 168"/>
      <path d="M10 270 L230 270"/>`,
  };
  return `<div class="pending"><svg class="art" viewBox="0 0 240 300" aria-hidden="true"><g class="ln">${scenes[kind]}</g></svg><span class="hand">${label}</span></div>`;
}

// The signature stamp: the circular text runs round a handwritten name.
export function stamp(text, name) {
  return `<svg class="stamp" viewBox="0 0 140 140" aria-hidden="true">
  <defs><path id="stampRing" d="M70 70 m-52 0 a52 52 0 1 1 104 0 a52 52 0 1 1 -104 0"/></defs>
  <circle cx="70" cy="70" r="66" class="stamp-o"/><circle cx="70" cy="70" r="40" class="stamp-i"/>
  <text class="stamp-t"><textPath href="#stampRing" textLength="318">${text}${text}</textPath></text>
  <text x="70" y="80" text-anchor="middle" class="stamp-n">${name}</text>
</svg>`;
}

// Fig. 1: Queenstown with numbered callouts. The key lives in the HTML legend beside it.
export const map = `<svg class="art map" viewBox="0 0 520 430" aria-hidden="true">
  <g class="ln">
    <path class="dots" d="M18 22 C 120 30, 150 110, 150 196"/>
    <g transform="translate(36 22) rotate(8)"><path class="crf" d="M-18 -10 L20 0 L-18 10 L-10 0 Z"/><path d="M-10 0 L20 0"/></g>
    <path d="M232 214 L282 140 L306 168 L344 96 L372 136 L400 112 L430 150 L452 128 L516 214"/>
    <path d="M330 118 L336 112 L344 120 L350 112 L356 118"/>
    <path d="M420 136 L426 131 L432 137 L438 131"/>
    <path class="bgf" d="M4 300 C 60 270, 120 300, 176 284 C 236 266, 300 296, 366 280 C 424 266, 480 284, 516 300 L516 360 C 470 372, 410 352, 350 368 C 280 386, 220 356, 160 372 C 100 388, 50 366, 4 376 Z"/>
    <path class="wave" d="M70 330 C 84 324, 98 336, 112 330 M250 322 C 264 316, 278 328, 292 322 M400 330 C 414 324, 428 336, 442 330"/>
    <path class="bgf" d="M120 238 L120 218 L134 206 L148 218 L148 238 Z"/>
    <path class="bgf" d="M154 238 L154 224 L166 214 L178 224 L178 238 Z"/>
    <path class="bgf" d="M98 238 L98 228 L108 220 L118 228 L118 238 Z"/>
    <path d="M86 240 L190 240"/>
    <path class="bgf" d="M300 250 L300 226 L318 212 L336 226 L336 250 Z"/>
    <path d="M318 212 L318 188"/><path class="crf" d="M318 188 L334 194 L318 200"/>
    <path d="M286 252 L350 252"/>
    <path d="M8 410 C 160 404, 360 414, 512 406"/>
  </g>
  <g class="lead">
    <path d="M60 50 C 70 74, 78 84, 92 92"/>
    <path d="M134 204 C 128 180, 116 168, 98 160"/>
    <path d="M200 332 C 210 350, 214 372, 206 392"/>
    <path d="M400 112 C 420 84, 440 70, 466 64"/>
    <path d="M336 214 C 360 196, 380 192, 410 194"/>
  </g>
  <g class="callouts">
    <g transform="translate(100 98)"><circle r="15"/><text y="5.5">1</text></g>
    <g transform="translate(90 152)"><circle r="15"/><text y="5.5">2</text></g>
    <g transform="translate(204 400)"><circle r="15"/><text y="5.5">3</text></g>
    <g transform="translate(482 62)"><circle r="15"/><text y="5.5">4</text></g>
    <g transform="translate(426 196)"><circle r="15"/><text y="5.5">5</text></g>
  </g>
</svg>`;

// Prayer: the candle from the app. The flame and glow light when someone prays.
export const candle = `<svg class="art candle" viewBox="0 0 120 190" aria-hidden="true">
  <g class="glow ln"><path d="M60 14v-9M36 26l-6-5M84 26l6-5M30 50h-9M90 50h9"/></g>
  <g class="ln">
    <path d="M60 74 L60 64"/>
    <path class="bgf" d="M38 80 L38 160 L82 160 L82 80"/>
    <path d="M38 80 A22 6 0 0 0 82 80 A22 6 0 0 0 38 80"/>
    <path d="M48 87 C 46 95, 48 103, 52 107"/>
    <path d="M14 160 L106 160"/>
    <path d="M22 160 C 24 175, 96 175, 98 160"/>
  </g>
  <g class="flame"><path class="flame-o" d="M60 24 C 68 38, 74 44, 74 56 A 14 14 0 0 1 46 56 C 46 44, 52 38, 60 24 Z"/><path class="flame-i" d="M60 46 C 63 51, 66 54, 66 59 A 6 6 0 0 1 54 59 C 54 54, 57 51, 60 46 Z"/></g>
</svg>`;

// Support: a dotted trail up a mountain to a flag. The walker stops at the support %.
export const trail = `<svg class="art trail" viewBox="0 0 390 150" aria-hidden="true">
  <g class="ln">
    <path class="dots" d="M20 138 C 90 136, 116 112, 160 106 S 238 78, 280 60 S 334 36, 354 32"/>
    <path class="trail-done" pathLength="1" d="M20 138 C 90 136, 116 112, 160 106 S 238 78, 280 60 S 334 36, 354 32"/>
    <path d="M354 32 L354 4"/><path class="crf" d="M354 4 L374 11 L354 18"/>
    <path d="M200 148 L248 110 L268 126 L300 92 L352 148"/>
    <path d="M290 102 L294 98 L300 103 L305 97 L310 102"/>
    <circle class="walker crf" cx="20" cy="138" r="7"/>
  </g>
</svg>`;

// Back cover: a letter heading out along a dotted route.
export const envelope = `<svg class="art envelope" viewBox="0 0 300 200" aria-hidden="true"><g class="ln">
  <path class="dots" d="M150 120 C 200 110, 230 60, 292 20"/>
  <path class="bgf" d="M30 70 L170 70 L170 170 L30 170 Z"/>
  <path d="M30 70 L100 124 L170 70"/>
  <path d="M30 170 L84 118 M170 170 L116 118"/>
  <path class="crf" d="M140 82 L160 82 L160 102 L140 102 Z"/>
  <path d="M278 16 L294 18 L284 30"/>
</g></svg>`;

// Spread 3: the road from leaving to staying, drawn as the app's stage path.
export const plane = `<svg class="art plane" viewBox="0 0 120 80" aria-hidden="true"><g class="ln">
  <path class="dots" d="M6 70 C 30 66, 52 50, 70 34"/>
  <g transform="translate(88 22) rotate(-30)"><path class="crf" d="M-22 -12 L24 0 L-22 12 L-12 0 Z"/><path d="M-12 0 L24 0"/></g>
</g></svg>`;
