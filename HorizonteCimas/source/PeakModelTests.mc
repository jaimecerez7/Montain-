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
