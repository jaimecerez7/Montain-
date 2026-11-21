#!/usr/bin/env python3
"""Validaciones rápidas sin SDK Garmin.

IMPORTANTE: valida el manifiesto y casos de referencia matemáticos;
NO compila Monkey C ni simula GPS/brújula/red.
"""
import math
import pathlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
NS = {"iq": "http://www.garmin.com/xml/connectiq"}


def distance(lat1, lon1, lat2, lon2):
    r = 6_371_000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi, dl = phi2 - phi1, math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    a = max(0, min(1, a))
    return 2*r*math.atan2(math.sqrt(a), math.sqrt(1-a))


def bearing(lat1, lon1, lat2, lon2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2-lon1)
    y = math.sin(dl)*math.cos(p2)
    x = math.cos(p1)*math.sin(p2) - math.sin(p1)*math.cos(p2)*math.cos(dl)
    return math.degrees(math.atan2(y, x)) % 360


def angle_diff(a, b):
    return (a-b+180)%360-180


class ProjectTests(unittest.TestCase):
    def test_manifest_valid(self):
        root = ET.parse(ROOT / "manifest.xml").getroot()
        app = root.find("iq:application", NS)
        self.assertIsNotNone(app)
        self.assertEqual(app.get("entry"), "HorizonteCimasApp")
        self.assertEqual(app.get("minSdkVersion"), "3.2.0")
        self.assertEqual(len(app.get("id")), 32)
        devices = {n.get("id") for n in root.findall(".//iq:product", NS)}
        self.assertIn("fr165", devices)
        self.assertIn("fr165m", devices)
        perms = {n.get("id") for n in root.findall(".//iq:uses-permission", NS)}
        self.assertTrue({"Positioning", "Communications", "Sensor"} <= perms)

    def test_resources_present(self):
        for rel in ["monkey.jungle", "resources/strings/strings.xml",
                    "resources/drawables/launcher_icon.png", "source/PeakModel.mc",
                    "source/GeoMath.mc", "source/HorizonteCimasView.mc"]:
            self.assertTrue((ROOT / rel).is_file(), rel)
        ET.parse(ROOT / "resources/strings/strings.xml")
        ET.parse(ROOT / "resources/drawables/drawables.xml")

    def test_geography_references(self):
        self.assertAlmostEqual(distance(0,0,0,0), 0)
        self.assertTrue(110_000 < distance(0,0,0,1) < 112_000)
        self.assertAlmostEqual(bearing(0,0,0,1), 90, places=4)
        self.assertAlmostEqual(bearing(0,0,1,0), 0, places=4)
        self.assertAlmostEqual(angle_diff(359,1), -2)
        self.assertAlmostEqual(angle_diff(1,359), 2)

    def test_overpass_contract_in_source(self):
        source = (ROOT / "source/PeakModel.mc").read_text()
        self.assertIn("overpass-api.de/api/interpreter", source)
        self.assertIn("convert peak name=", source)
        bands = re.findall(r"q \+= queryBand\((\w+), (\w+), (\d+), la, lo\)", source)
        self.assertEqual(len(bands), 4)
        self.assertEqual(bands[0][:2], ("0", "3000"))
        for previous, current in zip(bands, bands[1:]):
            self.assertEqual(previous[1], current[0])
        self.assertEqual(bands[-1][1], "FAR_RADIUS_M")
        self.assertEqual(sum(int(limit) for _, _, limit in bands), 120)
        self.assertIn('data["elements"]', source)
        self.assertIn('Application.Storage.setValue("peakCache",', source)

    def test_no_duplicate_product_ids(self):
        tree = ET.parse(ROOT / "manifest.xml")
        ids = [e.get("id") for e in tree.findall(".//iq:product", NS)]
        self.assertEqual(len(ids), len(set(ids)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
