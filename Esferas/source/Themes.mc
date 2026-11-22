import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Las tres composiciones. Coordenadas de diseño a 390 px (Draw.p las escala).
class Themes {
    var fTime;
    var fData;
    var fLabel;
    var shapes as Dictionary = {};   // polígonos precalculados por estilo
    var bg = null;                   // fondo pintado del estilo activo (BitmapResource)
    var strokes as Array = [];       // pinceladas de Trazos: [cuerpo, punta] × 5 (4 variantes + hoy)

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
    function campos(dc as Graphics.Dc, d as FaceData) as Void {
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        var r = Graphics.TEXT_JUSTIFY_RIGHT;
        background(dc, 0x1C2640);
        var cream = 0xEFE4CB;
        var soft = 0xB4AC9A;
        var warm = 0xF7E9D2;
        var ink = 0x3A2A20;
        Draw.text(dc, Draw.p(195), Draw.p(58), d.date, fLabel, soft, c);
        Draw.text(dc, Draw.p(195), Draw.p(86), d.time, fTime, cream, c);
        weatherRow(dc, Draw.p(195), Draw.p(188), d, cream, soft, 0x1C2640);
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
        Draw.moon(dc, Draw.p(246), Draw.p(343), Draw.p(11), d.moonIllum, d.waxing, ink, 0xCDBB98);
        Draw.text(dc, Draw.p(265), Draw.p(330), moonText(d), fData, ink, l);
    }

    // ===================== 2. ORGÁNICA =====================
    function organica(dc as Graphics.Dc, d as FaceData) as Void {
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        var bgc = 0x4E1420;
        background(dc, bgc);
        var cream = 0xF2E6D2;
        var soft = 0xD2B4AE;
        Draw.text(dc, Draw.p(195), Draw.p(52), d.date, fLabel, cream, c);
        Draw.text(dc, Draw.p(195), Draw.p(80), d.time, fTime, cream, c);
        weatherRow(dc, Draw.p(195), Draw.p(184), d, cream, soft, bgc);
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
        background(dc, paper);

        // Pinceladas = pasos: 7 días anteriores + hoy (la clara). Altura relativa al objetivo.
        var vals = [];
        vals.addAll(d.history);
        vals.add(d.steps);
        var top = d.goal;
        for (var i = 0; i < vals.size(); i++) { if (vals[i] > top) { top = vals[i]; } }
        var first = 8 - vals.size();   // alineadas a la derecha si hay menos de 7 días
        for (var i = 0; i < vals.size(); i++) {
            var f = vals[i].toFloat() / top;
            var today = i == vals.size() - 1;
            brushStroke(dc, Draw.p(80 + (first + i) * 19), Draw.p(376), f > 1 ? 1.0 : f, today ? 4 : (first + i) % 4);
        }

        // Curva del sol por encima de las pinceladas: la parte diurna de hoy, escalada para
        // ocupar siempre la misma altura (la forma del día, sin chocar con el texto en verano).
        var xs = Draw.p(24);
        var xe = Draw.p(366);
        var yh = Draw.p(304);
        dc.setColor(0xB9AE9B, Graphics.COLOR_TRANSPARENT);
        Draw.pen(dc, 1.5);
        dc.drawLine(xs, yh, xe, yh);
        var curve = d.sunCurve;
        if (curve != null && d.riseH != null && d.setH != null) {
            var peak = 1.0;
            for (var i = 0; i < curve.size(); i++) { if (curve[i] > peak) { peak = curve[i]; } }
            var pxd = 58 * Draw.k / peak;
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
                var sx = xs + (span * d.nowH / 24).toNumber();
                var sy = yh - (d.sunNow * pxd).toNumber();
                dc.setColor(paper, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx, sy, Draw.p(8));
                dc.setColor(0xE07A2E, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx, sy, Draw.p(6));
            }
        }

        Draw.text(dc, Draw.p(195), Draw.p(46), d.date, fLabel, ink, c);
        Draw.text(dc, Draw.p(195), Draw.p(70), d.time, fTime, ink, c);
        weatherMoonRow(dc, Draw.p(195), Draw.p(170), d, ink, soft, paper);
        var y = Draw.p(208);
        var ic = Draw.p(22);
        var sw = ic + Draw.p(8) + dc.getTextWidthInPixels(d.sunrise, fData);
        var xr = Draw.p(195) - Draw.p(18) - sw;
        Draw.iconSunEvent(dc, xr, y - Draw.p(2), ic, soft, true);
        Draw.text(dc, xr + ic + Draw.p(8), y, d.sunrise, fData, soft, l);
        var xx = Draw.p(195) + Draw.p(18);
        Draw.iconSunEvent(dc, xx, y - Draw.p(2), ic, soft, false);
        Draw.text(dc, xx + ic + Draw.p(8), y, d.sunset, fData, soft, l);
        Draw.iconSteps(dc, Draw.p(230), Draw.p(312), Draw.p(18), ink);
        Draw.text(dc, Draw.p(253), Draw.p(312), d.stepsText(), fData, ink, l);
    }

    // Tiempo + probabilidad de lluvia + luna en una sola fila (Trazos).
    function weatherMoonRow(dc as Graphics.Dc, cx, y, d as FaceData, color, soft, bg) as Void {
        var ic = Draw.p(26);
        var gap = Draw.p(8);
        var sep = Draw.p(22);
        var drop = Draw.p(14);
        var mr = Draw.p(9);
        var mt = moonText(d);
        var w = ic + gap + dc.getTextWidthInPixels(d.temp, fData) + sep + drop + gap
            + dc.getTextWidthInPixels(d.precip, fData) + sep + 2 * mr + gap + dc.getTextWidthInPixels(mt, fData);
        var x = cx - w / 2;
        Draw.iconWeather(dc, d.cond, x, y - Draw.p(4), ic, color, bg);
        x += ic + gap;
        x += Draw.text(dc, x, y, d.temp, fData, color, Graphics.TEXT_JUSTIFY_LEFT) + sep;
        Draw.iconDrop(dc, x, y + Draw.p(2), drop, soft);
        x += drop + gap;
        x += Draw.text(dc, x, y, d.precip, fData, color, Graphics.TEXT_JUSTIFY_LEFT) + sep;
        Draw.moon(dc, x + mr, y + Draw.p(10), mr, d.moonIllum, d.waxing, color, 0xCFC4AE);
        x += 2 * mr + gap;
        Draw.text(dc, x, y, mt, fData, color, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Fondo pintado (o color liso si no se pudo cargar la imagen).
    function background(dc as Graphics.Dc, fallback) as Void {
        dc.setColor(fallback, fallback);
        dc.clear();
        if (bg != null) { dc.drawBitmap(0, 0, bg); }
    }

    // Pincelada de altura variable sin perder la punta natural: el cuerpo se recorta
    // por arriba y encima se dibuja la punta, ambos de la misma pincelada pintada.
    function brushStroke(dc as Graphics.Dc, cx, base, frac, variant as Number) as Void {
        if (strokes.size() < 5) { return; }
        var body = strokes[variant][0];
        var tip = strokes[variant][1];
        var w = body.getWidth();
        var hMax = body.getHeight();
        var tipH = tip.getHeight();
        var h = (tipH + 4 + (hMax - tipH - 10) * frac).toNumber();
        var x = cx - w / 2;
        var top = base - h;
        dc.setClip(x, top + tipH, w, h - tipH + hMax);
        dc.drawBitmap(x, base - hMax + Draw.p(6), body);
        dc.clearClip();
        dc.drawBitmap(x, top, tip);
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
