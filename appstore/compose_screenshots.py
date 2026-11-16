import os
import math
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2796
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(BASE_DIR)
FONTS_DIR = os.path.join(ROOT_DIR, "game", "assets", "fonts")
ARTIFACTS_DIR = r"C:\Users\Gorkem\.gemini\antigravity\brain\9410c4be-d8ee-495d-ad94-e06026c63fb2"
OUT_DIR = os.path.join(BASE_DIR, "screenshots")
os.makedirs(OUT_DIR, exist_ok=True)

ITEMS = [
    {
        "out": "01_koy_ve_gorevler.png",
        "mockup": os.path.join(ARTIFACTS_DIR, "hand_mockup_01_1794770854888.jpg"),
        "game_shot": os.path.join(BASE_DIR, "raw", "raw_01_village_quests.png"),
        "tag": "ORTA ÇAĞ KRALLIK STRATEJİSİ",
        "title": ["KRALLIĞINI KUR,", "KÖYÜNÜ YÖNET"],
        "subtitle": "Vezir görevlerini tamamla, binalarını yükselt\nve kaynaklarını stratejik biçimde büyüt.",
        "zoom": 1.16,
        "phone_y_shift": 180,
        "top_tint": (18, 12, 10),
    },
    {
        "out": "02_kisla_ve_ordu.png",
        "mockup": os.path.join(ARTIFACTS_DIR, "hand_mockup_02_v2_1794770923040.jpg"),
        "game_shot": os.path.join(BASE_DIR, "raw", "raw_02_barracks_train.png"),
        "tag": "GERÇEK ZAMANLI ORDU EĞİTİMİ",
        "title": ["YENİLMEZ BİR", "ORDU EĞİT"],
        "subtitle": "Silahtar, Baltacı, Okçu, Şövalye ve Casus\nbirliklerini araştır, kuşatmaya hazırlan.",
        "zoom": 1.14,
        "phone_y_shift": 360,
        "top_tint": (16, 12, 14),
    },
    {
        "out": "03_dunya_haritasi.png",
        "mockup": os.path.join(ARTIFACTS_DIR, "hand_mockup_03_v2_1794770903212.jpg"),
        "game_shot": os.path.join(BASE_DIR, "raw", "raw_03_world_map.png"),
        "tag": "ORTAK ÇEVRİMİÇİ DÜNYA",
        "title": ["CANLI DÜNYA", "HARİTASI"],
        "subtitle": "Binlerce oyuncuyla aynı haritada buluş,\ncasus gönder ve gerçek zamanlı akın düzenle.",
        "zoom": 1.24,
        "phone_y_shift": 160,
        "top_tint": (12, 15, 13),
    },
    {
        "out": "04_fetih_ve_zafer.png",
        "mockup": os.path.join(ARTIFACTS_DIR, "hand_mockup_04_1794770870691.jpg"),
        "game_shot": os.path.join(BASE_DIR, "raw", "raw_05_reports_detail.png"),
        "tag": "KONT & KÖY FETHİ SİSTEMİ",
        "title": ["KONT GÖNDER,", "KÖY FETHET!"],
        "subtitle": "Düşman kalelerinin sadakatini kır,\nganimet topla ve imparatorluğunu genişlet.",
        "zoom": 1.18,
        "phone_y_shift": 240,
        "top_tint": (22, 10, 14),
    },
]


def order_quad(pts: np.ndarray) -> np.ndarray:
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # TL
    rect[2] = pts[np.argmax(s)]  # BR
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # TR
    rect[3] = pts[np.argmax(diff)]  # BL
    return rect


