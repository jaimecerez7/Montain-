import Toybox.Lang;
import Toybox.WatchUi;

// START / SELECT: fijar o soltar el avión seleccionado
// ARRIBA / ABAJO: alcance del radar (10 / 25 / 50 km)
// MENÚ (mantener ARRIBA): alternar brújula / norte arriba
class RadarDelegate extends WatchUi.BehaviorDelegate {
    var model as FlightModel;
    var view as RadarView;

    function initialize(m as FlightModel, v as RadarView) {
        BehaviorDelegate.initialize();
        model = m;
        view = v;
    }

    function onSelect() as Boolean {
        view.toggleLock();
        return true;
    }

    function onPreviousPage() as Boolean {
        view.changeRange(-1);
        return true;
    }

    function onNextPage() as Boolean {
        view.changeRange(1);
        return true;
    }

    function onMenu() as Boolean {
        model.useCompass = !model.useCompass;
        WatchUi.requestUpdate();
        return true;
    }
}
