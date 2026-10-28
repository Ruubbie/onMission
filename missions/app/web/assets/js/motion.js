// Motion kit for the web app: Lucide icons animated like lucide-animated (ported from
// design/tomato-flood/prototype.html), plus the shared tween and draw-in helpers.

const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const ph = document.querySelector('.phone');

const svgI = (n, inner, sw = 2) => `<svg viewBox="0 0 24 24" class="ln" data-la="${n}" style="stroke-width:${sw}">${inner}</svg>`;
const I = {
  plus: svgI('plus', '<path d="M5 12h14"/><path d="M12 5v14"/>', 2.5),
  x: svgI('x', '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>', 2.4),
  phone: svgI('phone', '<path data-w="2" d="M13 2a9 9 0 0 1 9 9"/><path data-w="1" d="M13 6a5 5 0 0 1 5 5"/><path d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384"/>'),
  check: '<svg viewBox="0 0 24 24" class="ln" data-la="check" style="stroke-width:2.6"><path pathLength="1" d="M4 12 9 17L20 6"/></svg>',
  heart: svgI('heart', '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>'),
  arrow: svgI('arrow', '<path data-s d="M5 12h14"/><path data-h d="m12 5 7 7-7 7"/>', 2.3),
  gear: svgI('gear', '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>', 1.8),
  sun: svgI('sun', '<circle cx="12" cy="12" r="4"/>' + ['M12 2v2', 'm19.07 4.93-1.41 1.41', 'M20 12h2', 'm17.66 17.66 1.41 1.41', 'M12 20v2', 'm6.34 17.66-1.41 1.41', 'M2 12h2', 'm4.93 4.93 1.41 1.41'].map(d => `<path data-r d="${d}"/>`).join('')),
  list: svgI('list', '<rect width="8" height="4" x="8" y="2" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path data-c d="m9 14 2 2 4-4"/>'),
  users: svgI('users', '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path data-a d="M22 21v-2a4 4 0 0 0-3-3.87"/><path data-a d="M16 3.13a4 4 0 0 1 0 7.75"/>'),
  plane: svgI('plane', '<path data-p d="M16.81 4.93A1.6 1.6 0 0 1 19.07 7.19L14.97 11.29L16.81 18.65Q17.09 19.64 16.38 20.34L16.17 20.56Q15.39 21.33 14.83 20.34L11.43 14.83L9.17 17.09L9.81 19.85Q9.95 20.56 9.45 21.05Q8.75 21.76 8.18 20.91L6.06 17.94L3.09 15.82Q2.24 15.25 2.95 14.55Q3.44 14.05 4.15 14.19L6.91 14.83L9.17 12.57L3.66 9.17Q2.67 8.61 3.44 7.83L3.66 7.62Q4.36 6.91 5.35 7.19L12.71 9.03Z"/>'),
  lock: svgI('lock', '<rect width="18" height="11" x="3" y="11" rx="2"/><path data-k d="M7 11V7a5 5 0 0 1 10 0v4"/>'),
  case: svgI('case', '<path d="M12 12h.01"/><path d="M16 6V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/><path d="M22 13a18.15 18.15 0 0 1-20 0"/><rect width="20" height="14" x="2" y="6" rx="2"/>'),
  euro: svgI('euro', '<path data-m d="M19 6a7.7 7.7 0 0 0-5.2-2A7.9 7.9 0 0 0 6 12c0 4.4 3.5 8 7.8 8 2 0 3.8-.8 5.2-2"/><path data-s d="M16 10h-12"/><path data-s d="M13 14h-9"/>'),
  tag: svgI('tag', '<path d="M11 15h2a2 2 0 1 0 0-4h-3c-.6 0-1.1.2-1.4.6L3 17"/><path d="m7 21 1.6-1.4c.3-.4.8-.6 1.4-.6h4c1.1 0 2.1-.4 2.8-1.2l4.6-4.4a2 2 0 0 0-2.75-2.91l-4.2 3.9"/><path d="m2 16 6 6"/><circle data-c cx="16" cy="9" r="2.9"/><circle data-c cx="6" cy="5" r="3"/>'),
  mail: svgI('mail', '<path d="M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/><path data-c d="m16 19 2 2 4-4"/>'),
  note: svgI('note', '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path data-l d="M10 9H8"/><path data-l d="M16 13H8"/><path data-l d="M16 17H8"/>'),
  book: svgI('book', '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20"/><path d="M8 11h8"/><path d="M8 7h6"/>'),
  back: svgI('back', '<path d="m15 18-6-6 6-6"/>', 2.4),
  chev: svgI('chev', '<path d="m9 18 6-6-6-6"/>', 2.4),
  camera: svgI('camera', '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle data-c cx="12" cy="13" r="3"/>'),
  search: svgI('search', '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>', 2.2),
  sync: svgI('sync', '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>'),
  pass: svgI('pass', '<path data-d="2" d="M16 10h2"/><path data-d="2" d="M16 14h2"/><path data-d="0" d="M6.17 15a3 3 0 0 1 5.66 0"/><circle data-d="1" cx="9" cy="11" r="2"/><rect width="20" height="14" x="2" y="5" rx="2"/>'),
  ticket: svgI('ticket', '<g data-lt><path d="M13 5H4a2 2 0 0 0-2 2v2a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h9"/><path d="M13 5v2"/><path d="M13 11v2"/><path d="M13 17v2"/></g><path data-rt d="M13 5h7a2 2 0 0 1 2 2v2a3 3 0 0 0 0 6v2a2 2 0 0 1-2 2h-7"/>'),
  shield: svgI('shield', '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path data-c d="m9 12 2 2 4-4"/>'),
  flame: svgI('flame', '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>'),
};

