import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class EsferasApp extends Application.AppBase {
    var view as EsferasView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new EsferasView();
        view = v;
        return [v];
    }

    // Cambio de estilo desde Garmin Connect (Ajustes de la esfera).
    function onSettingsChanged() as Void {
        var v = view;
        if (v != null) { v.loadSettings(); }
        WatchUi.requestUpdate();
    }
}
