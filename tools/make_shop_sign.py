"""Draws the shop's hanging "THE SHOP" sign (a nod to Geometry Dash's shop sign) in the
neon cyan palette of the shop sprites, and saves it to Assets/Sprites/Shop/shop_sign.png.

    python tools/make_shop_sign.py               # writes the sprite
    python tools/make_shop_sign.py --preview out.png
        # also writes a 3x mockup of the sign over the shop background
"""
import argparse
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Sprites", "Shop", "shop_sign.png")

# Palette taken from the shop sprites (dialog_box.png, shop_card.png, diamond_big.png)
DARK = (13, 20, 20)          # 0d1414 outlines
FILL_A = (7, 20, 22)         # 071416 panel rows
FILL_B = (10, 28, 30)        # 0a1c1e panel rows
CYAN = (4, 218, 255)         # 04daff
CYAN_DARK = (3, 112, 138)    # 03708a
CYAN_LIGHT = (162, 255, 255)  # a2ffff
WHITE = (255, 255, 255)
GEM_EDGE = (8, 60, 74)       # 083c4a
MINT = (0, 255, 209)         # 00ffd1
STEEL_HI = (141, 180, 174)   # 8db4ae
STEEL = (82, 128, 128)       # 528080
STEEL_MID = (69, 110, 103)   # 456e67
STEEL_LO = (43, 70, 65)      # 2b4641
STEEL_DEEP = (31, 46, 44)    # 1f2e2c

W, H = 84, 35
BOARD_TOP = 4

# Big letters (2px strokes) for SHOP, small ones for THE
BIG = {
    "S": [".#####.", "##...##", "##.....", "##.....", ".#####.",
          ".....##", ".....##", "##...##", ".#####."],
    "H": ["##...##", "##...##", "##...##", "##...##", "#######",
          "##...##", "##...##", "##...##", "##...##"],
    "O": [".#####.", "##...##", "##...##", "##...##", "##...##",
          "##...##", "##...##", "##...##", ".#####."],
    "P": ["######.", "##...##", "##...##", "##...##", "######.",
          "##.....", "##.....", "##.....", "##....."],
}
SMALL = {
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
}

# Small diamond, same drawing style as diamond_big.png
GEM = ["...a...",
       "..aba..",
       ".abdea.",
       "abddeea",
       ".adeea.",
       "..aea..",
       "...a..."]
GEM_COLORS = {"a": GEM_EDGE, "b": CYAN_LIGHT, "d": CYAN, "e": CYAN_DARK}


def put(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color + (255,))


def draw_board(img):
    x0, y0, x1, y1 = 0, BOARD_TOP, W - 1, H - 1
    cut = 2  # chamfered corners, like the dialog box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = min(x - x0, x1 - x)
            dy = min(y - y0, y1 - y)
            if dx + dy < cut:
                continue
            if dx + dy == cut or dx == 0 or dy == 0:
                color = DARK
            elif dx + dy == cut + 1 or dx == 1 or dy == 1:
                color = CYAN
            else:
                color = FILL_A if y % 2 == 0 else FILL_B
            put(img, x, y, color)
    # Bright top edge and a darker inner line under the cyan border
    for x in range(x0 + 3, x1 - 2):
        put(img, x, y0 + 1, CYAN_LIGHT)
        put(img, x, y1 - 2, CYAN_DARK)
    # Rivets in the corners
    for rx, ry in ((x0 + 3, y0 + 3), (x1 - 3, y0 + 3), (x0 + 3, y1 - 4), (x1 - 3, y1 - 4)):
        put(img, rx, ry, CYAN_DARK)


def draw_cables(img):
    for cx in (11, W - 13):
        for y in range(0, BOARD_TOP + 1):
            link = STEEL_HI if y % 2 == 0 else STEEL
            put(img, cx, y, link)
            put(img, cx + 1, y, STEEL_LO if y % 2 == 0 else STEEL_MID)
        # Clamp where the cable meets the board
        for x in range(cx - 2, cx + 4):
            put(img, x, BOARD_TOP, DARK)
            put(img, x, BOARD_TOP + 1, STEEL if x < cx + 2 else STEEL_LO)
        put(img, cx - 2, BOARD_TOP + 1, DARK)
        put(img, cx + 3, BOARD_TOP + 1, DARK)