/* ---------- animated icons ----------
   Each icon replays its lucide-animated motion when you tap (or hover) whatever holds it,
   when its tab becomes active, and when the Move tiles arrive. Springs are real damped springs,
   baked into CSS linear() easings. */
const SPR = {}, HAS_LINEAR = CSS.supports('animation-timing-function', 'linear(0, 1)');
function spr(k, c) {
  const key = k + '/' + c; if (SPR[key]) return SPR[key];
  let x = 0, v = 0, t = 0, still = 0; const dt = 1 / 240, pts = [0];
  while (t < 2.5) { v += (-k * (x - 1) - c * v) * dt; x += v * dt; t += dt; pts.push(x); if (Math.abs(x - 1) < .002 && Math.abs(v) < .02) { if (++still > 10) break; } else still = 0; }
  const n = 48, out = []; for (let i = 0; i <= n; i++) out.push(+pts[Math.round(i * (pts.length - 1) / n)].toFixed(4)); out[n] = 1;
  return SPR[key] = { easing: HAS_LINEAR ? `linear(${out.join(',')})` : 'cubic-bezier(.3,1.35,.5,1)', duration: Math.round(t * 1000) };
}
function la(el, kf, o) {
  if (!el || RM) return null;
  if (el.tagName !== 'svg') { el.style.transformBox ||= 'fill-box'; el.style.transformOrigin ||= 'center'; }
  const a = el.animate(kf, { fill: 'backwards', ...o }); a.finished.catch(() => {}); return a;
}
/* pathLength / pathOffset, motion-style: frames are [length, offset] */
function lp(el, frames, o) {
  if (!el || RM) return null; el.setAttribute('pathLength', 1);
  return la(el, frames.map(([l, off = 0]) => ({ strokeDasharray: `${Math.max(l, .001)} 2`, strokeDashoffset: -off })), o);
}
const fadeIn = (el, o) => la(el, [{ opacity: 0 }, { opacity: 1 }], { duration: 100, ...o });
async function thereBack(el, kf0, kf1, sp, hold = 360) {
  const a = la(el, [kf0, kf1], { ...sp, fill: 'forwards' }); if (!a) return;
  try { await a.finished; } catch { return; }
  await new Promise(r => setTimeout(r, hold));
  if (a.playState !== 'finished') return;
  la(el, [kf1, kf0], sp); a.cancel();
}
const $q = (el, sel) => el.querySelector(sel), $qa = (el, sel) => [...el.querySelectorAll(sel)];
const LA = {
  sun: s => $qa(s, '[data-r]').forEach((p, i) => la(p, [{ opacity: 0 }, { opacity: 1 }], { duration: 300, delay: (i + 1) * 90 })),
  list: s => { const c = $q(s, '[data-c]'); lp(c, [[0], [1]], { duration: 320, easing: 'ease-in-out' }); la(c, [{ opacity: 0 }, { opacity: 1 }], { duration: 300 }); },
  users: s => $qa(s, '[data-a]').forEach(p => la(p, [{ transform: 'translateX(-6px)' }, { transform: 'none' }], { ...spr(200, 13), delay: 100 })),
  flame: s => { const p = $q(s, 'path'); lp(p, [[0], [1]], { duration: 450, delay: 100, easing: 'ease-in-out' }); fadeIn(p, { delay: 100 }); },
  plane: s => la($q(s, '[data-p]'), [{ transform: 'translate(-25px,10px) scale(.8) rotate(-15deg)', opacity: 0 }, { transform: 'none', opacity: 1 }], { duration: 1100, easing: 'cubic-bezier(.25,1,.5,1)' }),
  plus: s => la(s, [{ transform: 'none' }, { transform: 'rotate(180deg)' }], spr(100, 15)),
  x: s => $qa(s, 'path').forEach((p, i) => { lp(p, [[0], [1]], { duration: 320, delay: i * 200, easing: 'ease-out' }); fadeIn(p, { delay: i * 200 }); }),
  phone: s => {
    la(s, [{ transform: 'rotate(10deg)' }, { transform: 'rotate(20deg) scale(1.1)' }, { transform: 'rotate(-10deg) scale(1.2)' }, { transform: 'rotate(10deg) scale(1.1)' }, { transform: 'none' }], { duration: 900, easing: 'ease-in-out' });
    $qa(s, '[data-w]').forEach(w => { const T = 600 + +w.dataset.w * 100; la(w, [{ opacity: 1 }, { opacity: 0, offset: 300 / T }, { opacity: 0, offset: (T - 300) / T }, { opacity: 1 }], { duration: T }); });
  },
  check: s => { const p = $q(s, 'path'); lp(p, [[0], [1]], { duration: 400, easing: 'ease-out' }); la(p, [{ transform: 'scale(.5)', opacity: 0 }, { transform: 'none', opacity: 1, offset: .25 }, { transform: 'none', opacity: 1 }], { duration: 400 }); },
  heart: s => la(s, [{ transform: 'none' }, { transform: 'scale(1.12)' }, { transform: 'none' }], { duration: 450, iterations: 3, easing: 'ease-in-out' }),
  arrow: s => {
    try { la($q(s, '[data-s]'), [{ d: 'path("M5 12h14")' }, { d: 'path("M5 12h9")' }, { d: 'path("M5 12h14")' }], { duration: 400 }); } catch (e) {}
    la($q(s, '[data-h]'), [{ transform: 'none' }, { transform: 'translateX(-3px)' }, { transform: 'none' }], { duration: 400 });
  },
  gear: s => la(s, [{ transform: 'none' }, { transform: 'rotate(180deg)' }], spr(50, 10)),
  lock: s => {
    la(s, [{ transform: 'rotate(-3deg) scale(.95)' }, { transform: 'rotate(1deg) scale(1.05)' }, { transform: 'rotate(-2deg) scale(.98)' }, { transform: 'none' }], { duration: 1000, easing: 'cubic-bezier(.4,0,.2,1)' });
    lp($q(s, '[data-k]'), [[1], [.7, 0], [.7, 0], [1]], { duration: 1000, easing: 'cubic-bezier(.4,0,.2,1)' });
  },
  case: s => { s.style.transformOrigin = '50% 17%'; la(s, [{ transform: 'none' }, { transform: 'rotate(4deg)' }, { transform: 'rotate(-3deg)' }, { transform: 'rotate(2deg)' }, { transform: 'none' }], { duration: 900, easing: 'ease-in-out' }); },
  euro: s => {
    const m = $q(s, '[data-m]'); lp(m, [[0], [1]], { duration: 600, easing: 'ease-in-out' }); fadeIn(m);
    $qa(s, '[data-s]').forEach(p => { lp(p, [[0, 1], [1, 0]], { duration: 400, delay: 500, easing: 'ease-out' }); fadeIn(p, { delay: 500 }); });
  },
  tag: s => $qa(s, '[data-c]').forEach((c, i) => la(c, [{ transform: 'translateY(-20px)', opacity: 0 }, { transform: 'none', opacity: 1 }], { ...spr(150, 15), delay: i * 150 })),
  mail: s => { const c = $q(s, '[data-c]'); lp(c, [[0], [1]], { duration: 400, easing: 'ease-in-out' }); la(c, [{ opacity: 0 }, { opacity: 1 }], { duration: 400 }); },
  note: s => {
    thereBack(s, { transform: 'none' }, { transform: 'scale(1.06)' }, { duration: 300, easing: 'ease-out' }, 900);
    $qa(s, '[data-l]').forEach((l, i) => lp(l, [[1], [0], [1]], { duration: 700, delay: 300 + i * 200, easing: 'ease-in-out' }));
  },
  book: s => la(s, [{ transform: 'none' }, { transform: 'translateY(-.8px) rotate(-8deg) scale(1.016)', offset: .2 }, { transform: 'translateY(-2px) rotate(8deg) scale(1.04)', offset: .5 }, { transform: 'translateY(-.8px) rotate(-8deg) scale(1.016)', offset: .8 }, { transform: 'none' }], { duration: 600, easing: 'ease-in-out' }),
  back: s => la($q(s, 'path'), [{ transform: 'none' }, { transform: 'translateX(-2px)', offset: .4 }, { transform: 'none' }], { duration: 500 }),
  chev: s => la($q(s, 'path'), [{ transform: 'none' }, { transform: 'translateX(2px)', offset: .4 }, { transform: 'none' }], { duration: 500 }),
  camera: s => la($q(s, '[data-c]'), [{ transform: 'none' }, { transform: 'scale(.55)' }, { transform: 'scale(1.15)' }, { transform: 'none' }], { duration: 520, easing: 'ease-in-out' }),
  search: s => la(s, [{ transform: 'none' }, { transform: 'translateY(-4px)' }, { transform: 'translateX(-3px)' }, { transform: 'none' }], { duration: 1000, easing: 'ease-in-out' }),
  sync: s => thereBack(s, { transform: 'none' }, { transform: 'rotate(50deg)' }, spr(250, 25)),
  pass: s => $qa(s, '[data-d]').forEach(p => { lp(p, [[0], [1]], { duration: 300, delay: +p.dataset.d * 100 }); la(p, [{ opacity: 0 }, { opacity: 1 }], { duration: 300, delay: +p.dataset.d * 100 }); }),
  ticket: s => {
    const r = $q(s, '[data-rt]'); r.style.transformBox = 'view-box'; r.style.transformOrigin = '13px 12px';
    thereBack($q(s, '[data-lt]'), { transform: 'none' }, { transform: 'translateX(-3px)' }, spr(300, 20));
    thereBack(r, { transform: 'none' }, { transform: 'translateX(3px) rotate(4deg)' }, spr(300, 20));
  },
  shield: s => { const p = $q(s, '[data-c]'); lp(p, [[0], [1]], { duration: 400 }); la(p, [{ transform: 'scale(.5)', opacity: 0 }, { transform: 'none', opacity: 1 }], { duration: 400 }); },
};
function playIcon(svg, delay = 0) {
  if (!svg || RM || !LA[svg.dataset.la]) return;
  const run = () => { svg.getAnimations({ subtree: true }).forEach(a => a.cancel()); LA[svg.dataset.la](svg); };
  delay ? setTimeout(run, delay) : run();
}
const ICON_HOST = 'button, .tile, .rw.tap, .set, .search, .more';

