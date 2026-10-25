import os
from PIL import Image, ImageFilter, ImageEnhance

base_dir = r"game/assets/sprites/ui/nano_banana"
icons = [
    "icon_wood.png",
    "icon_stone.png",
    "icon_iron.png",
    "icon_citizens.png",
    "icon_storage.png",
    "icon_tab_village.png"
]

for icon_name in icons:
    src_path = os.path.join(base_dir, icon_name)
    if not os.path.exists(src_path):
        continue
    im = Image.open(src_path).convert("RGBA")
    
    # Auto-crop transparent boundaries so the icon uses full frame
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    
    # Scale to fit neatly within 256x256 with 8px inner margin for breathability
    target_canvas = 256
    margin = 8
    avail = target_canvas - (margin * 2)
    w, h = im.size
    scale = min(avail / w, avail / h)
    nw, nh = int(round(w * scale)), int(round(h * scale))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    
    # Place on 256x256 transparent canvas
    canvas = Image.new("RGBA", (target_canvas, target_canvas), (0, 0, 0, 0))
    paste_x = (target_canvas - nw) // 2
    paste_y = (target_canvas - nh) // 2
    canvas.paste(resized, (paste_x, paste_y), resized)
    
    # Apply crisp unsharp mask and contrast/color/brightness pop
    sharpened = canvas.filter(ImageFilter.UnsharpMask(radius=1.2, percent=150, threshold=1))
    enh_c = ImageEnhance.Contrast(sharpened).enhance(1.12)
    enh_s = ImageEnhance.Color(enh_c).enhance(1.10)
    
    # Stone and iron are naturally darker, give them a subtle brightness boost for clear visibility
    if "stone" in icon_name or "iron" in icon_name:
        enh_s = ImageEnhance.Brightness(enh_s).enhance(1.15)
    elif "wood" in icon_name:
        enh_s = ImageEnhance.Brightness(enh_s).enhance(1.06)
        
    out_path = os.path.join(base_dir, "sharp_" + icon_name)
    enh_s.save(out_path, "PNG", optimize=True)
    print(f"Generated sharp icon: {out_path} ({enh_s.size})")

print("Sharp icon generation finished successfully.")
