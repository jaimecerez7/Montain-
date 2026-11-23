import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function geographicReferences(logger as Test.Logger) as Boolean {
    Test.assert(GeoMath.distance(0, 179.9, 0, -179.9) < 23000);
    Test.assert(GeoMath.distance(0, 179.9, 0, -179.9) > 22000);
    Test.assert(GeoMath.diff(359, 1) == -2);
    Test.assert(GeoMath.diff(1, 359) == 2);
    return true;
}

(:test)
function peakValidation(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    var peak = model.readPeak("Cumbre", "40.785", "-4.007", "1234,5 m");
    Test.assert(peak != null && peak[3] == 1234.5);
    Test.assert(model.readPeak("Cumbre", "91", "-4.007", "1234") == null);
    Test.assert(model.readPeak("Cumbre", "40.785", "-4.007", "unknown 1234") == null);
    Test.assert(model.parseNum("1234 m altitud") == null);
    Test.assert(model.parseNum("1 234") == null);
    Test.assert(model.parseNum("  -123,5 m  ") == -123.5);
    return true;
}

(:test)
function cacheRange(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    model.dataLat = 40.785;
    model.dataLon = -4.007;
    model.refreshLocalData();
    Test.assert(!model.localData);
    model.lat = 40.785;
    model.lon = -4.007;
    model.refreshLocalData();
    Test.assert(model.localData);
    model.lat = 40.9;
    model.refreshLocalData();
    Test.assert(!model.localData);
    return true;
}

(:test)
function overpassBands(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    var band = model.queryBand(3000, 10000, 32, "40.78500", "-4.00700");
    Test.assert(band.find("(around:10000,40.78500,-4.00700);-node") != null);
    Test.assert(band.find("(around:3000,40.78500,-4.00700););") != null);
    Test.assert(band.find("out tags 32;") != null);
    return true;
}

(:test)
function overpassScaling(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    Test.assert(model.buildQuery("40.78500", "-4.00700").find("out tags 24;") != null);
    model.limitDivisor = 2;
    var q = model.buildQuery("40.78500", "-4.00700");
    Test.assert(q.find("out tags 12;") != null);
    Test.assert(q.find("out tags 18;") != null);
    model.limitDivisor = 64;
    Test.assert(model.scaled(24) == 1);
    return true;
}

(:test)
function retryPolicy(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    Test.assert(model.retryAction(406) == :mirror);
    Test.assert(model.retryAction(429) == :mirror);
    Test.assert(model.retryAction(-300) == :mirror);
    Test.assert(model.retryAction(-104) == null);     // sin móvil: no cambiar de servidor
    Test.assert(model.retryAction(-402) == :smaller);
    model.endpointTries = model.endpoints.size() - 1;
    Test.assert(model.retryAction(503) == null);      // ya se probaron todos
    model.limitDivisor = 4;
    Test.assert(model.retryAction(-403) == null);
    Test.assert(model.errorMessage(-104).equals("Sin conexión con el móvil"));
    Test.assert(model.errorMessage(404).find("404") != null);
    return true;
}

(:test)
function occlusionHint(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    // [rumbo, ángulo, distancia, elevación, nombre, oculta]
    var g = [
        [10.0, 1.0, 20000.0, 2500.0, "Lejana tapada", false],
        [11.0, 5.0, 3000.0, 1800.0, "Cercana alta", false],
        [40.0, 2.0, 25000.0, 2600.0, "Lejana libre", false],
        [359.5, 0.5, 30000.0, 2400.0, "Tras el norte", false],
        [0.5, 3.0, 5000.0, 1700.0, "Norte cercana", false]
    ] as Array<Array>;
    model.sortCandidates(g, true);
    model.markHidden(g);
    for (var i = 0; i < g.size(); i++) {
        var name = g[i][4];
        if (name.equals("Lejana tapada") || name.equals("Tras el norte")) {
            Test.assert(g[i][5] == true);
        } else {
            Test.assert(g[i][5] == false);
        }
    }
    return true;
}