const wait = ms => new Promise(r => setTimeout(r, RM ? 0 : ms));
const ease = t => 1 - Math.pow(1 - t, 3);
function tween(ms, fn) { return new Promise(res => { if (RM) { fn(1); return res(); } const t0 = performance.now(); const step = now => { const t = Math.min(1, (now - t0) / ms); fn(t); t < 1 ? requestAnimationFrame(step) : res(); }; requestAnimationFrame(step); }); }
function anim(el, kf, opt) { if (!el) return Promise.resolve(); if (RM) opt = { ...opt, duration: 1, delay: 0 }; return el.animate(kf, { fill: 'backwards', ...opt }).finished.catch(() => {}); }

/* line drawings draw themselves in */
function draw(root, delay = 0) {
  if (RM) return;
  root.querySelectorAll('.art').forEach(svg => {
    let i = 0;
    svg.querySelectorAll('.ln path, .ln circle, .ln rect').forEach(el => {
      if (el.closest('.nodraw') || el.classList.contains('nodraw')) return;
      if (el.classList.contains('dots')) { anim(el, [{ opacity: 0 }, { opacity: 1 }], { duration: 700, delay: delay + 500 }); return; }
      el.setAttribute('pathLength', 1); el.style.strokeDasharray = '1';
      el.animate([{ strokeDashoffset: 1 }, { strokeDashoffset: 0 }], { duration: 900, delay: delay + i++ * 55, easing: 'cubic-bezier(.6,0,.3,1)', fill: 'both' })
        .finished.then(() => { el.style.strokeDasharray = ''; el.removeAttribute('pathLength'); el.getAnimations().forEach(a => a.cancel()); }).catch(() => {});
    });
  });
}


export { RM, $, $$, $q, $qa, I, svgI, la, lp, LA, playIcon, spr, wait, ease, tween, anim, draw };

/** The overshooting spring curve the prototype uses for tips and fills (0 to 1). */
export const spring = (t) => (t >= 1 ? 1 : 1 - Math.exp(-5.5 * t) * Math.cos(11 * t));
