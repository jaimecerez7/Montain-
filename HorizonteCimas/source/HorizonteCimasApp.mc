import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

class HorizonteCimasApp extends Application.AppBase {
    var model as PeakModel;

    function initialize() {
        AppBase.initialize();
        model = new PeakModel();
    }

    function onStart(state as Dictionary?) as Void {
        model.onPosition(Position.getInfo());   // última posición conocida
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
    }

    function onPosition(info as Position.Info) as Void {
        var previousGeometry = model.geom;
        var previousStatus = model.status;
        var previousAltitude = model.altitudeOk;
        var previousLocal = model.localData;
        model.onPosition(info);
        if (previousGeometry != model.geom || previousStatus != model.status
            || previousAltitude != model.altitudeOk || previousLocal != model.localData) {
            WatchUi.requestUpdate();
        }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new HorizonteCimasView(model), new HorizonteCimasDelegate(model)];
    }
}
