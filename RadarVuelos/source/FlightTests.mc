import Toybox.Lang;
import Toybox.Test;

(:test)
function adsbParsing(logger as Test.Logger) as Boolean {
    var model = new FlightModel();
    var data = {
        "ac" => [
            {"hex" => "344346", "flight" => "IBE0258 ", "r" => "EC-LYF", "t" => "A333",
             "alt_baro" => 35000, "alt_geom" => 35500, "gs" => 450.0, "track" => 90.0,
             "lat" => 40.5, "lon" => -3.5, "seen_pos" => 2.0},
            {"hex" => "~341382", "flight" => "TR71    ", "alt_baro" => "ground",
             "gs" => 3.2, "lat" => 40.45, "lon" => -3.57},
            {"hex" => "abc123", "alt_baro" => 1200, "lat" => 40.6, "lon" => -3.6}
        ]
    };
    var list = model.parseAdsb(data, 100000);
    Test.assert(list.size() == 2);                 // el de tierra se descarta
    Test.assert(list[0][1].equals("IBE0258"));
    Test.assert(list[0][4] > 10800 && list[0][4] < 10830);   // 35500 ft ≈ 10820 m
    Test.assert(list[0][9] == 98000);              // posición vista hace 2 s
    Test.assert(list[1][1].equals("ABC123"));      // sin indicativo: código hex
    Test.assert(model.parseAdsb({"msg" => "x"}, 0) == null);
    return true;
}

(:test)
function openSkyParsing(logger as Test.Logger) as Boolean {
    var model = new FlightModel();
    var data = {"time" => 1000, "states" => [
        ["4ca7b3", "RYR5RL  ", "Ireland", 995, 999, -3.6, 40.4, 3000.0, false, 120.0, 45.0, 0, null, 3050.0],
        ["341382", "TR71    ", "Spain", 990, 999, -3.57, 40.45, null, true, 1.0, 10.0, 0, null, null]
    ]};
    var list = model.parseOpenSky(data, 50000);
    Test.assert(list.size() == 1);
    Test.assert(list[0][1].equals("RYR5RL"));
    Test.assert(list[0][4] == 3050.0);
    Test.assert(list[0][9] == 45000);
    Test.assert(model.parseOpenSky({"time" => 1, "states" => null}, 0).size() == 0);
    return true;
}

(:test)
function deadReckoning(logger as Test.Logger) as Boolean {
    var model = new FlightModel();
    // 100 m/s hacia el este durante 10 s: ~1 km al este.
    var p = model.extrapolate(["h", "X", 40.0, -3.0, 1000.0, 100.0, 90.0, "", "", 0], 10000);
    var d = GeoMath.distance(40.0, -3.0, p[0], p[1]);
    Test.assert(d > 990 && d < 1010);
    Test.assert(GeoMath.bearing(40.0, -3.0, p[0], p[1]) > 89 && GeoMath.bearing(40.0, -3.0, p[0], p[1]) < 91);
    var q = model.extrapolate(["h", "X", 40.0, -3.0, 1000.0, 100.0, 90.0, "", "", 0], 600000);
    Test.assert(GeoMath.distance(40.0, -3.0, q[0], q[1]) < 6100);   // máx. 60 s
    return true;
}

(:test)
function airlineNames(logger as Test.Logger) as Boolean {
    Test.assert(Airlines.airline("IBE0258").equals("Iberia"));
    Test.assert(Airlines.airline("VLG12AB").equals("Vueling"));
    Test.assert(Airlines.airline("EC-LYF").equals(""));
    Test.assert(Airlines.airline("TR71").equals(""));
    Test.assert(Airlines.typeName("A20N").equals("A320neo"));
    Test.assert(Airlines.typeName("ZZZZ").equals("ZZZZ"));
    return true;
}

(:test)
function textHelpers(logger as Test.Logger) as Boolean {
    var model = new FlightModel();
    Test.assert(model.trim("  IBE1 ").equals("IBE1"));
    Test.assert(model.trim(null).equals(""));
    Test.assert(model.adsbUrl(40.4712, -3.5601, 25).equals("https://api.adsb.lol/v2/point/40.47/-3.56/25"));
    return true;
}

(:test)
function overheadAlertOnce(logger as Test.Logger) as Boolean {
    var model = new FlightModel();
    model.overheadAlerts = true;
    model.lat = 40.0;
    model.lon = -3.0;
    // Avión a 3000 m de altura casi en la vertical: elevación > 60°.
    model.aircraft = [["abc", "IBE1", 40.001, -3.0, 3000.0, 0.0, 0.0, "", "", 0]];
    model.updateGeometry(0);
    Test.assert(model.geom[0][2] > 60);
    Test.assert(model.alerted.size() == 1);
    model.updateGeometry(500);
    Test.assert(model.alerted.size() == 1);   // no repite el aviso
    return true;
}
