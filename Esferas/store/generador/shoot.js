const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.resolve(__dirname, '..');
// Datos de ejemplo: Madrid, sábado 21 de noviembre, 13:47.
const lat = 40.4 * Math.PI / 180, dec = -20.1 * Math.PI / 180, noon = 13.0;
const elev = h => Math.asin(Math.sin(lat)*Math.sin(dec) + Math.cos(lat)*Math.cos(dec)*Math.cos((h - noon) * 15 * Math.PI/180)) * 180/Math.PI;
const sunCurve = Array.from({length: 49}, (_, i) => elev(i / 2));
const now = 13 + 47/60;
const d = { time: '13:47', date: 'SÁB 21 NOV', temp: 12, precip: 30, cond: 'rain', sunrise: '08:12', sunset: '17:43',
  dayFrac: (now - (8+12/60)) / ((17+43/60) - (8+12/60)), steps: 7842, goal: 10000,
  history: [9120, 6400, 11850, 8300, 4100, 10230, 7600], moonIllum: 0.68, waxing: true,
  sunCurve, dayPos: now / 24, sunNow: elev(now), riseFrac: (8+12/60)/24, setFrac: (17+43/60)/24 };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 454, height: 454 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve(__dirname, 'render.html'));
  await p.evaluate(() => document.fonts.load('250 124px Jost'));
  await p.evaluate(() => window.loadArt());
  await p.waitForTimeout(300);
  for (const t of ['campos', 'organica', 'trazos', 'aod']) {
    await p.evaluate(([t, d]) => window.render(t, d), [t, d]);
    await (await p.$('#c')).screenshot({ path: path.join(out, `esfera-${t}.png`), omitBackground: true });
  }
  await b.close();
})();
