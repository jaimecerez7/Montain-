const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2];
// Escena de ejemplo: cielo de Madrid. b = rumbo desde ti, d = distancia (m), track = rumbo de vuelo.
const planes = [
  {cs:'IBE3166', b:62, d:14200, alt:10970, track:250, elev:36, type:'A333', reg:'EC-LYF'},
  {cs:'VLG1712', b:38, d:21800, alt:3350, track:330, elev:7, type:'A20N', reg:'EC-NAJ'},
  {cs:'RYR5RL', b:118, d:9600, alt:1190, track:180, elev:4, type:'B738', reg:'EI-DYZ'},
  {cs:'AEA1046', b:205, d:17500, alt:6100, track:20, elev:18, type:'B77W', reg:'EC-MUA'},
  {cs:'UAE141', b:300, d:23500, alt:11280, track:90, elev:25, type:'B77W', reg:'A6-EGA'},
  {cs:'ANE8823', b:12, d:6400, alt:2150, track:100, elev:15, type:'CRJ9', reg:'EC-MPA'},
  {cs:'EZY74QJ', b:255, d:12800, alt:8800, track:40, elev:33, type:'A321', reg:'G-UZMA'},
];
const scenes = {
  '1-apuntando': { compass:true, heading:58, range:25, planes },
  '2-fijado': { compass:true, heading:150, range:25, planes, lock:'UAE141' },
  '3-cercano': { compass:true, heading:15, range:10, planes },
};
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 390 } });
  await p.goto('file://' + path.resolve(__dirname, 'render.html'));
  for (const [name, s] of Object.entries(scenes)) {
    await p.evaluate(s => window.drawScene(s), s);
    await (await p.$('#c')).screenshot({ path: path.join(out, `captura-${name}.png`), omitBackground: true });
  }
  await b.close();
})();
