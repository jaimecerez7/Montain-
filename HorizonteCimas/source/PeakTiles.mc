import Toybox.Lang;

// GENERADO por tools/fetch_peaks.py — no editar a mano.
// Cumbres de Segovia y la Sierra de Guadarrama (OpenStreetMap, 2026-11-22).
// Datos © colaboradores de OpenStreetMap (ODbL).
module PeakTiles {
    const VERSION = "2026-11-22";
    const COUNT = 689;
    const SOUTH = 40.55;
    const WEST = -4.75;
    const NORTH = 41.62;
    const EAST = -3.15;
    const LAT0 = 40.5;
    const LON0 = -4.75;
    const STEP = 0.5;
    const ROWS = 3;
    const COLS = 4;

    // Identificador del recurso JSON de la tesela (fila, columna), o null si está vacía.
    function tile(r as Number, c as Number) as ResourceId or Null {
        if (r < 0 || r >= ROWS || c < 0 || c >= COLS) { return null; }
        var grid = [
            [Rez.JsonData.PeaksR0C0, Rez.JsonData.PeaksR0C1, Rez.JsonData.PeaksR0C2, Rez.JsonData.PeaksR0C3],
            [Rez.JsonData.PeaksR1C0, Rez.JsonData.PeaksR1C1, Rez.JsonData.PeaksR1C2, Rez.JsonData.PeaksR1C3],
            [Rez.JsonData.PeaksR2C0, Rez.JsonData.PeaksR2C1, Rez.JsonData.PeaksR2C2, null]
        ] as Array<Array<ResourceId or Null>>;
        return grid[r][c];
    }
}
