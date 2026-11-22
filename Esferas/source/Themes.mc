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

    var fTime;
    var fTimeM;
    var fData;
    var fLabel;
    var bg = null;       // obra del estilo activo
    var grid = null;     // retícula estampada completa (Retícula)
    var battery = 0;

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
        Draw.text(dc, Draw.p(195), Draw.p(50), d.date, fLabel, soft, c);
        Draw.text(dc, Draw.p(195), Draw.p(72), d.time, fTime, ink, c);
        row(dc, Draw.p(195), Draw.p(178), [[d.cond, d.temp], [:steps, d.stepsText()], [:battery, pct(d.battery)]],
            ink, soft, ground, 24);
        row(dc, Draw.p(195), Draw.p(210), [sunItem(d)], soft, soft, ground, 20);
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
        Draw.text(dc, Draw.p(250), Draw.p(194), d.time, fTimeM, 0xF2EBE1, c);
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
        Draw.text(dc, Draw.p(195), Draw.p(54), d.time, fTimeM, ink, c);
        row(dc, Draw.p(195), Draw.p(124), [[d.cond, d.temp], [:battery, pct(d.battery)], sunItem(d)], soft, soft, paper, 20);
        var g = grid;
        if (g != null) {
            var n = d.goal > 0 ? (d.steps * 100 / d.goal) : 0;
            if (n > 100) { n = 100; }
            var gx = Draw.p(105);
            var gy = Draw.p(150);
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
        Draw.text(dc, Draw.p(195), Draw.p(338), d.stepsText() + " PASOS", fLabel, ink, c);
    }

    // ------------------------------------------------------------ COLLAGE
    // Los datos van en la cartela de papel, como en un museo.
    function collage(dc as Graphics.Dc, d as FaceData) as Void {
        var ink = 0x24211E;
        var soft = 0x857A6B;
        var paper = 0xF4EEE2;
        background(dc, 0xEFE5CF);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Draw.p(195), Draw.p(110), d.date, fLabel, soft, c);
        Draw.text(dc, Draw.p(195), Draw.p(134), d.time, fTimeM, ink, c);
        dc.setColor(0xD6CCBB, Graphics.COLOR_TRANSPARENT);
        Draw.pen(dc, 1);
        dc.drawLine(Draw.p(150), Draw.p(210), Draw.p(240), Draw.p(210));
        row(dc, Draw.p(195), Draw.p(224), [[d.cond, d.temp], [:steps, d.stepsText()]], ink, soft, paper, 22);
        row(dc, Draw.p(195), Draw.p(260), [[:battery, pct(d.battery)], sunItem(d)], soft, soft, paper, 20);
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
