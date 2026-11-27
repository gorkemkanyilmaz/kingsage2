import os
import cv2
import numpy as np
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(BASE_DIR, "creative_assets")
SRC_PATH = os.path.join(OUT_DIR, "raw_key_art_16x9.jpg")


def _fit_center_crop(img_bgr: np.ndarray, target_w: int, target_h: int) -> np.ndarray:
    sh, sw = img_bgr.shape[:2]
    src_ar = sw / float(sh)
    tgt_ar = target_w / float(target_h)

    if abs(src_ar - tgt_ar) > 0.01:
        if src_ar > tgt_ar:
            # Source is wider -> crop width symmetrically around center
            new_w = int(round(sh * tgt_ar))
            x0 = max(0, (sw - new_w) // 2)
            img_bgr = img_bgr[:, x0 : x0 + new_w]
        else:
            # Source is taller (e.g., 16:9 -> 21:9) -> shift slightly upward so castle spires & knight helm stay clear
            new_h = int(round(sw / tgt_ar))
            y0 = max(0, int(round((sh - new_h) * 0.42)))
            img_bgr = img_bgr[y0 : y0 + new_h, :]

    up = cv2.resize(img_bgr, (target_w, target_h), interpolation=cv2.INTER_LANCZOS4)
    blur = cv2.GaussianBlur(up, (0, 0), 1.1)
    sharp = cv2.addWeighted(up, 1.16, blur, -0.16, 0)
    return sharp


def main() -> None:
    raw_bgr = cv2.imread(SRC_PATH, cv2.IMREAD_COLOR)
    assert raw_bgr is not None, f"Missing key art: {SRC_PATH}"

    specs = [
        ("creative_universal_5244x2950.png", 5244, 2950),
        ("header_3840x1646.png", 3840, 1646),
        ("search_result_3840x2560.png", 3840, 2560),
    ]
    for fname, w, h in specs:
        out_path = os.path.join(OUT_DIR, fname)
        comp = _fit_center_crop(raw_bgr, w, h)
        rgb = cv2.cvtColor(comp, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(rgb, "RGB")
        # Save as PNG without alpha channel; optimize=True keeps size clean
        pil_img.save(out_path, "PNG", optimize=True)
        size_mb = os.path.getsize(out_path) / (1024.0 * 1024.0)
        print(f"Generated {out_path} -> {pil_img.size} {pil_img.mode} ({size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
