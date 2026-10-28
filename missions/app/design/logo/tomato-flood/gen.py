"""Build the hesent.me Tomato Flood logo concepts (black first)."""
import math
from outline import font, text_path, bbox

INK = '#000'
ARCH = font('Archivo-Variable.ttf', wdth=78, wght=800)
DISP = font('Archivo-Variable.ttf', wdth=64, wght=900)
HAND = font('Caveat-Variable.ttf', wght=700)

def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{body}</svg>\n'

def save(name, s):
    open(name, 'w', encoding='utf-8').write(s)

# ---------- A: Postmark (stamp with a knocked-out h) ----------
def stamp_outline(x0=28, y0=28, size=200, n=7, r=9):
    p = size / n; x1 = x0 + size; y1 = y0 + size
    cs = [x0 + p / 2 + k * p for k in range(n)]
    d = [f'M{x0} {y0}']
    for c in cs: d += [f'L{c-r:.2f} {y0}', f'A{r} {r} 0 0 0 {c+r:.2f} {y0}']
    d.append(f'L{x1} {y0}')
    for c in cs: d += [f'L{x1} {c-r:.2f}', f'A{r} {r} 0 0 0 {x1} {c+r:.2f}']
    d.append(f'L{x1} {y1}')
    for c in reversed(cs): d += [f'L{c+r:.2f} {y1}', f'A{r} {r} 0 0 0 {c-r:.2f} {y1}']
    d.append(f'L{x0} {y1}')
    for c in reversed(cs): d += [f'L{x0} {c+r:.2f}', f'A{r} {r} 0 0 0 {x0} {c-r:.2f}']
    d.append('Z')
    return ' '.join(d)

H = ('M78 196 V56 H116 V102 C124 92 135 88 146 88 C166 88 178 102 178 124 V196 H140 V130 '
     'C140 122 135 118 128 118 C121 118 116 123 116 130 V196 Z')
A_SYM = f'<path fill="{INK}" fill-rule="evenodd" d="{stamp_outline()} {H}"/>'

# ---------- B: Loop h (one line: an h that leaves as an arrow) ----------
SW = 24
OX = -30  # optical centring for the arrow's extra width
B_LINE = (f'M{84+OX} 30 V214 '
          f'M{84+OX} 146 A44 44 0 0 1 {172+OX} 146 V170 A32 32 0 0 0 {204+OX} 202 H{238+OX}')
def arrowhead(x, y, ang_deg, L=30, spread=40):
    pts = []
    for s in (-1, 1):
        a = math.radians(ang_deg + 180 + s * spread)
        pts.append((x + L * math.cos(a), y + L * math.sin(a)))
    return f'M{pts[0][0]:.1f} {pts[0][1]:.1f} L{x} {y} L{pts[1][0]:.1f} {pts[1][1]:.1f}'
B_SYM = (f'<g fill="none" stroke="{INK}" stroke-width="{SW}" stroke-linecap="round" stroke-linejoin="round">'
         f'<path d="{B_LINE}"/><path d="{arrowhead(238+OX, 202, 0, L=34, spread=45)}"/></g>')

# ---------- C: HE SENT me (display + hand, the app's two voices) ----------
def hand_me(cx, cy, size, rot=-7):
    x0, y0, x1, y1 = bbox(HAND, 'me', size)
    w = x1 - x0; hgt = y1 - y0
    ox = cx - w / 2 - x0; oy = cy + hgt / 2 - y1
    d, _ = text_path(HAND, 'me', size, ox, oy)
    return f'<path fill="{INK}" transform="rotate({rot} {cx} {cy})" d="{d}"/>'
C_SYM = hand_me(118, 134, 212) + f'<circle cx="214" cy="168" r="15" fill="{INK}"/>'

# ---------- lockups ----------
def wordmark(x, baseline, size):
    d, w = text_path(ARCH, 'hesent.me', size, x, baseline, tracking=-0.005)
    return f'<path fill="{INK}" d="{d}"/>', w

def lockup(sym_body):
    wm, w = wordmark(280, 184, 150)
    W = int(280 + w + 16)
    return svg(W, 256, f'<g>{sym_body}</g>{wm}')

def c_lockup():
    d, w = text_path(DISP, 'HESENT', 210, 16, 204)
    x_me = 16 + w + 4
    x0, y0, x1, y1 = bbox(HAND, 'me', 300)
    mw = x1 - x0
    me = hand_me(x_me + mw / 2, 168, 300, rot=-8)
    dot = f'<circle cx="{x_me + mw + 14:.1f}" cy="192" r="15" fill="{INK}"/>'
    return svg(int(x_me + mw + 40), 256, f'<path fill="{INK}" d="{d}"/>{me}{dot}')

if __name__ == '__main__':
    import sys
    v = sys.argv[1] if len(sys.argv) > 1 else 'v1'
    save(f'a-symbol-{v}.svg', svg(256, 256, A_SYM)); save(f'a-lockup-{v}.svg', lockup(A_SYM))
    save(f'b-symbol-{v}.svg', svg(256, 256, B_SYM)); save(f'b-lockup-{v}.svg', lockup(B_SYM))
    save(f'c-symbol-{v}.svg', svg(256, 256, C_SYM)); save(f'c-lockup-{v}.svg', c_lockup())
