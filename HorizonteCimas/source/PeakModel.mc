import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

// Datos OSM, caché local y geometría precalculada para que el dibujo sea ligero.
// peaks: [nombre, latitud, longitud, elevacion_m]
// geom:  [rumbo_grados, elevacion_aparente, distancia_m, elevacion_m, nombre]
class PeakModel {
    const NEAR_RADIUS_M = 10000;
    const FAR_RADIUS_M = 40000;
    const CACHE_VERSION = 1;
    const GEOMETRY_MOVE_M = 15;
    const KEEP_NEAR = 50;
    const MAX_PEAKS = 100;
    const REFETCH_M = 5000.0;
    const RETRY_MS = 90000;

    var lat = null;
    var lon = null;
    var alt = 0.0;
    var altitudeOk = false;
    var peaks as Array<Array> = [];
    var geom as Array<Array> = [];
    var status as String or Null = "Buscando señal GPS…";
    var fetching = false;
    var lastAttempt = null;
    var dataLat = null;
    var dataLon = null;
    var requestLat = null;
    var requestLon = null;
    var requestAlt = 0.0;
    var localData = false;
    var geometryLat = null;
    var geometryLon = null;
    var geometryAlt = null;
    var useCompass = true;
    var manualHeading = 0.0;
    var lastHeading = 0.0;

    function initialize() {
        try {
            var cache = Application.Storage.getValue("peakCache");
            if (cache instanceof Dictionary && cache["version"] == CACHE_VERSION) {
                loadCache(cache["peaks"], cache["lat"], cache["lon"]);
            } else if (cache == null) {
                loadCache(Application.Storage.getValue("peaks"),
                    Application.Storage.getValue("dlat"), Application.Storage.getValue("dlon"));
                if (peaks.size() > 0) { saveCache(); }
            }
        } catch (ex) {
            // El almacenamiento puede no estar disponible al iniciar.
        }
    }

    function loadCache(stored, storedLat, storedLon) as Void {
        var la = parseNum(storedLat);
        var lo = parseNum(storedLon);
        if (!(stored instanceof Array) || la == null || lo == null
            || la < -90 || la > 90 || lo < -180 || lo > 180) { return; }

        for (var i = 0; i < stored.size() && peaks.size() < MAX_PEAKS; i++) {
            var peak = stored[i];
            if (peak instanceof Array && peak.size() == 4) {
                var row = readPeak(peak[0], peak[1], peak[2], peak[3]);
                if (row != null) { peaks.add(row); }
            }
        }
        if (peaks.size() > 0) {
            dataLat = la;
            dataLon = lo;
            status = null;
        }
    }

    function saveCache() as Void {
        Application.Storage.setValue("peakCache", {
            "version" => CACHE_VERSION, "lat" => dataLat, "lon" => dataLon, "peaks" => peaks
        });
    }

    function onPosition(info as Position.Info or Null) as Void {
        if (info == null || info.position == null || info.accuracy == null
            || info.accuracy < Position.QUALITY_POOR) { return; }

        var coords = info.position.toDegrees();
        lat = coords[0];
        lon = coords[1];
        altitudeOk = info.altitude != null;
        alt = altitudeOk ? info.altitude : 0.0;

        var wasLocal = localData;
        refreshLocalData();
        var currentAlt = altitudeOk ? alt : null;
        if (!localData || !wasLocal || geometryLat == null
            || GeoMath.distance(lat, lon, geometryLat, geometryLon) >= GEOMETRY_MOVE_M
            || (currentAlt == null) != (geometryAlt == null)
            || (currentAlt != null && geometryAlt != null
                && (currentAlt - geometryAlt >= 10 || geometryAlt - currentAlt >= 10))) {
            updateGeometry();
        }

        var now = System.getTimer();
        var canRetry = lastAttempt == null || now < lastAttempt || now - lastAttempt >= RETRY_MS;
        if (!localData && !fetching) {
            if (canRetry) {
                fetch();
            } else if (wasLocal) {
                status = "Cimas fuera de zona";
            }
        }
    }

