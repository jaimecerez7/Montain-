import Toybox.Lang;
import Toybox.WatchUi;

// SELECT / START: actualizar por Internet (opcional; la base offline ya basta en Segovia y Guadarrama)
// ARRIBA / ABAJO (o deslizar): girar a mano (modo manual, para relojes sin brújula)
// MENÚ (mantener ARRIBA): brújula, actualización online, recarga offline y diagnóstico
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
        var menu = new WatchUi.Menu2({:title => "Horizonte Cimas"});
        menu.addItem(new WatchUi.MenuItem("Reactivar brújula", null, :compass, null));
        menu.addItem(new WatchUi.MenuItem("Actualizar online", "Opcional", :online, null));
        menu.addItem(new WatchUi.MenuItem("Recargar offline", "Segovia y Guadarrama", :offline, null));
        menu.addItem(new WatchUi.MenuItem("Diagnóstico", null, :diag, null));
        WatchUi.pushView(menu, new HorizonteCimasMenuDelegate(model), WatchUi.SLIDE_UP);
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

class HorizonteCimasMenuDelegate extends WatchUi.Menu2InputDelegate {
    var model;

    function initialize(m) {
        Menu2InputDelegate.initialize();
        model = m;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :diag) {
            WatchUi.switchToView(new DiagnosticView(model), new DiagnosticDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :compass) {
            model.useCompass = true;
        } else if (id == :online) {
            model.forceFetch();
        } else if (id == :offline) {
            if (!model.loadOffline()) { model.status = "Fuera de la zona offline"; }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}
