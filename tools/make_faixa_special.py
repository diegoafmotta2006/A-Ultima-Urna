"""Gera assets/characters/faixa/special.png.

O set `faixa` nasceu com as 10 poses das folhas de referencia, sem pose de
especial; antes o special.png era copia byte a byte do heavy.png (pose
repetida). A unica arte extra do mesmo personagem e assets/characters/
presidente/idle.png, entao este script espelha (o set `faixa` olha para a
direita), recorta, reescal para a mesma altura de corpo do set e ancora nos
pes, igual a slice_poses.py.
"""

import os
from collections import deque

from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(BASE, "assets", "characters", "presidente", "idle.png")
DST = os.path.join(BASE, "assets", "characters", "faixa", "special.png")

# Altura cabeca->pes das poses em pe do set faixa (idle tem 652 px).
TARGET_BODY = 645.0
# Folga lateral para o braco levantado nao ficar colado na borda.
PAD_X = 4


def alpha_mask(im):
    w, h = im.size
    px = im.load()
    return [[px[x, y][3] > 128 for x in range(w)] for y in range(h)]


def drop_strays(im, min_area=300):
    """Forca o maior componente (o corpo) e descarta brilho/ruido solto."""
    w, h = im.size
    mask = alpha_mask(im)
    seen = [[False] * w for _ in range(h)]
    keep = [[False] * w for _ in range(h)]
    best = []
    for sy in range(h):
        for sx in range(w):
            if mask[sy][sx] and not seen[sy][sx]:
                q = deque([(sx, sy)])
                seen[sy][sx] = True
                comp = []
                while q:
                    x, y = q.popleft()
                    comp.append((x, y))
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                        if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
                if len(comp) >= min_area and len(comp) > len(best):
                    best = comp
    if best:
        for x, y in best:
            keep[y][x] = True
        px = im.load()
        for y in range(h):
            for x in range(w):
                if not keep[y][x]:
                    px[x, y] = (0, 0, 0, 0)
    return im


def runs(row):
    out, start = [], None
    for x, on in enumerate(row):
        if on and start is None:
            start = x
        elif not on and start is not None:
            out.append((start, x - 1))
            start = None
    if start is not None:
        out.append((start, len(row) - 1))
    return out


def head_top(mask, min_width=70):
    """Primeira linha com um traco largo de corpo (descarta braco e brilho)."""
    for y, row in enumerate(mask):
        if any(row) and max(b - a + 1 for a, b in runs(row)) >= min_width:
            return y
    return 0


def shoe_anchor(mask, y0, y1):
    """Centro dos pes: conteudo das ultimas 8% das linhas (igual slice_poses.py)."""
    band = max(6, int((y1 - y0 + 1) * 0.08))
    xs = [x for y in range(max(y0, y1 - band + 1), y1 + 1) for x, on in enumerate(mask[y]) if on]
    if not xs:
        xs = [x for y in range(y0, y1 + 1) for x, on in enumerate(mask[y]) if on]
    return (min(xs) + max(xs)) / 2.0


def main() -> None:
    im = drop_strays(Image.open(SRC).convert("RGBA"))
    w, h = im.size
    mask = alpha_mask(im)

    art_top = min(y for y in range(h) if any(mask[y]))
    body_top = head_top(mask)
    body_bottom = max(y for y in range(h) if any(mask[y]))
    left = min(x for y in range(h) for x, on in enumerate(mask[y]) if on)
    right = max(x for y in range(h) for x, on in enumerate(mask[y]) if on)

    scale = TARGET_BODY / float(body_bottom - body_top + 1)
    new_w = max(1, int(round((right - left + 1) * scale)))
    new_h = max(1, int(round((h - art_top) * scale)))
    im = im.crop((left, art_top, right + 1, h)).transpose(Image.FLIP_LEFT_RIGHT)
    im = im.resize((new_w, new_h), Image.LANCZOS)

    mask = alpha_mask(im)
    body_bottom = max(y for y in range(new_h) if any(mask[y]))
    anchor = shoe_anchor(mask, max(0, body_bottom - int(new_h * 0.08)), body_bottom)

    half = int(max(anchor, new_w - anchor) + PAD_X)
    canvas = Image.new("RGBA", (half * 2, new_h), (0, 0, 0, 0))
    canvas.paste(im, (int(round(half - anchor)), 0))
    canvas.save(DST)

    print("src=%dx%d body=%d..%d scale=%.3f -> %s %dx%d"
          % (w, h, body_top, body_bottom, scale, DST, canvas.size[0], canvas.size[1]))


if __name__ == "__main__":
    main()
