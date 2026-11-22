import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Ajustes en el propio reloj (mantener pulsada la esfera → Personalizar / Ajustes):
// lista de obras para elegir sin pasar por Garmin Connect.
module EsferasObras {
    // [valor de la propiedad Theme, nombre]
    function list() as Array<Array> {
        return [[8, "Óleo"], [7, "Ola"], [4, "Collage"], [6, "Geometría"], [0, "Cinta verde"],
            [1, "Cinta ámbar"], [2, "Bloques"], [5, "Cielo pintado"], [3, "Retícula (pasos)"]];
    }
}

class EsferasSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Obra"});
        var current = null;
        try { current = Application.Properties.getValue("Theme"); } catch (ex) {}
        var l = EsferasObras.list();
        for (var i = 0; i < l.size(); i++) {
            addItem(new WatchUi.MenuItem(l[i][1], l[i][0] == current ? "Actual" : null, l[i][0], null));
        }
    }
}

class EsferasSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        try { Application.Properties.setValue("Theme", item.getId() as Number); } catch (ex) {}
        var app = Application.getApp();
        if (app has :onSettingsChanged) { app.onSettingsChanged(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
