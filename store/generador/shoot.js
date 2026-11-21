const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2];
const scenes = {
  '1-brujula': { heading: 55, mode: 'BRÚJULA', peaks: [
    {name:'Siete Picos', b:57, ea:5.2, d:4200, ele:2138},
    {name:'Bola del Mundo', b:46, ea:3.4, d:7600, ele:2265},
    {name:'La Maliciosa', b:76, ea:2.7, d:9800, ele:2227},
    {name:'Cabezas de Hierro', b:36, ea:2.1, d:13800, ele:2383},
    {name:'Peñalara', b:28, ea:1.5, d:19500, ele:2428, occ:true},
    {name:'Cerro Minguete', b:68, ea:1.1, d:6100, ele:1665} ]},
  '2-manual': { heading: 290, mode: 'MANUAL', peaks: [
    {name:'La Peñota', b:287, ea:4.1, d:4900, ele:1945},
    {name:'Montón de Trigo', b:312, ea:2.6, d:6300, ele:2161},
    {name:'Cabeza Líjar', b:268, ea:2.2, d:8700, ele:1823},
    {name:'Cerro de la Gargantilla', b:300, ea:1.3, d:11200, ele:1694, occ:true} ]},
  '3-oculta': { heading: 30, mode: 'BRÚJULA', peaks: [
    {name:'Peñalara', b:29, ea:1.5, d:19500, ele:2428, occ:true},
    {name:'Siete Picos', b:57, ea:5.2, d:4200, ele:2138},
    {name:'Bola del Mundo', b:46, ea:3.4, d:7600, ele:2265},
    {name:'Cabezas de Hierro', b:37, ea:2.1, d:13800, ele:2383},
    {name:'Cerro Ventoso', b:12, ea:1.9, d:6800, ele:1797} ]},
};
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 390 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve(__dirname, 'render.html'));
  for (const [name, s] of Object.entries(scenes)) {
    await p.evaluate(s => window.drawScene(s), s);
    await (await p.$('#c')).screenshot({ path: path.join(out, `captura-${name}.png`), omitBackground: true });
  }
  // Icono de tienda 500x500 con el mismo diseño que el icono del reloj
  await p.setViewportSize({ width: 500, height: 500 });
  await p.setContent(`<body style="margin:0;background:transparent"><svg width="500" height="500" viewBox="0 0 100 100">
    <circle cx="50" cy="50" r="50" fill="#14284B"/>
    <polygon points="14,72 40,30 52,48 62,34 86,72" fill="#E8ECF2"/>
    <polygon points="62,34 56.5,42.5 67.5,42.5" fill="#FFAA00"/>
    <rect x="12" y="72" width="76" height="2.4" fill="#FFAA00"/></svg></body>`);
  await (await p.$('svg')).screenshot({ path: path.join(out, 'icono-500.png'), omitBackground: true });
  await b.close();
})();
