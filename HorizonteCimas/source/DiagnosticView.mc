import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Diagnóstico: de dónde salen las cimas, cuánto cuesta cargarlas y estado de GPS, red y memoria.
(:typecheck(false))
class DiagnosticView extends WatchUi.View {
    var model as PeakModel;
    var timer;

    function initialize(m as PeakModel) {
        View.initialize();
        model = m;
        timer = new Timer.Timer();
    }

    function onShow() as Void { timer.start(method(:tick), 1000, true); }
    function onHide() as Void { timer.stop(); }
    function tick() as Void { WatchUi.requestUpdate(); }

    function lines() as Array<String> {
        var m = model;
        var src = ["Sin datos", "Offline OSM", "Caché", "Internet"][m.dataSource];
        var out = [] as Array<String>;
        out.add("Fuente: " + src);
        out.add("Base: " + PeakTiles.COUNT + " cimas · " + PeakTiles.VERSION);
        out.add("Zona offline: " + (m.inCoverage(m.lat, m.lon) ? "sí" : (m.lat == null ? "?" : "no")));
        out.add("En memoria: " + m.peaks.size() + " · visibles " + m.geom.size() + (m.onlyBig ? " · grandes" : " · todas"));
        out.add("Carga: " + m.offlineTiles + " teselas · " + m.offlineCandidates + " cand. · " + m.offlineLoadMs + " ms");
        if (m.lat == null) {
            out.add("GPS: sin posición");
        } else {
            out.add("GPS: " + (m.fixOk ? "fijo" : (m.usingSavedPos ? "recordado" : "aproximado")) + " " + m.lat.format("%.4f") + ", " + m.lon.format("%.4f"));
        }
        out.add("Altitud: " + (m.altitudeOk ? m.alt.toNumber().toString() + " m" : "sin dato"));
        out.add("Rumbo: " + (m.useCompass ? "brújula" : "manual") + " " + m.lastHeading.toNumber() + "°");
        var online = m.fetching ? "descargando" : (m.lastOnlineCode == null ? "no usada" : "código " + m.lastOnlineCode);
        out.add("Red: " + (m.connectionAvailable() ? "móvil conectado" : "sin móvil") + " · " + online);
        var st = System.getSystemStats();
        out.add("Memoria: " + (st.usedMemory / 1024) + " / " + (st.totalMemory / 1024) + " KB");
        return out;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var f = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(f);
        var l = lines();
        var y = (h - (l.size() + 1) * fh) / 2;
        dc.setColor(0xFFD17A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, f, "DIAGNÓSTICO", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xD9EFF6, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < l.size(); i++) {
            y += fh;
            var dy = (y + fh / 2 - h / 2).abs();
            var half = Math.sqrt((h / 2) * (h / 2) - dy * dy) * 0.92;
            dc.drawText(w / 2, y, f, fit(dc, l[i], f, half * 2), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function fit(dc, s as String, f, width) as String {
        if (dc.getTextWidthInPixels(s, f) <= width) { return s; }
        var n = s.length();
        while (n > 1 && dc.getTextWidthInPixels(s.substring(0, n) + "…", f) > width) { n--; }
        return s.substring(0, n) + "…";
    }
}

class DiagnosticDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
