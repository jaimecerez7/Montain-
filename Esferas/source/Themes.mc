import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Las composiciones. La obra es un mapa de bits pintado (tools/paint.py); encima, los datos.
// Coordenadas de diseño a 390 px (Draw.p las escala a cada pantalla).
class Themes {
    const CINTA_VERDE = 0;
    const CINTA_AMBAR = 1;
    const BLOQUES = 2;
    const RETICULA = 3;
    const COLLAGE = 4;
    const CIELO = 5;
    // por estado del cielo: puntos del arco, montaña cercana (fondo de iconos)
    const SKY_DOT = [0x8C93B5, 0xF2D3C8, 0xDCEBF5, 0xFCE2B8, 0xE9B4A6];
    const SKY_NEAR = [0x0C1224, 0x383350, 0x2C4351, 0x3B2A30, 0x1C172E];

    var fTime;
    var fTimeM;
    var fData;
    var fLabel;
    var bg = null;       // obra del estilo activo
    var grid = null;     // retícula estampada completa (Retícula)
    var glyphs as Array = [];   // cifras pintadas del estilo activo: 0-9 y ':' (índice 10)
    var battery = 0;
    var sun = null;      // sol pintado (Cielo)
    var moonBmp = null;  // luna pintada en su fase (Cielo)

    function initialize(time, timeM, data, label) {
        fTime = time;
        fTimeM = timeM;
        fData = data;
        fLabel = label;
    }

    function resetCache() as Void {}

    function draw(dc as Graphics.Dc, theme as Number, d as FaceData) as Void {
        battery = d.battery;
        if (theme == BLOQUES) { bloques(dc, d); }
        else if (theme == RETICULA) { reticula(dc, d); }
        else if (theme == COLLAGE) { collage(dc, d); }
        else if (theme == CIELO) { cielo(dc, d); }
        else { cinta(dc, d, theme == CINTA_VERDE); }
    }

    // ------------------------------------------------------------ utilidades
    function background(dc as Graphics.Dc, fallback) as Void {
        dc.setColor(fallback, fallback);
        dc.clear();
        if (bg != null) { dc.drawBitmap(0, 0, bg); }
    }

    function icon(dc as Graphics.Dc, kind as Symbol, x, y, s, color, bg2) as Void {
        if (kind == :steps) { Draw.iconSteps(dc, x, y, s, color); }
        else if (kind == :battery) { Draw.iconBattery(dc, x, y, s, color, bg2, battery); }
        else if (kind == :sunrise) { Draw.iconSunEvent(dc, x, y, s, color, true); }
        else if (kind == :sunset) { Draw.iconSunEvent(dc, x, y, s, color, false); }
        else if (kind == :drop) { Draw.iconDrop(dc, x + s / 6, y + s / 8, (s * 0.7).toNumber(), color); }
        else { Draw.iconWeather(dc, kind, x, y, s, color, bg2); }
    }

    // Fila de datos [icono, texto] centrada como un bloque, separada por aire (sin barras).
    function row(dc as Graphics.Dc, cx, y, items as Array, color, iconColor, bg2, ic) as Void {
        var gap = Draw.p(7);
        var sep = Draw.p(22);
        var s = Draw.p(ic);
        var w = -sep;
        for (var i = 0; i < items.size(); i++) {
            w += s + gap + dc.getTextWidthInPixels(items[i][1], fData) + sep;
        }
        var x = cx - w / 2;
        for (var i = 0; i < items.size(); i++) {
            icon(dc, items[i][0], x, y - Draw.p(2), s, iconColor, bg2);
            x += s + gap;
            x += Draw.text(dc, x, y, items[i][1], fData, color, Graphics.TEXT_JUSTIFY_LEFT) + sep;
        }
    }

