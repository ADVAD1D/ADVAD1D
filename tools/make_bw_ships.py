"""Re-colours every ship sprite in black and white for the ship colour system.

The grey value of each pixel says what Shaders/ship_color.gdshader does with it:
  black (0..OUTLINE)          outline, stays black
  mid grey  (B1_LO..B1_HI)    colour 1 (body); darker grey = shadow
  light grey (B2_LO..255)     colour 2 (details); darker grey = shadow
  any non-grey pixel          keeps its own colour (eyes, faces... paint them in colour)
Keep these bands in sync with the constants in the shader.

The original coloured sprites are backed up once in tools/ship_originals/ (ignored by
Godot) and the conversion always starts from that backup, so it can be re-run safely.
Usage: python make_bw_ships.py <project_root> [--preview out.png] [--only 1,5,7]
Without --only it rewrites every ship sprite (hand retouches included).
"""
import sys, os, shutil
from PIL import Image

OUTLINE = 24           # 0..OUTLINE = black outline (shader: below 0.12)
B1_LO, B1_HI = 48, 140  # colour 1 band
B2_LO, B2_HI = 160, 255 # colour 2 band
FIXED_LUM = 0.10       # original pixels darker than this become outline
MIN_LAYER2 = 0.08      # if the light group is smaller than this, everything is colour 1
MIN_SHADE = 0.6        # darkest shade the shader paints (keep in sync)


def ship_paths(root):
    yield 1, "Assets/Sprites/Ship1.png"
    n = 2
    while os.path.exists(os.path.join(root, "Assets/Sprites/Ships/ship%d.png" % n)):
        yield n, "Assets/Sprites/Ships/ship%d.png" % n
        n += 1


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def otsu(values):
    vals = sorted(values)
    best_t, best_var = vals[len(vals) // 2], -1.0
    n = len(vals)
    for i in range(1, n):
        if vals[i] == vals[i - 1]:
            continue
        a, b = vals[:i], vals[i:]
        var = (len(a) / n) * (len(b) / n) * (sum(a) / len(a) - sum(b) / len(b)) ** 2
        if var > best_var:
            best_var, best_t = var, vals[i]
    return best_t


def to_bw(ship):
    w, h = ship.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    solid = [(x, y, c) for y in range(h) for x in range(w)
             for c in [ship.getpixel((x, y))] if c[3] > 0]
    paint = [p for p in solid if lum(p[2]) >= FIXED_LUM]
    for x, y, c in solid:
        if lum(c) < FIXED_LUM:
            v = round(OUTLINE * lum(c) / FIXED_LUM)
            out.putpixel((x, y), (v, v, v, c[3]))
    if not paint:
        return out
    lums = [lum(c) for _, _, c in paint]
    t = otsu(lums) if len(set(lums)) > 1 else max(lums) + 1
    if sum(1 for v in lums if v >= t) < MIN_LAYER2 * len(paint):
        t = 2.0
    for band, pts in (((B1_LO, B1_HI), [p for p in paint if lum(p[2]) < t]),
                      ((B2_LO, B2_HI), [p for p in paint if lum(p[2]) >= t])):
        if not pts:
            continue
        ls = [lum(c) for _, _, c in pts]
        lo, hi = min(ls), max(ls)
        for x, y, c in pts:
            k = 1.0 if hi - lo < 1e-6 else (lum(c) - lo) / (hi - lo)
            v = round(band[0] + (band[1] - band[0]) * k)
            out.putpixel((x, y), (v, v, v, c[3]))
    return out


def paint(bw, c1, c2):
    """Same maths as the shader, for previews."""
    out = bw.copy()
    for y in range(bw.height):
        for x in range(bw.width):
            r, g, b, a = bw.getpixel((x, y))
            if a == 0 or max(r, g, b) - min(r, g, b) > 5 or r <= OUTLINE:
                continue
            if r <= (B1_HI + B2_LO) / 2:
                k, col = (r - B1_LO) / (B1_HI - B1_LO), c1
            else:
                k, col = (r - B2_LO) / (B2_HI - B2_LO), c2
            s = MIN_SHADE + (1 - MIN_SHADE) * min(max(k, 0.0), 1.0)
            out.putpixel((x, y), tuple(round(col[i] * s) for i in range(3)) + (a,))
    return out


def main():
    root = sys.argv[1]
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    only = None
    if "--only" in sys.argv:
        only = {int(v) for v in sys.argv[sys.argv.index("--only") + 1].split(",")}
    backup_dir = os.path.join(root, "tools/ship_originals")
    os.makedirs(backup_dir, exist_ok=True)
    open(os.path.join(backup_dir, ".gdignore"), "a").close()
    rows = []
    for n, rel in ship_paths(root):
        if only and n not in only:
            continue
        sprite = os.path.join(root, rel)
        backup = os.path.join(backup_dir, os.path.basename(rel))
        if not os.path.exists(backup):
            shutil.copyfile(sprite, backup)
        original = Image.open(backup).convert("RGBA")
        bw = to_bw(original)
        bw.save(sprite)
        rows.append((original, bw))
    print("ships:", len(rows))
    if preview:
        cell, per_row = 52, 3
        variants = ["orig", "bw", ((140, 140, 140), (255, 255, 255)),
                    ((255, 48, 72), (255, 224, 64)), ((42, 107, 255), (35, 255, 255))]
        sheet = Image.new("RGBA", (cell * len(variants) * per_row,
                                   cell * ((len(rows) + per_row - 1) // per_row)), (20, 28, 30, 255))
        for i, (orig, bw) in enumerate(rows):
            ox, oy = (i % per_row) * cell * len(variants), (i // per_row) * cell
            for k, v in enumerate(variants):
                im = orig if v == "orig" else bw if v == "bw" else paint(bw, *v)
                sheet.alpha_composite(im, (ox + k * cell + (cell - im.width) // 2, oy + (cell - im.height) // 2))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(preview)


if __name__ == "__main__":
    main()