    function refreshLocalData() as Void {
        localData = lat != null && dataLat != null && dataLon != null
            && GeoMath.distance(lat, lon, dataLat, dataLon) <= REFETCH_M;
    }

    function forceFetch() as Void {
        if (lat == null) {
            status = "Primero espera al GPS";
            return;
        }
        if (!fetching) { fetch(); }
    }

    function fetch() as Void {
        if (lat == null || fetching) { return; }
        fetching = true;
        lastAttempt = System.getTimer();
        requestLat = lat;
        requestLon = lon;
        status = "Buscando cumbres...";

        var la = requestLat.format("%.5f");
        var lo = requestLon.format("%.5f");
        requestAlt = alt;
        var q = buildQuery(la, lo);

        try {
            Communications.makeWebRequest(
                "https://overpass-api.de/api/interpreter",
                { "data" => q },
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onResponse)
            );
        } catch (ex) {
            fetching = false;
            status = "No se pudo iniciar la descarga";
            WatchUi.requestUpdate();
        }
    }

    function buildQuery(la as String, lo as String) as String {
        var q = "[out:json][timeout:15];";
        // Anillos disjuntos. Cada cupo reserva espacio para una distancia distinta.
        q += queryBand(0, 3000, 24, la, lo);
        q += queryBand(3000, NEAR_RADIUS_M, 32, la, lo);
        q += queryBand(NEAR_RADIUS_M, 20000, 28, la, lo);
        q += queryBand(20000, FAR_RADIUS_M, 36, la, lo);
        return q;
    }

    function queryBand(inner as Number, outer as Number, limit as Number, la as String, lo as String) as String {
        var selector = "node[\"natural\"=\"peak\"][\"name\"][\"ele\"]";
        var center = "," + la + "," + lo + ");";
        var query = selector + "(around:" + outer + center;
        if (inner > 0) {
            query = "(" + query + "-" + selector + "(around:" + inner + center + ");";
        }
        return query
            + "convert peak name=t[\"name\"],ele=t[\"ele\"],la=lat(),lo=lon();out tags " + limit + ";";
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        fetching = false;
        if (code != 200 || !(data instanceof Dictionary)) {
            status = localData ? "Sin conexión · caché" : "Descarga no disponible";
            WatchUi.requestUpdate();
            return;
        }
        var elements = data["elements"];
        if (!(elements instanceof Array) || data["remark"] != null) {
            status = "Respuesta OSM inválida";
            WatchUi.requestUpdate();
            return;
        }

        if (GeoMath.distance(lat, lon, requestLat, requestLon) > REFETCH_M) {
            status = "Cimas fuera de zona";
            lastAttempt = null;
            WatchUi.requestUpdate();
            return;
        }

        var near = [] as Array<Array>;
        var far = [] as Array<Array>;
        var seen = [] as Array<Array>;
        for (var i = 0; i < elements.size(); i++) {
            var element = elements[i];
            if (!(element instanceof Dictionary)) { continue; }
            var tags = element["tags"];
            if (!(tags instanceof Dictionary)) { continue; }
            var peak = readPeak(tags["name"], tags["la"], tags["lo"], tags["ele"]);
            if (peak == null) { continue; }
            var d = GeoMath.distance(requestLat, requestLon, peak[1], peak[2]);
            if (d < 60 || d > FAR_RADIUS_M + 500) { continue; }
            var duplicate = false;
            for (var j = 0; j < seen.size(); j++) {
                if (peak[0].equals(seen[j][0]) && GeoMath.distance(peak[1], peak[2], seen[j][1], seen[j][2]) < 120) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) { continue; }
            seen.add(peak);
            if (d <= NEAR_RADIUS_M) {
                near.add([d, peak]);
            } else {
                // Priorizar cumbres elevadas y próximas al horizonte visible.
                var apparent = GeoMath.elevationAngle(peak[3] - requestAlt, d);
                far.add([apparent, peak]);
            }
        }
        // Un error de servidor no debe borrar una caché que sí funcionaba.
        if (near.size() + far.size() == 0) {
            status = "Sin cimas válidas en OSM";
            WatchUi.requestUpdate();
            return;
        }

        sortCandidates(near, true);    // cerca: primeras las más próximas
        sortCandidates(far, false);   // lejos: primeras las de mayor ángulo
        var list = [] as Array<Array>;
        for (var i = 0; i < near.size() && i < KEEP_NEAR; i++) {
            list.add(near[i][1]);
        }
        // Incluir también cimas cercanas restantes, sin tapar las lejanas.
        var farBudget = MAX_PEAKS - list.size();
        for (var i = 0; i < far.size() && i < farBudget; i++) {
            list.add(far[i][1]);
        }
        for (var i = KEEP_NEAR; i < near.size() && list.size() < MAX_PEAKS; i++) {
            list.add(near[i][1]);
        }

        peaks = list;
        dataLat = requestLat;
        dataLon = requestLon;
        refreshLocalData();
        status = null;
        // La memoria persistente tiene límites en algunos relojes.
        try {
            saveCache();
        } catch (ex) {
            status = "Cimas cargadas (sin caché)";
        }
        updateGeometry();
        WatchUi.requestUpdate();
    }

    function updateGeometry() as Void {
        if (!localData) {
            if (geom.size() > 0) { geom = []; }
            return;
        }
        geometryLat = lat;
        geometryLon = lon;
        geometryAlt = altitudeOk ? alt : null;
        var g = [] as Array<Array>;
        for (var i = 0; i < peaks.size(); i++) {
            var p = peaks[i];
            var d = GeoMath.distance(lat, lon, p[1], p[2]);
            if (d < 60 || d > FAR_RADIUS_M + 1000) { continue; }
            var b = GeoMath.bearing(lat, lon, p[1], p[2]);
            var ea = altitudeOk ? GeoMath.elevationAngle(p[3] - alt, d) : 0.0;
            g.add([b, ea, d, p[3], p[0]]);
        }
        geom = g;
    }

    // Inserción: se ejecuta solo después de una descarga (no en cada fotograma).
    function sortCandidates(arr as Array<Array>, ascending as Boolean) as Void {
        for (var i = 1; i < arr.size(); i++) {
            var item = arr[i];
            var j = i - 1;
            while (j >= 0 && (ascending ? arr[j][0] > item[0] : arr[j][0] < item[0])) {
                arr[j + 1] = arr[j];
                j--;
            }
            arr[j + 1] = item;
        }
    }

    function readPeak(name, latitude, longitude, elevation) as Array or Null {
        if (!(name instanceof String) || name.length() == 0) { return null; }
        var la = parseNum(latitude);
        var lo = parseNum(longitude);
        var elev = parseNum(elevation);
        if (la == null || lo == null || elev == null) { return null; }
        if (!(la >= -90 && la <= 90 && lo >= -180 && lo <= 180
            && elev >= -500 && elev <= 9000)) { return null; }
        if (name.length() > 80) { name = name.substring(0, 80); }
        return [name, la, lo, elev];
    }

    // Admite "1234", "1234 m", "1234,5", "-123"; rechaza cadenas vacías.
    function parseNum(value) {
        if (value == null) { return null; }
        if (value instanceof Number || value instanceof Float || value instanceof Double) {
            return value.toDouble();
        }
        if (!(value instanceof String) || value.length() > 24) { return null; }
        var chars = value.toCharArray();
        var buf = "";
        var hasDigit = false;
        var hasPoint = false;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toNumber();
            if (c >= 48 && c <= 57) {
                buf += chars[i].toString();
                hasDigit = true;
            } else if ((c == 46 || c == 44) && !hasPoint) {
                buf += ".";
                hasPoint = true;
            } else if (c == 45 && buf.length() == 0) {
                buf += "-";
            } else if (hasDigit && (c == 32 || c == 109)) {
                break;
            } else if (c != 32 || hasPoint || buf.length() > 0) {
                return null;
            }
        }
        if (!hasDigit) { return null; }
        return buf.toDouble();
    }
}
