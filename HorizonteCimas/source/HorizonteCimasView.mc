import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.Timer;
import Toybox.WatchUi;

// Interfaz de horizonte: compatible con pantallas redondas y AMOLED.
class HorizonteCimasView extends WatchUi.View {
    const FOV = 60.0;
    const VEXAG = 4.0;
    const MAX_LABELS = 4;
    const HIDDEN_PENALTY_DEG = 4.0;   // una visible a <4° del centro gana a una oculta

    var model as PeakModel;
    var timer;
    var heading = null;
    var compassOk = false;
    var drawnHeading = null;

    function initialize(m as PeakModel) {
        View.initialize();
        model = m;
        timer = new Timer.Timer();
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

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        drawCompassTape(dc, w, h, hd, ppd, fh);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.10).toNumber(), horizonY, (w * 0.90).toNumber(), horizonY);
        dc.drawLine(cx, (h * 0.28).toNumber(), cx, horizonY + 5);

        if (model.lat == null) {
            drawStatus(dc, cx, h, model.status);
        } else if (!model.localData) {
            drawStatus(dc, cx, h, model.fetching ? "Descargando cimas…" : (model.status == null ? "Cimas fuera de zona" : model.status));
        } else if (model.geom.size() == 0) {
            drawStatus(dc, cx, h, "Sin cimas en el alcance");
        } else {
            drawPeaks(dc, w, h, cx, hd, ppd, horizonY, fh);
        }

        var mode = model.useCompass ? (compassOk ? "BRÚJULA" : "SIN BRÚJULA") : "MANUAL";
        var direction = hd.toNumber().toString() + "°  " + mode;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.25).toNumber(), Graphics.FONT_XTINY, direction,
            Graphics.TEXT_JUSTIFY_CENTER);

        var foot = "© OpenStreetMap";
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
        dc.drawText(cx, (h * 0.86).toNumber(), Graphics.FONT_XTINY,
            fitText(dc, foot, Graphics.FONT_XTINY, w * 0.61), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawPeaks(dc, w, h, cx, hd, ppd, horizonY, fh) as Void {
        // item: [desvío_horizontal, prioridad_etiqueta, fila_geom]
        var visible = [] as Array<Array>;
        var g = model.geom;
        var selected = null as Array or Null;
        var bestScore = 0.0;
        for (var i = 0; i < g.size(); i++) {
            var dx = GeoMath.diff(g[i][0], hd);
            if (dx < -FOV / 2 || dx > FOV / 2) { continue; }
            var hidden = g[i][5];
            // Las posibles ocultas pierden prioridad en etiquetas y selección.
            var item = [dx, hidden ? g[i][1] - 100 : g[i][1], g[i]];
            visible.add(item);
            var score = absf(dx) + (hidden ? HIDDEN_PENALTY_DEG : 0.0);
            if (selected == null || score < bestScore) {
                selected = item;
                bestScore = score;
            }
        }
        if (selected == null) {
            drawStatus(dc, cx, h, "Sin cimas hacia aquí");
            return;
        }

        sortByElevation(visible);
        var shown = [] as Array<Array>;
        var font = Graphics.FONT_XTINY;
        var inset = (w * 0.12).toNumber();
        var labelY = (h * 0.34).toNumber();
        for (var i = -1; i < visible.size() && shown.size() < MAX_LABELS; i++) {
            var item = i < 0 ? selected : visible[i];
            if (i >= 0 && item == selected) { continue; }
            var x = cx + (item[0] * ppd).toNumber();
            var row = item[2];
            var markerY = clamp(horizonY - (row[1] * ppd * VEXAG).toNumber(),
                (h * 0.49).toNumber(), (h * 0.68).toNumber());
            var name = fitText(dc, row[4], font, w * 0.25);
            var halfWidth = (dc.getTextWidthInPixels(name, font) + 1) / 2;
            var labelX = clamp(x, inset + halfWidth, w - inset - halfWidth);
            var free = true;
            for (var j = 0; j < shown.size(); j++) {
                if (absf(labelX - shown[j][0]) < halfWidth + shown[j][1] + 6) {
                    free = false;
                    break;
                }
            }
            if (!free) { continue; }
            shown.add([labelX, halfWidth]);
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

        // Ficha inferior fija: los indicadores de rumbo/altura no bailan.
        var p = selected[2];
        var infoY = (h * 0.72).toNumber();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, infoY, Graphics.FONT_TINY,
            fitText(dc, p[4], Graphics.FONT_TINY, w * 0.72), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var details = p[3].toNumber().toString() + " m  ·  "
            + fmtDist(p[2]) + "  ·  " + p[0].toNumber().toString() + "°";
        if (p[5]) { details += "  ·  ¿oculta?"; }
        dc.drawText(cx, infoY + dc.getFontHeight(Graphics.FONT_TINY), Graphics.FONT_XTINY,
            fitText(dc, details, Graphics.FONT_XTINY, w * 0.80), Graphics.TEXT_JUSTIFY_CENTER);
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
