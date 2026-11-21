import os
from collections import deque
from PIL import Image

BRAIN_DIR = r"C:\Users\Gorkem\.gemini\antigravity\brain\9410c4be-d8ee-495d-ad94-e06026c63fb2"
OUT_DIR = os.path.join("game", "assets", "sprites", "ui", "nano_banana")
os.makedirs(OUT_DIR, exist_ok=True)

SQUARE_ASSETS = [
    ("royal_castle_keep_icon_1795258868781.jpg", "sharp_icon_castle_crest", "Image_cstl1"),
    ("heraldic_shield_icon_blackbg_1795258886913.jpg", "sharp_icon_alliance_shield", "Image_ally1"),
    ("master_mason_scroll_icon_v2_1795258894907.jpg", "sharp_scroll_build", "Image_scb1"),
    ("military_scroll_icon_v2_1795258894297.jpg", "sharp_scroll_train", "Image_sct1"),
    ("alchemy_scroll_icon_1795258899123.jpg", "sharp_scroll_research", "Image_scr1"),
    ("warhorse_scroll_icon_1795258903705.jpg", "sharp_scroll_march", "Image_scm1"),
    ("royal_sapphire_treasure_chest_icon_1795258906611.jpg", "sharp_pack_diamond_chest", "Image_dch1"),
    ("royal_supply_crate_icon_1795258907383.jpg", "sharp_pack_resource_caravan", "Image_rsc1"),
    ("royal_decree_seal_1794688841903.jpg", "sharp_icon_report_seal", "Image_rps1"),
]


def write_tres(img_rgba: Image.Image, out_name: str, sub_id: str) -> None:
    png_path = os.path.join(OUT_DIR, f"{out_name}.png")
    img_rgba.save(png_path, "PNG")
    w, h = img_rgba.size
    raw = img_rgba.tobytes()
    byte_str = ", ".join(str(b) for b in raw)
    tres_lines = [
        '[gd_resource type="ImageTexture" format=3]',
        "",
        f'[sub_resource type="Image" id="{sub_id}"]',
        "data = {",
        f'"data": PackedByteArray({byte_str}),',
        '"format": "RGBA8",',
        f'"height": {h},',
        '"mipmaps": false,',
        f'"width": {w}',
        "}",
        "",
        "[resource]",
        f'image = SubResource("{sub_id}")',
        "",
    ]
    tres_path = os.path.join(OUT_DIR, f"{out_name}.tres")
    with open(tres_path, "w", encoding="utf-8") as f:
        f.write("\n".join(tres_lines))
    print(f"Wrote {out_name}: {w}x{h} ({len(raw)} bytes) -> {tres_path}")


def convert_square_icon(src_file: str, out_name: str, sub_id: str) -> None:
    src_path = os.path.join(BRAIN_DIR, src_file)
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    px = img.load()
    bg_samples = [px[0, 0][:3], px[w - 1, 0][:3], px[0, h - 1][:3], px[w - 1, h - 1][:3]]
    bg_r = sum(c[0] for c in bg_samples) // 4
    bg_g = sum(c[1] for c in bg_samples) // 4
    bg_b = sum(c[2] for c in bg_samples) // 4

    visited = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))

    # Flood fill only pure/near-pure background so dark interior shadows (e.g. castle gate) stay opaque
    while q:
        cx, cy = q.popleft()
        if cx < 0 or cx >= w or cy < 0 or cy >= h or visited[cy][cx]:
            continue
        r, g, b, _a = px[cx, cy]
        dist = ((r - bg_r) ** 2 + (g - bg_g) ** 2 + (b - bg_b) ** 2) ** 0.5
        if dist <= 20.0:
            visited[cy][cx] = True
            px[cx, cy] = (0, 0, 0, 0)
            for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                    q.append((nx, ny))
        elif dist <= 64.0:
            visited[cy][cx] = True
            t = (dist - 20.0) / 44.0
            alpha = int((t * t) * 255.0)
            px[cx, cy] = (r, g, b, max(0, min(255, alpha)))

    bbox = img.getbbox()
    if bbox:
        pad = 10
        x0 = max(0, bbox[0] - pad)
        y0 = max(0, bbox[1] - pad)
        x1 = min(w, bbox[2] + pad)
        y1 = min(h, bbox[3] + pad)
        bw, bh = x1 - x0, y1 - y0
        side = max(bw, bh)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        cropped = img.crop((x0, y0, x1, y1))
        sq.paste(cropped, ((side - bw) // 2, (side - bh) // 2))
        img = sq

    img_256 = img.resize((256, 256), Image.Resampling.LANCZOS)
    write_tres(img_256, out_name, sub_id)


def convert_button_frame(src_file: str, out_name: str, sub_id: str) -> None:
    src_path = os.path.join(BRAIN_DIR, src_file)
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    px = img.load()
    bg = px[0, 0][:3]
    visited = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        cx, cy = q.popleft()
        if cx < 0 or cx >= w or cy < 0 or cy >= h or visited[cy][cx]:
            continue
        r, g, b, _a = px[cx, cy]
        dist = ((r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2) ** 0.5
        if dist <= 18.0:
            visited[cy][cx] = True
            px[cx, cy] = (0, 0, 0, 0)
            for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                    q.append((nx, ny))
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img_btn = img.resize((512, 128), Image.Resampling.LANCZOS)
    write_tres(img_btn, out_name, sub_id)


if __name__ == "__main__":
    for src_f, out_n, sid in SQUARE_ASSETS:
        convert_square_icon(src_f, out_n, sid)
    convert_button_frame("medieval_ui_button_frame_1795258879923.jpg", "sharp_ui_royal_btn_bg", "Image_rbtn1")
