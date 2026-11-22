#!/usr/bin/env python3
"""Descarga las cumbres de Segovia y la Sierra de Guadarrama de OpenStreetMap y las
empaqueta como recursos JSON de Connect IQ, en teselas de 0,5° × 0,5°.

Uso: python3 -I tools/fetch_peaks.py [--from-file respuesta_overpass.json]
     (desde la carpeta HorizonteCimas)

Genera:
- resources/peaks/peaks_rR_cC.json  {"k": N, "n": "nombres seguidos", "p": "registros"}
  Cada registro mide 21 caracteres: dlat(5) dlon(5) ele(4) inicio(5) largo(2), con dlat/dlon en
  1e-5 grados desde la esquina SO de la tesela. Dos cadenas por tesela: tipos triviales para el
  compilador (los arrays de miles de números lo dejan sin memoria) y pocos objetos en el reloj.
- resources/peaks/peaks.xml          declaraciones <jsonData>
- source/PeakTiles.mc                índice generado: rejilla, cobertura y versión
- tools/data/peaks_summary.json      resumen para el validador (recuento, ejemplos)

Datos © colaboradores de OpenStreetMap (ODbL).
"""
import datetime
import json
import unicodedata
import math
import pathlib
import re
import sys
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
# Provincia de Segovia + Sierra de Guadarrama (vertiente madrileña y abulense incluida)
SOUTH, WEST, NORTH, EAST = 40.55, -4.75, 41.62, -3.15
LAT0, LON0, STEP = 40.5, -4.75, 0.5
ROWS = math.ceil((NORTH - LAT0) / STEP)
COLS = math.ceil((EAST - LON0) / STEP)
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
QUERY = f"""[out:json][timeout:120];
node["natural"="peak"]["name"]({SOUTH},{WEST},{NORTH},{EAST});
out body;"""


def parse_ele(v):
    """'1234', '1234 m', '1234,5' → 1234.5; rechaza textos sin número claro."""
    if v is None:
        return None
    m = re.match(r"^\s*(-?\d+(?:[.,]\d+)?)\s*(m|msnm)?\s*$", str(v))
    return float(m.group(1).replace(",", ".")) if m else None


def fetch():
    body = urllib.parse.urlencode({"data": QUERY}).encode()
    last = None
    for url in ENDPOINTS:
        try:
            req = urllib.request.Request(url, data=body, headers={"User-Agent": "HorizonteCimas-datos/1.0"})
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.load(r)
            if data.get("elements"):
                print(f"OK {url}: {len(data['elements'])} nodos", file=sys.stderr)
                return data, url
        except Exception as ex:   # probar el siguiente servidor
            last = ex
            print(f"Fallo {url}: {ex}", file=sys.stderr)
    raise SystemExit(f"Ningún servidor Overpass respondió: {last}")


