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
        theme = t instanceof Number && t >= 0 && t <= 2 ? t : 0;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        themes = new Themes(WatchUi.loadResource(Rez.Fonts.Time), WatchUi.loadResource(Rez.Fonts.Data),
            WatchUi.loadResource(Rez.Fonts.Label));
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        Draw.k = w / 390.0;
        var t = themes;
        if (t == null) { return; }
        if (w != lastWidth) { t.resetCache(); lastWidth = w; }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        data.update();
        if (sleeping && burnIn) {
            t.aod(dc, data, System.getClockTime().min);
        } else if (theme == 1) {
            t.organica(dc, data);
        } else if (theme == 2) {
            t.trazos(dc, data);
        } else {
            t.campos(dc, data);
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
