// Word canlı düzenleme köprüsünün (assets/word/viewer.html) gerçek bir
// Chromium'da denetimi (Faz 9). CI'da koşmaz; JS değiştiyse elle:
//
//   PLAYWRIGHT_MODULE=/opt/node-tools/node_modules/playwright \
//   CHROMIUM=/opt/pw-browsers/chromium node tool/check_word_bridge.js
//
// Örnek belge: test/fixtures/office/tablo.docx (tool/write_fixtures_test.dart
// üretir). Denetlenen:
//  1. paragraf sayısı (tablo hücreleri dahil) Dart modeliyle aynı (6),
//  2. yazılan metin Flutter'a GİDİYOR — normal paragrafta ve tablo hücresinde
//     (Faz 9 kök neden: `input` olayının hedefi <article>, <p> değil),
//  3. seçime verilen punto/yazı tipi yalnız o parçaya işleniyor.
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const root = path.resolve(__dirname, '..');
const fail = (msg) => { console.error('HATA: ' + msg); process.exitCode = 1; };

(async () => {
  const browser = await chromium.launch(
    process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const page = await browser.newPage();
  page.on('pageerror', (e) => fail('sayfa hatası: ' + e.message));
  await page.addInitScript(() => {
    window.__msgs = [];
    window.Kalem = { postMessage: (m) => window.__msgs.push(JSON.parse(m)) };
    window.Sayfa = { postMessage: () => {} };
    window.Durum = { postMessage: () => {} };
  });
  await page.goto('file://' + path.join(root, 'assets/word/viewer.html'));
  const docx = fs.readFileSync(path.join(root, 'test/fixtures/office/tablo.docx'));
  await page.evaluate((b) => window.renderDocx(b), docx.toString('base64'));
  await page.waitForTimeout(1500);
  await page.evaluate(() => window.setEditable(true));
  const take = () => page.evaluate(() => window.__msgs.splice(0));

  const n = (await take()).find((m) => m.n !== undefined);
  if (!n || n.n !== 6) fail('paragraf sayısı 6 değil: ' + JSON.stringify(n));

  for (const [target, index] of [['Son paragraf', 5], ['Ayşe', 3]]) {
    await page.getByText(target, { exact: true }).click();
    await page.keyboard.press('End');
    await page.keyboard.type(' X');
    await page.waitForTimeout(400);
    const seg = (await take()).find((m) => m.segs);
    if (!seg || seg.i !== index || !seg.segs[0][0].endsWith(' X')) {
      fail(`"${target}" yazımı gitmedi: ` + JSON.stringify(seg));
    }
  }

  await page.evaluate(() => {
    const p = [...document.querySelectorAll('p')]
      .find((p) => p.textContent.startsWith('Toplantı'));
    const walker = document.createTreeWalker(p, NodeFilter.SHOW_TEXT);
    const tn = walker.nextNode();
    const r = document.createRange();
    r.setStart(tn, 0);
    r.setEnd(tn, 'Toplantı'.length);
    getSelection().removeAllRanges();
    getSelection().addRange(r);
    window.setFontSize(20);
  });
  await page.waitForTimeout(400);
  const size = (await take()).find((m) => m.segs);
  const sized = size && size.segs.filter((s) => s[5] === 20);
  if (!sized || sized.length !== 1 || sized[0][0] !== 'Toplantı') {
    fail('seçime punto verilemedi: ' + JSON.stringify(size));
  }

  const caret = await page.evaluate(() => window.caretParaIndex());
  if (caret !== 0) fail('imleç paragrafı 0 değil: ' + caret);

  await browser.close();
  if (!process.exitCode) console.log('Word köprüsü: tamam');
})();
