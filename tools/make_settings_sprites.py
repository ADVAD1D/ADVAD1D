"""Draws the main menu settings sprites (gear button and CRT roll toggle) on the frame of
the existing 30x30 toggle buttons, and saves them to Assets/Sprites/Settings/.

    python tools/make_settings_sprites.py
    python tools/make_settings_sprites.py --preview out.png   # also a 6x sheet
"""
import argparse
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "Assets", "Sprites")
OUT_DIR = os.path.join(SPRITES, "Settings")

# Palette of fps_button.png / shaders_button_*.png
ICON = (0, 255, 209)        # 00ffd1
ICON_SHADE = (0, 115, 94)   # 00735e
FILL_LOW = (31, 46, 44)     # 1f2e2c lower-left half of the button face
FILL_NORMAL = (18, 29, 27)  # 121d1b upper-right half
FILL_HOVER = (53, 81, 76)   # 35514c (fps_button_hover)
FILL_PRESSED = (69, 110, 103)  # 456e67 (shaders_button_pressed)
DIM = (58, 87, 87)          # 3a5757 disabled icon
DIM_SHADE = (43, 70, 65)    # 2b4641

FACE = range(4, 26)  # inside the frame of the 30x30 buttons

ROLL_ICON = [
    "aaaaaaaaaaaaaaa.......",
    "a.............a...a...",
    "a.aaaaaaaaaaa.a...a...",
    "a.hhhhhhhhhhh.a...a...",
    "a.............a...a...",
    "a.............a.aaaaa.",
    "a.aaaaaaaaaaa.a..aaa..",
    "a.hhhhhhhhhhh.a...a...",
    "a.............a.......",
    "aaaaaaaaaaaaaaa.......",
    "......aaa.............",
    "....aaaaaaa...........",
]


def blank_button(upper_fill):
    """The fps button frame with an empty face (diagonal two-tone like the originals)."""
    img = Image.open(os.path.join(SPRITES, "fps_button.png")).convert("RGBA")
    for y in FACE:
        for x in FACE:
            color = FILL_LOW if x - y <= 0 else upper_fill
            img.putpixel((x, y), color + (255,))
    return img


def draw_map(img, rows, ox, oy, color, shade):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "a":
                img.putpixel((ox + i, oy + j), color + (255,))
            elif ch == "h":
                img.putpixel((ox + i, oy + j), shade + (255,))


def draw_gear(img, color, shade):
    """Solid disc with 8 square teeth and a hole; the lower-right of the inner ring is
    shaded, like the two-tone triangle of the shader button."""
    cx = cy = 14.5
    teeth = [(math.cos(k * math.pi / 4), math.sin(k * math.pi / 4)) for k in range(8)]
    for y in FACE:
        for x in FACE:
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            solid = 2.3 < d <= 6.2
            for ux, uy in teeth:
                along = dx * ux + dy * uy
                across = abs(-dx * uy + dy * ux)
                if 5.0 <= along <= 8.6 and across <= 1.6:
                    solid = True
            if not solid:
                continue
            inner_shadow = dx + dy > 0.5 and d < 4.4
            img.putpixel((x, y), (shade if inner_shadow else color) + (255,))


def make_all():
    sprites = {}
    for name, fill in (("settings_button", FILL_NORMAL), ("settings_button_hover", FILL_HOVER)):
        img = blank_button(fill)
        draw_gear(img, ICON, ICON_SHADE)
        sprites[name] = img
    for name, fill, color, shade in (
            ("roll_button", FILL_NORMAL, ICON, ICON_SHADE),
            ("roll_button_pressed", FILL_PRESSED, ICON, ICON_SHADE),
            ("roll_button_disabled", FILL_NORMAL, DIM, DIM_SHADE)):
        img = blank_button(fill)
        draw_map(img, ROLL_ICON, 4, 9, color, shade)
        sprites[name] = img
    return sprites


def make_preview(sprites, path):
    sheet = Image.new("RGBA", (36 * len(sprites), 36), (5, 16, 18, 255))
    for i, img in enumerate(sprites.values()):
        sheet.alpha_composite(img, (3 + 36 * i, 3))
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="also save a 6x sheet of every sprite")
    args = parser.parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    sprites = make_all()
    for name, img in sprites.items():
        img.save(os.path.join(OUT_DIR, name + ".png"))
        print("saved", name)
    if args.preview:
        make_preview(sprites, args.preview)
        print("preview", args.preview)


if __name__ == "__main__":
    main()
