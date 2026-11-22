import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Timer;
import Toybox.WatchUi;

// GPS: continuo solo hasta el primer fijo bueno; después, una lectura cada 2 min.
// Para aviones a decenas de km, unos cientos de metros de error no se notan,
// y el GPS continuo es lo que más batería gasta.
class RadarVuelosApp extends Application.AppBase {
    const FIX_REFRESH_MS = 120000;

    var model as FlightModel;
    var positionTimer;
    var continuous = false;

    function initialize() {
        AppBase.initialize();
        model = new FlightModel();
        positionTimer = new Timer.Timer();
    }

    function onStart(state as Dictionary?) as Void {
        model.onPosition(Position.getInfo());   // última posición conocida
        continuous = true;
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onStop(state as Dictionary?) as Void {
        positionTimer.stop();
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
    }

    function onPosition(info as Position.Info) as Void {
        model.onPosition(info);
        if (continuous && info != null && info.accuracy != null
            && info.accuracy >= Position.QUALITY_USABLE) {
            continuous = false;
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            positionTimer.start(method(:refreshFix), FIX_REFRESH_MS, true);
        }
    }

    function refreshFix() as Void {
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new RadarView(model);
        return [v, new RadarDelegate(model, v)];
    }
}
