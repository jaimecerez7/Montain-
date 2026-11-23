import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Esfera «Collage»: papeles pintados, tinta y puntos; la hora en papel recortado que salta.
// Tres composiciones que rotan cada día.
class CollageApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new CollageView()];
    }
}

class CollageView extends WatchUi.WatchFace {
    const COLLAGE = 4;
    var data as FaceData;
    var themes as Themes or Null = null;
    var sleeping = false;
    var burnIn = false;
    var loadedVariant = -1;
    var loadedMoon = -1;

    function initialize() {
        WatchFace.initialize();
        data = new FaceData();
        var ds = System.getDeviceSettings();
        burnIn = (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        // Mismo orden de fuentes que Themes espera; las que Collage no usa van vacías.
        var t = new Themes([WatchUi.loadResource(Rez.Fonts.Time), null, null,
            WatchUi.loadResource(Rez.Fonts.Label), WatchUi.loadResource(Rez.Fonts.Small),
            WatchUi.loadResource(Rez.Fonts.Mini), null, null, null]);
        try {
            var ids = [Rez.Drawables.GlyphCo0, Rez.Drawables.GlyphCo1, Rez.Drawables.GlyphCo2,
                Rez.Drawables.GlyphCo3, Rez.Drawables.GlyphCo4, Rez.Drawables.GlyphCo5,
                Rez.Drawables.GlyphCo6, Rez.Drawables.GlyphCo7, Rez.Drawables.GlyphCo8,
                Rez.Drawables.GlyphCo9, Rez.Drawables.GlyphCo10];
            var g = [];
            for (var i = 0; i < ids.size(); i++) { g.add(WatchUi.loadResource(ids[i])); }
            t.glyphs = g;
        } catch (ex) {}
        themes = t;
    }

    // Composición del día y luna de la fase actual: solo se recargan cuando cambian.
    function loadArt(t as Themes) as Void {
        try {
            var v = data.dayIndex % 3;
            if (v != loadedVariant) {
                var bgs = [Rez.Drawables.BgCollage, Rez.Drawables.BgCollage2, Rez.Drawables.BgCollage3];
                t.bg = null;
                t.bg = WatchUi.loadResource(bgs[v]);
                loadedVariant = v;
            }
            if (data.moonIdx != loadedMoon) {
                var moons = [Rez.Drawables.Moon0, Rez.Drawables.Moon1, Rez.Drawables.Moon2, Rez.Drawables.Moon3,
                    Rez.Drawables.Moon4, Rez.Drawables.Moon5, Rez.Drawables.Moon6, Rez.Drawables.Moon7];
                t.moonBmp = WatchUi.loadResource(moons[data.moonIdx]);
                loadedMoon = data.moonIdx;
            }
        } catch (ex) {}
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.k = dc.getWidth() / 390.0;
        var t = themes;
        if (t == null) { return; }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        data.update();
        if (sleeping && burnIn) {
            t.aod(dc, data, System.getClockTime().min);
        } else {
            loadArt(t);
            t.draw(dc, COLLAGE, data);
        }
    }

    function onEnterSleep() as Void { sleeping = true; WatchUi.requestUpdate(); }
    function onExitSleep() as Void { sleeping = false; WatchUi.requestUpdate(); }
}
