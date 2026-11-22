import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Radar orientado hacia donde apunta el reloj: arriba = dirección del brazo.
class RadarView extends WatchUi.View {
    const SKY = 0x000000;
    const DISK = 0x07131E;
    const GRID = 0x2A4757;
    const WEDGE = 0x10293A;
    const MUTED = 0xA4BDCC;
    const ICE = 0xD9EFF6;
    const ACCENT = 0xFFD17A;
    const LOW = 0xFF9F43;       // < 1500 m: despegando o aterrizando
    const MID = 0x5BC0EB;       // < 6000 m
    const HIGH = 0xE8F4FA;      // crucero
    const SELECT_HALF_DEG = 20.0;
    const TICK_MS = 500;

    var model as FlightModel;
    var timer;
    var heading = null;
    var compassOk = false;
    var roundScreen = true;
    var rangesKm as Array<Number> = [10, 25, 50];
    var rangeIndex = 1;
    var selected = null;        // fila geom seleccionada en el último fotograma

    function initialize(m as FlightModel) {
        View.initialize();
        model = m;
        timer = new Timer.Timer();
        roundScreen = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
    }

    function onShow() as Void {
        timer.start(method(:onTick), TICK_MS, true);
        onTick();
    }

    function onHide() as Void {
        timer.stop();
    }

    function onTick() as Void {
        var prior = compassOk;
        compassOk = false;
        if (model.useCompass) {
            var si = Sensor.getInfo();
            if (si != null && si.heading != null) {
                var target = GeoMath.norm360(Math.toDegrees(si.heading));
                heading = heading == null || !prior ? target
                    : GeoMath.norm360(heading + GeoMath.diff(target, heading) * 0.5);
                compassOk = true;
            }
        }
        model.tick(System.getTimer());
        WatchUi.requestUpdate();   // los aviones se mueven: redibujar siempre
    }

    function changeRange(step as Number) as Void {
        rangeIndex += step;
        if (rangeIndex < 0) { rangeIndex = 0; }
        if (rangeIndex >= rangesKm.size()) { rangeIndex = rangesKm.size() - 1; }
        WatchUi.requestUpdate();
    }

    // START: fija el avión seleccionado o lo suelta.
    function toggleLock() as Void {
        if (model.lockedHex != null) {
            model.lockedHex = null;
        } else if (selected != null) {
            model.lockedHex = selected[4][0];
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var th = dc.getFontHeight(Graphics.FONT_TINY);
        var northUp = !model.useCompass || !compassOk;
        var hd = northUp ? 0.0 : heading;

        var topY = (h * 0.06).toNumber();
        var cy = topY + fh + (h * 0.27).toNumber();
        var radius = (h * 0.25).toNumber();
        var statusY = cy + radius + 4;
        var cardY = statusY + fh + 2;

        dc.setColor(SKY, SKY);
        dc.clear();

        // Cabecera: rumbo y modo en una línea.
        var head = northUp ? (model.useCompass ? "SIN BRÚJULA · N arriba" : "NORTE ARRIBA")
            : hd.toNumber().format("%03d") + "°  BRÚJULA";
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, topY, Graphics.FONT_XTINY, fitText(dc, head, Graphics.FONT_XTINY,
            usableWidth(w, h, topY, fh)), Graphics.TEXT_JUSTIFY_CENTER);

        drawRadarBase(dc, cx, cy, radius, hd, fh);

        var rangeM = rangesKm[rangeIndex] * 1000.0;
        selected = null;
        var locked = null;
        var best = 999.0;
        var count = 0;
        var g = model.geom;
        for (var i = 0; i < g.size(); i++) {
            var item = g[i];
            var row = item[4];
            if (model.lockedHex != null && row[0].equals(model.lockedHex)) { locked = item; }
            if (item[1] > rangeM) { continue; }
            count++;
            var rel = GeoMath.diff(item[0], hd);
            var absRel = rel < 0 ? -rel : rel;
            // El seleccionado: el más alineado con la dirección a la que apuntas.
            if (absRel <= SELECT_HALF_DEG && absRel + item[1] / 20000.0 < best) {
                best = absRel + item[1] / 20000.0;
                selected = item;
            }
        }
        if (locked != null) { selected = locked; }
        else if (model.lockedHex != null) { model.lockedHex = null; }   // ya no está en los datos

        for (var i = 0; i < g.size(); i++) {
            var item = g[i];
            if (item[1] > rangeM && item != selected) { continue; }
            drawAircraft(dc, cx, cy, radius, rangeM, hd, item, item == selected);
        }

        // Línea de estado bajo el radar.
        var now = System.getTimer();
        var info = "";
        if (model.status != null) {
            info = model.status;
        } else if (selected != null && selected[4][7].length() > 0) {
            info = Airlines.typeName(selected[4][7])
                + (selected[4][8].length() > 0 ? " · " + selected[4][8] : "");
        } else {
            var age = model.secondsSinceUpdate(now);
            info = count.toString() + (count == 1 ? " avión" : " aviones")
                + (age == null ? "" : " · " + age.toString() + " s") + " · adsb.lol";
        }
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, statusY, Graphics.FONT_XTINY,
            fitText(dc, info, Graphics.FONT_XTINY, usableWidth(w, h, statusY, fh)), Graphics.TEXT_JUSTIFY_CENTER);