(:test)
function distanceFormat(logger as Test.Logger) as Boolean {
    var view = new HorizonteCimasView(new PeakModel());
    Test.assert(view.fmtDist(850).equals("850 m"));
    Test.assert(view.fmtDist(4249).equals("4,2 km"));
    Test.assert(view.fmtDist(9960).equals("10 km"));
    Test.assert(view.fmtDist(19500).equals("20 km"));
    return true;
}

// ---------------------------------------------------------------------------
// Pruebas offline: no usan red ni GPS real. Se ejecutan en el simulador con
//   monkeydo HorizonteCimas-tests.prg fr165 -t
// (con la conexión del simulador desactivada deben pasar igual).

(:typecheck(false))
function findPeak(model as PeakModel, name as String) {
    for (var i = 0; i < model.geom.size(); i++) {
        var n = model.geom[i][4];
        if (n.find(name) != null) { return model.geom[i]; }
    }
    return null;
}

(:test :typecheck(false))
function offlineCoverage(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    Test.assert(model.inCoverage(40.7417, -4.0567));     // Cercedilla
    Test.assert(model.inCoverage(40.9481, -4.1184));     // Segovia (acueducto)
    Test.assert(model.inCoverage(41.3, -3.4));           // Sierra de Ayllón
    Test.assert(!model.inCoverage(40.4168, -3.7038));    // Madrid centro (fuera)
    Test.assert(!model.inCoverage(43.263, -2.935));      // Bilbao
    Test.assert(!model.inCoverage(null, null));
    logger.debug("Base offline: " + PeakTiles.COUNT + " cimas, versión " + PeakTiles.VERSION);
    Test.assert(PeakTiles.COUNT > 50);
    return true;
}

(:test :typecheck(false))
function offlineLoadCercedilla(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    model.lat = 40.7417;
    model.lon = -4.0567;
    model.altitudeOk = true;
    model.alt = 1200.0;
    Test.assert(model.loadOffline());
    logger.debug("Cercedilla: " + model.peaks.size() + " cimas, " + model.offlineTiles + " teselas, "
        + model.offlineCandidates + " candidatas, " + model.offlineLoadMs + " ms");
    Test.assert(model.dataSource == 1);
    Test.assert(model.localData);
    Test.assert(model.peaks.size() >= 12 && model.peaks.size() <= model.BIG_MAX);   // solo grandes
    Test.assert(model.geom.size() > 0);
    // Peñalara (2428 m) está a ~15 km al NNE de Cercedilla.
    var pen = findPeak(model, "Peñalara");
    Test.assert(pen != null);
    if (pen != null) {
        logger.debug("Peñalara: " + pen[2].toNumber() + " m, rumbo " + pen[0].toNumber() + "°");
        Test.assert(pen[2] > 12000 && pen[2] < 18000);
        Test.assert(pen[0] > 20 && pen[0] < 50);
        Test.assert(pen[3] > 2400 && pen[3] < 2450);
        Test.assert(pen[1] > 2);   // casi 1200 m más alta: varios grados sobre el horizonte
    }
    return true;
}

(:test :typecheck(false))
function offlineStartsWithoutNetwork(logger as Test.Logger) as Boolean {
    // Simula el arranque: primera posición (aunque sea la última conocida) dentro de la zona.
    var model = new PeakModel();
    model.peaks = [];
    model.dataLat = null;
    model.dataLon = null;
    model.dataSource = 0;
    model.applyPosition(40.9481, -4.1184, null, false);   // Segovia, sin altitud ni fijo GPS
    Test.assert(model.localData);
    Test.assert(model.dataSource == 1);
    Test.assert(!model.fetching);                           // no se ha pedido nada a Internet
    Test.assert(model.geom.size() > 0);
    // Moverse 2 km no recarga; moverse 10 km sí.
    var loads = model.offlineLoads;
    model.applyPosition(40.9661, -4.1184, 1000.0, true);
    Test.assert(model.offlineLoads == loads);
    model.applyPosition(41.0381, -4.1184, 1000.0, true);
    Test.assert(model.offlineLoads == loads + 1);
    return true;
}

