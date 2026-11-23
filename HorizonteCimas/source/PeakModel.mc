import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.WatchUi;

// Datos OSM, caché local y geometría precalculada para que el dibujo sea ligero.
// peaks: [nombre, latitud, longitud, elevacion_m]   (ordenadas por rumbo desde la descarga)
// geom:  [rumbo_grados, elevacion_aparente, distancia_m, elevacion_m, nombre, posible_oculta]
(:typecheck(false))
class PeakModel {
    const NEAR_RADIUS_M = 10000;
    const FAR_RADIUS_M = 40000;
    const CACHE_VERSION = 2;
    const GEOMETRY_MOVE_M = 15;
    const KEEP_NEAR = 50;
    const MAX_PEAKS = 100;
    const REFETCH_M = 5000.0;
    const RETRY_MS = 90000;
    const MAX_LIMIT_DIVISOR = 4;
    // Oclusión aproximada: la ladera de una cima cercana baja ~0,4° por cada grado
    // de separación lateral (pendiente media ~22°), independientemente de la distancia.
    const SLOPE_TAN = 0.4;
    const OCCLUSION_WINDOW_DEG = 10.0;
    const OCCLUSION_MARGIN_DEG = 0.05;
    const OCCLUSION_MIN_GAP_M = 300;
    const SEARCHING_GPS = "Buscando señal GPS…";
    const WAIT_FIX = "Esperando GPS preciso…";
    const OUT_OF_ZONE = "Cimas fuera de zona";
    // Origen de las cimas en memoria
    const SRC_NONE = 0;
    const SRC_OFFLINE = 1;   // base precargada (Segovia y Guadarrama)
    const SRC_CACHE = 2;     // última descarga guardada
    const SRC_ONLINE = 3;    // descarga de esta sesión
    const M_PER_DEG_LAT = 110540.0;
    const M_PER_DEG_LON = 111320.0;
    // «Solo grandes»: cimas a menos de 600 m de la más alta visible, la más alta de cada
    // sector de 3° y como mucho 24 (Peñalara, Siete Picos, Cabeza de Hierro… desde Segovia).
    const BIG_MARGIN_M = 600.0;
    const BIG_SPACING_DEG = 3.0;
    const BIG_MAX = 24;
    const NO_FIX_YET = "Esperando GPS…";

