import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Interfaz de horizonte: compatible con pantallas redondas y AMOLED.
class HorizonteCimasView extends WatchUi.View {
    const FOV = 60.0;
    const VEXAG = 4.0;
    const MAX_LABELS = 5;
    const HIDDEN_PENALTY_DEG = 4.0;
    const SLOPE_TAN = 0.4;             // misma pendiente que la pista de oclusión del modelo
    const TERRAIN_COLUMNS = 44;        // fillPolygon admite hasta 64 vértices
    // Capas de lejos a cerca: [distancia_mínima_m, relleno, cresta]
    const LAYERS = [
        [20000, 0x16243A, 0x34507A],
        [8000, 0x22395A, 0x5A84B8],
        [0, 0x30507A, 0x9CC8F5]
    ];   // una visible a <4° del centro gana a una oculta

    var model as PeakModel;
    var timer;
    var heading = null;
    var compassOk = false;
    var drawnHeading = null;
    var roundScreen = true;
    var selectedOccluded = false;

    function initialize(m as PeakModel) {
        View.initialize();
        model = m;
        timer = new Timer.Timer();
        roundScreen = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
    }

    function onShow() as Void {
        timer.start(method(:onTick), 400, true);  // 2,5 Hz: menor consumo que 5 Hz
        onTick();
    }

    function onHide() as Void {
        timer.stop();
    }

