"""Native launcher resource checks; uses the exporter's existing local Pillow."""
from math import hypot
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

from PIL import Image

ANDROID = "{http://schemas.android.com/apk/res/android}"
MAIN = Path(__file__).resolve().parents[1] / "android/app/src/main"
RES = MAIN / "res"


class LauncherResourcesTest(unittest.TestCase):
    def test_monochrome_reuses_foreground_and_normal_layers_match(self):
        old = ET.parse(RES / "mipmap-anydpi-v26/ic_launcher.xml").getroot()
        themed = ET.parse(RES / "mipmap-anydpi-v33/ic_launcher.xml").getroot()
        self.assertEqual(old.tag, "adaptive-icon")
        self.assertEqual(themed.tag, "adaptive-icon")
        self.assertEqual([node.tag for node in old], ["background", "foreground"])
        self.assertEqual(
            [node.tag for node in themed], ["background", "foreground", "monochrome"]
        )
        for layer in ("background", "foreground"):
            self.assertEqual(themed.find(layer).attrib, old.find(layer).attrib)
        foreground = themed.find("foreground").get(ANDROID + "drawable")
        self.assertEqual(foreground, "@drawable/filo_launcher_foreground")
        self.assertEqual(themed.find("monochrome").get(ANDROID + "drawable"), foreground)
        bitmap = ET.parse(RES / "drawable/filo_launcher_foreground.xml").getroot()
        self.assertEqual(bitmap.tag, "bitmap")
        self.assertEqual(bitmap.get(ANDROID + "src"), "@drawable/filo_launcher_logo")
        self.assertEqual(bitmap.get(ANDROID + "gravity"), "fill")

    def test_launcher_and_round_icon_select_same_resource(self):
        application = ET.parse(MAIN / "AndroidManifest.xml").find("application")
        self.assertEqual(application.get(ANDROID + "icon"), "@mipmap/ic_launcher")
        self.assertEqual(application.get(ANDROID + "roundIcon"), "@mipmap/ic_launcher")

    def test_artwork_is_single_color_with_transparent_antialiased_edges(self):
        with Image.open(RES / "drawable-nodpi/filo_launcher_logo.png") as image:
            self.assertEqual(image.mode, "RGBA")
            self.assertEqual(image.size, (432, 432))
            pixels = [image.getpixel((x, y)) for y in range(432) for x in range(432)]
            self.assertEqual({p[:3] for p in pixels if p[3]}, {(20, 66, 58)})
            self.assertEqual(image.getchannel("A").getextrema(), (0, 255))
            self.assertTrue(any(0 < p[3] < 255 for p in pixels))

    def test_all_visible_artwork_fits_central_66dp_safe_circle(self):
        with Image.open(RES / "drawable-nodpi/filo_launcher_logo.png") as image:
            alpha = image.getchannel("A")
            self.assertIsNotNone(alpha.getbbox())
            extent = max(
                hypot(x - 215.5, y - 215.5)
                for y in range(432)
                for x in range(432)
                if alpha.getpixel((x, y))
            )
            self.assertLessEqual(extent, 132)  # 108dp canvas at 4x; 66dp diameter.


if __name__ == "__main__":
    unittest.main()
