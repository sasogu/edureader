#!/usr/bin/env python3
"""Compone el material gráfico de las tiendas a partir de las capturas en bruto.

    python3 tool/store_assets.py [raw=store/screenshots/raw]

Espera `raw/iPhone17ProMax/*.png` y `raw/iPadPro13-inchM5/*.png`, generados por
`tool/store_screenshots.sh`, y escribe en `store/screenshots/` y
`store/graphics/`. La fuente se puede cambiar con STORE_FONT_BOLD/STORE_FONT.
"""

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "store"
RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else STORE / "screenshots" / "raw"
PHONE = "iPhone17ProMax"
TABLET = "iPadPro13-inchM5"

BACKGROUND = (48, 91, 113)
PAPER = (249, 245, 233)

CAPTIONS = {
    "01_biblioteca": "Tu biblioteca de EPUB, con portadas",
    "02_lectura": "Lectura paginada y cómoda",
    "03_indice": "Índice para ir a cualquier capítulo",
    "04_apariencia": "Sepia, oscuro, letra y márgenes",
    "05_voz_alta": "Escucha el libro mientras lees",
    "06_busqueda": "Busca cualquier palabra en el libro",
    "07_modo_oscuro": "Modo oscuro para leer de noche",
    "08_nextcloud": "Sincroniza con tu Nextcloud",
}


def font(size, bold=True):
    candidates = [
        os.environ.get("STORE_FONT_BOLD" if bold else "STORE_FONT"),
        "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    raise SystemExit("No se encuentra ninguna fuente; define STORE_FONT_BOLD")


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, *image.size), radius=radius, fill=255
    )
    image.putalpha(mask)
    return image


def centered_text(draw, width, y, text, text_font, fill):
    left, _, right, _ = draw.textbbox((0, 0), text, font=text_font)
    draw.text(((width - (right - left)) / 2, y), text, font=text_font, fill=fill)


def framed(source, size, caption):
    """Captura reducida bajo un titular, sobre el color de la marca."""
    width, height = size
    canvas = Image.new("RGB", size, BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    size = int(width * 0.058)
    headline = font(size)
    while draw.textlength(caption, font=headline) > width * 0.9:
        size -= 2
        headline = font(size)
    centered_text(draw, width, int(height * 0.045), caption, headline, PAPER)
    top = int(height * 0.14)
    shot = Image.open(source).convert("RGB")
    scale = (height - top - int(height * 0.035)) / shot.height
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)))
    shot = rounded(shot, int(shot.width * 0.06))
    canvas.paste(shot, ((width - shot.width) // 2, top), shot)
    return canvas


def export(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(path.relative_to(ROOT), f"{image.width}x{image.height}")


def main():
    phone_shots = sorted((RAW / PHONE).glob("*.png"))
    tablet_shots = sorted((RAW / TABLET).glob("*.png"))
    if not phone_shots:
        raise SystemExit(f"No hay capturas en {RAW / PHONE}")

    for shot in phone_shots:
        export(Image.open(shot).convert("RGB"),
               STORE / "screenshots/appstore/iphone-6.9" / shot.name)
        export(framed(shot, (1080, 1920), CAPTIONS.get(shot.stem, "")),
               STORE / "screenshots/play/phone" / shot.name)
    for shot in tablet_shots:
        image = Image.open(shot).convert("RGB")
        export(image, STORE / "screenshots/appstore/ipad-13" / shot.name)
        export(image.resize((1536, 2048)),
               STORE / "screenshots/play/tablet" / shot.name)

    icon = Image.open(ROOT / "assets/branding/edureader-icon.png").convert("RGB")
    export(icon.resize((512, 512), Image.LANCZOS),
           STORE / "graphics/icon-512.png")

    feature = Image.new("RGB", (1024, 500), BACKGROUND)
    draw = ImageDraw.Draw(feature)
    badge = rounded(icon.resize((260, 260), Image.LANCZOS), 56)
    feature.paste(badge, (90, 120), badge)
    draw.text((410, 150), "EduReader", font=font(92), fill=PAPER)
    draw.text((414, 270), "Lee, subraya y escucha", font=font(40, False),
              fill=PAPER)
    draw.text((414, 322), "tus libros EPUB", font=font(40, False), fill=PAPER)
    export(feature, STORE / "graphics/feature-graphic.png")


if __name__ == "__main__":
    main()
