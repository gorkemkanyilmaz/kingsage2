"""Taht ve Kılıç — UI denetim ikonlarını (ok/kaydırma) kod ile üretir.

Kaynak: marka tonu (koyu sıcak kahve). Çıktı: game/assets/sprites/ui/*.png
Bu ikonlar tema (`TahtVeKilic.tres`) üzerinden OptionButton ve SpinBox
denetimlerine bağlanır; Godot'un soluk varsayılan okları yerine geçer.

Çalıştırma:  python game/tools/gen_ui_icons.py
Ardından:    godot --headless --path game --import
"""
import os
from PIL import Image, ImageDraw

SS = 8  # supersampling
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "ui")
COLOR = (92, 66, 36, 255)  # sıcak koyu kahve


def _line(draw, pts, width, color):
    draw.line(pts, fill=color, width=width, joint="curve")
    r = width / 2.0
    for p in (pts[0], pts[-1]):
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def chevron_down(w=64, h=64):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    _line(d, [(0.22 * w * SS, 0.36 * h * SS), (0.5 * w * SS, 0.64 * h * SS),
              (0.78 * w * SS, 0.36 * h * SS)], int(0.13 * h * SS), COLOR)
    return im.resize((w, h), Image.LANCZOS)


def updown(w=32, h=64):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    lw = int(0.16 * h * SS)
    # yukarı ok (üst yarım)
    _line(d, [(0.25 * w * SS, 0.36 * h * SS), (0.5 * w * SS, 0.12 * h * SS),
              (0.75 * w * SS, 0.36 * h * SS)], lw, COLOR)
    # aşağı ok (alt yarım)
    _line(d, [(0.25 * w * SS, 0.64 * h * SS), (0.5 * w * SS, 0.88 * h * SS),
              (0.75 * w * SS, 0.64 * h * SS)], lw, COLOR)
    return im.resize((w, h), Image.LANCZOS)


def main():
    out = os.path.abspath(OUT_DIR)
    os.makedirs(out, exist_ok=True)
    chevron_down().save(os.path.join(out, "chevron_down.png"))
    print("yazildi:", out)


if __name__ == "__main__":
    main()
