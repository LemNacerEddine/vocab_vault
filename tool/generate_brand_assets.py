#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""توليد أصول هوية VP Developer لتطبيق VocabVault.

يولّد:
  - assets/icon/app_icon.png            الأيقونة الرئيسية 1024×1024 (زوايا دائرية شفافة)
  - assets/images/vp_logo.png           شعار السبلاش (VP + DEVELOPER، خلفية شفافة)
  - android/app/src/main/res/mipmap-*/ic_launcher.png   (5 مقاسات)
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png (كل المقاسات في Contents.json،
    نسخة مصمتة بدون شفافية كما تشترط Apple)

التشغيل:  pip install Pillow  ثم  python3 tool/generate_brand_assets.py
"""

import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# ألوان الهوية (من شعار VP Developer)
BLUE = (30, 136, 229, 255)     # V الأزرق
NAVY = (26, 35, 126, 255)      # P الكحلي
RED = (229, 57, 53, 255)       # اللمسة الحمراء
WHITE = (255, 255, 255, 255)


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD, size)


def draw_monogram(draw: ImageDraw.ImageDraw, cx: int, cy: int, size: int) -> None:
    """رسم مونوغرام VP: حرف V أزرق وحرف P كحلي متقاربان مع مثلث أحمر صغير
    أسفل يسار الحرف V (كما في الشعار الأصلي)."""
    font = _font(size)
    # تقارب الحرفين يدوياً كي يتلاصقا كما في الشعار
    gap = int(size * 0.30)
    draw.text((cx - gap, cy), "V", font=font, fill=BLUE, anchor="mm")
    draw.text((cx + gap, cy), "P", font=font, fill=NAVY, anchor="mm")
    # المثلث الأحمر أسفل يسار الـ V
    tri_w = int(size * 0.16)
    tri_h = int(size * 0.13)
    tx = cx - gap - int(size * 0.30)
    ty = cy + int(size * 0.34)
    draw.polygon(
        [(tx, ty), (tx + tri_w, ty), (tx, ty - tri_h)],
        fill=RED,
    )


def draw_book(draw: ImageDraw.ImageDraw, cx: int, cy: int, w: int) -> None:
    """كتاب مفتوح مبسّط (صفحتان + خط وسط) — يوحي بتعلم المفردات."""
    h = int(w * 0.42)
    spine = 4
    # الصفحة اليسرى
    draw.polygon(
        [
            (cx - spine, cy - int(h * 0.45)),
            (cx - w // 2, cy - int(h * 0.20)),
            (cx - w // 2, cy + int(h * 0.45)),
            (cx - spine, cy + int(h * 0.20)),
        ],
        fill=NAVY,
    )
    # الصفحة اليمنى
    draw.polygon(
        [
            (cx + spine, cy - int(h * 0.45)),
            (cx + w // 2, cy - int(h * 0.20)),
            (cx + w // 2, cy + int(h * 0.45)),
            (cx + spine, cy + int(h * 0.20)),
        ],
        fill=BLUE,
    )


def draw_icon_content(img: Image.Image) -> None:
    """محتوى الأيقونة (يُرسم على خلفية جاهزة 1024×1024)."""
    draw = ImageDraw.Draw(img)
    draw_monogram(draw, 512, 400, 470)
    # شريط أحمر تحت المونوغرام
    draw.rounded_rectangle([302, 668, 722, 716], radius=24, fill=RED)
    # كتاب صغير أسفل الشريط
    draw_book(draw, 512, 830, 220)


def make_android_master() -> Image.Image:
    """أيقونة أندرويد: مربع أبيض بزوايا دائرية على خلفية شفافة."""
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([0, 0, 1023, 1023], radius=180, fill=WHITE)
    draw_icon_content(img)
    return img


def make_ios_master() -> Image.Image:
    """أيقونة iOS: مربع مصمت كامل (Apple تقصّ الزوايا بنفسها، وترفض الشفافية)."""
    img = Image.new("RGB", (1024, 1024), (255, 255, 255))
    draw_icon_content(img)
    return img


def make_splash_logo() -> Image.Image:
    """شعار السبلاش: مونوغرام VP كبير وتحته DEVELOPER (حرف R الأخير أحمر)."""
    img = Image.new("RGBA", (800, 600), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_monogram(draw, 400, 250, 340)
    # كلمة DEVELOPER بتباعد أحرف؛ الأحرف الأخيرة R حمراء كما في الشعار الأصلي
    word = "DEVELOPER"
    font = _font(72)
    spacing = 10
    widths = [draw.textlength(ch, font=font) for ch in word]
    total = sum(widths) + spacing * (len(word) - 1)
    x = 400 - total / 2
    y = 500
    for i, ch in enumerate(word):
        color = RED if i == len(word) - 1 else NAVY
        draw.text((x, y), ch, font=font, fill=color, anchor="lm")
        x += widths[i] + spacing
    return img


def save(img: Image.Image, rel_path: str) -> None:
    path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(f"  wrote {rel_path} ({img.size[0]}x{img.size[1]})")


def resize(img: Image.Image, px: int) -> Image.Image:
    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    print("== الأصول الرئيسية ==")
    android_master = make_android_master()
    ios_master = make_ios_master()
    splash = make_splash_logo()

    save(android_master, "assets/icon/app_icon.png")
    save(splash, "assets/images/vp_logo.png")

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
        save(resize(ios_master, px), f"{appiconset}/{filename}")

    print("تمّ التوليد بنجاح ✓")


if __name__ == "__main__":
    main()
