import Toybox.Lang;
import Toybox.Math;

// Cálculos geográficos: distancia, rumbo y ángulo de elevación aparente.
module GeoMath {
    const EARTH_R = 6371000.0d;
    const REFRACTION = 0.13d;   // coeficiente de refracción atmosférica típico

    function rad(d) {
        return d.toDouble() * Math.PI / 180.0d;
    }

    // Distancia (m) por la fórmula del haversine
    function distance(lat1, lon1, lat2, lon2) {
        var p1 = rad(lat1);
        var p2 = rad(lat2);
        var dp = p2 - p1;
        var dl = rad(lon2 - lon1);
        var a = Math.sin(dp / 2) * Math.sin(dp / 2)
              + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
        // Proteger la raíz de pequeños errores de redondeo flotante.
        if (a < 0.0d) { a = 0.0d; }
        if (a > 1.0d) { a = 1.0d; }
        return 2 * EARTH_R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    // Rumbo inicial (0..360, 0 = norte)
    function bearing(lat1, lon1, lat2, lon2) {
        var p1 = rad(lat1);
        var p2 = rad(lat2);
        var dl = rad(lon2 - lon1);
        var y = Math.sin(dl) * Math.cos(p2);
        var x = Math.cos(p1) * Math.sin(p2) - Math.sin(p1) * Math.cos(p2) * Math.cos(dl);
        return norm360(Math.toDegrees(Math.atan2(y, x)));
    }

    // Ángulo sobre el horizonte (grados) teniendo en cuenta curvatura y refracción
    function elevationAngle(dh, d) {
        if (d < 1) { d = 1; }
        var drop = d * d / (2 * EARTH_R) * (1 - REFRACTION);
        return Math.toDegrees(Math.atan2(dh - drop, d));
    }

    function norm360(a) {
        while (a < 0) { a += 360; }
        while (a >= 360) { a -= 360; }
        return a;
    }

    // Diferencia angular a - b en el rango -180..180
    function diff(a, b) {
        var d = a - b;
        while (d > 180) { d -= 360; }
        while (d < -180) { d += 360; }
        return d;
    }
}
