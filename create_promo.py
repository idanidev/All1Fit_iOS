#!/usr/bin/env python3
"""Generate All1Fit promotional image for App Store / Watch screenshot."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter

# --- Config ---
OUTPUT = "/Volumes/SSDani/Proyectos/All1Fit_IOS/promo_all1fit.png"
BG_PHOTO = "/Users/dani/Downloads/_DSC3001.JPEG"
LOGO = "/Volumes/SSDani/Proyectos/All1Fit_IOS/All1Fit/Assets.xcassets/AppIcon.appiconset/1024.png"

# Output: 1290x2796 (iPhone 6.7" screenshot size — max quality)
W, H = 1284, 2778

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
# Top: semi-transparent black
for y in range(H):
    # Darker at top and bottom, lighter in middle
    if y < H * 0.35:
        alpha = int(200 - (y / (H * 0.35)) * 80)
    elif y > H * 0.65:
        progress = (y - H * 0.65) / (H * 0.35)
        alpha = int(120 + progress * 100)
    else:
        alpha = 120
    draw_ov.line([(0, y), (W, y)], fill=(0, 0, 0, alpha))

bg = Image.alpha_composite(bg, overlay)

# 3. Logo — large, centered upper area
logo = Image.open(LOGO).convert("RGBA")
logo_size = 380
logo = logo.resize((logo_size, logo_size), Image.LANCZOS)

# Round corners for logo
mask = Image.new("L", (logo_size, logo_size), 0)
mask_draw = ImageDraw.Draw(mask)
corner_r = 80
mask_draw.rounded_rectangle([(0, 0), (logo_size, logo_size)], radius=corner_r, fill=255)
logo.putalpha(mask)

logo_x = (W - logo_size) // 2
logo_y = 220
bg.paste(logo, (logo_x, logo_y), logo)

# 4. Text
draw = ImageDraw.Draw(bg)

# Feature pills
font_feat = ImageFont.truetype(FONT_ROUNDED, 44)
features = [
    ("🏋️", "Trackea tus RMs"),
    ("⏱️", "Tabatas & HIIT"),
    ("💪", "WODs y Entrenos"),
    ("⌚", "Apple Watch"),
    ("📊", "Gráficas y Estadísticas"),
    ("🆓", "Gratis y sin límites"),
]

pill_y = 1200
pill_spacing = 120
pill_h = 90
pill_margin = 100

for emoji, text in features:
    full = f"  {emoji}   {text}"
    bbox = draw.textbbox((0, 0), full, font=font_feat)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pill_w = tw + 60
    px = (W - pill_w) // 2

    # Pill background
    pill_bg = Image.new("RGBA", (pill_w, pill_h), (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_bg)
    pill_draw.rounded_rectangle(
        [(0, 0), (pill_w, pill_h)],
        radius=pill_h // 2,
        fill=(255, 255, 255, 30),
        outline=(255, 255, 255, 50),
        width=2
    )
    bg.paste(pill_bg, (px, pill_y), pill_bg)

    # Text
    text_y = pill_y + (pill_h - th) // 2 - 4
    draw.text((px + 30, text_y), full, fill="white", font=font_feat)

    pill_y += pill_spacing

# Orange accent line
accent_y = pill_y + 40
line_w = 200
draw.rounded_rectangle(
    [((W - line_w) // 2, accent_y), ((W + line_w) // 2, accent_y + 6)],
    radius=3,
    fill=(255, 149, 0)
)

# Bottom text
font_bottom = ImageFont.truetype(FONT_BOLD, 38)
bottom_text = "Diseñada por un atleta, para atletas"
bbox = draw.textbbox((0, 0), bottom_text, font=font_bottom)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, accent_y + 50), bottom_text, fill=(255, 255, 255, 180), font=font_bottom)

# 5. Save
bg = bg.convert("RGB")
bg.save(OUTPUT, "PNG", quality=100)
print(f"Saved: {OUTPUT} ({W}x{H})")
