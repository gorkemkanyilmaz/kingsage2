import os
from PIL import Image, ImageFilter, ImageEnhance

src_dir = r"c:\Users\Gorkem\Desktop\kingsage2\game\assets\sprites\ui\nano_banana"
out_dir = r"c:\Users\Gorkem\Desktop\kingsage2\game\assets\sprites\ui\nano_banana"

icons_to_sharpen = [
    "icon_wood.png",
    "icon_stone.png",
    "icon_iron.png",
    "icon_storage.png",
    "icon_citizens.png",
    "icon_tab_village.png"
]

for icon_name in icons_to_sharpen:
    path = os.path.join(src_dir, icon_name)
    if not os.path.exists(path):
        continue
    im = Image.open(path).convert("RGBA")
    
    # Resize with high-quality LANCZOS to 64x64
    im.thumbnail((64, 64), Image.Resampling.LANCZOS)
    
    # Apply subtle sharpening so it is crisp and not blurry on mobile
    enhancer = ImageEnhance.Sharpness(im)
    sharpened = enhancer.enhance(1.8)
    
    # Also boost contrast slightly for maximum pop
    contrast = ImageEnhance.Contrast(sharpened)
    crisp = contrast.enhance(1.15)
    
    out_path = os.path.join(out_dir, "sharp_" + icon_name)
    crisp.save(out_path, "PNG")
    print(f"Generated sharp icon: {out_path} ({crisp.size})")

print("Sharp icon generation complete!")
