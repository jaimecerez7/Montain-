import Toybox.Attention;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

// Aviones cercanos desde adsb.lol (principal) u OpenSky (reserva).
// aircraft: [hex, indicativo, lat, lon, altitud_m, velocidad_m_s, rumbo_vuelo, tipo, matricula, instante_ms]
// geom:     [rumbo_desde_ti, distancia_m, elevacion_grados, altitud_m, fila_aircraft]
class FlightModel {
    const REFRESH_MS = 10000;
    const REFRESH_EMPTY_MS = 30000;   // sin aviones cerca: preguntar menos a menudo
    const OVERHEAD_DEG = 60.0;
    const MAX_ALERTED = 20;
    const RETRY_MS = 20000;
    const MAX_AIRCRAFT = 40;
    const MAX_EXTRAPOLATE_S = 60.0;
    const KNOT_MS = 0.514444;
    const FT_M = 0.3048;
    const M_PER_DEG = 111320.0;
    const SEARCHING_GPS = "Buscando señal GPS…";

    var radiiNm as Array<Number> = [25, 15, 8];   // se reduce si el reloj no puede con la respuesta
    var radiusIndex = 0;
    var source = 0;                                // 0 = adsb.lol, 1 = OpenSky
    var failures = 0;

    var lat = null;
    var lon = null;
    var alt = 0.0;
    var altitudeOk = false;
    var aircraft as Array<Array> = [];
    var geom as Array<Array> = [];
    var status as String or Null = SEARCHING_GPS;
    var fetching = false;
    var lastAttempt = null;
    var lastSuccess = null;
    var useCompass = true;
    var lockedHex = null;
    var overheadAlerts = true;
    var alerted as Array<String> = [];   // aviones que ya avisaron al pasar por encima

    function initialize() {}

    function onPosition(info as Position.Info or Null) as Void {
        if (info == null || info.position == null || info.accuracy == null
            || info.accuracy < Position.QUALITY_LAST_KNOWN) { return; }
        var coords = info.position.toDegrees();
        if (coords[0] == 0 && coords[1] == 0) { return; }
        lat = coords[0];
        lon = coords[1];
        altitudeOk = info.accuracy >= Position.QUALITY_POOR && info.altitude != null;
        alt = altitudeOk ? info.altitude : 0.0;
        var st = status;
        if (st != null && st.equals(SEARCHING_GPS)) { status = "Buscando aviones…"; }
    }

    // Se llama en cada fotograma: lanza descargas periódicas y mueve los aviones.
    function tick(now as Number) as Void {
        if (lat != null && !fetching) {
            var wait = failures > 0 ? RETRY_MS : (aircraft.size() == 0 ? REFRESH_EMPTY_MS : REFRESH_MS);
            if (lastAttempt == null || now < lastAttempt || now - lastAttempt >= wait) {
                fetch(now);
            }
        }
        updateGeometry(now);
    }

    function forceRefresh() as Void {
        lastAttempt = null;
        failures = 0;
    }

    function connectionAvailable() as Boolean {
        try {
            var ds = System.getDeviceSettings();
            if (ds has :connectionAvailable) { return ds.connectionAvailable; }
            return ds.phoneConnected;
        } catch (ex) {
            return true;
        }
    }

