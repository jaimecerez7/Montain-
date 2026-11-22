import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Las tres composiciones. Coordenadas de diseño a 390 px (Draw.p las escala).
class Themes {
    var fTime;
    var fData;
    var fLabel;
    var shapes as Dictionary = {};   // polígonos precalculados por estilo

    function initialize(time, data, label) {
        fTime = time;
        fData = data;
        fLabel = label;
    }

    function resetCache() as Void { shapes = {}; }

    // Fila de tiempo: icono + temperatura · gota + probabilidad, centrada como grupo.
    function weatherRow(dc as Graphics.Dc, cx, y, d as FaceData, color, soft, bg) as Void {
        var ic = Draw.p(26);
        var gap = Draw.p(8);
        var sep = Draw.p(24);
        var drop = Draw.p(14);
        var w = ic + gap + dc.getTextWidthInPixels(d.temp, fData) + sep + drop + gap
            + dc.getTextWidthInPixels(d.precip, fData);
        var x = cx - w / 2;
        Draw.iconWeather(dc, d.cond, x, y - Draw.p(4), ic, color, bg);
        x += ic + gap;
        x += Draw.text(dc, x, y, d.temp, fData, color, Graphics.TEXT_JUSTIFY_LEFT) + sep;
        Draw.iconDrop(dc, x, y + Draw.p(2), drop, soft);
        x += drop + gap;
        Draw.text(dc, x, y, d.precip, fData, color, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function moonText(d as FaceData) as String {
        return Math.round(d.moonIllum * 100).toNumber().toString() + "%";
    }

    // ===================== 1. CAMPOS (Rothko) =====================
    // Cada banda son capas anidadas con tonos muy próximos: el borde queda difuso.
    function band(dc as Graphics.Dc, y0, y1, colors as Array) as Void {
        for (var i = 0; i < colors.size(); i++) {
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(Draw.p(-30 + i * 6), Draw.p(y0 + i * 3), Draw.p(450 - i * 12),
                Draw.p(y1 - y0 - i * 6), Draw.p(14));
        }
    }

    function campos(dc as Graphics.Dc, d as FaceData) as Void {
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        var r = Graphics.TEXT_JUSTIFY_RIGHT;
        dc.setColor(0x2B1E18, 0x2B1E18);
        dc.clear();
        band(dc, -30, 228, [0x1A2236, 0x1B263D, 0x1D2A44, 0x1F2E4A, 0x213250]);
        band(dc, 236, 300, [0x9E3B1C, 0xAA421F, 0xB44922, 0xBC4F25, 0xC25528]);
        band(dc, 308, 430, [0xD8C8A9, 0xDFD0B2, 0xE5D8BC, 0xE9DDC3, 0xECE1C9]);
        var cream = 0xEFE4CB;
        var soft = 0xB4AC9A;
        var warm = 0xF7E9D2;
        var ink = 0x3A2A20;
        Draw.text(dc, Draw.p(195), Draw.p(58), d.date, fLabel, soft, c);
        Draw.text(dc, Draw.p(195), Draw.p(86), d.time, fTime, cream, c);
        weatherRow(dc, Draw.p(195), Draw.p(188), d, cream, soft, 0x213250);
        // Banda óxido: amanecer · línea del día con el sol en su sitio · atardecer
        var y = Draw.p(258);
        var ic = Draw.p(24);
        Draw.iconSunEvent(dc, Draw.p(52), y - Draw.p(3), ic, warm, true);
        Draw.text(dc, Draw.p(82), y, d.sunrise, fData, warm, l);
        Draw.text(dc, Draw.p(308), y, d.sunset, fData, warm, r);
        Draw.iconSunEvent(dc, Draw.p(314), y - Draw.p(3), ic, warm, false);
        var x0 = Draw.p(166);
        var x1 = Draw.p(224);
        var ly = y + Draw.p(10);
        dc.setColor(0xE3967A, Graphics.COLOR_TRANSPARENT);
        Draw.pen(dc, 2);
        dc.drawLine(x0, ly, x1, ly);
        dc.setColor(warm, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + ((x1 - x0) * d.dayFrac).toNumber(), ly, Draw.p(5));
        // Banda crema: pasos · luna
        Draw.iconSteps(dc, Draw.p(96), Draw.p(330), Draw.p(22), ink);
        Draw.text(dc, Draw.p(126), Draw.p(330), d.stepsText(), fData, ink, l);
        Draw.moon(dc, Draw.p(246), Draw.p(343), Draw.p(11), d.moonIllum, d.waxing, ink, 0xD3C3A4);
        Draw.text(dc, Draw.p(265), Draw.p(330), moonText(d), fData, ink, l);
    }

    // ===================== 2. ORGÁNICA =====================
    function organicShapes() as Array {
        var s = shapes[:organica];
        if (s == null) {
            s = [
                [Draw.spline([[-30, -30], [120, -30], [112, 30], [58, 92], [-30, 118]], true, 6), 0x8C8957],
                [Draw.spline([[-30, 150], [30, 140], [52, 200], [34, 250], [-30, 262]], true, 6), 0x7A5569],
                [Draw.spline([[-30, 282], [60, 272], [180, 290], [200, 352], [150, 430], [-30, 430]], true, 6), 0x232C44],
                [Draw.spline([[350, 110], [430, 80], [430, 270], [372, 258], [344, 190]], true, 6), 0xC0561F],
                [Draw.spline([[214, 282], [300, 268], [430, 290], [430, 430], [200, 430], [196, 340]], true, 6), 0xE6D6BA],
                [Draw.spline([[175, 372], [226, 356], [262, 430], [150, 430]], true, 6), 0xB24C1D],
                [Draw.spline([[96, -10], [70, 70], [28, 150], [44, 230], [20, 300]], false, 8), -1],
                [Draw.spline([[430, 262], [372, 272], [330, 330], [300, 372], [285, 430]], false, 8), -1]
            ];
            shapes[:organica] = s;
        }
        return s;
    }

    function organica(dc as Graphics.Dc, d as FaceData) as Void {
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        var bg = 0x5A1824;
        dc.setColor(bg, bg);
        dc.clear();
        var s = organicShapes();
        for (var i = 0; i < s.size(); i++) {
            if (s[i][1] >= 0) { Draw.poly(dc, s[i][0], s[i][1]); }
            else { Draw.polyline(dc, s[i][0], 0x14080A, 2); }
        }
        var cream = 0xF2E6D2;
        var soft = 0xD2B4AE;
        Draw.text(dc, Draw.p(195), Draw.p(52), d.date, fLabel, cream, c);
        Draw.text(dc, Draw.p(195), Draw.p(80), d.time, fTime, cream, c);
        weatherRow(dc, Draw.p(195), Draw.p(184), d, cream, soft, bg);
        var y = Draw.p(224);
        var ic = Draw.p(22);
        var sw = ic + Draw.p(8) + dc.getTextWidthInPixels(d.sunrise, fData);
        var xr = Draw.p(195) - Draw.p(18) - sw;
        Draw.iconSunEvent(dc, xr, y - Draw.p(2), ic, soft, true);
        Draw.text(dc, xr + ic + Draw.p(8), y, d.sunrise, fData, cream, l);
        var xs = Draw.p(195) + Draw.p(18);
        Draw.iconSunEvent(dc, xs, y - Draw.p(2), ic, soft, false);
        Draw.text(dc, xs + ic + Draw.p(8), y, d.sunset, fData, cream, l);
        // Abajo: pasos sobre el azul noche, luna sobre la crema.
        Draw.iconSteps(dc, Draw.p(70), Draw.p(300), Draw.p(20), 0xE9DCC4);
        Draw.text(dc, Draw.p(96), Draw.p(300), d.stepsText(), fData, 0xE9DCC4, l);
        Draw.moon(dc, Draw.p(236), Draw.p(313), Draw.p(11), d.moonIllum, d.waxing, 0x2A1A14, 0xCDB999);
        Draw.text(dc, Draw.p(254), Draw.p(300), moonText(d), fData, 0x2A1A14, l);
    }

    // ===================== 3. TRAZOS =====================
    function trazos(dc as Graphics.Dc, d as FaceData) as Void {
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        var r = Graphics.TEXT_JUSTIFY_RIGHT;
        var paper = 0xEEE6D6;
        var ink = 0x1C1B19;
        var soft = 0x6E675C;
        dc.setColor(paper, paper);
        dc.clear();
        var hill = shapes[:hill];
        if (hill == null) {
            hill = Draw.spline([[205, 300], [268, 262], [340, 250], [430, 262], [430, 430], [215, 430]], true, 6);
            shapes[:hill] = hill;
        }
        Draw.poly(dc, hill, 0xDCCFB2);

        // Curva del sol: solo la parte diurna, sobre el horizonte, con el sol en su posición.
        var xs = Draw.p(28);
        var xe = Draw.p(362);
        var yh = Draw.p(262);
        var pxd = 1.4 * Draw.k;
        dc.setColor(0xBDB2A0, Graphics.COLOR_TRANSPARENT);
        Draw.pen(dc, 1.5);
        dc.drawLine(xs, yh, xe, yh);
        var curve = d.sunCurve;
        if (curve != null && d.riseH != null && d.setH != null) {
            var span = xe - xs;
            var pts = [[xs + (span * d.riseH / 24).toNumber(), yh]];
            for (var i = 0; i < curve.size(); i++) {
                if (curve[i] >= 0) {
                    pts.add([xs + (span * i / (curve.size() - 1.0)).toNumber(), yh - (curve[i] * pxd).toNumber()]);
                }
            }
            pts.add([xs + (span * d.setH / 24).toNumber(), yh]);
            Draw.polyline(dc, pts, ink, 2);
            if (d.sunNow > 0) {
                dc.setColor(0xE07A2E, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(xs + (span * d.nowH / 24).toNumber(), yh - (d.sunNow * pxd).toNumber(), Draw.p(6));
            }
            Draw.text(dc, xs + (span * d.riseH / 24).toNumber() - Draw.p(8), yh - Draw.p(24), d.sunrise, fData, soft, r);
            Draw.text(dc, xs + (span * d.setH / 24).toNumber() + Draw.p(8), yh - Draw.p(24), d.sunset, fData, soft, l);
        }

        // Trazos = pasos: 7 días anteriores + hoy (más claro). Altura relativa al objetivo.
        Draw.seed = 11;
        var vals = [];
        vals.addAll(d.history);
        vals.add(d.steps);
        var top = d.goal;
        for (var i = 0; i < vals.size(); i++) { if (vals[i] > top) { top = vals[i]; } }
        var first = 8 - vals.size();   // alineados a la derecha si hay menos de 7 días
        for (var i = 0; i < vals.size(); i++) {
            var f = vals[i].toFloat() / top;
            var h = 74 * Draw.k * (f > 1 ? 1 : f);
            if (h < 10 * Draw.k) { h = 10 * Draw.k; }
            var today = i == vals.size() - 1;
            Draw.brush(dc, Draw.p(104 + (first + i) * 14), Draw.p(350), h, 10 * Draw.k,
                today ? 0x6F86D6 : 0x2341A6, today ? 0x9DB0E6 : 0x3E5CC4);
        }

        Draw.text(dc, Draw.p(195), Draw.p(50), d.date, fLabel, ink, c);
        Draw.text(dc, Draw.p(195), Draw.p(76), d.time, fTime, ink, c);
        weatherRow(dc, Draw.p(195), Draw.p(178), d, ink, soft, paper);
        Draw.iconSteps(dc, Draw.p(226), Draw.p(286), Draw.p(20), ink);
        Draw.text(dc, Draw.p(252), Draw.p(286), d.stepsText(), fData, ink, l);
        Draw.moon(dc, Draw.p(236), Draw.p(331), Draw.p(10), d.moonIllum, d.waxing, ink, 0xC9BEA6);
        Draw.text(dc, Draw.p(252), Draw.p(319), moonText(d), fData, ink, l);
    }

    // ===================== Siempre encendida (AMOLED) =====================
    // Pocos píxeles encendidos y desplazamiento de unos px cada minuto contra el desgaste.
    function aod(dc as Graphics.Dc, d as FaceData, minute as Number) as Void {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        var dx = (minute % 3 - 1) * Draw.p(3);
        var dy = (minute / 3 % 3 - 1) * Draw.p(3);
        Draw.text(dc, Draw.p(195) + dx, Draw.p(120) + dy, d.time, fTime, 0x9A9A9A, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, Draw.p(195) + dx, Draw.p(240) + dy, d.date, fLabel, 0x6A6A6A, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
