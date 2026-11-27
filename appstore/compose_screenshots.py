import os
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(BASE_DIR)
FONTS_DIR = os.path.join(ROOT_DIR, "game", "assets", "fonts")
RAW_DIR = os.path.join(BASE_DIR, "raw")

OUT_69_TR = os.path.join(BASE_DIR, "screenshots_6_9")
OUT_LEGACY_TR = os.path.join(BASE_DIR, "screenshots")
OUT_69_EN = os.path.join(BASE_DIR, "screenshots_en")
for d in (OUT_69_TR, OUT_LEGACY_TR, OUT_69_EN):
    os.makedirs(d, exist_ok=True)

SLIDES = [
    {
        "file": "01_koy_ve_lord.png",
        "raw": "raw_01_village_lord_quests.png",
        "tag_tr": "7/24 GERÇEK ZAMANLI KÖY & GÖREVLER",
        "title_tr": ["KÖYÜNÜ KUR,", "KRALLIĞINI BÜYÜT"],
        "sub_tr": "Vezir görevlerini tamamla, binaları yükselt, 7/24 hammadde üret.",
        "tag_en": "24/7 PERSISTENT MEDIEVAL VILLAGE",
        "title_en": ["BUILD YOUR VILLAGE,", "RULE AN EMPIRE"],
        "sub_en": "Complete Vizier quests, upgrade buildings & produce offline 24/7.",
        "bg_top": (18, 12, 10),
        "bg_bot": (36, 22, 14),
        "glow": (195, 130, 52),
    },
    {
        "file": "02_lord_ve_ekipman.png",
        "raw": "raw_02_lord_equipment.png",
        "tag_tr": "13 SLOTLU KAHRAMAN LORD SİSTEMİ",
        "title_tr": ["LORDUNU KUŞAT,", "ORDUNU GÜÇLENDİR"],
        "sub_tr": "Kılıç, zırh, kalkan ve takılarla savaş gücünü anında katla.",
        "tag_en": "13-SLOT HERO LORD EQUIPMENT",
        "title_en": ["EQUIP YOUR LORD,", "BOOST EVERY ARMY"],
        "sub_en": "Unlock swords, shields, armor & relics to power up your troops.",
        "bg_top": (14, 12, 22),
        "bg_bot": (32, 22, 46),
        "glow": (160, 110, 215),
    },
    {
        "file": "03_ekipman_gelistirme.png",
        "raw": "raw_03_lord_upgrade_anvil.png",
        "tag_tr": "KRALİYET ÖRSÜ • +0'DAN +8'E BAS",
        "title_tr": ["ÖRS'TE GÜÇLENDİR,", "EFSANEYİ DÖV"],
        "sub_tr": "Parşömen kullan, nadir ekipmanlara +8 seviye bas ve parlat.",
        "tag_en": "ROYAL ANVIL • +0 TO +8 UPGRADES",
        "title_en": ["FORGE +8 GEAR", "AT THE ANVIL"],
        "sub_en": "Use upgrade scrolls to temper rare weapons and armor up to +8.",
        "bg_top": (22, 11, 10),
        "bg_bot": (52, 20, 14),
        "glow": (235, 118, 45),
    },
    {
        "file": "04_dunya_haritasi.png",
        "raw": "raw_04_world_map_bandits.png",
        "tag_tr": "ORTAK CANLI DÜNYA HARİTASI",
        "title_tr": ["HAYDUT AVLA,", "KÖYLERİ FETHET"],
        "sub_tr": "Sv.1–10 haydut kamplarına baskın at; koruma kalkanın bozulmasın.",
        "tag_en": "SHARED LIVE WORLD MAP",
        "title_en": ["RAID BANDITS ON", "ONE LIVE MAP"],
        "sub_en": "Plunder Lv.1–10 bandit strongholds without losing your starter shield.",
        "bg_top": (10, 18, 13),
        "bg_bot": (18, 40, 24),
        "glow": (86, 178, 110),
    },
    {
        "file": "05_kisla_ve_ordu.png",
        "raw": "raw_05_barracks_army.png",
        "tag_tr": "11 ORTA ÇAĞ ASKERİ BİRLİĞİ",
        "title_tr": ["ORDUNU EĞİT,", "KUŞATMAYA HAZIRLAN"],
        "sub_tr": "Piyade, Okçu, Süvari, Casus, Şahmerdan ve Kont ile zafere yürü.",
        "tag_en": "11 MEDIEVAL TROOP TYPES",
        "title_en": ["TRAIN 11 UNITS,", "LEAD THE SIEGE"],
        "sub_en": "Infantry, archers, cavalry, spies, rams, catapults & Counts.",
        "bg_top": (18, 13, 14),
        "bg_bot": (44, 24, 22),
        "glow": (212, 92, 74),
    },
    {
        "file": "06_ittifak_diplomasi.png",
        "raw": "raw_06_alliance_diplomacy.png",
        "tag_tr": "KLAN SAVAŞLARI & DİPLOMASİ",
        "title_tr": ["İTTİFAK KUR,", "DİPLOMASİ YÖNET"],
        "sub_tr": "Müttefik seç, düşman ilan et, katılma isteklerini tek tıkla onayla.",
        "tag_en": "ALLIANCE WARS & DIPLOMACY",
        "title_en": ["FORGE ALLIANCES,", "WAGE CLAN WARS"],
        "sub_en": "Declare allies or enemies, approve recruits & send reinforcements.",
        "bg_top": (12, 15, 24),
        "bg_bot": (22, 30, 54),
        "glow": (95, 148, 228),
    },
    {
        "file": "07_savas_ganimet.png",
        "raw": "raw_07_bandit_loot_report.png",
        "tag_tr": "YAĞMA & NADİR EKİPMAN GANİMETİ",
        "title_tr": ["SAVAŞ, YAĞMALA,", "NADİR EŞYA KAP!"],
        "sub_tr": "Haydut savaşlarını kazan, ganimet ve nadir Lord ekipmanları topla.",
        "tag_en": "VICTORY REPORTS & RARE DROPS",
        "title_en": ["WIN BATTLES,", "LOOT RARE GEAR"],
        "sub_en": "Analyze detailed combat reports and claim rare Lord equipment.",
        "bg_top": (20, 12, 22),
        "bg_bot": (48, 20, 44),
        "glow": (210, 120, 225),
    },
]


