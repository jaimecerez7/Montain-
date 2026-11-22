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
    const GEOMETRIA = 6;
    // por estado del cielo: puntos del arco, montaña cercana (fondo de iconos)
    const SKY_DOT = [0x8C93B5, 0xF2D3C8, 0xDCEBF5, 0xFCE2B8, 0xE9B4A6];
    const SKY_NEAR = [0x0C1224, 0x383350, 0x2C4351, 0x3B2A30, 0x1C172E];

    var fTime;
    var fTimeM;
    var fData;
    var fLabel;
    var fSmall;
    var fMini;
    var bg = null;       // obra del estilo activo
    var grid = null;     // retícula estampada completa (Retícula)
    var glyphs as Array = [];   // cifras pintadas del estilo activo: 0-9 y ':' (índice 10)
    var battery = 0;
    var sun = null;      // sol pintado (Cielo)
    var moonBmp = null;  // luna pintada en su fase (Cielo)

    function initialize(fonts as Array) {
        fTime = fonts[0];
        fTimeM = fonts[1];
        fData = fonts[2];
        fLabel = fonts[3];
        fSmall = fonts[4];
        fMini = fonts[5];
    }

    function resetCache() as Void {}

    function draw(dc as Graphics.Dc, theme as Number, d as FaceData) as Void {
        battery = d.battery;
        if (theme == BLOQUES) { bloques(dc, d); }
        else if (theme == RETICULA) { reticula(dc, d); }
        else if (theme == COLLAGE) { collage(dc, d); }
        else if (theme == CIELO) { cielo(dc, d); }
        else if (theme == GEOMETRIA) { geometria(dc, d); }
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
        rowF(dc, cx, y, items, [color, iconColor, bg2], ic, fData, false);
    }

    // Fila con fuente a elegir; compact = cifras pequeñas (fuente Small), icono centrado en la línea.
    function rowF(dc as Graphics.Dc, cx, y, items as Array, colors as Array, ic, font, compact as Boolean) as Void {
        var gap = Draw.p(compact ? 5 : 7);
        var sep = Draw.p(compact ? 14 : 22);
        var s = Draw.p(ic);
        var w = -sep;
        for (var i = 0; i < items.size(); i++) {
            w += s + gap + dc.getTextWidthInPixels(items[i][1], font) + sep;
        }
        var x = cx - w / 2;
        var dy = compact ? Draw.p(3) - (s - Draw.p(21 * 0.7)) / 2 : Draw.p(2);
        for (var i = 0; i < items.size(); i++) {
            icon(dc, items[i][0], x, y - dy, s, colors[1], colors[2]);
            x += s + gap;
            x += Draw.text(dc, x, y, items[i][1], font, colors[0], Graphics.TEXT_JUSTIFY_LEFT) + sep;
        }
    }

    function small(dc as Graphics.Dc, cx, y, items as Array, colors as Array, ic) as Void {
        rowF(dc, cx, y, items, colors, ic, fSmall, true);
    }

    function moonImg(dc as Graphics.Dc, cx, cy) as Void {
        var mb = moonBmp;
        if (mb != null) { dc.drawBitmap(cx - mb.getWidth() / 2, cy - mb.getHeight() / 2, mb); }
    }

    function moonPct(d as FaceData) as String {
        return Math.round(d.moonIllum * 100).toNumber().toString() + "%";
    }

    // Hora compuesta con las cifras pintadas de la obra (cada una con PAD px de margen).
    function glyphTime(dc as Graphics.Dc, cx, top, s as String, track) as Void {
        glyphTimeB(dc, cx, top, s, track, false);
    }

    // bounce: las cifras saltan arriba y abajo (Collage), alineado desde la derecha.
    function glyphTimeB(dc as Graphics.Dc, cx, top, s as String, track, bounce as Boolean) as Void {
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
        var hops = [-3, 4, 0, -4, 3];
        for (var i = 0; i < list.size(); i++) {
            var dy = bounce ? Draw.p(hops[(i + 5 - list.size()) % 5]) : 0;
            dc.drawBitmap(x, top - pad + dy, list[i]);
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
        background(dc, 0x2B2C2A);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        // Cada bloque es un dato, escrito en un tono derivado de su propio color.
        var sp = d.date.find(" ");
        var day = sp == null ? d.date : d.date.substring(0, sp);
        var rest = sp == null ? "" : d.date.substring(sp + 1, d.date.length());
        Draw.text(dc, Draw.p(72), Draw.p(88), day, fSmall, 0x5E201C, c);                         // salmón: fecha
        Draw.text(dc, Draw.p(72), Draw.p(114), rest, fMini, 0x7E3329, c);
        small(dc, Draw.p(190), Draw.p(86), [[d.cond, d.temp]], [0xF3D2C2, 0xF3D2C2, 0x7B2A2C], 20);   // burdeos: tiempo
        Draw.text(dc, Draw.p(190), Draw.p(114), "LLUVIA " + d.precip, fMini, 0xD69A8A, c);
        moonImg(dc, Draw.p(290), Draw.p(96));                                                     // sangre de buey: luna
        Draw.text(dc, Draw.p(308), Draw.p(86), moonPct(d), fSmall, 0xE9BFB4, l);
        Draw.text(dc, Draw.p(312), Draw.p(114), "LUNA", fMini, 0xB87A72, c);
        Draw.iconSteps(dc, Draw.p(60), Draw.p(176), Draw.p(22), 0x6A2E22);                         // melocotón: pasos
        Draw.text(dc, Draw.p(70), Draw.p(208), d.stepsText(), fData, 0x4A1F17, c);
        Draw.text(dc, Draw.p(70), Draw.p(240), "PASOS", fMini, 0x8E4C3A, c);
        glyphTime(dc, Draw.p(252), Draw.p(184), d.time, 3);                                        // grafito: hora
        small(dc, Draw.p(80), Draw.p(300), [[:battery, pct(d.battery)]], [0xCFC5B5, 0xCFC5B5, 0x151513], 14);
        small(dc, Draw.p(250), Draw.p(300), [[:sunrise, d.sunrise], [:sunset, d.sunset]],
            [0xF6DDC8, 0xF6DDC8, 0xA9471B], 14);                                                   // óxido: sol
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
    // Batería camuflada: cinco rayitas (el motivo de rayas del collage); las oscuras son la carga.
    function batteryBars(dc as Graphics.Dc, x0, y0, level, ink, empty) as Void {
        var n = Math.round(level / 20.0).toNumber();
        var w = Draw.p(3.2) < 2 ? 2 : Draw.p(3.2);
        for (var i = 0; i < 5; i++) {
            dc.setColor(i < n ? ink : empty, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + Draw.p(i * 6), y0, w, Draw.p(17));
        }
    }

    function collage(dc as Graphics.Dc, d as FaceData) as Void {
        var ink = 0x2A2119;
        var soft = 0x5C4D3C;
        background(dc, 0xEFE5CF);
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Draw.p(172), Draw.p(64), d.date, fLabel, ink, c);                               // cinta: fecha
        batteryBars(dc, Draw.p(266), Draw.p(62), d.battery, ink, 0xC9BB9C);                           // batería camuflada
        glyphTimeB(dc, Draw.p(195), Draw.p(104), d.time, -2, true);                                    // papeles que saltan
        small(dc, Draw.p(98), Draw.p(252), [[d.cond, d.temp]], [ink, ink, 0xE2AE2E], 18);              // mancha azafrán
        small(dc, Draw.p(98), Draw.p(278), [[:drop, d.precip]], [0x5A4216, 0x5A4216, 0xE2AE2E], 12);
        Draw.iconSteps(dc, Draw.p(187), Draw.p(242), Draw.p(16), soft);                                // tira: pasos
        Draw.text(dc, Draw.p(195), Draw.p(262), d.stepsText(), fSmall, ink, c);
        var bx = Draw.p(165);
        var bw = Draw.p(60);
        var bh = Draw.p(2) < 1 ? 1 : Draw.p(2);
        var f = d.goal > 0 ? d.steps.toFloat() / d.goal : 0.0;
        if (f > 1) { f = 1.0; }
        dc.setColor(0xD3C4A4, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, Draw.p(285), bw, bh);
        dc.setColor(0xC0392B, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, Draw.p(285), (bw * f).toNumber(), bh);
        moonImg(dc, Draw.p(292), Draw.p(258));                                                         // mancha azul noche
        Draw.text(dc, Draw.p(292), Draw.p(280), moonPct(d), fMini, 0xD9D1BF, c);
        small(dc, Draw.p(195), Draw.p(319), [[:sunrise, d.sunrise], [:sunset, d.sunset]], [0xE6DCC8, 0xD9A22C, 0x1E1B18], 12);
    }

    // ------------------------------------------------------------ GEOMETRÍA
    // Baldosas al gouache; cada dato vive en una baldosa con su propia geometría.
    function geometria(dc as Graphics.Dc, d as FaceData) as Void {
        background(dc, 0x1F3A5F);
        var cream = 0xF1E6D0;
        var ink = 0x1C1A17;
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        // tira negra: fecha + batería en cinco puntos
        Draw.text(dc, Draw.p(172), Draw.p(68), d.date, fLabel, cream, c);
        var n = Math.round(d.battery / 20.0).toNumber();
        var dr = Draw.p(2) < 2 ? 2 : Draw.p(2);
        for (var i = 0; i < 5; i++) {
            dc.setColor(i < n ? 0xE3A72F : 0x4A453F, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(Draw.p(264 + i * 6), Draw.p(75), dr);
        }
        glyphTime(dc, Draw.p(195), Draw.p(116), d.time, 0);                                     // franja marino: hora
        // sol (terracota): amanecer y atardecer sobre el medio sol
        small(dc, Draw.p(78), Draw.p(244), [[:sunrise, d.sunrise]], [cream, 0xF6D28A, 0xC8553D], 12);
        small(dc, Draw.p(78), Draw.p(266), [[:sunset, d.sunset]], [cream, 0xF6D28A, 0xC8553D], 12);
        // tiempo (mostaza)
        small(dc, Draw.p(156), Draw.p(252), [[d.cond, d.temp]], [ink, ink, 0xE3A72F], 18);
        Draw.text(dc, Draw.p(148), Draw.p(280), d.precip, fMini, 0x5A3E10, c);
        // pasos (marino): anillo de progreso hacia el objetivo
        var cx = Draw.p(234);
        var cy = Draw.p(273);
        var r = Draw.p(27);
        var f = d.goal > 0 ? d.steps.toFloat() / d.goal : 0.0;
        if (f > 1) { f = 1.0; }
        Draw.pen(dc, 5);
        dc.setColor(0x34507A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        if (f > 0.005) {
            dc.setColor(0xE3A72F, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * f).toNumber());
        }
        var tenths = Math.round(d.steps / 100.0).toNumber();
        Draw.text(dc, cx, cy - Draw.p(7), (tenths / 10).toString() + "," + (tenths % 10).toString() + "K", fSmall, cream, c);
        // luna (negro)
        moonImg(dc, Draw.p(312), Draw.p(264));
        Draw.text(dc, Draw.p(312), Draw.p(286), moonPct(d), fMini, 0xD9D1BF, c);
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
        moonImg(dc, Draw.p(84), Draw.p(176));
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
