"""Create runtime PNGs without editing the retained source artwork. Uses local Pillow."""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
for source in sorted((ROOT / "artwork/mascots").glob("*.png")):
    image = Image.open(source).convert("RGBA")
    assert image.width == image.height, f"Review nonsquare source: {source.name}"
    for folder, size in [(ROOT / "assets/mascots", 720), (ROOT / "assets/mascots/empty", 360)]:
        folder.mkdir(parents=True, exist_ok=True)
        image.resize((size, size), Image.Resampling.LANCZOS).save(folder / source.name, optimize=True)
print("Exported 720px hero and 360px empty-state PNGs; source artwork retained unchanged.")
