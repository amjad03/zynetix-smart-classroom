// Renders the real Kinetix 3D viewer page (kinetix_3d/assets/viewer3d: three.js + the model's GLB)
// in headless Chromium, for the v4 screenshots only (the test engine cannot run a WebView).
// Run from apps/board:  node screenshots/renders/render.js
// Needs Node with the `playwright` package and its Chromium.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const viewer = '/root/.pub-cache/git/Kinetix-6db5f65a84c0b30f227fa9d5929db3e169ad2ffb/packages/kinetix_3d/assets/viewer3d';
const out = path.join(__dirname);
const types = { html: 'text/html', js: 'text/javascript', json: 'application/json', glb: 'model/gltf-binary', png: 'image/png', jpg: 'image/jpeg', txt: 'text/plain' };

// [file name, model id, variant, CSS width, CSS height, extra commands]
const shots = [
  ['3d-hybridisation-sp3', 'hybridisation', 'sp3', 1360, 720, [{ cmd: 'labels', mode: 'all' }]],
];

const server = http.createServer((req, res) => {
  const p = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '') || 'index.html';
  const f = path.join(viewer, p);
  if (!f.startsWith(viewer) || !fs.existsSync(f)) { res.statusCode = 404; return res.end(); }
  res.setHeader('content-type', types[p.split('.').pop()] || 'application/octet-stream');
  fs.createReadStream(f).pipe(res);
});

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const [name, model, variant, w, h, extra] of shots) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    const events = [];
    page.on('console', (m) => { if (m.type() === 'error') console.log('page error:', m.text()); });
    await page.addInitScript(() => {
      window.__kx = [];
      window.KX = { postMessage: (m) => window.__kx.push(typeof m === 'string' ? JSON.parse(m) : m) };
    });
    await page.goto(`http://127.0.0.1:${port}/index.html?model=${model}&lang=en`);
    await page.waitForFunction(() => window.__kx.some((e) => e.event === 'ready' || e.event === 'loaded' || e.event === 'error'), null, { timeout: 60000 });
    for (const c of [{ cmd: 'variant', id: variant }, ...extra]) {
      await page.evaluate((c) => window.kx.cmd(c), c);
    }
    // The board's stage colour behind the model (the page paints its own dark grey otherwise).
    await page.addStyleTag({ content: 'html, body { background: #141A1D !important; }' });
    await page.waitForTimeout(2500);
    const seen = await page.evaluate(() => window.__kx.map((e) => e.event));
    console.log(name, 'events:', [...new Set(seen)].join(', '));
    await page.screenshot({ path: path.join(out, `${name}.png`) });
    await page.close();
  }
  await browser.close();
  server.close();
})().catch((e) => { console.error(e); process.exit(1); });