(:test :typecheck(false))
function offlineOutsideZone(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    model.peaks = [];
    model.dataSource = 0;
    model.lat = 43.263;
    model.lon = -2.935;
    Test.assert(!model.loadOffline());
    Test.assert(model.peaks.size() == 0);
    Test.assert(model.dataSource == 0);
    return true;
}

(:test :typecheck(false))
function offlineSelectionOrder(logger as Test.Logger) as Boolean {
    var model = new PeakModel();
    var near = [] as Array<Array>;
    for (var i = 0; i < 120; i++) {
        near.add([9900.0 - i * 80, ["c" + i, 40.8 + i * 0.0005, -4.0, 1500.0]]);
    }
    var far = [[2.0, ["lejana alta", 41.1, -4.0, 2400.0]], [-1.0, ["lejana baja", 41.1, -3.9, 1200.0]]];
    var list = model.choosePeaks(near, far, 40.8, -4.0);
    Test.assert(list.size() == 100);
    var names = "";
    for (var i = 0; i < list.size(); i++) { names += list[i][0] + ","; }
    Test.assert(names.find("lejana alta") != null);   // una lejana relevante entra antes que cercanas sobrantes
    Test.assert(names.find("c119,") != null);          // la más cercana siempre entra
    return true;
}

(:test :typecheck(false))
function offlineSegoviaBigPeaks(logger as Test.Logger) as Boolean {
    // Desde Segovia ciudad: solo las grandes de Guadarrama, sin los cerros de al lado.
    var model = new PeakModel();
    model.onlyBig = true;
    model.lat = 40.9481;
    model.lon = -4.1184;
    model.altitudeOk = true;
    model.alt = 1000.0;
    Test.assert(model.loadOffline());
    var names = "";
    for (var i = 0; i < model.peaks.size(); i++) { names += model.peaks[i][0] + ","; }
    logger.debug("Segovia: " + model.peaks.size() + " cimas: " + names);
    Test.assert(model.peaks.size() >= 12 && model.peaks.size() <= model.BIG_MAX);
    Test.assert(names.find("Peñalara") != null);
    Test.assert(names.find("Siete Picos") != null);
    Test.assert(names.find("Montón de Trigo") != null);
    Test.assert(names.find("Cabeza de Hierro Mayor") != null);
    Test.assert(names.find("Cerro Torralbo") == null);   // 1049 m, a 3 km: no es «grande»
    var pen = findPeak(model, "Peñalara");
    Test.assert(pen != null);
    if (pen != null) {
        logger.debug("Peñalara desde Segovia: " + (pen[2] / 1000).toNumber() + " km, rumbo " + pen[0].toNumber() + "°");
        Test.assert(pen[0] > 115 && pen[0] < 140);   // al SE
    }
    // Con «todas las cimas» vuelven las pequeñas.
    model.setOnlyBig(false);
    Test.assert(model.peaks.size() > 50);
    return true;
}

(:test :typecheck(false))
function savedPositionWithoutGps(logger as Test.Logger) as Boolean {
    // Arranque en casa sin GPS: usa la última posición guardada y carga offline.
    Application.Storage.setValue("lastPos", [40.9481, -4.1184]);
    var model = new PeakModel();
    model.lat = null;
    model.peaks = [];
    model.dataLat = null;
    model.dataSource = 0;
    Test.assert(model.useSavedPosition());
    Test.assert(model.usingSavedPos);
    Test.assert(model.dataSource == 1);
    Test.assert(model.peaks.size() > 0);
    Test.assert(!model.fetching);
    Application.Storage.deleteValue("lastPos");
    var m2 = new PeakModel();
    m2.reloadOffline();
    Test.assert(m2.status.equals(m2.NO_FIX_YET));       // sin GPS ni posición: no dice «fuera de zona»
    return true;
}
