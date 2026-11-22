const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.resolve(__dirname, '..');
// Datos de ejemplo: Madrid, sábado 21 de noviembre, 13:47.
const d = { time: '13:47', date: 'SÁB 21 NOV', temp: 12, cond: 'rain', sunrise: '08:12', sunset: '17:43',
  nextSun: 'sunset', steps: 7842, goal: 10000, battery: 84 };
const themes = ['cinta_verde', 'cinta_ambar', 'bloques', 'reticula', 'collage', 'aod'];
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 454, height: 454 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve(__dirname, 'render.html'));
  await p.evaluate(() => document.fonts.load('250 124px Jost'));
  await p.evaluate(() => window.loadArt());
  await p.waitForTimeout(300);
  for (const t of themes) {
    await p.evaluate(([t, d]) => window.render(t, d), [t, d]);
    await (await p.$('#c')).screenshot({ path: path.join(out, `esfera-${t}.png`) });
  }
  await b.close();
})();
