"""Export approved Filo source artwork. Requires the existing local Pillow tool."""
from pathlib import Path
from math import hypot
import argparse
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android/app/src/main/res"
INK = (20, 66, 58)
MINT = (220, 233, 218)


def write(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def foreground(alpha, size, radius, color):
    # Scale every nontransparent pixel into a safe circle, rather than only a box.
    width, height = alpha.size
    extent = max(hypot(x - (width-1)/2, y - (height-1)/2)
                 for y in range(height) for x in range(width) if alpha.getpixel((x, y)))
    factor = (radius - 2) / extent
    mask = alpha.resize((round(width*factor), round(height*factor)), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (size, size))
    mark = Image.new("RGBA", mask.size, color)
    mark.putalpha(mask)
    result.paste(mark, ((size-mask.width)//2, (size-mask.height)//2))
    return result


def export(preview):
    source = Image.open(ROOT / "assets/brand/icon.png").convert("RGB")
    # shortcut: thresholds target this approved opaque PNG; review extraction when source changes.
    # Blend only their antialiased boundary, keeping the original leaf/page contours.
    alpha = source.getchannel("R").point(lambda red: max(0, min(255, round((180-red)*255/90))))
    bounds = alpha.getbbox()
    assert bounds is not None and bounds == (314, 232, 954, 1042), "Review extraction if source changes"
    alpha = alpha.crop(bounds)
    light = foreground(alpha, 512, 228, INK)
    dark = foreground(alpha, 512, 228, MINT)
    assert light.getchannel("A").tobytes() == dark.getchannel("A").tobytes()
    write(light, ROOT / "assets/brand/logo-mark-light.png")
    write(dark, ROOT / "assets/brand/logo-mark-dark.png")
    write(light, RES / "drawable-nodpi/filo_logo_mark.png")
    adaptive = foreground(alpha, 432, 124, INK)
    for y in range(432):
        for x in range(432):
            if adaptive.getpixel((x, y))[3]:
                assert hypot(x-215.5, y-215.5) <= 132, "Adaptive mark exceeds 66dp safe circle"
    write(adaptive, RES / "drawable-nodpi/filo_launcher_logo.png")
    splash = foreground(alpha, 1152, 360, INK)
    write(splash, RES / "drawable-nodpi/filo_splash_logo.png")
    # Launchers expose the central 72dp of the 108dp adaptive canvas.
    legacy = Image.new("RGBA", (432, 432), MINT + (255,))
    legacy.alpha_composite(adaptive)
    legacy = legacy.crop((72, 72, 360, 360))
    for density, size in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)]:
        write(legacy.resize((size, size), Image.Resampling.LANCZOS), RES / f"mipmap-{density}/ic_launcher.png")
    if preview:
        sheet = Image.new("RGB", (1120, 620), "#F9FAF5")
        draw = ImageDraw.Draw(sheet)
        for i, shape in enumerate(["Round", "Square", "Squircle"]):
            icon = legacy.resize((240, 240), Image.Resampling.LANCZOS)
            mask = Image.new("L", (240, 240))
            d = ImageDraw.Draw(mask)
            if shape == "Round": d.ellipse((0,0,239,239), fill=255)
            elif shape == "Square": d.rectangle((0,0,239,239), fill=255)
            else:
                for y in range(240):
                    for x in range(240):
                        if abs((x-119.5)/119.5)**4 + abs((y-119.5)/119.5)**4 <= 1:
                            mask.putpixel((x,y),255)
            sheet.paste(icon, (40+i*360,40), mask)
            draw.text((40+i*360,295), shape, fill=INK)
        for i, (color, mark, label) in enumerate([("#F9FAF5",light,"Light splash / mark"),("#0F1A17",dark,"Dark splash / mark")]):
            panel = Image.new("RGBA", (500,260), color)
            panel.alpha_composite(mark.resize((200,200),Image.Resampling.LANCZOS),(150,20))
            sheet.paste(panel.convert("RGB"),(20+i*560,340))
            draw.text((40+i*560,580), label, fill=INK if not i else MINT)
        write(sheet, preview)
    print("Exported shared light/dark marks, native marks, adaptive foreground and five fallback icons.")
    print("Alpha variants match; all adaptive foreground pixels fit the central 66dp safe circle.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path)
    export(parser.parse_args().preview)
