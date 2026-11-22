import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

class RadarVuelosApp extends Application.AppBase {
    var model as FlightModel;
    var view as RadarView or Null = null;

    function initialize() {
        AppBase.initialize();
        model = new FlightModel();
    }

    function onStart(state as Dictionary?) as Void {
        model.onPosition(Position.getInfo());   // última posición conocida
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
    }

    function onPosition(info as Position.Info) as Void {
        model.onPosition(info);
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new RadarView(model);
        view = v;
        return [v, new RadarDelegate(model, v)];
    }
}
