#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""توليد أصول هوية تطبيق Mofradati (مؤسسة VP Developer).

الأيقونة: مربع أزرق متدرج بزوايا دائرية، وبداخله كتاب مفتوح أبيض تعلوه
مصباح إضاءة (فكرة/معرفة) — مطابقة لتصميم Stitch المعتمد.

يولّد:
  - assets/icon/app_icon.png            الأيقونة الرئيسية 1024×1024 (مربعة مصمتة)
  - assets/images/vp_logo.png           نسخة بزوايا دائرية شفافة (تُعرض في السبلاش)
  - android/app/src/main/res/mipmap-*/ic_launcher.png   (5 مقاسات، زوايا دائرية)
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png (كل المقاسات، مصمتة كما
    تشترط Apple — النظام يقصّ الزوايا بنفسه)

التشغيل:  pip install Pillow  ثم  python3 tool/generate_brand_assets.py
"""

import json
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# فضاء الرسم المنطقي 1024×1024 مضروب في SS للتنعيم (supersampling)
SS = 4
CANVAS = 1024

# ألوان الأيقونة
BLUE_TOP = (62, 169, 245)      # أزرق فاتح أعلى التدرج
BLUE_BOTTOM = (23, 118, 220)   # أزرق أعمق أسفل التدرج
WHITE = (255, 255, 255, 255)


def s(v: float) -> int:
    """تحويل إحداثي من فضاء 1024 إلى فضاء الرسم المكبّر."""
    return int(round(v * SS))


def gradient_color(y: float) -> tuple:
    """لون التدرج عند ارتفاع y (فضاء 1024)."""
    t = max(0.0, min(1.0, y / CANVAS))
    return tuple(
        int(BLUE_TOP[i] + (BLUE_BOTTOM[i] - BLUE_TOP[i]) * t) for i in range(3)
    ) + (255,)


def make_background() -> Image.Image:
    """خلفية زرقاء متدرجة عمودياً مع توهج أبيض خفيف خلف المصباح."""
    size = s(CANVAS)
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    for yy in range(size):
        draw.line([(0, yy), (size, yy)], fill=gradient_color(yy / SS))

    # توهج شعاعي أبيض خلف المصباح
    glow = Image.new("L", (size, size), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [s(512 - 300), s(400 - 300), s(512 + 300), s(400 + 300)], fill=90
    )
    glow = glow.filter(ImageFilter.GaussianBlur(s(90)))
    white = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    white.putalpha(glow)
    img = Image.alpha_composite(img, white)
    return img


def _stroke_line(draw, pts, width):
    """خط متعدد النقاط بأطراف دائرية (يمنع الفجوات عند الزوايا)."""
    w = s(width)
    pts = [(s(x), s(y)) for x, y in pts]
    draw.line(pts, fill=WHITE, width=w, joint="curve")
    r = w // 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)


def _quad_bezier(p0, p1, p2, n=40):
    return [
        (
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1],
        )
        for t in (i / n for i in range(n + 1))
    ]


# هندسة المصباح (فضاء 1024) — تُستخدم للرسم ولقناع الفجوة معاً
BULB_CX, BULB_CY, BULB_R = 512, 398, 118
BASE_TOP = BULB_CY + BULB_R + 8
BASE_WIDTHS = (148, 126, 102)
BAR_H, BAR_GAP = 28, 12


def draw_book(draw: ImageDraw.ImageDraw) -> None:
    """كتاب مفتوح: ثلاث طبقات صفحات على كل جانب + صفحات سفلية منحنية
    تلتقي في نقطة الوسط (شكل V)."""
    stroke = 20
    for i in range(3):
        out_x_l = 272 + i * 40
        out_x_r = CANVAS - out_x_l
        top_y = 448 + i * 28
        bot_y = 640
        # الجانب الأيسر: حافة علوية أفقية + حافة خارجية عمودية
        _stroke_line(draw, [(out_x_l, top_y), (500, top_y)], stroke)
        _stroke_line(draw, [(out_x_l, top_y), (out_x_l, bot_y)], stroke)
        # الجانب الأيمن (مرآة)
        _stroke_line(draw, [(524, top_y), (out_x_r, top_y)], stroke)
        _stroke_line(draw, [(out_x_r, top_y), (out_x_r, bot_y)], stroke)
        # الصفحة السفلية المنحنية نحو نقطة الوسط
        curve_l = _quad_bezier(
            (out_x_l, bot_y),
            (398, bot_y + 26 + i * 24),
            (512, bot_y + 30 + i * 24),
        )
        curve_r = [(CANVAS - x, y) for x, y in curve_l]
        _stroke_line(draw, curve_l, stroke)
        _stroke_line(draw, curve_r, stroke)


def bulb_silhouette_mask(pad: int) -> Image.Image:
    """قناع صورة ظلّية للمصباح (زجاجة + قاعدة + ساق) موسَّع بمقدار pad —
    يُستخدم لمحو خطوط الكتاب خلف المصباح فتظهر فجوة زرقاء نظيفة حوله."""
    mask = Image.new("L", (s(CANVAS), s(CANVAS)), 0)
    d = ImageDraw.Draw(mask)
    cx, cy, r = BULB_CX, BULB_CY, BULB_R + pad
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=255)
    half_w = BASE_WIDTHS[0] / 2 + pad
    base_bottom = BASE_TOP + len(BASE_WIDTHS) * (BAR_H + BAR_GAP) + pad
    d.rounded_rectangle(
        [s(cx - half_w), s(cy + r - 20), s(cx + half_w), s(base_bottom)],
        radius=s(24),
        fill=255,
    )
    # الساق حتى وسط الكتاب (بلا توسيع سفلي كي تلمس نقطة الـ V)
    d.rectangle([s(cx - 10 - pad), s(base_bottom - pad), s(cx + 10 + pad), s(688)], fill=255)
    return mask


def draw_bulb(img: Image.Image, draw: ImageDraw.ImageDraw) -> None:
    """مصباح إضاءة أبيض: زجاجة دائرية بفتيل أزرق، قاعدة لولبية،
    وساق تنزل إلى وسط الكتاب."""
    cx, cy, r = BULB_CX, BULB_CY, BULB_R

    # زجاجة المصباح
    draw.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=WHITE)

    # الفتيل الأزرق: حلقتان متجاورتان يتصل أسفلهما بسلكين قصيرين نحو العنق
    fil = gradient_color(cy)
    fw = s(14)
    for dx in (-32, 32):
        lx = cx + dx
        draw.ellipse(
            [s(lx - 30), s(cy - 16), s(lx + 30), s(cy + 52)],
            outline=fil,
            width=fw,
        )
    for dx, bx in ((-32, -48), (32, 48)):
        draw.line(
            [(s(cx + dx), s(cy + 46)), (s(cx + bx), s(cy + r - 18))],
            fill=fil,
            width=fw,
        )

    # القاعدة اللولبية: ثلاث درجات بيضاء بعرض متناقص
    for i, wdt in enumerate(BASE_WIDTHS):
        y0 = BASE_TOP + i * (BAR_H + BAR_GAP)
        draw.rounded_rectangle(
            [s(cx - wdt / 2), s(y0), s(cx + wdt / 2), s(y0 + BAR_H)],
            radius=s(BAR_H / 2),
            fill=WHITE,
        )
    # الساق النازلة إلى نقطة التقاء الصفحات
    stem_top = BASE_TOP + len(BASE_WIDTHS) * (BAR_H + BAR_GAP) - 6
    _stroke_line(draw, [(cx, stem_top), (cx, 682)], 18)


def draw_icon_art(img: Image.Image) -> None:
    # طبقة الكتاب منفصلة كي نمحو منها ظلّ المصباح الموسَّع (فجوة نظيفة
    # بلون الخلفية نفسها بدل ترقيع بألوان مقاربة).
    book_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_book(ImageDraw.Draw(book_layer))
    punch = bulb_silhouette_mask(pad=26)
    alpha = book_layer.getchannel("A")
    alpha.paste(0, mask=punch)
    book_layer.putalpha(alpha)
    img.alpha_composite(book_layer)

    draw_bulb(img, ImageDraw.Draw(img))


def make_master_square() -> Image.Image:
    """الأيقونة المصدرية: مربع كامل مصمت (لـ iOS ومتجر التطبيقات)."""
    img = make_background()
    draw_icon_art(img)
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def rounded(master: Image.Image, radius: int = 230) -> Image.Image:
    """نسخة بزوايا دائرية شفافة (لأندرويد والسبلاش)."""
    mask = Image.new("L", (CANVAS * SS, CANVAS * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, CANVAS * SS - 1, CANVAS * SS - 1], radius=radius * SS, fill=255
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
    master = make_master_square()
    android_master = rounded(master)

    save(master, "assets/icon/app_icon.png")
    save(android_master, "assets/images/vp_logo.png")

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
        save(resize(master.convert("RGB"), px), f"{appiconset}/{filename}")

    print("تمّ التوليد بنجاح ✓")


if __name__ == "__main__":
    main()