        drawCard(dc, w, h, cx, cardY, th, fh, hd);
    }

    function drawRadarBase(dc, cx, cy, radius, hd, fh) as Void {
        dc.setColor(DISK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, radius);
        // Cuña de selección: lo que queda delante del brazo.
        var a = Math.toRadians(SELECT_HALF_DEG);
        dc.setColor(WEDGE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy],
            [cx - (radius * Math.sin(a)).toNumber(), cy - (radius * Math.cos(a)).toNumber()],
            [cx, cy - radius],
            [cx + (radius * Math.sin(a)).toNumber(), cy - (radius * Math.cos(a)).toNumber()]]);
        dc.setColor(GRID, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);
        dc.drawCircle(cx, cy, radius / 2);
        dc.drawLine(cx - radius, cy, cx + radius, cy);
        dc.drawLine(cx, cy - radius, cx, cy + radius);
        // Norte sobre el anillo.
        var n = Math.toRadians(-hd);
        var nx = cx + ((radius - fh / 2 - 2) * Math.sin(n)).toNumber();
        var ny = cy - ((radius - fh / 2 - 2) * Math.cos(n)).toNumber();
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(nx, ny - fh / 2, Graphics.FONT_XTINY, "N", Graphics.TEXT_JUSTIFY_CENTER);
        // Escala del anillo exterior.
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + radius - 2, cy + 2, Graphics.FONT_XTINY,
            rangesKm[rangeIndex].toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        // Tú, en el centro.
        dc.setColor(ICE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 3);
    }

    // Flecha con la orientación real del vuelo, coloreada por altitud.
    function drawAircraft(dc, cx, cy, radius, rangeM, hd, item as Array, isSelected as Boolean) as Void {
        var r = item[1] / rangeM;
        if (r > 1) { r = 1.0; }
        var rel = Math.toRadians(GeoMath.diff(item[0], hd));
        var x = cx + (radius * r * Math.sin(rel)).toNumber();
        var y = cy - (radius * r * Math.cos(rel)).toNumber();
        // Vector hacia delante (f) y perpendicular (p) en coordenadas de pantalla (y hacia abajo).
        var t = Math.toRadians(item[4][6] - hd);
        var s = isSelected ? 9 : 6;
        var fx = Math.sin(t);
        var fy = -Math.cos(t);
        var px = -fy;
        var py = fx;
        var tip = [x + (s * fx).toNumber(), y + (s * fy).toNumber()];
        var left = [x - (s * (0.7 * fx + 0.6 * px)).toNumber(), y - (s * (0.7 * fy + 0.6 * py)).toNumber()];
        var notch = [x - (s * 0.3 * fx).toNumber(), y - (s * 0.3 * fy).toNumber()];
        var right = [x - (s * (0.7 * fx - 0.6 * px)).toNumber(), y - (s * (0.7 * fy - 0.6 * py)).toNumber()];
        var altM = item[3];
        dc.setColor(isSelected ? ACCENT : (altM < 1500 ? LOW : (altM < 6000 ? MID : HIGH)), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([tip, left, notch, right]);
        if (isSelected) {
            dc.drawCircle(x, y, s + 5);
        }
    }

    // Ficha del avión seleccionado: indicativo, aerolínea y altitud/distancia/elevación.
    function drawCard(dc, w, h, cx, y, th, fh, hd) as Void {
        var item = selected;
        if (item == null) {
            dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
            var msg = model.geom.size() == 0 ? "Sin aviones cerca" : "Apunta a un avión";
            dc.drawText(cx, y, Graphics.FONT_TINY, fitText(dc, msg, Graphics.FONT_TINY,
                usableWidth(w, h, y, th)), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var row = item[4];
        var title = row[1];
        var airline = Airlines.airline(row[1]);
        if (airline.length() > 0) { title += " " + airline; }
        var lockedNow = model.lockedHex != null;
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, fitText(dc, (lockedNow ? "» " : "") + title,
            Graphics.FONT_TINY, usableWidth(w, h, y, th)), Graphics.TEXT_JUSTIFY_CENTER);

        var y2 = y + th;
        var rel = GeoMath.diff(item[0], hd);
        var line;
        if (lockedNow && (rel > SELECT_HALF_DEG || rel < -SELECT_HALF_DEG)) {
            // Fijado pero fuera de la cuña: indicar hacia dónde girar.
            var turn = (rel < 0 ? -rel : rel).toNumber();
            line = "Gira " + turn.toString() + "° a la " + (rel < 0 ? "izquierda" : "derecha");
            dc.setColor(ICE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y2, Graphics.FONT_XTINY, fitText(dc, line, Graphics.FONT_XTINY,
                usableWidth(w, h, y2, fh)), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var elev = item[2] < 0 ? 0 : item[2].toNumber();
        drawStats(dc, w, h, cx, y2, fmtAlt(item[3]), fmtDist(item[1]), elev.toString() + "°");
    }

    // ▲ altitud   ↔ distancia   ↗ grados sobre el horizonte (iconos dibujados, no glifos).
    function drawStats(dc, w, h, cx, y, altText, distText, elevText) as Void {
        var f = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(f);
        var icon = (fh * 0.45).toNumber();
        var gap = (icon * 0.5).toNumber();
        var sep = icon + 2;
        var texts = [altText, distText, elevText];
        var total = 0;
        for (var i = 0; i < 3; i++) { total += icon + gap + dc.getTextWidthInPixels(texts[i], f); }
        total += sep * 2;
        var width = usableWidth(w, h, y, fh);
        if (total > width) {
            dc.setColor(ICE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, f, fitText(dc, altText + " · " + distText + " · " + elevText, f, width),
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var x = cx - total / 2;
        var mid = y + fh / 2;
        var half = icon / 2;
        for (var i = 0; i < 3; i++) {
            dc.setColor(MID, Graphics.COLOR_TRANSPARENT);
            if (i == 0) {
                dc.fillPolygon([[x, mid + half], [x + half, mid - half], [x + icon, mid + half]]);
            } else if (i == 1) {
                dc.fillRectangle(x + 2, mid - 1, icon - 4, 3);
                dc.fillPolygon([[x, mid], [x + half, mid - half], [x + half, mid + half]]);
                dc.fillPolygon([[x + icon, mid], [x + half, mid - half], [x + half, mid + half]]);
            } else {
                // Ángulo: horizonte y línea de mira inclinada.
                dc.drawLine(x, mid + half, x + icon, mid + half);
                dc.drawLine(x, mid + half, x + icon, mid - half);
            }
            x += icon + gap;
            dc.setColor(ICE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, f, texts[i], Graphics.TEXT_JUSTIFY_LEFT);
            x += dc.getTextWidthInPixels(texts[i], f) + sep;
        }
    }

    function fmtAlt(m) as String {
        var v = Math.round(m / 10.0).toNumber() * 10;
        return v.toString() + " m";
    }

    function fmtDist(meters) as String {
        if (meters < 1000) { return meters.toNumber().toString() + " m"; }
        var tenths = Math.round(meters / 100.0).toNumber();
        if (tenths < 100) {
            return (tenths / 10).toString() + "," + (tenths % 10).toString() + " km";
        }
        return Math.round(meters / 1000.0).toNumber().toString() + " km";
    }

    function usableWidth(w, h, top, lineHeight) {
        if (!roundScreen) { return w * 0.92; }
        var r = w / 2.0;
        var dTop = top - h / 2.0;
        var dBottom = top + lineHeight - h / 2.0;
        var dy = (dTop < 0 ? -dTop : dTop) > (dBottom < 0 ? -dBottom : dBottom) ? dTop : dBottom;
        var sq = r * r - dy * dy;
        if (sq <= 0) { return 0; }
        return 2 * Math.sqrt(sq) * 0.9;
    }

    function fitText(dc, text, font, width) {
        if (dc.getTextWidthInPixels(text, font) <= width) { return text; }
        var low = 0;
        var high = text.length() - 1;
        while (low < high) {
            var length = (low + high + 1) / 2;
            if (dc.getTextWidthInPixels(text.substring(0, length) + "…", font) <= width) {
                low = length;
            } else {
                high = length - 1;
            }
        }
        return low == 0 ? "" : text.substring(0, low) + "…";
    }
}
