import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Esfera «Óleo»: pincelada al óleo naranja con la hora como cartela y los datos en el crema.
class OleoApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new OleoView()];
    }
}

class OleoView extends WatchUi.WatchFace {
    const OLEO = 8;
    var data as FaceData;
    var themes as Themes or Null = null;
    var sleeping = false;
    var burnIn = false;

    function initialize() {
        WatchFace.initialize();
        data = new FaceData();
        var ds = System.getDeviceSettings();
        burnIn = (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        // Mismo orden de fuentes que Themes espera; las que Óleo no usa van vacías.
        var t = new Themes([WatchUi.loadResource(Rez.Fonts.Time), null, null,
            WatchUi.loadResource(Rez.Fonts.Label), WatchUi.loadResource(Rez.Fonts.Small),
            WatchUi.loadResource(Rez.Fonts.Mini), null, WatchUi.loadResource(Rez.Fonts.Timesb),
            WatchUi.loadResource(Rez.Fonts.Timesl)]);
        try { t.bg = WatchUi.loadResource(Rez.Drawables.BgOleo); } catch (ex) { t.bg = null; }
        themes = t;
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
            t.draw(dc, OLEO, data);
        }
    }

    function onEnterSleep() as Void { sleeping = true; WatchUi.requestUpdate(); }
    function onExitSleep() as Void { sleeping = false; WatchUi.requestUpdate(); }
}
