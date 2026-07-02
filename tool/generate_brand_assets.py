#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""توليد أصول هوية تطبيق Mofradati من الصور الأصلية المعتمدة.

المصدر (لا يُشحن مع التطبيق، فقط مدخل لهذا السكربت):
  - tool/source/mofradati_app_icon.png   تصميم أيقونة التطبيق (مربع بخلفية
    بيضاء حول الشكل الدائري الأزرق — نقصّ الحواف البيضاء آلياً فنحصل على
    أيقونة تملأ الإطار بالكامل كما يشترط متجرا التطبيقات).
  - tool/source/vp_logo.png              شعار مؤسسة VP Developer الرسمي.

يولّد:
  - assets/icon/app_icon.png            الأيقونة الرئيسية 1024×1024 (مصمتة، بلا حواف بيضاء)
  - assets/images/vp_logo.png           نسخة من شعار المؤسسة (تُعرض في تذييل السبلاش)
  - android/app/src/main/res/mipmap-*/ic_launcher.png   (5 مقاسات، زوايا دائرية)
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png (كل المقاسات، مصمتة كما
    تشترط Apple — النظام يقصّ الزوايا بنفسه)

التشغيل:  pip install Pillow  ثم  python3 tool/generate_brand_assets.py
"""

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "tool", "source")
CANVAS = 1024


def load_app_icon_master() -> Image.Image:
    """يقرأ تصميم الأيقونة الأصلي، يقصّ الحواف البيضاء المحيطة بالشكل
    (padding التصدير من أداة التصميم)، ثم يكبّر المحتوى ليملأ إطار
    1024×1024 بالكامل (full-bleed) — الشكل المدوّر نفسه مرسوم داخل
    التصميم، والنظام (Android/iOS) يضيف قصّه الخاص فوق ذلك.
    """
    img = Image.open(os.path.join(SOURCE, "mofradati_app_icon.png")).convert("RGB")

    # نبحث عن حدود الشكل الملوّن الحقيقي عبر لون واضح التمايز عن الخلفية
    # (وليس "أي اختلاف عن أبيض صرف" — حواف التصدير تحمل تدرّجاً رمادياً
    # خفيفاً جداً يغطي الإطار كله ويُفسد أي عتبة بسيطة).
    px = img.load()
    w, h = img.size
    left = top = None
    right = bottom = None
    step = 2
    for x in range(0, w, step):
        for y in range(0, h, step):
            r, g, b = px[x, y]
            if b - r > 15 and b > 120:
                left = x if left is None else min(left, x)
                right = x if right is None else max(right, x)
                top = y if top is None else min(top, y)
                bottom = y if bottom is None else max(bottom, y)
    if left is not None:
        pad = 4
        left = max(0, left - pad)
        top = max(0, top - pad)
        right = min(w, right + pad)
        bottom = min(h, bottom + pad)
        img = img.crop((left, top, right, bottom))

    # التصميم مربّع أصلاً؛ نتأكد ونكبّر إلى مقاس العمل الموحّد.
    side = max(img.size)
    square = Image.new("RGB", (side, side), (255, 255, 255))
    square.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return square.resize((CANVAS, CANVAS), Image.LANCZOS)


def rounded(master: Image.Image, radius: int = 230) -> Image.Image:
    """نسخة بزوايا دائرية شفافة (لأندرويد)."""
    ss = 4
    mask = Image.new("L", (CANVAS * ss, CANVAS * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, CANVAS * ss - 1, CANVAS * ss - 1], radius=radius * ss, fill=255
    )
    mask = mask.resize((CANVAS, CANVAS), Image.LANCZOS)
    out = master.convert("RGBA").copy()
    out.putalpha(mask)
    return out


def save(img: Image.Image, rel_path: str) -> None:
    path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(f"  wrote {rel_path} ({img.size[0]}x{img.size[1]})")


def resize(img: Image.Image, px: int) -> Image.Image:
    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    print("== الأصول الرئيسية ==")
    master = load_app_icon_master()
    android_master = rounded(master)
    vp_logo = Image.open(os.path.join(SOURCE, "vp_logo.png")).convert("RGBA")

    save(master, "assets/icon/app_icon.png")
    save(vp_logo, "assets/images/vp_logo.png")

    print("== أيقونات Android ==")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in android_sizes.items():
        save(
            resize(android_master, px),
            f"android/app/src/main/res/{folder}/ic_launcher.png",
        )

    print("== أيقونات iOS ==")
    appiconset = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    with open(os.path.join(ROOT, appiconset, "Contents.json")) as f:
        contents = json.load(f)
    # نفس اسم الملف قد يتكرر بين iphone/ipad — نكتبه مرة واحدة
    seen: dict[str, int] = {}
    for entry in contents["images"]:
        base = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(base * scale)
        seen[entry["filename"]] = px
    for filename, px in seen.items():
        save(resize(master, px), f"{appiconset}/{filename}")

    print("تمّ التوليد بنجاح ✓")


if __name__ == "__main__":
    main()
