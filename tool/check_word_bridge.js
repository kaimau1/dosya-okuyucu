// Word canlı düzenleme köprüsünün (assets/word/viewer.html) gerçek bir
// Chromium'da denetimi (Faz 9). CI'da koşmaz; JS değiştiyse elle:
//
//   PLAYWRIGHT_MODULE=/opt/node-tools/node_modules/playwright \
//   CHROMIUM=/opt/pw-browsers/chromium node tool/check_word_bridge.js
//
// Örnek belgeler: test/fixtures/office/view/*.docx — WebView'ın gördüğü
// İŞARETLİ kopyalar (DocxEditor.viewBytes; tool/write_fixtures_test.dart
// üretir). Denetlenen:
//  1. paragraf sayısı (tablo hücreleri dahil) Dart modeliyle aynı (6),
//  2. yazılan metin Flutter'a GİDİYOR — normal paragrafta ve tablo hücresinde
//     (Faz 9 kök neden: `input` olayının hedefi <article>, <p> değil),
//  3. seçime verilen punto/yazı tipi yalnız o parçaya işleniyor,
//  5. (Faz 21a) Word'de kaydedilmiş çok sayfalı belgede düzenleme açılıyor
//     (W1: lastRenderedPageBreak paragrafı bölünce sayı TUTMUYORDU), bölünmüş
//     paragrafın ikinci yarısına yazılan metin TEK paragraf olarak gidiyor,
//     Enter yeni paragraf açıyor, geri silme birleştiriyor, adalar
//     düzenlenemiyor ve parçalarda kimlikleriyle gidiyor, geri al çalışıyor.
//     Mesaj dizisi test/fixtures/office/view/bridge_messages.jsonl'e yazılır
//     (Dart testi aynı diziyi modele oynatır).
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
  const docx = fs.readFileSync(path.join(root, 'test/fixtures/office/view/tablo.docx'));
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

  // 4. Symbol/Wingdings madde imleri ve w:sym Unicode'a çevrilir (kullanıcı
  //    2026-10-22: "nokta simgesi görülmüyor"); düzenlemede Flutter'a ÖZGÜN
  //    karakter gider. Belge: python3 tool/make_symbol_bullets_docx.py
  const sym = fs.readFileSync(
      path.join(root, 'test/fixtures/office/view/madde_imleri.docx'));
  await page.evaluate((b) => window.renderDocx(b), sym.toString('base64'));
  await page.waitForTimeout(1500);
  const marks = await page.evaluate(() => [...document.querySelectorAll('#container p')]
    .map((p) => getComputedStyle(p, '::before').content));
  for (const ch of ['•', '▪', '➢', '✓']) {
    if (!marks.some((m) => m.includes(ch))) fail(`madde imi ${ch} yok: ` + JSON.stringify(marks));
  }
  if (marks.some((m) => /[\uF000-\uF0FF]/.test(m))) fail('özel kod noktası kaldı');
  const line = await page.evaluate(() => [...document.querySelectorAll('#container p')]
    .pop().textContent);
  if (line !== 'Simge: → ve α') fail('w:sym çevrilmedi: ' + line);
  await page.evaluate(() => window.setEditable(true));
  take();
  await page.getByText('Simge:', { exact: false }).click();
  await page.keyboard.press('End');
  await page.keyboard.type('!');
  await page.waitForTimeout(400);
  const symSeg = (await take()).find((m) => m.segs);
  const joined = symSeg ? symSeg.segs.map((x) => x[0]).join('') : '';
  // Faz 21: w:sym artık dokunulmaz ADA — XML'de özgün düğüm korunur,
  // parçada "\uFFFC" + kimlik gider (eskiden özgün karakter metin olarak
  // geri yazılıyordu).
  const symIslands = symSeg ? symSeg.segs.filter((x) => x.length > 9).length : 0;
  if (joined !== 'Simge: \uFFFC ve \uFFFC!' || symIslands !== 2) {
    fail('düzenlemede simge adası gitmedi: ' + JSON.stringify(joined));
  }

  // 5. Faz 21a — çok sayfalı Word belgesi.
  const multi = fs.readFileSync(
      path.join(root, 'test/fixtures/office/view/word_kaydedilmis_cok_sayfa.docx'));
  await page.evaluate(() => window.setEditable(false));
  await page.evaluate((b) => window.renderDocx(b), multi.toString('base64'));
  await page.waitForTimeout(1500);
  const log = [];
  const takeLog = async () => { const m = await take(); log.push(...m); return m; };
  await takeLog();
  await page.evaluate(() => window.setEditable(true));
  const nMsg = (await takeLog()).find((m) => m.n !== undefined);
  if (!nMsg || nMsg.n !== 31) fail('çok sayfalı belgede işaretli paragraf 31 değil: ' + JSON.stringify(nMsg));
  const pCount = await page.evaluate(() => document.querySelectorAll('#container article p').length);
  if (pCount <= 31) fail('docx-preview paragrafı bölmedi (örnek yanlış?): ' + pCount);

  // Bölünmüş paragrafın İKİNCİ yarısına yaz → tek paragraf, tam metin.
  const second = await page.evaluate(() => {
    const p = document.querySelector('#container p[data-fkc]');
    return p ? p.getAttribute('data-fkc') : null;
  });
  if (second === null) fail('devam parçası işaretlenmedi');
  await page.evaluate(() => {
    const p = document.querySelector('#container p[data-fkc]');
    const r = document.createRange();
    r.selectNodeContents(p);
    r.collapse(false);
    getSelection().removeAllRanges();
    getSelection().addRange(r);
  });
  await page.keyboard.type('!');
  await page.waitForTimeout(400);
  const contSeg = (await takeLog()).find((m) => m.segs && m.i !== undefined);
  const contText = contSeg ? contSeg.segs.map((x) => x[0]).join('') : '';
  if (!contSeg || String(contSeg.i) !== second ||
      contText !== 'Sayfa sonunda başlayan ve sonraki sayfada biten paragraf.!') {
    fail('devam parçasına yazım tek paragraf gitmedi: ' + JSON.stringify(contSeg));
  }
  if (!contSeg.base) fail('ilk düzenlemede base gitmedi');

  // Enter: "Giriş paragrafı." → "Giriş " | "paragrafı."
  await page.getByText('Giriş paragrafı.', { exact: true }).click();
  await page.evaluate(() => {
    const p = [...document.querySelectorAll('#container p')]
      .find((x) => x.textContent === 'Giriş paragrafı.');
    const walker = document.createTreeWalker(p, NodeFilter.SHOW_TEXT);
    const tn = walker.nextNode();
    const r = document.createRange();
    r.setStart(tn, 6);
    r.collapse(true);
    getSelection().removeAllRanges();
    getSelection().addRange(r);
  });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(200);
  const split = (await takeLog()).find((m) => m.split !== undefined);
  if (!split || split.split !== 1 || split.at !== 6 ||
      split.b.map((x) => x[0]).join('') !== 'paragrafı.') {
    fail('Enter yeni paragraf açmadı: ' + JSON.stringify(split));
  }
  const n2 = await page.evaluate(() => document.querySelectorAll('#container p[data-fkp]').length);
  if (n2 !== 32) fail('Enter sonrası işaretli paragraf 32 değil: ' + n2);
  // İmleç yeni paragrafın başında: geri silme birleştirir.
  await page.keyboard.press('Backspace');
  await page.waitForTimeout(200);
  const merge = (await takeLog()).find((m) => m.merge !== undefined);
  if (!merge || merge.merge !== 2 || merge.segs.map((x) => x[0]).join('') !== 'Giriş paragrafı.') {
    fail('geri silme birleştirmedi: ' + JSON.stringify(merge));
  }
  // Geri al → bölünmüş hâl; yinele → birleşik.
  await page.evaluate(() => window.undoEdit());
  await page.waitForTimeout(100);
  const rest = (await takeLog()).find((m) => m.restore !== undefined);
  if (!rest || rest.undo !== true || rest.segs.length !== 2) fail('geri al yapısal adımı geri almadı: ' + JSON.stringify(rest));
  await page.evaluate(() => window.redoEdit());
  await page.waitForTimeout(100);
  await takeLog();

  // Adalar: köprü/sekme/dipnot düzenlenemez, parçalarda kimlikleriyle.
  const isl = await page.evaluate(() => {
    const p = [...document.querySelectorAll('#container p')]
      .find((x) => x.textContent.startsWith('Bağlantı'));
    return [...p.querySelectorAll('.fk-island')].map((e) => e.getAttribute('contenteditable'));
  });
  if (isl.length < 3 || isl.some((v) => v !== 'false')) fail('adalar yok/düzenlenebilir: ' + JSON.stringify(isl));
  await page.evaluate(() => {
    const p = [...document.querySelectorAll('#container p')]
      .find((x) => x.textContent.startsWith('Bağlantı'));
    const r = document.createRange();
    r.selectNodeContents(p);
    r.collapse(false);
    getSelection().removeAllRanges();
    getSelection().addRange(r);
  });
  await page.keyboard.type(' X');
  await page.waitForTimeout(400);
  const islSeg = (await takeLog()).find((m) => m.segs && m.i !== undefined);
  const ids = islSeg ? islSeg.segs.filter((x) => x.length > 9).length : 0;
  if (ids !== 3) fail('ada kimlikleri parçalarda yok: ' + JSON.stringify(islSeg));

  fs.writeFileSync(path.join(root, 'test/fixtures/office/view/bridge_messages.jsonl'),
      log.filter((m) => m.segs || m.split !== undefined ||
        m.merge !== undefined || m.restore !== undefined || m.mrange)
        .map((m) => JSON.stringify(m)).join('\n') + '\n');

  await browser.close();
  if (!process.exitCode) console.log('Word köprüsü: tamam');
})();
