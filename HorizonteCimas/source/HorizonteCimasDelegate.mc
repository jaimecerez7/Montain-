import Toybox.Lang;
import Toybox.WatchUi;

// SELECT / START: volver a descargar cimas
// ARRIBA / ABAJO (o deslizar): girar a mano (modo manual, para relojes sin brújula)
// MENÚ (mantener ARRIBA): volver a la brújula
class HorizonteCimasDelegate extends WatchUi.BehaviorDelegate {
    var model;

    function initialize(m) {
        BehaviorDelegate.initialize();
        model = m;
    }

    function onSelect() as Boolean {
        model.forceFetch();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        rotate(10);
        return true;
    }

    function onPreviousPage() as Boolean {
        rotate(-10);
        return true;
    }

    function onMenu() as Boolean {
        model.useCompass = true;
        WatchUi.requestUpdate();
        return true;
    }

    function rotate(step) as Void {
        if (model.useCompass) {
            model.useCompass = false;
            model.manualHeading = model.lastHeading;
        }
        model.manualHeading = GeoMath.norm360(model.manualHeading + step);
        WatchUi.requestUpdate();
    }
}