    function onTick() as Void {
        var target = model.manualHeading;
        var priorCompassOk = compassOk;
        compassOk = false;
        if (model.useCompass) {
            var si = Sensor.getInfo();
            if (si != null && si.heading != null) {
                target = GeoMath.norm360(Math.toDegrees(si.heading));
                compassOk = true;
            }
        }
        // Si no hay brújula, no fingir que 0 grados es una lectura real.
        if (model.useCompass && !compassOk) {
            heading = model.lastHeading;
            if (priorCompassOk) { WatchUi.requestUpdate(); }
            return;
        }
        if (heading == null || !priorCompassOk || !model.useCompass) {
            heading = target;
        } else {
            heading = GeoMath.norm360(heading + GeoMath.diff(target, heading) * 0.45);
        }
        model.lastHeading = heading;
        if (drawnHeading == null || priorCompassOk != compassOk || absf(GeoMath.diff(heading, drawnHeading)) > 0.35) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var hd = !model.useCompass || heading == null ? model.manualHeading : heading;
        drawnHeading = hd;
        var ppd = w * 0.74 / FOV;
        var horizonY = (h * 0.63).toNumber();
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        selectedOccluded = false;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        drawCompassTape(dc, w, h, hd, ppd, fh);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.10).toNumber(), horizonY, (w * 0.90).toNumber(), horizonY);

        if (model.lat == null) {
            drawStatus(dc, cx, h, model.status);
        } else if (!model.localData) {
            drawStatus(dc, cx, h, model.fetching ? "Descargando cimas…" : (model.status == null ? "Cimas fuera de zona" : model.status));
        } else if (model.geom.size() == 0) {
            drawStatus(dc, cx, h, "Sin cimas en el alcance");
        } else {
            drawPeaks(dc, w, h, cx, hd, ppd, horizonY, fh);
        }
        // Mira central por encima de la silueta.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, (h * 0.28).toNumber(), cx, (h * 0.33).toNumber());

        var mode = model.useCompass ? (compassOk ? "BRÚJULA" : "SIN BRÚJULA") : "MANUAL";
        var direction = hd.toNumber().toString() + "°  " + mode;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.25).toNumber(), Graphics.FONT_XTINY, direction,
            Graphics.TEXT_JUSTIFY_CENTER);

        var foot = "© OpenStreetMap";
        if (selectedOccluded) {
            foot = "Quizá oculta";
        }
        if (model.localData && model.fetching) {
            foot = "Actualizando cimas…";
        } else if (model.localData && model.status != null) {
            foot = model.status;
        } else if (model.useCompass && !compassOk) {
            foot = "Gira con ARRIBA/ABAJO";
        } else if (model.lat != null && !model.fixOk) {
            foot = "Posición aproximada";
        } else if (!model.altitudeOk) {
            foot = "Sin altitud GPS";
        }
        var footY = (h * 0.845).toNumber();
        var footWidth = usableWidth(w, h, footY, fh);
        if (foot.equals("© OpenStreetMap") && dc.getTextWidthInPixels(foot, Graphics.FONT_XTINY) > footWidth) {
            foot = "© OSM";
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footY, Graphics.FONT_XTINY, fitText(dc, foot, Graphics.FONT_XTINY, footWidth),
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawPeaks(dc, w, h, cx, hd, ppd, horizonY, fh) as Void {
        // item: [desvío_horizontal, prioridad_etiqueta, fila_geom]
        var visible = [] as Array<Array>;
        var terrain = [] as Array<Array>;     // [desvío, ángulo, distancia]
        var g = model.geom;
        var selected = null as Array or Null;
        var bestScore = 0.0;
        var margin = FOV / 2 + 15;            // las laderas de cimas algo fuera de campo también entran
        for (var i = 0; i < g.size(); i++) {
            var dx = GeoMath.diff(g[i][0], hd);
            if (dx >= -margin && dx <= margin) { terrain.add([dx, g[i][1], g[i][2]]); }
            if (dx < -FOV / 2 || dx > FOV / 2) { continue; }
            var occluded = g[i][5];
            // Las posibles ocultas pierden prioridad en etiquetas y selección.
            var item = [dx, occluded ? g[i][1] - 100 : g[i][1], g[i]];
            visible.add(item);
            var score = absf(dx) + (occluded ? HIDDEN_PENALTY_DEG : 0.0);
            if (selected == null || score < bestScore) {
                selected = item;
                bestScore = score;
            }
        }
        if (model.altitudeOk) {
            drawTerrain(dc, w, h, cx, ppd, horizonY, terrain);
        }
        if (selected == null) {
            drawStatus(dc, cx, h, "Sin cimas hacia aquí");
            return;
        }

        sortByElevation(visible);
        var shown = [] as Array<Array>;
        var font = Graphics.FONT_XTINY;
        var inset = (w * 0.12).toNumber();
        // Dos filas de etiquetas: si una choca en la primera, se prueba la segunda.
        var rowY = [(h * 0.34).toNumber(), (h * 0.34).toNumber() + fh + 2];
        for (var i = -1; i < visible.size() && shown.size() < MAX_LABELS; i++) {
            var item = i < 0 ? selected : visible[i];
            if (i >= 0 && item == selected) { continue; }
            var x = cx + (item[0] * ppd).toNumber();
            var row = item[2];
            var markerY = angleToY(row[1], ppd, h, horizonY);
            var name = fitText(dc, row[4], font, w * 0.30);
            var halfWidth = (dc.getTextWidthInPixels(name, font) + 1) / 2;
            var labelX = clamp(x, inset + halfWidth, w - inset - halfWidth);
            var labelRow = -1;
            for (var r = 0; r < 2 && labelRow < 0; r++) {
                var free = true;
                for (var j = 0; j < shown.size(); j++) {
                    if (shown[j][2] == r && absf(labelX - shown[j][0]) < halfWidth + shown[j][1] + 6) {
                        free = false;
                        break;
                    }
                }
                if (free) { labelRow = r; }
            }
            if (labelRow < 0) { continue; }
            shown.add([labelX, halfWidth, labelRow]);
            var labelY = rowY[labelRow];
            var isSelected = item == selected;
            var lineColor = isSelected ? Graphics.COLOR_YELLOW
                : (row[5] ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY);
            dc.setColor(lineColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(labelX, labelY + fh, x, markerY - 7);
            if (row[5]) {
                // Contorno: cima que probablemente queda tras otra montaña.
                dc.drawLine(x, markerY - 6, x - 5, markerY + 3);
                dc.drawLine(x - 5, markerY + 3, x + 5, markerY + 3);
                dc.drawLine(x + 5, markerY + 3, x, markerY - 6);
            } else {
                dc.fillPolygon([[x, markerY - 6], [x - 5, markerY + 3], [x + 5, markerY + 3]]);
            }
            dc.setColor(isSelected ? Graphics.COLOR_YELLOW
                : (row[5] ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE), Graphics.COLOR_TRANSPARENT);
            dc.drawText(labelX, labelY, Graphics.FONT_XTINY,
                name, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Ficha inferior fija: nombre y, debajo, altitud y distancia con iconos.
        var p = selected[2];
        selectedOccluded = p[5];
        var infoY = (h * 0.675).toNumber();
        var tf = Graphics.FONT_TINY;
        var th = dc.getFontHeight(tf);
        dc.setColor(p[5] ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, infoY, tf, fitText(dc, p[4], tf, usableWidth(w, h, infoY, th)),
            Graphics.TEXT_JUSTIFY_CENTER);
        drawStats(dc, w, h, cx, infoY + th, p[3].toNumber().toString() + " m", fmtDist(p[2]));
    }

    // "▲ 2138 m   ↔ 4,2 km": iconos dibujados (no dependen de la fuente del reloj).
    function drawStats(dc, w, h, cx, y, altText, distText) as Void {
        var f = Graphics.FONT_TINY;
        var th = dc.getFontHeight(f);
        var icon = (th * 0.45).toNumber();
        var gap = (icon * 0.5).toNumber();
        var aw = dc.getTextWidthInPixels(altText, f);
        var dw = dc.getTextWidthInPixels(distText, f);
        var arrow = (icon * 1.6).toNumber();
        var total = icon + gap + aw + icon * 2 + arrow + gap + dw;
        if (total > usableWidth(w, h, y, th)) {
            f = Graphics.FONT_XTINY;
            aw = dc.getTextWidthInPixels(altText, f);
            dw = dc.getTextWidthInPixels(distText, f);
            total = icon + gap + aw + icon * 2 + arrow + gap + dw;
        }
        var x = cx - total / 2;
        var midY = y + th / 2;
        var half = icon / 2;
        // Altitud: pequeño pico
        dc.setColor(0x9CC8F5, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, midY + half], [x + half, midY - half], [x + icon, midY + half]]);
        x += icon + gap;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + (th - dc.getFontHeight(f)) / 2, f, altText, Graphics.TEXT_JUSTIFY_LEFT);
        x += aw + icon * 2;
        // Distancia: flecha doble
        dc.setColor(0x9CC8F5, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + half, midY - 1, arrow - icon, 3);
        dc.fillPolygon([[x, midY], [x + half, midY - half], [x + half, midY + half]]);
        dc.fillPolygon([[x + arrow, midY], [x + arrow - half, midY - half], [x + arrow - half, midY + half]]);
        x += arrow + gap;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + (th - dc.getFontHeight(f)) / 2, f, distText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Ángulo de elevación → coordenada Y. Lineal cerca del horizonte y comprimido
    // suavemente hacia los límites, para que las cimas altas no queden aplanadas.
    function angleToY(ea, ppd, h, horizonY) as Number {
        var px = ea * ppd * VEXAG;
        if (px >= 0) {
            var up = horizonY - (h * 0.49);
            return (horizonY - up * px / Math.sqrt(up * up + px * px)).toNumber();
        }
        var down = (h * 0.665) - horizonY;
        return (horizonY + down * (-px) / Math.sqrt(down * down + px * px)).toNumber();
    }

    // Silueta aproximada: cada cima es un cono (ladera SLOPE_TAN) y cada capa de
    // distancia se rellena con un tono distinto, de lejos (oscuro) a cerca (claro).
    function drawTerrain(dc, w, h, cx, ppd, horizonY, terrain as Array<Array>) as Void {
        var base = (h * 0.665).toNumber();
        var x0 = (w * 0.05).toNumber();
        var step = (w - 2 * x0) / (TERRAIN_COLUMNS - 1.0);
        for (var L = 0; L < LAYERS.size(); L++) {
            var minD = LAYERS[L][0];
            var maxD = L == 0 ? 1.0e9 : LAYERS[L - 1][0];
            var items = [] as Array<Array>;
            for (var i = 0; i < terrain.size(); i++) {
                var d = terrain[i][2];
                if (d > minD && d <= maxD) { items.add(terrain[i]); }
            }
            if (items.size() == 0) { continue; }
            var pts = [] as Array<Array>;
            var any = false;
            for (var c = 0; c < TERRAIN_COLUMNS; c++) {
                var x = (x0 + c * step).toNumber();
                var a = (x - cx) / ppd;
                var best = -90.0;
                for (var i = 0; i < items.size(); i++) {
                    var off = a - items[i][0];
                    if (off < 0) { off = -off; }
                    var e = items[i][1] - off * SLOPE_TAN;
                    if (e > best) { best = e; }
                }
                var y = best <= -89.0 ? base : angleToY(best, ppd, h, horizonY);
                if (y > base) { y = base; }
                if (y < base) { any = true; }
                pts.add([x, y]);
            }
            if (!any) { continue; }
            var poly = [] as Array<Array>;
            poly.addAll(pts);
            poly.add([pts[pts.size() - 1][0], base]);
            poly.add([pts[0][0], base]);
            dc.setColor(LAYERS[L][1], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(poly);
            dc.setColor(LAYERS[L][2], Graphics.COLOR_TRANSPARENT);
            for (var c = 1; c < pts.size(); c++) {
                if (pts[c - 1][1] < base || pts[c][1] < base) {
                    dc.drawLine(pts[c - 1][0], pts[c - 1][1], pts[c][0], pts[c][1]);
                }
            }
        }
    }

    function drawStatus(dc, cx, h, message) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.48).toNumber(), Graphics.FONT_XTINY,
            fitText(dc, message, Graphics.FONT_XTINY, dc.getWidth() * 0.83), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawCompassTape(dc, w, h, hd, ppd, fh) as Void {
        var y = (h * 0.21).toNumber();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var start = Math.ceil((hd - FOV / 2) / 10) * 10;
        var end = hd + FOV / 2;
        for (var a = start; a <= end; a += 10) {
            var x = w / 2 + (GeoMath.diff(a, hd) * ppd).toNumber();
            var direction = GeoMath.norm360(a).toNumber();
            if (direction % 90 == 0 && x >= w * 0.17 && x <= w * 0.83) {
                dc.drawLine(x, y - 8, x, y);
                dc.drawText(x, y - 8 - fh, Graphics.FONT_XTINY,
                    cardinal(direction), Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawLine(x, y - 4, x, y);
            }
        }
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[w / 2, y + 1], [w / 2 - 5, y + 8], [w / 2 + 5, y + 8]]);
    }

    function cardinal(degrees) {
        var names = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"];
        return names[((degrees / 45).toNumber()) % 8];
    }

    function fmtDist(meters) {
        if (meters < 10000) { return (meters / 1000.0).format("%.1f") + " km"; }
        return (meters / 1000.0).toNumber().toString() + " km";
    }

    function fitText(dc, name, font, width) {
        if (dc.getTextWidthInPixels(name, font) <= width) { return name; }
        var low = 0;
        var high = name.length() - 1;
        while (low < high) {
            var length = (low + high + 1) / 2;
            if (dc.getTextWidthInPixels(name.substring(0, length) + "…", font) <= width) {
                low = length;
            } else {
                high = length - 1;
            }
        }
        return low == 0 ? "" : name.substring(0, low) + "…";
    }

    // Ancho útil de una línea de texto: en pantallas redondas, la cuerda del círculo
    // en el borde más estrecho de la línea, con un pequeño margen.
    function usableWidth(w, h, top, lineHeight) {
        if (!roundScreen) { return w * 0.92; }
        var r = w / 2.0;
        var dTop = top - h / 2.0;
        var dBottom = top + lineHeight - h / 2.0;
        var dy = absf(dTop) > absf(dBottom) ? dTop : dBottom;
        var sq = r * r - dy * dy;
        if (sq <= 0) { return 0; }
        return 2 * Math.sqrt(sq) * 0.9;
    }

    function clamp(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    function absf(v) { return v < 0 ? -v : v; }

    function sortByElevation(arr as Array<Array>) as Void {
        for (var i = 1; i < arr.size(); i++) {
            var item = arr[i];
            var j = i - 1;
            while (j >= 0 && arr[j][1] < item[1]) {
                arr[j + 1] = arr[j];
                j--;
            }
            arr[j + 1] = item;
        }
    }
}