def _make_background(w: int, h: int, bg_top, bg_bot, glow) -> Image.Image:
    yy = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    top_arr = np.array(bg_top, dtype=np.float32).reshape(1, 1, 3)
    bot_arr = np.array(bg_bot, dtype=np.float32).reshape(1, 1, 3)
    grad = top_arr * (1.0 - yy ** 0.85) + bot_arr * (yy ** 0.85)

    # Warm radial glow behind top edge of the oversized phone
    y_grid, x_grid = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * 0.5, h * 0.25
    dx = (x_grid - cx) / (w * 0.62)
    dy = (y_grid - cy) / (h * 0.24)
    rad = np.exp(-(dx * dx + dy * dy) * 1.45)[:, :, None]
    glow_arr = np.array(glow, dtype=np.float32).reshape(1, 1, 3)
    img_arr = np.clip(grad + rad * glow_arr * 0.28, 0, 255).astype(np.uint8)
    return Image.fromarray(img_arr, "RGB").convert("RGBA")


def _fit_text(draw: ImageDraw.ImageDraw, text: str, font_path: str, max_w: int, start_size: int, min_size: int = 24) -> ImageFont.FreeTypeFont:
    sz = start_size
    while sz >= min_size:
        f = ImageFont.truetype(font_path, sz)
        bbox = draw.textbbox((0, 0), text, font=f)
        if (bbox[2] - bbox[0]) <= max_w:
            return f
        sz -= 2
    return ImageFont.truetype(font_path, min_size)


