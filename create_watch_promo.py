#!/usr/bin/env python3
"""Generate All1Fit promotional image for Apple Watch (45mm) screenshot."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter

# --- Config ---
OUTPUT = "/Volumes/SSDani/Proyectos/All1Fit_IOS/promo_watch.png"
BG_PHOTO = "/Users/dani/Downloads/_DSC3001.JPEG"
LOGO = "/Volumes/SSDani/Proyectos/All1Fit_IOS/All1Fit/Assets.xcassets/AppIcon.appiconset/1024.png"

# Apple Watch 45mm screenshot size
W, H = 396, 484

FONT_BOLD = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"

# --- Build image ---
# 1. Background photo — crop to fill, blur slightly
bg = Image.open(BG_PHOTO).convert("RGBA")
bg_ratio = max(W / bg.width, H / bg.height)
bg = bg.resize((int(bg.width * bg_ratio), int(bg.height * bg_ratio)), Image.LANCZOS)
left = (bg.width - W) // 2
top = (bg.height - H) // 2
bg = bg.crop((left, top, left + W, top + H))
bg = bg.filter(ImageFilter.GaussianBlur(radius=2))

# 2. Dark gradient overlay
overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw_ov = ImageDraw.Draw(overlay)
for y in range(H):
    if y < H * 0.35:
        alpha = int(200 - (y / (H * 0.35)) * 80)
    elif y > H * 0.65:
        progress = (y - H * 0.65) / (H * 0.35)
        alpha = int(120 + progress * 100)
    else:
        alpha = 120
    draw_ov.line([(0, y), (W, y)], fill=(0, 0, 0, alpha))

bg = Image.alpha_composite(bg, overlay)

# 3. Logo — centered upper area
logo = Image.open(LOGO).convert("RGBA")
logo_size = 100
logo = logo.resize((logo_size, logo_size), Image.LANCZOS)

# Round corners for logo
mask = Image.new("L", (logo_size, logo_size), 0)
mask_draw = ImageDraw.Draw(mask)
corner_r = 22
mask_draw.rounded_rectangle([(0, 0), (logo_size, logo_size)], radius=corner_r, fill=255)
logo.putalpha(mask)

logo_x = (W - logo_size) // 2
logo_y = 38
bg.paste(logo, (logo_x, logo_y), logo)

# 4. App name under logo
draw = ImageDraw.Draw(bg)
font_name = ImageFont.truetype(FONT_BOLD, 22)
name_text = "All1Fit"
bbox = draw.textbbox((0, 0), name_text, font=font_name)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, logo_y + logo_size + 10), name_text, fill="white", font=font_name)

# 5. Feature pills
font_feat = ImageFont.truetype(FONT_ROUNDED, 13)
features = [
    ("🏋️", "Trackea tus RMs"),
    ("⏱️", "Tabatas & HIIT"),
    ("💪", "WODs y Entrenos"),
    ("⌚", "Apple Watch"),
    ("📊", "Gráficas"),
    ("🆓", "Gratis"),
]

pill_y = logo_y + logo_size + 46
pill_spacing = 36
pill_h = 28
pill_margin = 20

for emoji, text in features:
    full = f"  {emoji}  {text}"
    bbox = draw.textbbox((0, 0), full, font=font_feat)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pill_w = min(tw + 24, W - pill_margin * 2)
    px = (W - pill_w) // 2

    # Pill background
    pill_bg = Image.new("RGBA", (pill_w, pill_h), (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_bg)
    pill_draw.rounded_rectangle(
        [(0, 0), (pill_w, pill_h)],
        radius=pill_h // 2,
        fill=(255, 255, 255, 30),
        outline=(255, 255, 255, 50),
        width=1
    )
    bg.paste(pill_bg, (px, pill_y), pill_bg)

    text_y = pill_y + (pill_h - th) // 2 - 2
    draw.text((px + 12, text_y), full, fill="white", font=font_feat)

    pill_y += pill_spacing

# Orange accent line
accent_y = pill_y + 10
line_w = 60
draw.rounded_rectangle(
    [((W - line_w) // 2, accent_y), ((W + line_w) // 2, accent_y + 3)],
    radius=2,
    fill=(255, 149, 0)
)

# Bottom tagline
font_bottom = ImageFont.truetype(FONT_BOLD, 11)
bottom_text = "Diseñada por atletas"
bbox = draw.textbbox((0, 0), bottom_text, font=font_bottom)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, accent_y + 10), bottom_text, fill=(255, 255, 255, 180), font=font_bottom)

# 6. Save
bg = bg.convert("RGB")
bg.save(OUTPUT, "PNG", quality=100)
print(f"Saved: {OUTPUT} ({W}x{H})")
