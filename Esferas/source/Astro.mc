import Toybox.Lang;
import Toybox.Math;

// Sol (algoritmo de la NOAA) y Luna (edad sinódica). Sin red: todo se calcula en el reloj.
module Astro {
    const SYNODIC = 29.530588853;
    const NEW_MOON_UNIX = 947182440;   // luna nueva de referencia: 2000-01-06 18:14 UTC

    // Ecuación del tiempo (min) y declinación (rad) para el día del año y la hora UTC.
    function solarTerms(doy as Number, hourUtc) as Array {
        var g = 2 * Math.PI / 365.0 * (doy - 1 + (hourUtc - 12) / 24.0);
        var eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
            - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        var decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g)
            - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g)
            - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        return [eqtime, decl];
    }

    // Elevación del sol (grados) en una hora local dada.
    function elevation(lat, lon, doy as Number, hourLocal, tzHours) {
        var hourUtc = hourLocal - tzHours;
        var t = solarTerms(doy, hourUtc);
        var tst = hourUtc * 60 + t[0] + 4 * lon;
        var ha = Math.toRadians(tst / 4.0 - 180);
        var phi = Math.toRadians(lat);
        var c = Math.sin(phi) * Math.sin(t[1]) + Math.cos(phi) * Math.cos(t[1]) * Math.cos(ha);
        if (c > 1) { c = 1.0; }
        if (c < -1) { c = -1.0; }
        return 90 - Math.toDegrees(Math.acos(c));
    }

    // [amanecer, atardecer] en horas locales, o null si es día o noche polar.
    function sunTimes(lat, lon, doy as Number, tzHours) as Array or Null {
        var t = solarTerms(doy, 12 - tzHours);
        var phi = Math.toRadians(lat);
        var arg = Math.cos(Math.toRadians(90.833)) / (Math.cos(phi) * Math.cos(t[1]))
            - Math.tan(phi) * Math.tan(t[1]);
        if (arg > 1 || arg < -1) { return null; }
        var ha = Math.toDegrees(Math.acos(arg));
        var rise = (720 - 4 * (lon + ha) - t[0]) / 60.0 + tzHours;
        var set = (720 - 4 * (lon - ha) - t[0]) / 60.0 + tzHours;
        return [wrap24(rise), wrap24(set)];
    }

    function wrap24(h) {
        while (h < 0) { h += 24; }
        while (h >= 24) { h -= 24; }
        return h;
    }

    // [iluminación 0..1, creciente]
    function moon(unixSeconds as Number) as Array {
        var days = (unixSeconds - NEW_MOON_UNIX) / 86400.0;
        var age = days - Math.floor(days / SYNODIC) * SYNODIC;
        var illum = (1 - Math.cos(2 * Math.PI * age / SYNODIC)) / 2;
        return [illum, age < SYNODIC / 2];
    }

    function dayOfYear(year as Number, month as Number, day as Number) as Number {
        var cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        var leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
        return cum[month - 1] + day + (leap && month > 2 ? 1 : 0);
    }
}
