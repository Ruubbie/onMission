"""Outline text from the bundled Archivo/Caveat variable fonts into SVG path data."""
import os
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONTS = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'ios', 'OnMission', 'Resources', 'Fonts')
_cache = {}

def font(name, **axes):
    key = (name, tuple(sorted(axes.items())))
    if key not in _cache:
        f = TTFont(os.path.join(FONTS, name))
        _cache[key] = instancer.instantiateVariableFont(f, axes)
    return _cache[key]

def text_path(f, text, size, x=0, y=0, tracking=0.0):
    """Path data for text with baseline at y; returns (d, width). tracking in em."""
    gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm
    s = size / upm; pen = SVGPathPen(gs); cx = 0
    for ch in text:
        g = cmap[ord(ch)]
        tp = TransformPen(pen, (s, 0, 0, -s, x + cx * s, y))
        gs[g].draw(tp)
        cx += gs[g].width + tracking * upm
    return pen.getCommands(), (cx - tracking * upm) * s

def bbox(f, text, size, tracking=0.0):
    from fontTools.pens.boundsPen import BoundsPen
    gs = f.getGlyphSet(); cmap = f.getBestCmap(); upm = f['head'].unitsPerEm
    bp = BoundsPen(gs); cx = 0
    for ch in text:
        g = cmap[ord(ch)]
        tp = TransformPen(bp, (1, 0, 0, 1, cx, 0)); gs[g].draw(tp)
        cx += gs[g].width + tracking * upm
    s = size / upm; x0, y0, x1, y1 = bp.bounds
    return x0 * s, -y1 * s, x1 * s, -y0 * s  # svg coords relative to origin/baseline
