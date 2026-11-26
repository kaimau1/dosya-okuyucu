// Yapay zekâ ses motorunun (VoiceServer.engineHtml) GERÇEK Chromium'da
// denetimi. Önce tool/voice_install_check_test.dart sesleri VOICE_ROOT'a
// indirir; bu betik aynı başlıklarla (COOP/COEP) yerel sunucu kurar,
// motor sayfasını açar, iki sesle Türkçe cümle üretir, WAV'ı doğrular.
//   VOICE_ROOT=… PLAYWRIGHT_MODULE=/opt/node-tools/node_modules/playwright \
//   CHROMIUM=/opt/pw-browsers/chromium node tool/voice_engine_check.mjs
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = process.env.VOICE_ROOT;
const outDir = process.env.OUT_DIR || root;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };
const outputs = {};
const server = http.createServer((req, res) => {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (req.method === 'POST' && url.startsWith('/out/')) {
    const chunks = []; req.on('data', (c) => chunks.push(c));
    req.on('end', () => { outputs[url.slice(5)] = Buffer.concat(chunks); res.statusCode = 204; res.end(); });
    return;
  }
  const file = path.join(root, url);
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.statusCode = 404; res.end(); return; }
  res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;
const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
const page = await browser.newPage();
const msgs = [];
await page.addInitScript(() => { window.Ses = { postMessage: (m) => window.__msgs.push(JSON.parse(m)) }; window.__msgs = []; });
page.on('pageerror', (e) => console.error('sayfa hatası:', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.error('konsol:', m.text()); });
await page.goto(`http://127.0.0.1:${port}/engine.html`);
let failed = false;
for (const voice of ['antalia', 'ema']) {
  const t0 = Date.now();
  await page.evaluate(([v]) => engine.synth('test-' + v, v, 'Merhaba! Randevunuz 14 Ekim Salı günü saat 15:30\'da.', 1.0), [voice]);
  for (let i = 0; i < 600 && !outputs['test-' + voice]; i++) {
    const err = (await page.evaluate(() => window.__msgs)).find((m) => m.type === 'error');
    if (err) { console.error(voice, 'HATA', err.message); failed = true; break; }
    await new Promise((r) => setTimeout(r, 500));
  }
  const wav = outputs['test-' + voice];
  if (!wav) { console.error(voice, 'ses gelmedi'); failed = true; continue; }
  const rate = wav.readUInt32LE(24), bytes = wav.readUInt32LE(40);
  const secs = bytes / 2 / rate;
  let peak = 0; for (let i = 44; i < wav.length; i += 2) peak = Math.max(peak, Math.abs(wav.readInt16LE(i)));
  console.log(`${voice}: ${rate} Hz, ${secs.toFixed(2)} sn, tepe ${peak}, ${((Date.now() - t0) / 1000).toFixed(1)} sn sürdü`);
  fs.writeFileSync(path.join(outDir, `${voice}.wav`), wav);
  if (secs < 1 || peak < 1000) { console.error(voice, 'ses boş/kısa'); failed = true; }
}
console.log('isolated:', await page.evaluate(() => self.crossOriginIsolated));
await browser.close(); server.close();
process.exitCode = failed ? 1 : 0;
