import os
import numpy as np
from PIL import Image, ImageFilter

brain_dir = r"C:\Users\Gorkem\.gemini\antigravity-ide\brain\0147d47f-693a-48ac-83a7-b9b6f6fd075e"
out_dir = r"c:\Users\Gorkem\Desktop\kingsage2\game\assets\sprites\ui\nano_banana"
os.makedirs(out_dir, exist_ok=True)

files_map = {
    "btn_close_ornate": ("btn_close_ornate_1792425303765.jpg", "black"),
    "btn_upgrade_green": ("btn_upgrade_green_1792425324252.jpg", "black_rect"),
    "btn_upgrade_disabled": ("btn_disabled_clean_1792425362440.jpg", "black_rect"),
    "hud_header_bar": ("hud_header_bar_1792425402873.jpg", "black_rect"),
    "bottom_nav_dock": ("bottom_nav_dock_1792425425286.jpg", "black_rect"),
    "icon_wood": ("icon_wood_stack_1792425532327.jpg", "white"),
    "icon_stone": ("icon_stone_blocks_1792425555272.jpg", "black"),
    "icon_iron": ("icon_iron_ingots_1792425589667.jpg", "black"),
    "icon_citizens": ("icon_population_crest_1792425616751.jpg", "black"),
    "icon_storage": ("icon_storage_chest_1792425637601.jpg", "black"),
    "icon_tab_village": ("icon_tab_village_1792425666809.jpg", "black"),
    "panel_dialog_bg": ("panel_dialog_bg_1792425381550.jpg", "white_panel"),
}

def remove_background(im, bg_type="black", thresh=15):
    im = im.convert("RGBA")
    arr = np.array(im, dtype=np.float32)
    rgb = arr[:, :, :3]

    if bg_type == "black":
        # Calculate distance from black
        lum = np.max(rgb, axis=2)
        # Seeded flood fill or distance threshold
        # For icons on pure black background:
        alpha = np.clip((lum - thresh) / 20.0 * 255.0, 0, 255).astype(np.uint8)
        arr[:, :, 3] = alpha
    elif bg_type == "white":
        # Distance from white
        diff_from_white = 255.0 - np.min(rgb, axis=2)
        alpha = np.clip((diff_from_white - thresh) / 20.0 * 255.0, 0, 255).astype(np.uint8)
        arr[:, :, 3] = alpha
    elif bg_type == "black_rect":
        # Buttons / Rectangles: crop to bounding box where lum > thresh
        lum = np.max(rgb, axis=2)
        alpha = np.clip((lum - thresh) / 15.0 * 255.0, 0, 255).astype(np.uint8)
        arr[:, :, 3] = alpha
    elif bg_type == "white_panel":
        diff_from_white = 255.0 - np.min(rgb, axis=2)
        alpha = np.clip((diff_from_white - 10) / 15.0 * 255.0, 0, 255).astype(np.uint8)
        arr[:, :, 3] = alpha

    res_im = Image.fromarray(arr.astype(np.uint8), "RGBA")
    
    # Auto-crop bounding box based on alpha
    bbox = res_im.getbbox()
    if bbox:
        # Add small padding if possible
        res_im = res_im.crop(bbox)
        
    return res_im

for name, (src_file, bg_type) in files_map.items():
    src_path = os.path.join(brain_dir, src_file)
    if not os.path.exists(src_path):
        print(f"Skipping missing: {src_path}")
        continue
    im = Image.open(src_path)
    processed = remove_background(im, bg_type=bg_type)
    out_path = os.path.join(out_dir, f"{name}.png")
    processed.save(out_path, "PNG")
    print(f"Saved: {out_path} {processed.size}")

print("Processing complete!")
