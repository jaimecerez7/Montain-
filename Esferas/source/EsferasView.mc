import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class EsferasView extends WatchUi.WatchFace {
    var data as FaceData;
    var themes as Themes or Null = null;
    var theme = 0;
    var sleeping = false;
    var burnIn = false;
    var lastWidth = 0;

    function initialize() {
        WatchFace.initialize();
        data = new FaceData();
        var ds = System.getDeviceSettings();
        burnIn = (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
        loadSettings();
    }

    function loadSettings() as Void {
        var t = null;
        try { t = Application.Properties.getValue("Theme"); } catch (ex) {}
        theme = t instanceof Number && t >= 0 && t <= 4 ? t : 0;
        loadArt();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        themes = new Themes(WatchUi.loadResource(Rez.Fonts.Time), WatchUi.loadResource(Rez.Fonts.Timem),
            WatchUi.loadResource(Rez.Fonts.Data), WatchUi.loadResource(Rez.Fonts.Label));
        loadArt();
    }

    // Solo se carga la obra del estilo activo (y la retícula si es Retícula).
    function loadArt() as Void {
        var t = themes;
        if (t == null) { return; }
        t.bg = null;
        t.grid = null;
        try {
            var ids = [Rez.Drawables.BgCintaVerde, Rez.Drawables.BgCintaAmbar, Rez.Drawables.BgBloques,
                Rez.Drawables.BgReticula, Rez.Drawables.BgCollage];
            t.bg = WatchUi.loadResource(ids[theme]);
            if (theme == 3) { t.grid = WatchUi.loadResource(Rez.Drawables.Grid); }
        } catch (ex) {
            // Sin memoria para la obra: la esfera sigue funcionando con fondo liso.
            t.bg = null;
            t.grid = null;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        Draw.k = w / 390.0;
        var t = themes;
        if (t == null) { return; }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        data.update();
        if (sleeping && burnIn) {
            t.aod(dc, data, System.getClockTime().min);
        } else {
            t.draw(dc, theme, data);
        }
    }

    function onEnterSleep() as Void {
        sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        sleeping = false;
        WatchUi.requestUpdate();
    }
}