def build_phone_display_image(game_path: str, target_aspect_h_over_w: float) -> np.ndarray:
    """Loads crisp Godot capture, upscales cleanly, and adds authentic slim iPhone Dynamic Island status bar."""
    raw = cv2.imread(game_path, cv2.IMREAD_COLOR)
    assert raw is not None, f"Missing {game_path}"
    gh, gw = raw.shape[:2]

    # Upscale cleanly for razor-sharp UI inside iPhone frame
    up_w = 1350
    up_h = int(round(gh * (up_w / gw)))
    up = cv2.resize(raw, (up_w, up_h), interpolation=cv2.INTER_LANCZOS4)

    # Subtle micro-sharpening so tiny Turkish UI text stays tack-sharp inside mockup
    blur = cv2.GaussianBlur(up, (0, 0), 0.9)
    up = cv2.addWeighted(up, 1.15, blur, -0.15, 0)

    # Exact aspect ratio match with tiny slim iPhone safe-area status bar at top + home pill at bottom
    total_h = max(up_h + 132, int(round(up_w * target_aspect_h_over_w)))
    bar_h = total_h - up_h
    top_bar_h = int(min(130, max(96, bar_h * 0.72)))
    # Fit game image seamlessly into remaining screen height (minor ~1-3% aspect fit if needed)
    game_target_h = total_h - top_bar_h - 36
    if abs(game_target_h - up_h) > 6:
        up = cv2.resize(up, (up_w, game_target_h), interpolation=cv2.INTER_LANCZOS4)
        up_h = game_target_h
    bot_bar_h = total_h - up_h - top_bar_h

    canvas = np.zeros((total_h, up_w, 3), dtype=np.uint8)
    canvas[:, :] = (20, 15, 19)  # BGR dark obsidian matching game top HUD
    canvas[top_bar_h:top_bar_h + up_h, :] = up

    # Draw authentic slim iPhone status bar (clock left beside Dynamic Island, signal/battery right) + home bar
    pil_c = Image.fromarray(cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB))
    d = ImageDraw.Draw(pil_c)
    f_status = ImageFont.truetype(os.path.join(FONTS_DIR, "Nunito-Bold.ttf"), 40)
    status_y = int(top_bar_h * 0.44)
    d.text((int(up_w * 0.145), status_y), "22:30", font=f_status, fill=(242, 240, 245), anchor="mm")

    # Signal bars & battery outline on right side beside Dynamic Island
    rx = int(up_w * 0.76)
    ry = status_y - 12
    for idx, bh in enumerate([10, 15, 20, 25]):
        bx = rx + idx * 12
        d.rounded_rectangle([bx, ry + (25 - bh), bx + 8, ry + 25], radius=2, fill=(242, 240, 245))
    bat_x = rx + 62
    d.rounded_rectangle([bat_x, ry + 1, bat_x + 50, ry + 25], radius=6, outline=(220, 220, 228), width=3)
    d.rounded_rectangle([bat_x + 4, ry + 5, bat_x + 42, ry + 21], radius=3, fill=(242, 240, 245))
    d.rectangle([bat_x + 52, ry + 9, bat_x + 55, ry + 17], fill=(200, 200, 210))

    # Home indicator pill at bottom
    if bot_bar_h >= 20:
        hy = total_h - int(bot_bar_h * 0.45)
        d.rounded_rectangle([int(up_w * 0.34), hy - 5, int(up_w * 0.66), hy + 5], radius=5, fill=(215, 210, 224))

    return cv2.cvtColor(np.array(pil_c), cv2.COLOR_RGB2BGR)