def _draw_dynamic_island_and_status(screen_img: Image.Image, w: int) -> None:
    d = ImageDraw.Draw(screen_img)
    s = w / 1120.0
    status_h = int(round(88 * s))

    # Solid top obsidian safe strip matching ResourceBar dark frame
    d.rectangle([0, 0, w, status_h], fill=(16, 13, 19, 255))

    # Dynamic Island pill
    di_w = int(round(290 * s))
    di_h = int(round(58 * s))
    di_x0 = (w - di_w) // 2
    di_y0 = int(round(16 * s))
    d.rounded_rectangle([di_x0, di_y0, di_x0 + di_w, di_y0 + di_h], radius=di_h // 2, fill=(4, 4, 6, 255))
    # Subtle camera lens highlight
    lens_r = int(round(10 * s))
    lx = di_x0 + di_w - int(round(44 * s))
    ly = di_y0 + di_h // 2
    d.ellipse([lx - lens_r, ly - lens_r, lx + lens_r, ly + lens_r], fill=(18, 24, 38, 255))

    # Clock on left
    f_clock = ImageFont.truetype(os.path.join(FONTS_DIR, "Nunito-Bold.ttf"), int(round(34 * s)))
    d.text((int(round(124 * s)), di_y0 + di_h // 2), "22:30", font=f_clock, fill=(244, 242, 248, 255), anchor="mm")

    # Signal bars + Battery on right
    rx = w - int(round(215 * s))
    ry = di_y0 + int(round(18 * s))
    for i, bh in enumerate([9, 13, 17, 22]):
        bx = rx + int(round(i * 11 * s))
        bw = int(round(7 * s))
        bhh = int(round(bh * s))
        full_h = int(round(22 * s))
        d.rounded_rectangle([bx, ry + full_h - bhh, bx + bw, ry + full_h], radius=2, fill=(244, 242, 248, 255))
    bat_x = rx + int(round(58 * s))
    bat_w = int(round(46 * s))
    bat_h = int(round(22 * s))
    d.rounded_rectangle([bat_x, ry, bat_x + bat_w, ry + bat_h], radius=int(round(6 * s)), outline=(225, 225, 232, 255), width=max(2, int(round(2.5 * s))))
    d.rounded_rectangle([bat_x + 4, ry + 4, bat_x + bat_w - 6, ry + bat_h - 4], radius=3, fill=(244, 242, 248, 255))
    d.rectangle([bat_x + bat_w + 2, ry + int(round(7 * s)), bat_x + bat_w + 5, ry + bat_h - int(round(7 * s))], fill=(210, 210, 220, 255))


def _rounded_mask(w: int, h: int, radius: int) -> Image.Image:
    # Supersampled 2x rounded rectangle alpha mask for crisp anti-aliasing
    mw, mh, mr = w * 2, h * 2, radius * 2
    mask = Image.new("L", (mw, mh), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, mw - 1, mh - 1], radius=mr, fill=255)
    return mask.resize((w, h), Image.Resampling.LANCZOS)


def compose_one(slide: dict, w: int, h: int, lang: str, out_dir: str) -> str:
    raw_path = os.path.join(RAW_DIR, slide["raw"])
    raw_bgr = cv2.imread(raw_path, cv2.IMREAD_COLOR)
    assert raw_bgr is not None, f"Missing raw screenshot: {raw_path}"

    canvas = _make_background(w, h, slide["bg_top"], slide["bg_bot"], slide["glow"])
    s = w / 1320.0

    # --- Top Marketing Typography (Compact ~18% height so the phone is HUGE!) ---
    draw = ImageDraw.Draw(canvas)
    tag_text = slide[f"tag_{lang}"]
    title_lines = slide[f"title_{lang}"]
    sub_text = slide[f"sub_{lang}"]

    font_tag = ImageFont.truetype(os.path.join(FONTS_DIR, "Nunito-Bold.ttf"), int(round(26 * s)))
    tb = draw.textbbox((0, 0), tag_text, font=font_tag)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    pad_x, pad_y = int(round(28 * s)), int(round(11 * s))
    pill_x0 = (w - (tw + pad_x * 2)) // 2
    pill_y0 = int(round(62 * s))
    draw.rounded_rectangle(
        [pill_x0, pill_y0, pill_x0 + tw + pad_x * 2, pill_y0 + th + pad_y * 2],
        radius=int(round(24 * s)),
        fill=(28, 20, 18, 225),
        outline=(226, 182, 92, 225),
        width=max(2, int(round(3 * s))),
    )
    draw.text((w // 2, pill_y0 + pad_y + th // 2 - 1), tag_text, font=font_tag, fill=(248, 214, 128, 255), anchor="mm")

    y_cur = int(round(138 * s))
    cinzel_path = os.path.join(FONTS_DIR, "Cinzel-Bold.ttf")
    for idx, line in enumerate(title_lines):
        f_title = _fit_text(draw, line, cinzel_path, int(round(w * 0.90)), int(round(88 * s)), int(round(56 * s)))
        fill_col = (255, 224, 134, 255) if idx == 0 else (252, 248, 240, 255)
        draw.text((w // 2 + int(round(3 * s)), y_cur + int(round(4 * s))), line, font=f_title, fill=(0, 0, 0, 210), anchor="mt")
        draw.text((w // 2, y_cur), line, font=f_title, fill=fill_col, anchor="mt")
        y_cur += int(round(98 * s))

    sub_font_path = os.path.join(FONTS_DIR, "Nunito-SemiBold.ttf")
    f_sub = _fit_text(draw, sub_text, sub_font_path, int(round(w * 0.90)), int(round(33 * s)), int(round(24 * s)))
    sub_y = y_cur + int(round(14 * s))
    draw.text((w // 2 + 2, sub_y + 2), sub_text, font=f_sub, fill=(0, 0, 0, 195), anchor="mt")
    draw.text((w // 2, sub_y), sub_text, font=f_sub, fill=(230, 224, 214, 245), anchor="mt")

    # --- Oversized iPhone Chassis (~84.5% of width, showing full screen including BottomNav!) ---
    phone_w = int(round(1116 * s))
    phone_x = (w - phone_w) // 2
    phone_y = int(round(430 * s))
    bezel = int(round(20 * s))
    screen_w = phone_w - bezel * 2
    outer_radius = int(round(116 * s))
    inner_radius = outer_radius - bezel

    # Prepare razor-sharp upscaled game screen + slim iPhone Dynamic Island header
    gh, gw = raw_bgr.shape[:2]
    status_top_h = int(round(82 * (screen_w / 1120.0)))
    game_h = int(round(gh * (screen_w / float(gw))))
    up = cv2.resize(raw_bgr, (screen_w, game_h), interpolation=cv2.INTER_LANCZOS4)
    blur = cv2.GaussianBlur(up, (0, 0), 1.0)
    up = cv2.addWeighted(up, 1.18, blur, -0.18, 0)
    up_rgb = cv2.cvtColor(up, cv2.COLOR_BGR2RGB)

    screen_h = max(h - phone_y + int(round(30 * s)), status_top_h + game_h + int(round(16 * s)))
    phone_h = screen_h + bezel * 2

    screen_rgba = Image.new("RGBA", (screen_w, screen_h), (16, 13, 19, 255))
    screen_rgba.paste(Image.fromarray(up_rgb, "RGB").convert("RGBA"), (0, status_top_h))
    _draw_dynamic_island_and_status(screen_rgba, screen_w)

    # Bottom safe-bar tint if screen extends slightly below raw height
    bot_start = status_top_h + game_h
    if bot_start < screen_h:
        sd = ImageDraw.Draw(screen_rgba)
        sd.rectangle([0, bot_start, screen_w, screen_h], fill=(22, 16, 14, 255))

    # Drop shadow behind phone frame
    shadow_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh_d = ImageDraw.Draw(shadow_layer)
    sh_pad = int(round(18 * s))
    sh_d.rounded_rectangle(
        [phone_x - sh_pad, phone_y - sh_pad // 2, phone_x + phone_w + sh_pad, phone_y + phone_h],
        radius=outer_radius + sh_pad,
        fill=(0, 0, 0, 140),
    )
    from PIL import ImageFilter
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(int(round(28 * s))))
    canvas = Image.alpha_composite(canvas, shadow_layer)

    # Draw crisp dark titanium metallic outer chassis + black bezel
    chassis = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chassis)
    # Outer metallic titanium ring
    cd.rounded_rectangle([0, 0, phone_w - 1, phone_h - 1], radius=outer_radius, fill=(48, 44, 42, 255), outline=(146, 128, 96, 235), width=max(2, int(round(4 * s))))
    # Inner dark bezel body
    ring_w = int(round(7 * s))
    cd.rounded_rectangle([ring_w, ring_w, phone_w - 1 - ring_w, phone_h - 1 - ring_w], radius=outer_radius - ring_w, fill=(10, 10, 12, 255), outline=(72, 66, 62, 220), width=max(2, int(round(2 * s))))

    screen_mask = _rounded_mask(screen_w, screen_h, inner_radius)
    chassis.paste(screen_rgba, (bezel, bezel), screen_mask)

    # Paste cropped-bottom chassis onto main canvas cleanly
    visible_h = h - phone_y
    if visible_h > 0:
        crop_ch = chassis.crop((0, 0, phone_w, min(phone_h, visible_h)))
        canvas.paste(crop_ch, (phone_x, phone_y), crop_ch)

    out_path = os.path.join(out_dir, slide["file"])
    final_rgb = canvas.convert("RGB")
    final_rgb.save(out_path, "PNG", optimize=True)
    print(f"Generated {out_path} ({final_rgb.size}, screen_w={screen_w}px at y={phone_y})")
    return out_path


if __name__ == "__main__":
    for sl in SLIDES:
        compose_one(sl, 1320, 2868, "tr", OUT_69_TR)
        compose_one(sl, 1290, 2796, "tr", OUT_LEGACY_TR)
        compose_one(sl, 1320, 2868, "en", OUT_69_EN)
