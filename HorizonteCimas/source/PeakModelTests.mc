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
