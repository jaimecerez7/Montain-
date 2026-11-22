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
        t.glyphs = [];
        try {
            var ids = [Rez.Drawables.BgCintaVerde, Rez.Drawables.BgCintaAmbar, Rez.Drawables.BgBloques,
                Rez.Drawables.BgReticula, Rez.Drawables.BgCollage];
            t.bg = WatchUi.loadResource(ids[theme]);
            if (theme == 3) { t.grid = WatchUi.loadResource(Rez.Drawables.Grid); }
            var sets = [
                [Rez.Drawables.GlyphCv0, Rez.Drawables.GlyphCv1, Rez.Drawables.GlyphCv2, Rez.Drawables.GlyphCv3,
                 Rez.Drawables.GlyphCv4, Rez.Drawables.GlyphCv5, Rez.Drawables.GlyphCv6, Rez.Drawables.GlyphCv7,
                 Rez.Drawables.GlyphCv8, Rez.Drawables.GlyphCv9, Rez.Drawables.GlyphCv10],
                [Rez.Drawables.GlyphCa0, Rez.Drawables.GlyphCa1, Rez.Drawables.GlyphCa2, Rez.Drawables.GlyphCa3,
                 Rez.Drawables.GlyphCa4, Rez.Drawables.GlyphCa5, Rez.Drawables.GlyphCa6, Rez.Drawables.GlyphCa7,
                 Rez.Drawables.GlyphCa8, Rez.Drawables.GlyphCa9, Rez.Drawables.GlyphCa10],
                [Rez.Drawables.GlyphBl0, Rez.Drawables.GlyphBl1, Rez.Drawables.GlyphBl2, Rez.Drawables.GlyphBl3,
                 Rez.Drawables.GlyphBl4, Rez.Drawables.GlyphBl5, Rez.Drawables.GlyphBl6, Rez.Drawables.GlyphBl7,
                 Rez.Drawables.GlyphBl8, Rez.Drawables.GlyphBl9, Rez.Drawables.GlyphBl10],
                [Rez.Drawables.GlyphRe0, Rez.Drawables.GlyphRe1, Rez.Drawables.GlyphRe2, Rez.Drawables.GlyphRe3,
                 Rez.Drawables.GlyphRe4, Rez.Drawables.GlyphRe5, Rez.Drawables.GlyphRe6, Rez.Drawables.GlyphRe7,
                 Rez.Drawables.GlyphRe8, Rez.Drawables.GlyphRe9, Rez.Drawables.GlyphRe10],
                [Rez.Drawables.GlyphCo0, Rez.Drawables.GlyphCo1, Rez.Drawables.GlyphCo2, Rez.Drawables.GlyphCo3,
                 Rez.Drawables.GlyphCo4, Rez.Drawables.GlyphCo5, Rez.Drawables.GlyphCo6, Rez.Drawables.GlyphCo7,
                 Rez.Drawables.GlyphCo8, Rez.Drawables.GlyphCo9, Rez.Drawables.GlyphCo10]
            ];
            var g = [];
            for (var i = 0; i < 11; i++) { g.add(WatchUi.loadResource(sets[theme][i])); }
            t.glyphs = g;
        } catch (ex) {
            // Sin memoria para la obra: la esfera sigue funcionando con fondo liso.
            t.bg = null;
            t.grid = null;
            t.glyphs = [];
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