def find_green_mask_and_quad(bg_bgr: np.ndarray):
    hsv = cv2.cvtColor(bg_bgr, cv2.COLOR_BGR2HSV)
    # Main bright green screen region
    mask = cv2.inRange(hsv, (36, 95, 95), (86, 255, 255))
    # Keep only largest connected component (the iPhone screen)
    num_lbl, labels, stats, _ = cv2.connectedComponentsWithStats(mask)
    if num_lbl <= 1:
        raise RuntimeError("No green screen found in mockup!")
    best_lbl = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    clean_mask = np.where(labels == best_lbl, 255, 0).astype(np.uint8)

    # Tight minAreaRect on the green screen contour gives exact rotated rectangle corners
    contours, _ = cv2.findContours(clean_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    big_cnt = max(contours, key=cv2.contourArea)
    rect = cv2.minAreaRect(big_cnt)
    box = cv2.boxPoints(rect)
    quad = order_quad(box)

    # Expand quad outward slightly by 2px so no green anti-alias ring appears inside edges
    center = quad.mean(axis=0)
    dirs = quad - center
    norms = np.linalg.norm(dirs, axis=1, keepdims=True)
    quad_expanded = quad + (dirs / np.maximum(norms, 1e-6)) * 2.5

    # Also build soft edge-despilled mask covering anti-aliased fringe around screen & Dynamic Island
    dilated = cv2.dilate(clean_mask, np.ones((5, 5), np.uint8), iterations=1)
    # Only include dilated border pixels if they actually lean green in RGB (G > R and G > B)
    b, g, r = cv2.split(bg_bgr)
    green_tint = ((g.astype(np.int16) - np.maximum(r, b).astype(np.int16)) > 12).astype(np.uint8) * 255
    mask_final = np.maximum(clean_mask, cv2.bitwise_and(dilated, green_tint))
    alpha = cv2.GaussianBlur(mask_final.astype(np.float32) / 255.0, (3, 3), 0.7)
    return quad_expanded, alpha


def composite_item(cfg: dict) -> str:
    mockup_bgr = cv2.imread(cfg["mockup"], cv2.IMREAD_COLOR)
    assert mockup_bgr is not None, f"Missing mockup: {cfg['mockup']}"
    mh, mw = mockup_bgr.shape[:2]

    # Zoom slightly around horizontal center so phone is prominent yet hands remain authentic
    zoom = cfg["zoom"]
    scale = (W / mw) * zoom
    nw, nh = int(round(mw * scale)), int(round(mh * scale))
    resized = cv2.resize(mockup_bgr, (nw, nh), interpolation=cv2.INTER_LANCZOS4)

    # Crop horizontally to W=1290
    x0 = max(0, (nw - W) // 2)
    cropped = resized[:, x0:x0 + W]
    ch, cw = cropped.shape[:2]

    # Create full 1290x2796 base canvas by extending top blurred color smoothly
    canvas = np.zeros((H, W, 3), dtype=np.uint8)
    y_place = H - ch + cfg["phone_y_shift"]
    if y_place > 0:
        # Fill upper space with smooth top-edge sample gradient to tint color
        top_strip = cropped[:24, :, :]
        avg_top = np.median(top_strip.reshape(-1, 3), axis=0)
        tint_bgr = np.array([cfg["top_tint"][2], cfg["top_tint"][1], cfg["top_tint"][0]], dtype=np.float32)
        for yy in range(y_place):
            t = yy / max(1, y_place)
            col = tint_bgr * (1.0 - t) + avg_top * t
            canvas[yy, :, :] = np.clip(col, 0, 255).astype(np.uint8)
        avail_h = min(ch, H - y_place)
        canvas[y_place:y_place + avail_h, :] = cropped[:avail_h, :]
        # Soft blend seam around y_place
        seam_h = min(140, y_place)
        for dy in range(-seam_h // 2, seam_h // 2):
            yy = y_place + dy
            if 0 <= yy < H and yy - y_place < avail_h:
                t = (dy + seam_h / 2) / max(1, seam_h)
                row_ext = tint_bgr * (1.0 - t * 0.7) + avg_top * (t * 0.7)
                canvas[yy] = np.clip(row_ext * (1.0 - t) + canvas[yy].astype(np.float32) * t, 0, 255).astype(np.uint8)
    else:
        src_y0 = -y_place
        canvas[:, :] = cropped[src_y0:src_y0 + H, :]

    # Detect screen quad + alpha on the positioned mockup canvas
    quad, screen_alpha = find_green_mask_and_quad(canvas)
    screen_w = np.linalg.norm(quad[1] - quad[0])
    screen_h = np.linalg.norm(quad[3] - quad[0])
    aspect = float(screen_h / max(1.0, screen_w))

    game_bgr = build_phone_display_image(cfg["game_shot"], aspect)
    gh, gw = game_bgr.shape[:2]
    src_quad = np.array([[0, 0], [gw - 1, 0], [gw - 1, gh - 1], [0, gh - 1]], dtype=np.float32)
    M = cv2.getPerspectiveTransform(src_quad, quad)
    warped_game = cv2.warpPerspective(game_bgr, M, (W, H), flags=cv2.INTER_LANCZOS4)

    # Subtle realistic diagonal OLED screen glass sheen (very faint 3.5% top-left highlight)
    yy_grid, xx_grid = np.mgrid[0:H, 0:W].astype(np.float32)
    sheen = np.clip(1.0 - ((xx_grid / W) * 0.7 + (yy_grid / H) * 0.9), 0.0, 1.0) ** 2.4
    warped_sheen = np.clip(warped_game.astype(np.float32) + sheen[:, :, None] * 14.0, 0, 255).astype(np.uint8)

    # Composite warped genuine game UI into phone screen mask (preserving Dynamic Island & hands!)
    a3 = screen_alpha[:, :, None]
    comp_bgr = (warped_sheen.astype(np.float32) * a3 + canvas.astype(np.float32) * (1.0 - a3)).astype(np.uint8)

    # Despill any remaining 1px green fringe right outside screen edge (never touching hands/UI)
    edge_band = np.clip(cv2.dilate(screen_alpha, np.ones((7, 7), np.uint8)) - screen_alpha, 0.0, 1.0)
    b, g, r = cv2.split(comp_bgr)
    max_rb = np.maximum(r, b)
    despill_g = np.where((edge_band > 0.05) & (g > max_rb), max_rb, g)
    comp_bgr = cv2.merge([b, despill_g.astype(np.uint8), r])

    # Switch to PIL RGB for crisp golden medieval App Store typography header
    pil_img = Image.fromarray(cv2.cvtColor(comp_bgr, cv2.COLOR_BGR2RGB)).convert("RGBA")

    # Atmospheric dark gradient scrim behind top typography (top 950px, fading cleanly to zero)
    scrim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    scrim_arr = np.zeros((H, W, 4), dtype=np.uint8)
    tint_r, tint_g, tint_b = cfg["top_tint"]
    for yy in range(960):
        # Smooth ease-out curve
        p = yy / 960.0
        alpha_val = int(round(230 * (1.0 - p) ** 1.35))
        scrim_arr[yy, :, 0] = tint_r
        scrim_arr[yy, :, 1] = tint_g
        scrim_arr[yy, :, 2] = tint_b
        scrim_arr[yy, :, 3] = alpha_val
    scrim = Image.fromarray(scrim_arr, "RGBA")
    pil_img = Image.alpha_composite(pil_img, scrim)

    draw = ImageDraw.Draw(pil_img)
    font_tag = ImageFont.truetype(os.path.join(FONTS_DIR, "Nunito-Bold.ttf"), 30)
    font_title = ImageFont.truetype(os.path.join(FONTS_DIR, "Cinzel-Bold.ttf"), 92)
    font_sub = ImageFont.truetype(os.path.join(FONTS_DIR, "Nunito-SemiBold.ttf"), 38)

    # Gold pill tag at top
    tag_text = cfg["tag"]
    tb = draw.textbbox((0, 0), tag_text, font=font_tag)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    pad_x, pad_y = 34, 14
    pill_x0 = (W - (tw + pad_x * 2)) // 2
    pill_y0 = 128
    draw.rounded_rectangle(
        [pill_x0, pill_y0, pill_x0 + tw + pad_x * 2, pill_y0 + th + pad_y * 2],
        radius=28,
        fill=(32, 24, 22, 220),
        outline=(212, 170, 82, 210),
        width=3,
    )
    draw.text((W // 2, pill_y0 + pad_y + th // 2 - 2), tag_text, font=font_tag, fill=(244, 210, 128, 255), anchor="mm")

    # Main 2-line royal gold-ivory title with soft drop shadow
    y_cursor = 236
    for idx, line in enumerate(cfg["title"]):
        fill_col = (255, 226, 145, 255) if idx == 0 else (252, 248, 240, 255)
        draw.text((W // 2 + 4, y_cursor + 5), line, font=font_title, fill=(0, 0, 0, 200), anchor="mt")
        draw.text((W // 2, y_cursor), line, font=font_title, fill=fill_col, anchor="mt")
        y_cursor += 108

    # Subtle ornamental gold divider
    div_y = y_cursor + 24
    draw.line([(W // 2 - 190, div_y), (W // 2 + 190, div_y)], fill=(214, 172, 86, 180), width=3)
    draw.polygon([(W // 2, div_y - 8), (W // 2 + 10, div_y), (W // 2, div_y + 8), (W // 2 - 10, div_y)], fill=(246, 214, 130, 240))

    # Crisp 2-line subtitle
    sub_y = div_y + 34
    for sub_line in cfg["subtitle"].split("\n"):
        draw.text((W // 2 + 2, sub_y + 3), sub_line, font=font_sub, fill=(0, 0, 0, 190), anchor="mt")
        draw.text((W // 2, sub_y), sub_line, font=font_sub, fill=(224, 218, 206, 245), anchor="mt")
        sub_y += 52

    out_path = os.path.join(OUT_DIR, cfg["out"])
    final_rgb = pil_img.convert("RGB")
    final_rgb.save(out_path, "PNG", optimize=True)
    print(f"Generated {out_path} ({final_rgb.size}, screen={int(screen_w)}x{int(screen_h)} at y~{int(quad[0][1])})")
    return out_path


if __name__ == "__main__":
    for item in ITEMS:
        composite_item(item)
