const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.resolve(__dirname, '..');
// Datos de ejemplo: Madrid, sábado 21 de noviembre, 13:47.
const d = { time: '13:47', date: 'SÁB 21 NOV', temp: 12, cond: 'rain', sunrise: '08:12', sunset: '17:43',
  nextSun: 'sunset', steps: 7842, goal: 10000, battery: 84, precip: 30, moonIllum: 0.68, moonIdx: 3,
  nowH: 13 + 47/60, riseH: 8.2, setH: 17.72, sunNow: 26.5, peak: 29.4 };
const scenes = { collage2: { variant: 1, time: '20:58' }, collage3: { variant: 2, time: '07:31' }, cielo_alba: { time: '08:41', nowH: 8.68, sunNow: 4 }, cielo_dorada: { time: '17:05', nowH: 17.08, sunNow: 5 },
  cielo_ocaso: { time: '18:02', nowH: 18.03, sunNow: -4 }, cielo_noche: { time: '23:16', nowH: 23.27, sunNow: -50 } };
const themes = ['cinta_verde', 'cinta_ambar', 'geometria', 'collage2', 'collage3', 'cielo', 'cielo_alba', 'cielo_dorada', 'cielo_ocaso', 'cielo_noche', 'cinta_verde', 'cinta_ambar', 'bloques', 'reticula', 'collage', 'aod'];
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 454, height: 454 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve(__dirname, 'render.html'));
  await p.evaluate(() => document.fonts.load('250 124px Jost'));
  await p.evaluate(() => window.loadArt());
  await p.waitForTimeout(300);
  for (const t of themes) {
    await p.evaluate(([t, d]) => window.render(t, d), [t, { ...d, ...(scenes[t] || {}) }]);
    await (await p.$('#c')).screenshot({ path: path.join(out, `esfera-${t}.png`) });
  }
  await b.close();
})();
