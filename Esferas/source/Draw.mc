import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Primitivas compartidas por las esferas. Coordenadas de diseño a 390 px, escaladas con k.
module Draw {
    var k = 1.0;
    var seed = 1;

    function p(v) as Number {
        var s = v * k;
        return (s < 0 ? s - 0.5 : s + 0.5).toNumber();
    }

    function pen(dc as Graphics.Dc, w) as Void {
        var px = (w * k + 0.5).toNumber();
        dc.setPenWidth(px < 1 ? 1 : px);
    }

    // Texto con la parte superior de las cifras/mayúsculas en y. Devuelve el ancho.
    // Jost: altura de mayúscula ≈ 0,653 × ascendente.
    function text(dc as Graphics.Dc, x, y, s as String, font, color, justify) as Number {
        var a = dc.getFontAscent(font);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - (a * 0.347).toNumber(), font, s, justify);
        return dc.getTextWidthInPixels(s, font);
    }

    function poly(dc as Graphics.Dc, pts as Array, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    function polyline(dc as Graphics.Dc, pts as Array, color, width) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        pen(dc, width);
        for (var i = 1; i < pts.size(); i++) {
            dc.drawLine(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1]);
        }
    }

    // Catmull-Rom: puntos de control (coordenadas de diseño) → polígono escalado.
    function spline(pts as Array, closed as Boolean, steps as Number) as Array {
        var out = [];
        var n = pts.size();
        var last = closed ? n : n - 1;
        for (var i = 0; i < last; i++) {
            var p0 = pts[closed ? (i - 1 + n) % n : (i > 0 ? i - 1 : 0)];
            var p1 = pts[i];
            var p2 = pts[closed ? (i + 1) % n : i + 1];
            var p3 = pts[closed ? (i + 2) % n : (i + 2 < n ? i + 2 : n - 1)];
            for (var s = 0; s < steps; s++) {
                var t = s.toFloat() / steps;
                var t2 = t * t;
                var t3 = t2 * t;
                var xy = [0, 0];
                for (var j = 0; j < 2; j++) {
                    xy[j] = p(0.5 * (2 * p1[j] + (p2[j] - p0[j]) * t
                        + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                        + (3 * p1[j] - p0[j] - 3 * p2[j] + p3[j]) * t3));
                }
                out.add(xy);
            }
        }
        if (!closed) { out.add([p(pts[n - 1][0]), p(pts[n - 1][1])]); }
        return out;
    }

    // Generador pseudoaleatorio determinista (mismas pinceladas en cada dibujado).
    function rnd() as Float {
        seed = (seed * 1103 + 12345) % 65536;
        return seed / 65536.0;
    }

    // ---------- Iconos (trazo uniforme). x, y: esquina superior izquierda; s: lado ----------

    function iconSunEvent(dc as Graphics.Dc, x, y, s, color, rising as Boolean) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        pen(dc, 2);
        var cx = x + s / 2;
        var cy = y + (s * 0.70).toNumber();
        dc.drawLine(x, cy, x + s, cy);
        dc.drawArc(cx, cy, (s * 0.26).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        for (var a = 30; a <= 150; a += 30) {
            var r = Math.toRadians(a);
            dc.drawLine(cx + (Math.cos(r) * s * 0.38).toNumber(), cy - (Math.sin(r) * s * 0.38).toNumber(),
                cx + (Math.cos(r) * s * 0.50).toNumber(), cy - (Math.sin(r) * s * 0.50).toNumber());
        }
        var ay = y + (s * (rising ? 0.92 : 0.84)).toNumber();
        var d = (s * 0.06 * (rising ? -1 : 1)).toNumber();
        var dx = (s * 0.12).toNumber();
        dc.drawLine(cx - dx, ay - d, cx, ay + d);
        dc.drawLine(cx + dx, ay - d, cx, ay + d);
    }

    function iconDrop(dc as Graphics.Dc, x, y, s, color) as Void {
        var cx = x + s / 2;
        var r = (s * 0.27).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, y + (s * 0.08).toNumber()], [cx + r, y + (s * 0.58).toNumber()],
            [cx - r, y + (s * 0.58).toNumber()]]);
        dc.fillCircle(cx, y + (s * 0.62).toNumber(), r);
    }

    function iconSteps(dc as Graphics.Dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var a = (s * 0.13).toNumber();
        var b = (s * 0.22).toNumber();
        var h = (s * 0.08).toNumber();
        dc.fillEllipse(x + (s * 0.30).toNumber(), y + (s * 0.40).toNumber(), a, b);
        dc.fillCircle(x + (s * 0.30).toNumber(), y + (s * 0.76).toNumber(), h);
        dc.fillEllipse(x + (s * 0.70).toNumber(), y + (s * 0.30).toNumber(), a, b);
        dc.fillCircle(x + (s * 0.70).toNumber(), y + (s * 0.66).toNumber(), h);
    }

    // Nube con contorno: silueta en color y la misma silueta, 2 px más pequeña, en el fondo.
    function cloud(dc as Graphics.Dc, x, y, s, color, bg, base) as Void {
        var w = (2 * k + 0.5).toNumber();
        if (w < 1) { w = 1; }
        var parts = [[0.30, -0.14, 0.17], [0.55, -0.22, 0.22], [0.76, -0.12, 0.14]];
        for (var pass = 0; pass < 2; pass++) {
            dc.setColor(pass == 0 ? color : bg, Graphics.COLOR_TRANSPARENT);
            var inset = pass == 0 ? 0 : w;
            for (var i = 0; i < 3; i++) {
                var c = parts[i];
                dc.fillCircle(x + (s * c[0]).toNumber(), base + (s * c[1]).toNumber(), (s * c[2]).toNumber() - inset);
            }
            var lx = x + (s * 0.13).toNumber() + inset;
            var rx = x + (s * 0.90).toNumber() - inset;
            var top = base - (s * 0.16).toNumber();
            dc.fillRoundedRectangle(lx, top + inset, rx - lx, base - top - 2 * inset + (pass == 0 ? 2 : 0),
                (s * 0.12).toNumber());
        }
    }

    function iconWeather(dc as Graphics.Dc, kind as Symbol, x, y, s, color, bg) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        pen(dc, 2);
        if (kind == :sun || kind == :partly) {
            var sun = kind == :sun;
            var cx = x + (s * (sun ? 0.5 : 0.64)).toNumber();
            var cy = y + (s * (sun ? 0.5 : 0.34)).toNumber();
            var r = s * (sun ? 0.20 : 0.15);
            dc.drawCircle(cx, cy, r.toNumber());
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4;
                dc.drawLine(cx + (Math.cos(a) * r * 1.55).toNumber(), cy + (Math.sin(a) * r * 1.55).toNumber(),
                    cx + (Math.cos(a) * r * 2.1).toNumber(), cy + (Math.sin(a) * r * 2.1).toNumber());
            }
            if (sun) { return; }
        }
        var base = y + (s * (kind == :rain || kind == :snow ? 0.60 : 0.74)).toNumber();
        cloud(dc, x, y, s, color, bg, base);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        pen(dc, 2);
        var fx = [0.34, 0.54, 0.74];
        for (var i = 0; i < 3; i++) {
            var lx = x + (s * fx[i]).toNumber();
            if (kind == :rain) {
                dc.drawLine(lx, base + (s * 0.14).toNumber(), lx - (s * 0.07).toNumber(), base + (s * 0.32).toNumber());
            } else if (kind == :snow) {
                dc.fillCircle(lx - (s * 0.03).toNumber(), base + (s * 0.24).toNumber(), (s * 0.05 + 1).toNumber());
            }
        }
    }

    // Luna con su fase: disco en sombra + parte iluminada (semicírculo + terminador elíptico).
    function moon(dc as Graphics.Dc, cx, cy, r, illum, waxing as Boolean, lit, dark) as Void {
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        if (illum < 0.02) { return; }
        var side = waxing ? 1 : -1;
        var tx = r * (1 - 2 * illum);
        var pts = [];
        for (var i = 0; i <= 16; i++) {
            var a = -Math.PI / 2 + Math.PI * i / 16;
            pts.add([cx + (side * Math.cos(a) * r).toNumber(), cy + (Math.sin(a) * r).toNumber()]);
        }
        for (var i = 16; i >= 0; i--) {
            var a = -Math.PI / 2 + Math.PI * i / 16;
            pts.add([cx + (side * Math.cos(a) * tx).toNumber(), cy + (Math.sin(a) * r).toNumber()]);
        }
        dc.setColor(lit, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    // Pincelada vertical: cuerpo casi recto, punta redondeada, base deshilachada y una veta clara.
    function brush(dc as Graphics.Dc, cx, yb, h, w, color, streak) as Void {
        var n = 6;
        var lean = (rnd() - 0.5) * 4 * k;
        var pts = [];
        for (var i = 0; i <= n; i++) {
            var f = i.toFloat() / n;
            var half = w / 2.0 * (i == n ? 0.55 : 0.9 + 0.1 * rnd());
            pts.add([(cx - half + lean * f).toNumber(), (yb - h * f).toNumber()]);
        }
        for (var i = n; i >= 0; i--) {
            var f = i.toFloat() / n;
            var half = w / 2.0 * (i == n ? 0.55 : 0.9 + 0.1 * rnd());
            pts.add([(cx + half + lean * f).toNumber(), (yb - h * f).toNumber()]);
        }
        pts.add([(cx + w * 0.25).toNumber(), (yb + (2 + rnd() * 4) * k).toNumber()]);
        pts.add([(cx - w * 0.1).toNumber(), (yb + rnd() * 3 * k).toNumber()]);
        pts.add([(cx - w * 0.4).toNumber(), (yb + (1 + rnd() * 4) * k).toNumber()]);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(streak, Graphics.COLOR_TRANSPARENT);
        pen(dc, 1.5);
        dc.drawLine((cx - w * 0.15 + lean * 0.2).toNumber(), (yb - h * 0.15).toNumber(),
            (cx - w * 0.15 + lean * 0.8).toNumber(), (yb - h * 0.8).toNumber());
    }
}
