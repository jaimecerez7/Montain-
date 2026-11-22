import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Recoge todo lo que muestran las esferas. Se rellena una vez por minuto.
class FaceData {
    const DAYS = ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"];
    const MONTHS = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"];
    const CURVE_POINTS = 49;   // elevación del sol cada media hora

    var time = "";
    var date = "";
    var temp = "--°";
    var precip = "--%";
    var cond = :cloud;
    var sunrise = "--:--";
    var sunset = "--:--";
    var riseH = null;          // horas locales (Float) o null
    var setH = null;
    var nowH = 0.0;
    var dayFrac = 0.0;         // 0..1 entre amanecer y atardecer
    var steps = 0;
    var goal = 10000;
    var history as Array<Number> = [];   // pasos de días anteriores, del más antiguo al más reciente
    var moonIllum = 0.0;
    var waxing = true;
    var sunCurve as Array or Null = null; // elevaciones (grados) de 0 h a 24 h
    var sunNow = 0.0;

    var curveKey = -1;         // día del año con el que se calculó sunCurve
    var lat = null;
    var lon = null;

    function initialize() {
        try {
            var loc = Application.Storage.getValue("loc");
            if (loc instanceof Array && loc.size() == 2) { lat = loc[0]; lon = loc[1]; }
        } catch (ex) {}
    }

    function update() as Void {
        var ds = System.getDeviceSettings();
        var ct = System.getClockTime();
        var now = Time.now();
        var g = Gregorian.info(now, Time.FORMAT_SHORT);

        time = clock(ct.hour, ct.min, ds.is24Hour);
        date = DAYS[(g.day_of_week as Number) - 1] + " " + g.day.toString() + " " + MONTHS[(g.month as Number) - 1];
        nowH = ct.hour + ct.min / 60.0;

        updateWeather(ds);
        updateActivity();
        var m = Astro.moon(now.value());
        moonIllum = m[0];
        waxing = m[1];
        updateSun(g.year as Number, g.month as Number, g.day as Number, ct, ds.is24Hour);
    }

    function clock(h as Number, m as Number, is24 as Boolean) as String {
        if (is24) { return h.format("%02d") + ":" + m.format("%02d"); }
        var h12 = h % 12;
        return (h12 == 0 ? 12 : h12).toString() + ":" + m.format("%02d");
    }

    function updateWeather(ds) as Void {
        var c = null;
        try { c = Weather.getCurrentConditions(); } catch (ex) {}
        if (c == null) { return; }
        if (c.temperature != null) {
            var t = c.temperature;
            if (ds.temperatureUnits == System.UNIT_STATUTE) { t = t * 9 / 5.0 + 32; }
            temp = Math.round(t).toNumber().toString() + "°";
        }
        if (c.precipitationChance != null) { precip = c.precipitationChance.toString() + "%"; }
        cond = conditionIcon(c.condition);
        var p = c.observationLocationPosition;
        if (p != null) { remember(p.toDegrees()); }
    }

    function conditionIcon(code) as Symbol {
        if (code == null) { return :cloud; }
        if (code == Weather.CONDITION_CLEAR || code == Weather.CONDITION_MOSTLY_CLEAR
            || code == Weather.CONDITION_PARTLY_CLEAR || code == Weather.CONDITION_FAIR) { return :sun; }
        if (code == Weather.CONDITION_PARTLY_CLOUDY || code == Weather.CONDITION_MOSTLY_CLOUDY
            || code == Weather.CONDITION_THIN_CLOUDS) { return :partly; }
        if (code == Weather.CONDITION_SNOW || code == Weather.CONDITION_LIGHT_SNOW
            || code == Weather.CONDITION_HEAVY_SNOW || code == Weather.CONDITION_WINTRY_MIX
            || code == Weather.CONDITION_FLURRIES || code == Weather.CONDITION_SLEET
            || code == Weather.CONDITION_HAIL) { return :snow; }
        if (code == Weather.CONDITION_CLOUDY || code == Weather.CONDITION_FOG
            || code == Weather.CONDITION_HAZY || code == Weather.CONDITION_MIST
            || code == Weather.CONDITION_WINDY || code == Weather.CONDITION_UNKNOWN) { return :cloud; }
        return :rain;   // lluvias, chubascos y tormentas
    }

    function updateActivity() as Void {
        var info = ActivityMonitor.getInfo();
        steps = info.steps == null ? 0 : info.steps;
        goal = info.stepGoal == null || info.stepGoal <= 0 ? 10000 : info.stepGoal;
        var h = ActivityMonitor.getHistory();
        var list = [] as Array<Number>;
        if (h != null) {
            // getHistory: [0] = ayer. Se guarda en orden cronológico, máximo 7 días.
            for (var i = (h.size() < 7 ? h.size() : 7) - 1; i >= 0; i--) {
                var s = h[i].steps;
                list.add(s == null ? 0 : s);
            }
        }
        history = list;
        if (lat == null) {
            var a = Activity.getActivityInfo();
            if (a != null && a.currentLocation != null) { remember(a.currentLocation.toDegrees()); }
        }
    }

    function remember(deg as Array) as Void {
        if (deg[0] == 0 && deg[1] == 0) { return; }
        var moved = lat == null || (lat - deg[0]).abs() > 0.05 || (lon - deg[1]).abs() > 0.05;
        lat = deg[0];
        lon = deg[1];
        if (moved) {
            curveKey = -1;
            try { Application.Storage.setValue("loc", [lat, lon]); } catch (ex) {}
        }
    }

    function updateSun(year as Number, month as Number, day as Number, ct, is24 as Boolean) as Void {
        if (lat == null) { return; }
        var doy = Astro.dayOfYear(year, month, day);
        var tz = ct.timeZoneOffset / 3600.0;
        var times = Astro.sunTimes(lat, lon, doy, tz);
        if (times != null) {
            riseH = times[0];
            setH = times[1];
            sunrise = clockH(riseH, is24);
            sunset = clockH(setH, is24);
            var f = (nowH - riseH) / (setH - riseH);
            dayFrac = f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
        }
        sunNow = Astro.elevation(lat, lon, doy, nowH, tz);
        if (curveKey != doy) {   // la curva del día solo se recalcula una vez al día
            var c = [];
            for (var i = 0; i < CURVE_POINTS; i++) {
                c.add(Astro.elevation(lat, lon, doy, i * 24.0 / (CURVE_POINTS - 1), tz));
            }
            sunCurve = c;
            curveKey = doy;
        }
    }

    function clockH(hours, is24 as Boolean) as String {
        var total = Math.round(hours * 60).toNumber();
        return clock((total / 60) % 24, total % 60, is24);
    }

    // 7842 → "7.842"
    function stepsText() as String {
        var s = steps.toString();
        var out = "";
        var n = s.length();
        for (var i = 0; i < n; i++) {
            if (i > 0 && (n - i) % 3 == 0) { out += "."; }
            out += s.substring(i, i + 1);
        }
        return out;
    }
}