    // Instancias públicas de Overpass con datos mundiales. Se prueba la siguiente
    // si una falla (HTTP 406/429/5xx, tiempo agotado, respuesta inválida).
    var endpoints as Array<String> = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter"
    ];
    var endpointIndex = 0;
    var endpointTries = 0;
    var limitDivisor = 1;

    var lat = null;
    var lon = null;
    var alt = 0.0;
    var altitudeOk = false;
    var fixOk = false;           // posición GPS real (no la última conocida)
    var peaks as Array<Array> = [];
    var geom as Array<Array> = [];
    var status as String or Null = SEARCHING_GPS;
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
    // Diagnóstico de la base offline
    var dataSource = SRC_NONE;
    var offlineTiles = 0;        // teselas leídas en la última carga
    var offlineCandidates = 0;   // cimas dentro de 40 km en la última carga
    var offlineLoadMs = 0;       // duración de la última carga
    var offlineLoads = 0;        // cargas desde el inicio
    var lastOnlineCode = null;   // último código HTTP o de error de la descarga online
    var onlyBig = true;          // mostrar solo las cimas grandes (menú)
    var usingSavedPos = false;   // posición recordada de la última sesión, a la espera del GPS

    function initialize() {
        try {
            var cache = Application.Storage.getValue("peakCache");
            if (cache instanceof Dictionary && (cache["version"] == CACHE_VERSION || cache["version"] == 1)) {
                // v1 → v2: mismo formato de cimas; solo cambia el orden (se reordena al descargar).
                loadCache(cache["peaks"], cache["lat"], cache["lon"]);
                if (cache["version"] != CACHE_VERSION && peaks.size() > 0) { saveCache(); }
            } else if (cache == null) {
                // Migración desde 0.2 (claves sueltas).
                loadCache(Application.Storage.getValue("peaks"),
                    Application.Storage.getValue("dlat"), Application.Storage.getValue("dlon"));
                if (peaks.size() > 0) { saveCache(); }
            }
            if (peaks.size() > 0) { dataSource = SRC_CACHE; }
            var ep = Application.Storage.getValue("overpassEndpoint");
            if (ep instanceof Number && ep >= 0 && ep < endpoints.size()) { endpointIndex = ep; }
            var ob = Application.Storage.getValue("onlyBig");
            if (ob instanceof Boolean) { onlyBig = ob; }
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
        }
    }

    function saveCache() as Void {
        Application.Storage.setValue("peakCache", {
            "version" => CACHE_VERSION, "lat" => dataLat, "lon" => dataLon, "peaks" => peaks
        });
    }

    function onPosition(info as Position.Info or Null) as Void {
        if (info == null || info.position == null || info.accuracy == null
            || info.accuracy < Position.QUALITY_LAST_KNOWN) { return; }
        var precise = info.accuracy >= Position.QUALITY_POOR;
        // La última posición conocida sirve para mostrar la caché al instante,
        // pero nunca sustituye a un fijo GPS real.
        if (!precise && fixOk) { return; }

        var coords = info.position.toDegrees();
        if (coords[0] == 0 && coords[1] == 0) { return; }   // posición vacía del sistema
        usingSavedPos = false;
        if (precise) { rememberPosition(coords[0], coords[1]); }
        applyPosition(coords[0], coords[1], precise && info.altitude != null ? info.altitude : null, precise);
    }

    // Guarda la última posición buena (solo si se ha movido >1 km, para no gastar escrituras).
    function rememberPosition(la, lo) as Void {
        try {
            var old = Application.Storage.getValue("lastPos");
            if (old instanceof Array && old.size() == 2
                && GeoMath.distance(la, lo, old[0], old[1]) < 1000) { return; }
            Application.Storage.setValue("lastPos", [la, lo]);
        } catch (ex) {}
    }

    // Al arrancar sin GPS (en casa, a cubierto): usar la última posición conocida de la app
    // para que las cimas salgan al instante; el GPS la sustituye en cuanto llega.
    function useSavedPosition() as Boolean {
        if (lat != null) { return false; }
        var pos = null;
        try { pos = Application.Storage.getValue("lastPos"); } catch (ex) {}
        if (!(pos instanceof Array) || pos.size() != 2) { return false; }
        var la = parseNum(pos[0]);
        var lo = parseNum(pos[1]);
        if (la == null || lo == null) { return false; }
        applyPosition(la, lo, null, false);
        usingSavedPos = true;
        return true;
    }

    // Menú «Recargar offline»: mensaje claro según el caso.
    function reloadOffline() as Void {
        if (lat == null && !useSavedPosition()) { status = NO_FIX_YET; return; }
        if (!loadOffline()) { status = "Fuera de la zona offline"; }
    }

    function setOnlyBig(v as Boolean) as Void {
        onlyBig = v;
        try { Application.Storage.setValue("onlyBig", v); } catch (ex) {}
        if (dataSource == SRC_OFFLINE && lat != null) { loadOffline(); }
    }

    // Separado de onPosition para poder probarlo sin GPS (pruebas de simulador offline).
    function applyPosition(la, lo, altitude, precise as Boolean) as Void {
        lat = la;
        lon = lo;
        fixOk = precise;
        altitudeOk = altitude != null;
        alt = altitudeOk ? altitude : 0.0;

        // Base offline: dentro de la zona cubierta, las cimas salen al instante, sin Internet.
        // Solo se recarga al cambiar de zona (5 km); una descarga online reciente se respeta.
        if (inCoverage(lat, lon)) {
            var nearData = dataLat != null && GeoMath.distance(lat, lon, dataLat, dataLon) <= REFETCH_M;
            if (!nearData || dataSource == SRC_CACHE || dataSource == SRC_NONE) {
                if (!(nearData && dataSource == SRC_ONLINE)) { loadOffline(); }
            }
        }

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

        var st = status;
        if (localData && !fetching && st != null
            && (st.equals(SEARCHING_GPS) || st.equals(WAIT_FIX) || st.equals(OUT_OF_ZONE)
                || st.equals(NO_FIX_YET) || st.equals("Fuera de la zona offline"))) {
            status = null;   // avisos que ya no aplican al volver a la zona con datos
        }
        if (localData || fetching) { return; }
        if (inCoverage(lat, lon)) { return; }   // la descarga online es opcional en la zona offline
        if (!fixOk) {
            status = WAIT_FIX;
            return;
        }
        var now = System.getTimer();
        var canRetry = lastAttempt == null || now < lastAttempt || now - lastAttempt >= RETRY_MS;
        if (canRetry) {
            fetch();
        } else if (wasLocal) {
            status = OUT_OF_ZONE;
        }
    }

    // ¿Está el punto dentro de la base offline? (margen de unos 5 km)
    function inCoverage(la, lo) as Boolean {
        return la != null && lo != null && la >= PeakTiles.SOUTH - 0.05 && la <= PeakTiles.NORTH + 0.05
            && lo >= PeakTiles.WEST - 0.06 && lo <= PeakTiles.EAST + 0.06;
    }

    // Carga las cimas precargadas en 40 km alrededor de la posición actual.
    // Solo se leen las teselas que tocan el círculo; la distancia de filtrado es
    // equirrectangular (barata) y la selección no ordena todo el conjunto.
    // Sin comprobación de tipos: el compilador intenta deducir el tipo exacto de cada
    // JSON de cumbres y se queda sin memoria. Los datos se validan aquí a mano.
    (:typecheck(false))
    function loadOffline() as Boolean {
        if (lat == null || !inCoverage(lat, lon)) { return false; }
        var t0 = System.getTimer();
        var reach = FAR_RADIUS_M + 500.0;
        var kx = M_PER_DEG_LON * Math.cos(Math.toRadians(lat));
        var rLat = reach / M_PER_DEG_LAT;
        var rLon = reach / kx;
        var r0 = Math.floor((lat - rLat - PeakTiles.LAT0) / PeakTiles.STEP).toNumber();
        var r1 = Math.floor((lat + rLat - PeakTiles.LAT0) / PeakTiles.STEP).toNumber();
        var c0 = Math.floor((lon - rLon - PeakTiles.LON0) / PeakTiles.STEP).toNumber();
        var c1 = Math.floor((lon + rLon - PeakTiles.LON0) / PeakTiles.STEP).toNumber();
        var near = [] as Array<Array>;
        var far = [] as Array<Array>;
        var tiles = 0;
        for (var r = r0; r <= r1; r++) {
            for (var c = c0; c <= c1; c++) {
                var id = PeakTiles.tile(r, c);
                if (id == null) { continue; }
                var data = null;
                try { data = WatchUi.loadResource(id); } catch (ex) { data = null; }
                if (!(data instanceof Dictionary)) { continue; }
                tiles++;
                // {"k": N, "n": nombres seguidos, "p": registros de 21 caracteres}
                // registro: dlat(5) dlon(5) ele(4) inicio(5) largo(2); dlat/dlon en 1e-5° desde la esquina SO
                var names = data["n"];
                var recs = data["p"];
                var count = data["k"];
                if (!(names instanceof String) || !(recs instanceof String) || !(count instanceof Number)
                    || recs.length() < count * 21) { continue; }
                var lat0 = PeakTiles.LAT0 + r * PeakTiles.STEP;
                var lon0 = PeakTiles.LON0 + c * PeakTiles.STEP;
                for (var i = 0; i < count; i++) {
                    var o = i * 21;
                    var pla = lat0 + recs.substring(o, o + 5).toNumber() / 100000.0d;
                    var plo = lon0 + recs.substring(o + 5, o + 10).toNumber() / 100000.0d;
                    var dy = (pla - lat) * M_PER_DEG_LAT;
                    var dx = (plo - lon) * kx;
                    var d = Math.sqrt(dx * dx + dy * dy);
                    if (d < 60 || d > reach) { continue; }
                    var ele = recs.substring(o + 10, o + 14).toNumber().toFloat();
                    var st = recs.substring(o + 14, o + 19).toNumber();
                    var nm = names.substring(st, st + recs.substring(o + 19, o + 21).toNumber());
                    var peak = [nm, pla, plo, ele];
                    if (d <= NEAR_RADIUS_M) {
                        near.add([d, peak]);
                    } else {
                        far.add([GeoMath.elevationAngle(ele - alt, d), peak]);
                    }
                }
                data = null;   // liberar la tesela antes de leer la siguiente
            }
        }
        offlineTiles = tiles;
        offlineCandidates = near.size() + far.size();
        offlineLoads++;
        peaks = onlyBig ? chooseBig(near, far, lat, lon) : choosePeaks(near, far, lat, lon);
        dataLat = lat;
        dataLon = lon;
        dataSource = SRC_OFFLINE;
        status = null;
        refreshLocalData();
        updateGeometry();
        offlineLoadMs = System.getTimer() - t0;
        return true;
    }

    // Selección común (offline y online): las 50 más cercanas, después las lejanas de mayor
    // ángulo aparente, y el resto de cercanas si sobra sitio. Ordenadas por rumbo al final.
    // Se usa clasificación por cubetas (lineal) para no ordenar cientos de candidatas.
    function choosePeaks(near as Array<Array>, far as Array<Array>, refLat, refLon) as Array<Array> {
        var nearS = bucketOrder(near, 0.0, NEAR_RADIUS_M.toFloat(), 40, true);
        var farS = bucketOrder(far, -3.0, 15.0, 90, false);
        var chosen = [] as Array<Array>;
        for (var i = 0; i < nearS.size() && i < KEEP_NEAR; i++) { chosen.add(nearS[i][1]); }
        var farBudget = MAX_PEAKS - chosen.size();
        for (var i = 0; i < farS.size() && i < farBudget; i++) { chosen.add(farS[i][1]); }
        for (var i = KEEP_NEAR; i < nearS.size() && chosen.size() < MAX_PEAKS; i++) { chosen.add(nearS[i][1]); }
        var byBearing = [] as Array<Array>;
        for (var i = 0; i < chosen.size(); i++) {
            var p = chosen[i];
            byBearing.add([GeoMath.bearing(refLat, refLon, p[1], p[2]), p]);
        }
        sortCandidates(byBearing, true);   // ≤ 100 elementos
        var list = [] as Array<Array>;
        for (var i = 0; i < byBearing.size(); i++) { list.add(byBearing[i][1]); }
        return list;
    }

    // Solo las grandes: de la más alta a la más baja (dentro de BIG_MARGIN_M de la cima más alta),
    // descartando las que caen a menos de BIG_SPACING_DEG de rumbo de otra ya elegida.
    function chooseBig(near as Array<Array>, far as Array<Array>, refLat, refLon) as Array<Array> {
        var all = [] as Array<Array>;
        var top = -1000.0;
        for (var k = 0; k < 2; k++) {
            var src = k == 0 ? near : far;
            for (var i = 0; i < src.size(); i++) {
                var p = src[i][1];
                if (p[3] > top) { top = p[3]; }
                all.add([p[3], p]);
            }
        }
        var minEle = top - BIG_MARGIN_M;
        var cand = [] as Array<Array>;
        for (var i = 0; i < all.size(); i++) { if (all[i][0] >= minEle) { cand.add(all[i]); } }
        cand = bucketOrder(cand, minEle, top + 1.0, 30, false);
        var kept = [] as Array<Array>;   // [rumbo, cima]
        for (var i = 0; i < cand.size() && kept.size() < BIG_MAX; i++) {
            var p = cand[i][1];
            var b = GeoMath.bearing(refLat, refLon, p[1], p[2]);
            var free = true;
            for (var j = 0; j < kept.size(); j++) {
                var dd = (b - kept[j][0]).abs();
                if (dd > 180) { dd = 360 - dd; }
                if (dd < BIG_SPACING_DEG) { free = false; break; }
            }
            if (free) { kept.add([b, p]); }
        }
        sortCandidates(kept, true);
        var list = [] as Array<Array>;
        for (var i = 0; i < kept.size(); i++) { list.add(kept[i][1]); }
        return list;
    }

    // Ordenación aproximada por cubetas de la primera columna (orden exacto entre cubetas).
    function bucketOrder(items as Array<Array>, lo, hi, nb as Number, ascending as Boolean) as Array<Array> {
        if (items.size() <= 1) { return items; }
        var buckets = new [nb];
        for (var i = 0; i < nb; i++) { buckets[i] = []; }
        var span = hi - lo;
        for (var i = 0; i < items.size(); i++) {
            var b = ((items[i][0] - lo) / span * nb).toNumber();
            if (b < 0) { b = 0; }
            if (b >= nb) { b = nb - 1; }
            buckets[b].add(items[i]);
        }
        var out = [] as Array<Array>;
        for (var k = 0; k < nb; k++) {
            var bk = buckets[ascending ? k : nb - 1 - k];
            sortCandidates(bk, ascending);   // cubetas pequeñas
            out.addAll(bk);
        }
        return out;
    }

    function refreshLocalData() as Void {
        localData = lat != null && dataLat != null && dataLon != null
            && GeoMath.distance(lat, lon, dataLat, dataLon) <= REFETCH_M;
    }

    function forceFetch() as Void {
        if (!fixOk) {
            status = WAIT_FIX;
            return;
        }
        if (!fetching) { fetch(); }
    }

    function connectionAvailable() as Boolean {
        try {
            var ds = System.getDeviceSettings();
            if (ds has :connectionAvailable) { return ds.connectionAvailable; }
            return ds.phoneConnected;
        } catch (ex) {
            return true;   // ante la duda, que lo diga la propia petición
        }
    }

    // Inicia una ronda de descarga: fija el punto de consulta y reinicia los reintentos.
    function fetch() as Void {
        if (lat == null || fetching) { return; }
        lastAttempt = System.getTimer();
        if (!connectionAvailable()) {
            status = localData ? (dataSource == SRC_OFFLINE ? "Sin móvil · offline" : "Sin móvil · caché") : "Conecta el móvil";
            WatchUi.requestUpdate();
            return;
        }
        requestLat = lat;
        requestLon = lon;
        requestAlt = alt;
        endpointTries = 0;
        limitDivisor = 1;
        sendRequest();
    }

    function sendRequest() as Void {
        fetching = true;
        status = "Buscando cumbres...";
        var q = buildQuery(requestLat.format("%.5f"), requestLon.format("%.5f"));
        try {
            Communications.makeWebRequest(
                endpoints[endpointIndex],
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
        var q = "[out:json][timeout:20];";
        // Anillos disjuntos. Cada cupo reserva espacio para una distancia distinta.
        q += queryBand(0, 3000, scaled(24), la, lo);
        q += queryBand(3000, NEAR_RADIUS_M, scaled(32), la, lo);
        q += queryBand(NEAR_RADIUS_M, 20000, scaled(28), la, lo);
        q += queryBand(20000, FAR_RADIUS_M, scaled(36), la, lo);
        return q;
    }

    // Reduce los cupos si el reloj no pudo recibir una respuesta tan grande.
    function scaled(limit as Number) as Number {
        var v = limit / limitDivisor;
        return v < 1 ? 1 : v;
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

    // Decide si un fallo merece otro intento y cómo. Devuelve :mirror, :smaller o null.
    function retryAction(code as Number) {
        if (code == -402 || code == -403) {          // respuesta demasiado grande / sin memoria
            return limitDivisor < MAX_LIMIT_DIVISOR ? :smaller : null;
        }
        if (code == -300 || code == -400 || code == -1002 || code == 200
            || code == 406 || code == 429 || code == 504 || code >= 500) {
            return endpointTries + 1 < endpoints.size() ? :mirror : null;
        }
        return null;   // sin móvil, BLE, permisos…: otro servidor no lo arregla
    }

    function errorMessage(code as Number) as String {
        if (code == -104 || (code <= -1 && code >= -5)) { return "Sin conexión con el móvil"; }
        if (code == -300) { return "Tiempo de espera agotado"; }
        if (code == -402 || code == -403) { return "Respuesta demasiado grande"; }
        if (code == 429) { return "Servidor OSM saturado"; }
        if (code == 200) { return "Respuesta OSM inválida"; }
        if (code >= 500) { return "Servidor OSM no disponible"; }
        return "Descarga no disponible (" + code + ")";
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        lastOnlineCode = code;
        if (lat != null && GeoMath.distance(lat, lon, requestLat, requestLon) > REFETCH_M) {
            fetching = false;
            status = localData ? null : OUT_OF_ZONE;
            lastAttempt = null;
            WatchUi.requestUpdate();
            return;
        }

        var valid = code == 200 && (data instanceof Dictionary)
            && ((data as Dictionary)["elements"] instanceof Array)
            && (data as Dictionary)["remark"] == null;
        if (!valid) {
            var action = retryAction(code);
            if (action == :mirror) {
                endpointTries++;
                endpointIndex = (endpointIndex + 1) % endpoints.size();
                sendRequest();
                return;
            } else if (action == :smaller) {
                limitDivisor *= 2;
                sendRequest();
                return;
            }
            fetching = false;
            var msg = errorMessage(code);
            status = localData ? msg + (dataSource == SRC_OFFLINE ? " · offline" : " · caché") : msg;
            WatchUi.requestUpdate();
            return;
        }
        fetching = false;
        var elements = (data as Dictionary)["elements"] as Array;

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
            status = localData ? "Sin cimas nuevas · caché" : "Sin cimas válidas en OSM";
            WatchUi.requestUpdate();
            return;
        }

        // Guardar ordenadas por rumbo: al moverse el orden apenas cambia.
        peaks = onlyBig ? chooseBig(near, far, requestLat, requestLon) : choosePeaks(near, far, requestLat, requestLon);
        dataSource = SRC_ONLINE;
        dataLat = requestLat;
        dataLon = requestLon;
        refreshLocalData();
        status = limitDivisor > 1 ? "Lista reducida (memoria)" : null;
        // La memoria persistente tiene límites en algunos relojes.
        try {
            saveCache();
            Application.Storage.setValue("overpassEndpoint", endpointIndex);
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
            g.add([b, ea, d, p[3], p[0], false]);
        }
        sortCandidates(g, true);       // por rumbo; casi ordenado → casi lineal
        if (altitudeOk) { markHidden(g); }
        geom = g;
    }

    // Marca como "posible oculta" una cima si otra más cercana, en un rumbo próximo,
    // asoma por encima de su línea de visión. Sin modelo del terreno: solo es una pista.
    // Requiere g ordenado por rumbo.
    function markHidden(g as Array<Array>) as Void {
        var n = g.size();
        for (var i = 0; i < n; i++) {
            var gi = g[i];
            var occluded = false;
            for (var dir = -1; dir <= 1 && !occluded; dir += 2) {
                for (var k = 1; k < n; k++) {
                    var j = (i + dir * k) % n;
                    if (j < 0) { j += n; }
                    var gj = g[j];
                    var offset = GeoMath.diff(gj[0], gi[0]);
                    if (offset < 0) { offset = -offset; }
                    if (offset > OCCLUSION_WINDOW_DEG) { break; }
                    if (gj[2] + OCCLUSION_MIN_GAP_M < gi[2]
                        && gj[1] - offset * SLOPE_TAN > gi[1] + OCCLUSION_MARGIN_DEG) {
                        occluded = true;
                        break;
                    }
                }
            }
            gi[5] = occluded;
        }
    }

    // Inserción estable por la primera columna.
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
        var suffix = false;
        var hasUnit = false;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toNumber();
            if (c == 32) {
                if (buf.length() > 0 && !hasDigit) { return null; }
                suffix = hasDigit;
            } else if (c == 109 && hasDigit && !hasUnit) {
                hasUnit = true;
                suffix = true;
            } else if (suffix) {
                return null;
            } else if (c >= 48 && c <= 57) {
                buf += chars[i].toString();
                hasDigit = true;
            } else if ((c == 46 || c == 44) && !hasPoint) {
                buf += ".";
                hasPoint = true;
            } else if (c == 45 && buf.length() == 0) {
                buf += "-";
            } else {
                return null;
            }
        }
        return hasDigit ? buf.toDouble() : null;
    }
}