def build(data, source_url):
    peaks, seen = [], []
    for el in data["elements"]:
        tags = el.get("tags", {})
        name = unicodedata.normalize("NFC", (tags.get("name") or "").strip())
        ele = parse_ele(tags.get("ele"))
        lat, lon = el.get("lat"), el.get("lon")
        if not name or ele is None or lat is None or not (-100 <= ele <= 5000):
            continue
        if not (SOUTH <= lat <= NORTH and WEST <= lon <= EAST):
            continue
        dup = any(n == name and abs(a - lat) < 0.0015 and abs(b - lon) < 0.002 for n, a, b in seen)
        if dup:
            continue
        seen.append((name, lat, lon))
        peaks.append((name[:60], lat, lon, round(ele)))
    peaks.sort(key=lambda p: -p[3])   # las más altas primero dentro de cada tesela

    out = ROOT / "resources/peaks"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("peaks_r*_c*.json"):
        old.unlink()
    tiles = {}
    for p in peaks:
        r = int((p[1] - LAT0) // STEP)
        c = int((p[2] - LON0) // STEP)
        tiles.setdefault((r, c), []).append(p)
    xml = ["<resources>"]
    for (r, c), items in sorted(tiles.items()):
        names, recs = "", []
        lat0, lon0 = LAT0 + r * STEP, LON0 + c * STEP
        for p in items:
            nm = p[0][:60]
            recs.append(f"{round((p[1] - lat0) * 1e5):05d}{round((p[2] - lon0) * 1e5):05d}"
                        f"{max(0, p[3]):04d}{len(names):05d}{len(nm):02d}")
            names += nm
        doc = {"k": len(items), "n": names, "p": "".join(recs)}
        fn = f"peaks_r{r}_c{c}.json"
        (out / fn).write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        xml.append(f'    <jsonData id="PeaksR{r}C{c}" filename="{fn}"/>')
    xml.append("</resources>")
    (out / "peaks.xml").write_text("\n".join(xml) + "\n", encoding="utf-8")

    version = datetime.date.today().isoformat()
    grid = []
    for r in range(ROWS):
        row = [f"Rez.JsonData.PeaksR{r}C{c}" if (r, c) in tiles else "null" for c in range(COLS)]
        grid.append("[" + ", ".join(row) + "]")
    mc = f"""import Toybox.Lang;

// GENERADO por tools/fetch_peaks.py — no editar a mano.
// Cumbres de Segovia y la Sierra de Guadarrama (OpenStreetMap, {version}).
// Datos © colaboradores de OpenStreetMap (ODbL).
module PeakTiles {{
    const VERSION = "{version}";
    const COUNT = {len(peaks)};
    const SOUTH = {SOUTH};
    const WEST = {WEST};
    const NORTH = {NORTH};
    const EAST = {EAST};
    const LAT0 = {LAT0};
    const LON0 = {LON0};
    const STEP = {STEP};
    const ROWS = {ROWS};
    const COLS = {COLS};

    // Identificador del recurso JSON de la tesela (fila, columna), o null si está vacía.
    // Sin comprobación de tipos: deducir el tipo de cada JSON agota la memoria del compilador.
    (:typecheck(false))
    function tile(r as Number, c as Number) as ResourceId or Null {{
        if (r < 0 || r >= ROWS || c < 0 || c >= COLS) {{ return null; }}
        var grid = [
            {(","+chr(10)+"            ").join(grid)}
        ] as Array<Array<ResourceId or Null>>;
        return grid[r][c];
    }}
}}
"""
    (ROOT / "source/PeakTiles.mc").write_text(mc, encoding="utf-8")

    summary = {
        "version": version, "source": source_url, "count": len(peaks),
        "bbox": [SOUTH, WEST, NORTH, EAST], "tiles": {f"{r},{c}": len(v) for (r, c), v in sorted(tiles.items())},
        "highest": [list(p) for p in peaks[:10]],
    }
    d = ROOT / "tools/data"
    d.mkdir(parents=True, exist_ok=True)
    (d / "peaks_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(peaks)} cumbres en {len(tiles)} teselas", file=sys.stderr)


def from_tiles():
    """Reconstruye una respuesta tipo Overpass desde las teselas ya generadas (cualquier formato)."""
    els = []
    for f in sorted((ROOT / "resources/peaks").glob("peaks_r*_c*.json")):
        r, c = map(int, re.match(r"peaks_r(\d+)_c(\d+)", f.stem).groups())
        doc = json.loads(f.read_text(encoding="utf-8"))
        if isinstance(doc["n"], list):
            for i, nm in enumerate(doc["n"]):
                la, lo, el = doc["p"][3 * i:3 * i + 3]
                els.append({"lat": la / 1e5, "lon": lo / 1e5, "tags": {"name": nm, "ele": str(el)}})
        else:
            lat0, lon0, P, N = LAT0 + r * STEP, LON0 + c * STEP, doc["p"], doc["n"]
            for i in range(doc["k"]):
                q = P[21 * i:21 * i + 21]
                st, ln = int(q[14:19]), int(q[19:21])
                els.append({"lat": lat0 + int(q[0:5]) / 1e5, "lon": lon0 + int(q[5:10]) / 1e5,
                            "tags": {"name": N[st:st + ln], "ele": str(int(q[10:14]))}})
    return {"elements": els}


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--from-tiles":
        data, src = from_tiles(), "teselas existentes"
    elif len(sys.argv) > 2 and sys.argv[1] == "--from-file":
        data, src = json.loads(pathlib.Path(sys.argv[2]).read_text()), "archivo local"
    else:
        data, src = fetch()
    build(data, src)


if __name__ == "__main__":
    main()