    // Hora compuesta con las cifras pintadas de la obra (cada una con PAD px de margen).
    function glyphTime(dc as Graphics.Dc, cx, top, s as String, track) as Void {
        if (glyphs.size() < 11) {
            Draw.text(dc, cx, top + Draw.p(6), s, fTimeM, 0x222222, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var chars = s.toCharArray();
        var pad = Draw.p(6);
        var tr = Draw.p(track);
        var w = -tr;
        var list = [];
        for (var i = 0; i < chars.size(); i++) {
            var idx = chars[i] == ':' ? 10 : chars[i].toNumber() - 48;
            if (idx < 0 || idx > 10) { continue; }
            var g = glyphs[idx];
            list.add(g);
            w += g.getWidth() - 2 * pad + tr;
        }
        var x = cx - w / 2 - pad;
        for (var i = 0; i < list.size(); i++) {
            dc.drawBitmap(x, top - pad, list[i]);
            x += list[i].getWidth() - 2 * pad + tr;
        }
    }

    function sunItem(d as FaceData) as Array {
        return d.nextSunrise ? [:sunrise, d.sunrise] : [:sunset, d.sunset];
    }

    function pct(n) as String { return n.toString() + "%"; }

    // ------------------------------------------------------------ CINTA (verde / ámbar)
    // Datos arriba, sobre el lino limpio; la cinta pintada ocupa la parte baja.
    function cinta(dc as Graphics.Dc, d as FaceData, verde as Boolean) as Void {
        var ink = verde ? 0x1E2620 : 0x2A1C11;
        var soft = verde ? 0x5E665E : 0x86735F;
        var ground = verde ? 0xD4CFC3 : 0xEEEAE3;
        background(dc, ground);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Draw.p(195), Draw.p(42), d.date, fLabel, soft, c);
        row(dc, Draw.p(195), Draw.p(70), [[d.cond, d.temp], [:steps, d.stepsText()], [:battery, pct(d.battery)]],
            ink, soft, ground, 20);
        glyphTime(dc, Draw.p(195), Draw.p(110), d.time, 2);
    }

    // ------------------------------------------------------------ BLOQUES
    // Cada bloque de color es un dato: grafito = reloj, burdeos = tiempo, sangre de buey =
    // batería, melocotón = pasos, franja óxido = próximo amanecer/atardecer.
    function bloques(dc as Graphics.Dc, d as FaceData) as Void {
        background(dc, 0x2D2F2D);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var cream = 0xF0E4D6;
        var dark = 0x3A1E18;
        row(dc, Draw.p(193), Draw.p(102), [[d.cond, d.temp]], cream, cream, 0x7A2C2E, 24);
        row(dc, Draw.p(312), Draw.p(102), [[:battery, pct(d.battery)]], cream, cream, 0x4A161A, 22);
        Draw.text(dc, Draw.p(250), Draw.p(166), d.date, fLabel, 0xB9B2A8, c);
        glyphTime(dc, Draw.p(250), Draw.p(196), d.time, 2);
        Draw.iconSteps(dc, Draw.p(58), Draw.p(186), Draw.p(24), dark);
        Draw.text(dc, Draw.p(70), Draw.p(220), d.stepsText(), fData, dark, c);
        row(dc, Draw.p(250), Draw.p(299), [sunItem(d)], cream, cream, 0xA3461C, 18);
    }

    // ------------------------------------------------------------ RETÍCULA
    // 100 casillas = objetivo de pasos; cada casilla estampada es un 1 % conseguido.
    function reticula(dc as Graphics.Dc, d as FaceData) as Void {
        var ink = 0x1C1A17;
        var soft = 0x6B655C;
        var paper = 0xEDE9E1;
        background(dc, paper);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Draw.p(195), Draw.p(30), d.date, fLabel, ink, c);
        glyphTime(dc, Draw.p(195), Draw.p(50), d.time, 6);
        row(dc, Draw.p(195), Draw.p(132), [[d.cond, d.temp], [:battery, pct(d.battery)], sunItem(d)], soft, soft, paper, 20);
        var g = grid;
        if (g != null) {
            var n = d.goal > 0 ? (d.steps * 100 / d.goal) : 0;
            if (n > 100) { n = 100; }
            var gx = Draw.p(105);
            var gy = Draw.p(160);
            var pitch = 18 * Draw.k;
            var rows = n / 10;
            var rem = n % 10;
            if (rows > 0) {
                dc.setClip(gx, gy, g.getWidth(), (rows * pitch).toNumber());
                dc.drawBitmap(gx, gy, g);
            }
            if (rem > 0) {
                dc.setClip(gx, gy + (rows * pitch).toNumber(), (rem * pitch).toNumber(), pitch.toNumber() + 1);
                dc.drawBitmap(gx, gy, g);
            }
            dc.clearClip();
        }
        Draw.text(dc, Draw.p(195), Draw.p(346), d.stepsText() + " PASOS", fLabel, ink, c);
    }

