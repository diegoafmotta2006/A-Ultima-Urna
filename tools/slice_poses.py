import os, math
from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(BASE, "assets", "characters", "referencia")
OUT = os.path.join(BASE, "assets", "characters")
BG = (22, 22, 30)

SHEETS = {
    "faixa": os.path.join(SRC, "faixa_folha_direita.jpg"),
    "azul": os.path.join(SRC, "azul_folha_direita.jpg"),
}

ROW_POSES = [
    ["idle", "walk", "jump", "light", "heavy"],
    ["launcher", "hit", "block", "knockdown", "ko"],
]

def d2(px):
    r, g, b = px
    return (r - BG[0]) ** 2 + (g - BG[1]) ** 2 + (b - BG[2]) ** 2

T_BG = 220  # squared distance; below => background

def is_fg(px):
    return d2(px) > T_BG

def label_score(px, W, cw, y):
    zones = 0
    for c in range(5):
        bright = 0
        for x in range(c * cw, (c + 1) * cw, 4):
            r, g, b = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            if mn > 150 and mx - mn < 30:
                bright += 1
        if bright > 3:
            zones += 1
    return zones

def find_label_bands(px, W, H, cw):
    flags = [label_score(px, W, cw, y) >= 4 for y in range(H)]
    bands, inb, s, gap = [], False, 0, 0
    for y, f in enumerate(flags):
        if f:
            if not inb:
                inb, s = True, y
            gap = 0
        elif inb:
            gap += 1
            if gap > 6:
                bands.append((s, y - gap))
                inb = False
    if inb:
        bands.append((s, H - 1))
    # expand each band upward/downward while nearby rows still look like text
    expanded = []
    for s, e in bands:
        ns, ne = s, e
        while ns > 0 and (s - ns) < 40 and label_score(px, W, cw, ns - 1) >= 2:
            ns -= 1
        while ne < H - 1 and (ne - e) < 40 and label_score(px, W, cw, ne + 1) >= 2:
            ne += 1
        expanded.append((ns, ne))
    return expanded

def col_profile(px, W, ya, ycut):
    cols = [0] * W
    for x in range(W):
        c = 0
        for y in range(ya, ycut):
            if is_fg(px[x, y]):
                c += 1
        cols[x] = c
    return cols

def segments(cols):
    segs, inb, s = [], False, 0
    for x, c in enumerate(cols):
        if c > 0 and not inb:
            inb, s = True, x
        elif c == 0 and inb:
            inb = False
            segs.append([s, x - 1])
    if inb:
        segs.append([s, len(cols) - 1])
    # merge tiny gaps
    merged = []
    for a, b in segs:
        if merged and a - merged[-1][1] <= 16:
            merged[-1][1] = b
        else:
            merged.append([a, b])
    return merged

def refine_to_five(segs, cols):
    segs = [list(s) for s in segs]
    # merge closest neighbours until 5
    while len(segs) > 5:
        gaps = [(segs[i + 1][0] - segs[i][1], i) for i in range(len(segs) - 1)]
        _, i = min(gaps)
        segs[i][1] = segs[i + 1][1]
        del segs[i + 1]
    # split widest at lowest density until 5
    while len(segs) < 5:
        widest = max(range(len(segs)), key=lambda i: segs[i][1] - segs[i][0])
        a, b = segs[widest]
        inner = range(a + 40, b - 39)
        cut = min(inner, key=lambda x: cols[x])
        segs.insert(widest, [a, cut])
        segs[widest + 1][0] = cut + 1
    return segs

def key_and_crop(img, box, out_path):
    from collections import deque
    x0, y0, x1, y1 = box
    crop = img.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGBA")
    w, h = crop.size
    px = crop.load()
    mask = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            if d2((r, g, b)) > T_BG:
                mask[base + x] = 1
    # keep only the largest 4-connected component (the character)
    seen = bytearray(w * h)
    best = None
    best_size = 0
    for start in range(w * h):
        if mask[start] and not seen[start]:
            seen[start] = 1
            q = deque([start])
            comp = []
            while q:
                i = q.popleft()
                comp.append(i)
                y, x = divmod(i, w)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if mask[j] and not seen[j]:
                            seen[j] = 1
                            q.append(j)
            if len(comp) > best_size:
                best_size = len(comp)
                best = comp
    keep = bytearray(w * h)
    if best:
        for i in best:
            keep[i] = 1
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            if keep[base + x]:
                px[x, y] = (r, g, b, 255)
            else:
                px[x, y] = (r, g, b, 0)
    # horizontal anchor = center of shoes (bottom 8% rows of kept content)
    bottom_start = max(0, h - max(6, int(h * 0.08)))
    xs = []
    for y in range(bottom_start, h):
        base = y * w
        for x in range(w):
            if keep[base + x]:
                xs.append(x)
    anchor = (min(xs) + max(xs)) / 2.0 if xs else w / 2.0
    # pad so that anchor sits at horizontal center of canvas
    half = int(math.ceil(max(anchor, w - anchor)))
    new_w = half * 2
    canvas = Image.new("RGBA", (new_w, h), (0, 0, 0, 0))
    canvas.paste(crop, (int(round(half - anchor)), 0))
    canvas.save(out_path)
    return canvas.size

def process(name, path):
    img = Image.open(path).convert("RGB")
    W, H = img.size
    px = img.load()
    cw, ch = W // 5, H // 2
    outdir = os.path.join(OUT, name)
    os.makedirs(outdir, exist_ok=True)
    bands = find_label_bands(px, W, H, cw)
    print("  label bands:", bands)
    # row0 labels = band whose center is between 40% and 60% height
    mid = [b for b in bands if 0.40 * H < (b[0] + b[1]) / 2 < 0.62 * H]
    low = [b for b in bands if (b[0] + b[1]) / 2 > 0.85 * H]
    row0_label = mid[-1] if mid else (int(H * 0.48), int(H * 0.49))
    row1_label = low[-1] if low else (int(H * 0.95), int(H * 0.96))
    row_ranges = [
        (140, row0_label[0]),
        (row0_label[1] + 12, row1_label[0]),
    ]
    info = {}
    for r in range(2):
        ya, ycut = row_ranges[r]
        cols = col_profile(px, W, ya, ycut)
        segs = [s for s in segments(cols) if s[1] - s[0] >= 30]
        segs = refine_to_five(segs, cols)
        for pose, (sx0, sx1) in zip(ROW_POSES[r], segs):
            minx, miny, maxx, maxy = 10 ** 9, 10 ** 9, -1, -1
            for y in range(ya, ycut):
                for x in range(sx0, sx1 + 1):
                    if is_fg(px[x, y]):
                        if x < minx: minx = x
                        if x > maxx: maxx = x
                        if y < miny: miny = y
                        if y > maxy: maxy = y
            if maxx < 0:
                print("  EMPTY", name, r, pose)
                continue
            box = (minx, miny, maxx, maxy)
            size = key_and_crop(img, box, os.path.join(outdir, pose + ".png"))
            info[pose] = {"box": box, "size": size, "row": r}
            print(f"  {name}/{pose:9s} y[{ya},{ycut}) box={box} crop={size}")
    return info

for name, path in SHEETS.items():
    print("==", name)
    process(name, path)
print("done")