def draw_bag(img, ox, oy):
    """Money bag: crumpled top, cyan tie, round body with a diamond on it."""
    mask = {}
    # Crumpled opening (rows 0-3): three peaks, then the folds narrowing into the tie
    for x in (5, 6, 9, 12, 13):
        mask[(x, 0)] = "flare"
    for x in range(4, 15):
        mask[(x, 1)] = "flare"
    for x in range(5, 14):
        mask[(x, 2)] = "flare"
    for x in range(6, 13):
        mask[(x, 3)] = "inner"
    # Tie (rows 4-5)
    for y in (4, 5):
        for x in range(7, 12):
            mask[(x, y)] = "tie"
    # Neck (row 6) and round body (rows 7-20)
    for x in range(6, 13):
        mask[(x, 6)] = "body"
    cx, cy, rx, ry = 9.0, 14.0, 8.6, 7.4
    for y in range(7, 22):
        for x in range(0, 19):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                mask[(x, y)] = "body"

    for (x, y), part in mask.items():
        if part == "flare":
            color = STEEL_HI if x < 8 and y < 2 else STEEL
            if x > 11 or y == 2 and x % 3 == 1:
                color = STEEL_MID  # shade on the right and the folds
        elif part == "inner":
            color = STEEL_DEEP
        elif part == "tie":
            color = CYAN
            if y == 4 and x < 9:
                color = CYAN_LIGHT
            if x == 11 or y == 5 and x > 9:
                color = CYAN_DARK
        else:
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            lit = -(nx * 0.75 + ny * 0.65)
            if lit > 0.62:
                color = STEEL_HI
            elif lit > 0.2:
                color = STEEL
            elif lit > -0.45:
                color = STEEL_MID
            else:
                color = STEEL_LO
        put(img, ox + x, oy + y, color)

    # Outline every empty pixel that touches the bag
    for y in range(-1, 24):
        for x in range(-1, 20):
            if (x, y) in mask:
                continue
            if any((x + dx, y + dy) in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                put(img, ox + x, oy + y, DARK)

    # Diamond emblem on the body (the bag's "$")
    ex, ey = ox + 6, oy + 11
    emblem = ["...m...",
              "..mwm..",
              ".mw.mm.",
              "mw...mm",
              ".mm.mm.",
              "..mmm..",
              "...m..."]
    for j, row in enumerate(emblem):
        for i, ch in enumerate(row):
            if ch == "m":
                put(img, ex + i, ey + j, MINT)
            elif ch == "w":
                put(img, ex + i, ey + j, CYAN_LIGHT)
    put(img, ex + 3, ey + 3, MINT)


def draw_gem(img, ox, oy):
    for j, row in enumerate(GEM):
        for i, ch in enumerate(row):
            if ch in GEM_COLORS:
                put(img, ox + i, oy + j, GEM_COLORS[ch])


def draw_word(img, word, glyphs, ox, oy, top_rows):
    """Neon letters: light core on top, cyan below, dark outline around."""
    pixels = set()
    x = ox
    for ch in word:
        rows = glyphs[ch]
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c == "#":
                    pixels.add((x + i, oy + j))
        x += len(rows[0]) + (2 if glyphs is BIG else 1)
    for px, py in pixels:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (px + dx, py + dy)
                if q not in pixels:
                    put(img, q[0], q[1], CYAN_DARK if dy <= 0 else GEM_EDGE)
    for px, py in pixels:
        row = py - oy
        put(img, px, py, WHITE if row == 0 else CYAN_LIGHT if row < top_rows else CYAN)


def word_width(word, glyphs):
    gap = 2 if glyphs is BIG else 1
    return sum(len(glyphs[c][0]) for c in word) + gap * (len(word) - 1)


def make_sign():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_board(img)
    draw_cables(img)
    draw_bag(img, 4, 7)
    # Small pile of diamonds at the bag's foot
    draw_gem(img, 17, 25)
    draw_gem(img, 23, 25)
    draw_gem(img, 20, 21)
    # THE over SHOP, centred in the space right of the bag
    centre = 57
    draw_word(img, "THE", SMALL, centre - word_width("THE", SMALL) // 2, 9, 3)
    draw_word(img, "SHOP", BIG, centre - word_width("SHOP", BIG) // 2, 19, 4)
    return img


def make_preview(sign, path):
    shop = os.path.join(ROOT, "Assets", "Sprites", "Shop")
    scene = Image.open(os.path.join(shop, "shop_bg.png")).convert("RGBA")
    for layer in ("shopkeeper_idle.png", "shop_counter.png"):
        scene.alpha_composite(Image.open(os.path.join(shop, layer)).convert("RGBA"))
    card = Image.open(os.path.join(shop, "shop_card.png")).convert("RGBA")
    for x in (18, 104, 190):
        scene.alpha_composite(card, (x, 46))
    back = Image.open(os.path.join(ROOT, "Assets", "Sprites", "exitbutton.png")).convert("RGBA")
    back = back.resize((round(back.width * 0.8), round(back.height * 0.8)), Image.NEAREST)
    scene.alpha_composite(back, (6, 4))
    gem = Image.open(os.path.join(ROOT, "Assets", "Sprites", "Arcade", "diamond_big.png"))
    scene.alpha_composite(gem.convert("RGBA"), (120, 12))
    scene.alpha_composite(sign, (33, 0))
    scene = scene.resize((scene.width * 3, scene.height * 3), Image.NEAREST)
    scene.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="also save a 3x mockup over the shop")
    args = parser.parse_args()
    sign = make_sign()
    sign.save(OUT)
    print("saved", OUT)
    if args.preview:
        make_preview(sign, args.preview)
        print("preview", args.preview)


if __name__ == "__main__":
    main()