    // ------------------------------------------------------------ COLLAGE
    // La hora, en papeles de color recortados y pegados; los datos, en una tira de papel.
    function collage(dc as Graphics.Dc, d as FaceData) as Void {
        var ink = 0x24211E;
        var soft = 0x857A6B;
        var paper = 0xF4EEE2;
        background(dc, 0xEFE5CF);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Draw.p(195), Draw.p(66), d.date, fLabel, ink, c);
        glyphTime(dc, Draw.p(195), Draw.p(112), d.time, -2);
        row(dc, Draw.p(195), Draw.p(264), [[d.cond, d.temp], [:steps, d.stepsText()], [:battery, pct(d.battery)]],
            ink, soft, paper, 20);
    }

    // ------------------------------------------------------------ CIELO PINTADO
    // El cielo cambia con la altura real del sol; el sol recorre su arco del día; la luna
    // muestra su fase. Los datos descansan sobre la montaña cercana.
    function cielo(dc as Graphics.Dc, d as FaceData) as Void {
        var st = d.skyState;
        background(dc, SKY_NEAR[st]);
        var cream = 0xFBF4E6;
        var soft = 0xE6DACA;
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Draw.p(195), Draw.p(28), d.date, fLabel, soft, c);
        Draw.text(dc, Draw.p(195), Draw.p(50), d.time, fTime, cream, c);

        // Recorrido del sol (punteado) y el sol en su posición real
        var xs = Draw.p(44);
        var xe = Draw.p(346);
        var yh = Draw.p(232);
        var hh = 92 * Draw.k;
        dc.setColor(SKY_DOT[st], Graphics.COLOR_TRANSPARENT);
        var dot = Draw.p(1.2);
        if (dot < 1) { dot = 1; }
        for (var i = 0; i <= 34; i++) {
            var f = i / 34.0;
            dc.fillCircle(xs + ((xe - xs) * f).toNumber(), yh - (Math.sin(Math.PI * f) * hh).toNumber(), dot);
        }
        var sp = sun;
        if (sp != null && d.riseH != null && d.setH != null && d.sunNow > -1) {
            var f = (d.nowH - d.riseH) / (d.setH - d.riseH);
            if (f > -0.02 && f < 1.02) {
                var e = d.sunNow > 0 ? d.sunNow : 0;
                var sx = xs + ((xe - xs) * f).toNumber() - sp.getWidth() / 2;
                var sy = yh - (e / d.peak * hh).toNumber() - sp.getHeight() / 2;
                dc.setClip(0, 0, dc.getWidth(), Draw.p(226));   // se oculta tras las cumbres
                dc.drawBitmap(sx, sy, sp);
                dc.clearClip();
            }
        }
        // Luna en su fase
        var mb = moonBmp;
        if (mb != null) {
            dc.drawBitmap(Draw.p(84) - mb.getWidth() / 2, Draw.p(176) - mb.getHeight() / 2, mb);
        }
        Draw.text(dc, Draw.p(102), Draw.p(170), Math.round(d.moonIllum * 100).toNumber().toString() + "%",
            fLabel, cream, Graphics.TEXT_JUSTIFY_LEFT);
        // Amanecer y atardecer en los extremos del arco
        row(dc, Draw.p(70), Draw.p(240), [[:sunrise, d.sunrise]], cream, soft, SKY_NEAR[st], 16);
        row(dc, Draw.p(320), Draw.p(240), [[:sunset, d.sunset]], cream, soft, SKY_NEAR[st], 16);
        // Datos sobre la montaña cercana
        row(dc, Draw.p(195), Draw.p(298), [[d.cond, d.temp], [:drop, d.precip]], cream, soft, SKY_NEAR[st], 22);
        row(dc, Draw.p(195), Draw.p(332), [[:steps, d.stepsText()], [:battery, pct(d.battery)]], cream, soft,
            SKY_NEAR[st], 20);
    }

    // ------------------------------------------------------------ siempre encendida (AMOLED)
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