    function fetch(now as Number) as Void {
        lastAttempt = now;
        if (!connectionAvailable()) {
            status = "Conecta el móvil";
            failures++;
            return;
        }
        fetching = true;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            if (source == 0) {
                Communications.makeWebRequest(adsbUrl(lat, lon, radiiNm[radiusIndex]), null, options,
                    method(:onResponse));
            } else {
                Communications.makeWebRequest("https://opensky-network.org/api/states/all",
                    openSkyParams(lat, lon, radiiNm[radiusIndex]), options, method(:onResponse));
            }
        } catch (ex) {
            fetching = false;
            failures++;
            status = "No se pudo iniciar la descarga";
        }
    }

    // La posición se redondea a ~1 km: suficiente para un radio de decenas de km.
    function adsbUrl(la, lo, radiusNm as Number) as String {
        return "https://api.adsb.lol/v2/point/" + la.format("%.2f") + "/" + lo.format("%.2f")
            + "/" + radiusNm.toString();
    }

    function openSkyParams(la, lo, radiusNm as Number) as Dictionary {
        var dLat = radiusNm * 1852.0 / M_PER_DEG;
        var dLon = dLat / Math.cos(Math.toRadians(la));
        return {
            "lamin" => (la - dLat).format("%.3f"), "lamax" => (la + dLat).format("%.3f"),
            "lomin" => (lo - dLon).format("%.3f"), "lomax" => (lo + dLon).format("%.3f")
        };
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        fetching = false;
        var now = System.getTimer();
        if (code == 200 && data instanceof Dictionary) {
            var list = source == 0 ? parseAdsb(data as Dictionary, now) : parseOpenSky(data as Dictionary, now);
            if (list != null) {
                aircraft = keepNearest(list);
                lastSuccess = now;
                failures = 0;
                status = null;
                updateGeometry(now);
                WatchUi.requestUpdate();
                return;
            }
        }
        if ((code == -402 || code == -403) && radiusIndex < radiiNm.size() - 1) {
            radiusIndex++;            // demasiados aviones para la memoria: radio menor
            lastAttempt = null;
            return;
        }
        failures++;
        if (failures >= 2 && code != -104 && !(code <= -1 && code >= -5)) {
            source = 1 - source;      // alternar entre adsb.lol y OpenSky
            lastAttempt = null;
        }
        status = errorMessage(code);
        WatchUi.requestUpdate();
    }

    function errorMessage(code as Number) as String {
        if (code == -104 || (code <= -1 && code >= -5)) { return "Sin conexión con el móvil"; }
        if (code == -300) { return "Tiempo de espera agotado"; }
        if (code == -402 || code == -403) { return "Demasiados aviones"; }
        if (code == 429) { return "Servidor saturado"; }
        if (code == 200) { return "Respuesta no válida"; }
        if (code >= 500) { return "Servidor no disponible"; }
        return "Sin datos (" + code + ")";
    }

    function parseAdsb(data as Dictionary, now as Number) as Array or Null {
        var ac = data["ac"];
        if (!(ac instanceof Array)) { return null; }
        var list = [] as Array<Array>;
        for (var i = 0; i < ac.size(); i++) {
            var a = ac[i];
            if (!(a instanceof Dictionary)) { continue; }
            var la = num(a["lat"]);
            var lo = num(a["lon"]);
            var altFt = num(a["alt_geom"]);
            if (altFt == null) { altFt = num(a["alt_baro"]); }   // "ground" → null: en tierra
            if (la == null || lo == null || altFt == null) { continue; }
            var gs = num(a["gs"]);
            var track = num(a["track"]);
            var seen = num(a["seen_pos"]);
            var callsign = trim(a["flight"]);
            var reg = a["r"] instanceof String ? a["r"] : "";
            var type = a["t"] instanceof String ? a["t"] : "";
            var hex = a["hex"] instanceof String ? a["hex"] : "";
            if (callsign.length() == 0) { callsign = reg.length() > 0 ? reg : hex.toUpper(); }
            list.add([hex, callsign, la, lo, altFt * FT_M,
                gs == null || track == null ? 0.0 : gs * KNOT_MS,
                track == null ? 0.0 : track, type, reg,
                now - (seen == null ? 0 : (seen * 1000).toNumber())]);
        }
        return list;
    }

    // OpenSky: matrices [icao24, indicativo, país, t_pos, t_ult, lon, lat, alt_baro_m,
    //                    en_tierra, vel_m_s, rumbo, vs, sensores, alt_geo_m, ...]
    function parseOpenSky(data as Dictionary, now as Number) as Array or Null {
        var states = data["states"];
        if (states == null) { return [] as Array<Array>; }   // sin aviones
        if (!(states instanceof Array)) { return null; }
        var t = num(data["time"]);
        var list = [] as Array<Array>;
        for (var i = 0; i < states.size(); i++) {
            var s = states[i];
            if (!(s instanceof Array) || s.size() < 14 || s[8] == true) { continue; }
            var la = num(s[6]);
            var lo = num(s[5]);
            var altM = num(s[13]);
            if (altM == null) { altM = num(s[7]); }
            if (la == null || lo == null || altM == null) { continue; }
            var v = num(s[9]);
            var track = num(s[10]);
            var tpos = num(s[3]);
            var age = t != null && tpos != null ? t - tpos : 0;
            var hex = s[0] instanceof String ? s[0] : "";
            var callsign = trim(s[1]);
            if (callsign.length() == 0) { callsign = hex.toUpper(); }
            list.add([hex, callsign, la, lo, altM,
                v == null || track == null ? 0.0 : v, track == null ? 0.0 : track, "", "",
                now - (age * 1000).toNumber()]);
        }
        return list;
    }

    // Conserva los MAX_AIRCRAFT más cercanos al punto consultado.
    function keepNearest(list as Array<Array>) as Array<Array> {
        if (list.size() <= MAX_AIRCRAFT || lat == null) { return list; }
        var keyed = [] as Array<Array>;
        for (var i = 0; i < list.size(); i++) {
            keyed.add([GeoMath.distance(lat, lon, list[i][2], list[i][3]), list[i]]);
        }
        sortByFirst(keyed);
        var out = [] as Array<Array>;
        for (var i = 0; i < MAX_AIRCRAFT; i++) { out.add(keyed[i][1]); }
        return out;
    }

    // Posición estimada ahora: avanza en línea recta con su velocidad y rumbo.
    function extrapolate(row as Array, now as Number) as Array {
        var dt = (now - row[9]) / 1000.0;
        if (dt < 0) { dt = 0.0; }
        if (dt > MAX_EXTRAPOLATE_S) { dt = MAX_EXTRAPOLATE_S; }
        var d = row[5] * dt;
        var tr = Math.toRadians(row[6]);
        var la = row[2] + d * Math.cos(tr) / M_PER_DEG;
        var lo = row[3] + d * Math.sin(tr) / (M_PER_DEG * Math.cos(Math.toRadians(row[2])));
        return [la, lo];
    }

    function updateGeometry(now as Number) as Void {
        if (lat == null) { return; }
        var g = [] as Array<Array>;
        for (var i = 0; i < aircraft.size(); i++) {
            var row = aircraft[i];
            var p = extrapolate(row, now);
            var d = GeoMath.distance(lat, lon, p[0], p[1]);
            var elev = GeoMath.elevationAngle(row[4] - alt, d);
            g.add([GeoMath.bearing(lat, lon, p[0], p[1]), d, elev, row[4], row]);
            if (elev >= OVERHEAD_DEG) { alertOverhead(row[0]); }
        }
        geom = g;
    }

    // Vibración corta la primera vez que cada avión pasa por encima.
    function alertOverhead(hex as String) as Void {
        if (!overheadAlerts || alerted.indexOf(hex) >= 0) { return; }
        alerted.add(hex);
        if (alerted.size() > MAX_ALERTED) { alerted = alerted.slice(1, null); }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, 250)]);
        }
    }

    function secondsSinceUpdate(now as Number) {
        return lastSuccess == null ? null : (now - lastSuccess) / 1000;
    }

    function sortByFirst(arr as Array<Array>) as Void {
        for (var i = 1; i < arr.size(); i++) {
            var item = arr[i];
            var j = i - 1;
            while (j >= 0 && arr[j][0] > item[0]) {
                arr[j + 1] = arr[j];
                j--;
            }
            arr[j + 1] = item;
        }
    }

    function num(v) {
        if (v instanceof Number || v instanceof Float || v instanceof Double || v instanceof Long) {
            return v.toDouble();
        }
        return null;
    }

    function trim(v) as String {
        if (!(v instanceof String)) { return ""; }
        var chars = v.toCharArray();
        var start = 0;
        var end = chars.size();
        while (start < end && chars[start] == ' ') { start++; }
        while (end > start && chars[end - 1] == ' ') { end--; }
        var out = v.substring(start, end);
        return out == null ? "" : out;
    }
}
