/// **Kokoro-82M çalışanı** (U6a, 2026-11-21) — motor sayfası (`VoiceServer.engineHtml`)
/// bunu `kokoro-worker.js` adresinden Web Worker olarak açar. Dosya bizim:
/// indirilmez, [VoiceServer] doğrudan bu metni verir. Türkçe metin→ses birimi
/// kuralları `empiriolabsai/kokoro-turkish` deposundaki `g2p_tr.py`nin birebir
/// karşılığı (Python ile 12 cümlede aynı çıktı denendi); ses birimleri
/// espeak-ng (GPL-3.0, WASM, ayrı indirilir) ile çıkar.
const kokoroWorkerJs = r'''// Kokoro-82M çalışanı (2026-11-21, U6a). Türkçe: empiriolabsai/kokoro-turkish
// (Apache-2.0; metin->ses birimi g2p_tr.py'nin JS karşılığı), İngilizce:
// Kokoro-82M v1.0 (Apache-2.0; normalleştirme kokoro.js'ten). Ses birimleri
// espeak-ng (GPL-3.0, WASM) ile; model ONNX Runtime Web (antalia kopyası).
//   -> {type:'load', lang:'tr'|'en', dir, voice}   <- progress / ready / error
//   -> {type:'speak', id, text, speed}             <- chunk ... done {rate}
import * as ort from './antalia/vendor/ort/ort.wasm.min.mjs';
import ESpeakNG from './kokoro/espeak-ng.js';

const BASE = new URL('./', import.meta.url);
const SYMBOLS = ';:,.!?—…"()“” ̃ʣʥʦʨᵝꭧAIOQSTWYᵊ' +
  'abcdefhijklmnopqrstuvwxyzɑɐɒæβɔɕçɖðʤəɚɛɜɟɡ' +
  'ɥɨɪʝɯɰŋɳɲɴøɸθœɹɾɻ' +
  'ʁɽʂʃʈʧʊʋʌɣɤχʎʒʔˈˌ' +
  'ːʰʲ↓→↗↘ᵻ';
// Kokoro-82M config.json "vocab" (iki modelde aynı): sembol -> kimlik.
const IDS = [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 31, 33, 35, 36, 39, 41, 42,
  43, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 75, 76,
  77, 78, 80, 81, 82, 83, 85, 86, 87, 90, 92, 99, 101, 102, 103, 110, 111, 112, 113, 114, 115, 116, 118, 119, 120, 123, 125,
  126, 128, 129, 130, 131, 132, 133, 135, 136, 138, 139, 140, 142, 143, 147, 148, 156, 157, 158, 162, 164, 169, 171, 172, 173,
  177];
export const VOCAB = new Map([...SYMBOLS].map((s, i) => [s, IDS[i]]));

const clean = (s) => s.replace(/\s+/g, ' ').trim();

// ── espeak-ng: tek çağrıda satır başına bir parça (stdin satır satır okunur) ──
let espeakWasm = null;
async function espeakRun(lines, voice) {
  espeakWasm ??= WebAssembly.compile(await (await fetch(new URL('kokoro/espeak-ng.wasm', BASE))).arrayBuffer());
  const wasm = await espeakWasm;
  const bytes = new TextEncoder().encode(lines.join('\n') + '\n');
  let i = 0;
  const m = await ESpeakNG({
    arguments: ['--phonout', 'out', '-q', '-b', '1', '--ipa', '-v', voice],
    stdin: () => (i < bytes.length ? bytes[i++] : null),
    print: () => {}, printErr: () => {},
    instantiateWasm: (imports, ok) => { WebAssembly.instantiate(wasm, imports).then((x) => ok(x)); return {}; },
  });
  return m.FS.readFile('out', { encoding: 'utf8' }).split('\n').map((s) => s.trim()).filter(Boolean);
}

// Parça sayısı tutmazsa (espeak bir parçayı bölmüş) o öbek tek tek yapılır.
async function espeak(chunks, voice) {
  const out = [];
  for (let s = 0; s < chunks.length; s += 64) {
    const part = chunks.slice(s, s + 64);
    const got = await espeakRun(part, voice);
    if (got.length === part.length) out.push(...got);
    else for (const c of part) out.push((await espeakRun([c], voice)).join(' '));
  }
  return out;
}

// ── Türkçe: g2p_tr.py (EmpirioLabs, Apache-2.0) birebir ──
const W = '\\p{L}\\p{N}_';
const B = `(?<![${W}])`, E = `(?![${W}])`;
const R = (s) => new RegExp(s, 'gu');
const UNITS = ['sıfır', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz'];
const TENS = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli', 'altmış', 'yetmiş', 'seksen', 'doksan'];
const MONTHS = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const LETTERS = { a: 'a', b: 'be', c: 'ce', ç: 'çe', d: 'de', e: 'e', f: 'fe', g: 'ge', ğ: 'yumuşak ge', h: 'he', ı: 'ı',
  i: 'i', j: 'je', k: 'ke', l: 'le', m: 'me', n: 'ne', o: 'o', ö: 'ö', p: 'pe', q: 'kü', r: 're', s: 'se', ş: 'şe', t: 'te',
  u: 'u', ü: 'ü', v: 've', w: 'çift ve', x: 'iks', y: 'ye', z: 'ze' };
const ABBR = [
  [`${B}vb\\.`, 've benzeri'], [`${B}vs\\.`, 'vesaire'], [`${B}vd\\.`, 've diğerleri'], [`${B}Dr\\.`, 'Doktor'],
  [`${B}Prof\\.`, 'Profesör'], [`${B}Doç\\.`, 'Doçent'], [`${B}Op\\.`, 'Operatör'], [`${B}Av\\.`, 'Avukat'],
  [`${B}Sn\\.`, 'Sayın'], [`${B}örn\\.`, 'örneğin'], [`${B}bkz\\.`, 'bakınız'], [`${B}Cad\\.`, 'Caddesi'],
  [`${B}Sok\\.`, 'Sokağı'], [`${B}Mah\\.`, 'Mahallesi'], [`${B}Blv\\.`, 'Bulvarı'], [`${B}No\\.?(?=\\s?\\d)`, 'numara'],
  [`${B}yy\\.`, 'yüzyıl'], [`${B}M\\.Ö\\.`, 'milattan önce'], [`${B}M\\.S\\.`, 'milattan sonra'], [`${B}MÖ${E}`, 'milattan önce'],
  [`${B}MS${E}`, 'milattan sonra'], [`${B}Tel\\.`, 'telefon'], [`${B}çev\\.`, 'çeviren'], [`${B}haz\\.`, 'hazırlayan'],
  [`${B}AŞ${E}`, 'anonim şirketi'], [`${B}A\\.Ş\\.`, 'anonim şirketi'], [`${B}Ltd\\.`, 'limitet'], [`${B}Şti\\.`, 'şirketi'],
].map(([p, r]) => [R(p), r]);
const UNIT_WORDS = { 'km/sa': 'kilometre', km: 'kilometre', cm: 'santimetre', mm: 'milimetre', m: 'metre',
  kg: 'kilogram', gr: 'gram', g: 'gram', mg: 'miligram', lt: 'litre', l: 'litre', ml: 'mililitre', '°C': 'derece',
  '°': 'derece', TL: 'lira', '₺': 'lira', $: 'dolar', USD: 'dolar', '€': 'avro', EUR: 'avro', '£': 'sterlin', sa: 'saat',
  dk: 'dakika', sn: 'saniye', MB: 'megabayt', GB: 'gigabayt' };
const AFFRICATES = [['t͡s', 'ʦ'], ['d͡z', 'ʣ'], ['t͡ʃ', 'ʧ'], ['d͡ʒ', 'ʤ'], ['t͡ɕ', 'ʨ'], ['d͡ʑ', 'ʥ'],
  ['ts', 'ʦ'], ['dz', 'ʣ'], ['tʃ', 'ʧ'], ['dʒ', 'ʤ'], ['tɕ', 'ʨ'], ['dʑ', 'ʥ']];
const TR_MAP = [...AFFRICATES, ['ɫ', 'l'], ['g', 'ɡ'], ['ʎ', 'l'], ['ɦ', 'h']];
const VOWELS = 'aıoueiöü';

const trLower = (s) => s.replace(/I/g, 'ı').replace(/İ/g, 'i').toLowerCase();

function below1000(n) {
  const h = Math.floor(n / 100), r = n % 100, w = [];
  if (h) w.push(...(h === 1 ? ['yüz'] : [UNITS[h], 'yüz']));
  const t = Math.floor(r / 10), u = r % 10;
  if (t) w.push(TENS[t]);
  if (u) w.push(UNITS[u]);
  return w;
}

function intWords(n) {
  if (n < 0) return 'eksi ' + intWords(-n);
  if (n === 0) return 'sıfır';
  const w = [];
  for (const [v, word] of [[1e12, 'trilyon'], [1e9, 'milyar'], [1e6, 'milyon'], [1000, 'bin']]) {
    const q = Math.floor(n / v);
    n %= v;
    if (q) w.push(...(q === 1 && word === 'bin' ? [word] : [...below1000(q), word]));
  }
  w.push(...below1000(n));
  return w.join(' ');
}

function lastVowel(word) {
  const s = trLower(word);
  for (let i = s.length - 1; i >= 0; i--) if (VOWELS.includes(s[i])) return s[i];
  return 'e';
}

function ordinalWords(n) {
  const w = intWords(n).split(' ');
  const last = w[w.length - 1];
  const base = last === 'dört' ? 'dörd' : last;
  let sfx = { a: 'ıncı', ı: 'ıncı', o: 'uncu', u: 'uncu', e: 'inci', i: 'inci', ö: 'üncü', ü: 'üncü' }[lastVowel(last)];
  if (VOWELS.includes(base[base.length - 1])) sfx = sfx.slice(1);
  return [...w.slice(0, -1), base + sfx].join(' ');
}

// ponytail: 15 haneyi aşan sayı (Number sınırı) hane hane okunur.
const num = (s) => {
  const d = s.replace(/\./g, '');
  return d.length > 15 ? null : Number(d);
};
const numWords = (s) => {
  const n = num(s);
  return n === null ? [...s.replace(/\./g, '')].map((c) => UNITS[+c]).join(' ') : intWords(n);
};
const decimal = (i, f) =>
  `${numWords(i)} virgül ${f.startsWith('0') || f.length > 15 ? [...f].map((d) => UNITS[+d]).join(' ') : intWords(Number(f))}`;
const spell = (w) => [...trLower(w)].map((c) => LETTERS[c] ?? c).join(' ');

function unify(t) {
  t = t.replace(/…/g, '...').replace(/[  ]/g, ' ');
  t = t.replace(/[‘’‚‛ʼ´`]/g, "'");
  t = t.replace(/[“”„‟«»‹›"]/g, '"');
  t = t.replace(/\s[-–—]+\s/g, ' — ');
  t = t.replace(/[–—]/g, ' — ');
  t = t.replace(/\.{3,}/g, '…');
  t = t.replace(/[!?]{2,}/g, (m) => m[0]);
  return clean(t);
}

function keepFinalPunct(original, normalized) {
  const o = original.trimEnd(), n = normalized.trimEnd();
  if (o && '.!?…'.includes(o[o.length - 1]) && n && !'.!?…'.includes(n[n.length - 1])) return n + o[o.length - 1];
  return n;
}

export function normalizeTr(text) {
  let t = unify(text.normalize('NFC'));
  for (const [p, r] of ABBR) t = t.replace(p, r);
  const sfx = "(?:'([a-zçğıöşüA-ZÇĞİÖŞÜ]+))?";
  t = t.replace(R(`${B}(\\d{1,2})[./](\\d{1,2})[./](\\d{4})${sfx}`), (m, d, mo, y, s) => {
    d = +d; mo = +mo;
    if (!(mo >= 1 && mo <= 12 && d >= 1 && d <= 31)) return m;
    return `${intWords(d)} ${MONTHS[mo - 1]} ${intWords(+y)}` + (s || '');
  });
  t = t.replace(R(`${B}(\\d{4})-(\\d{1,2})-(\\d{1,2})${E}`), (m, y, mo, d) =>
    +mo >= 1 && +mo <= 12 ? `${intWords(+d)} ${MONTHS[+mo - 1]} ${intWords(+y)}` : m);
  const hm = (m, h, mi, s) => {
    h = +h; mi = +mi;
    if (h > 23 || mi > 59) return m;
    let w = intWords(h);
    if (mi) w += ' ' + (mi >= 10 ? intWords(mi) : 'sıfır ' + UNITS[mi]);
    return w + (s || '');
  };
  t = t.replace(R(`${B}(\\d{1,2}):(\\d{2})${sfx}`), hm);
  t = t.replace(R(`(?<=${B}saat )(\\d{1,2})\\.(\\d{2})${sfx}`), hm);
  t = t.replace(R(`%\\s?(\\d+(?:,\\d+)?)${sfx}`), (m, n, s) => 'yüzde ' + n + (s ? "'" + s : ''));
  t = t.replace(/(\d+(?:,\d+)?)\s?%/g, (m, n) => 'yüzde ' + n);
  t = t.replace(/([₺$€£])\s?((?:\d{1,3}(?:\.\d{3})+|\d+)(?:,\d{1,2})?)/g, (m, c, n) => `${n} ${UNIT_WORDS[c]}`);
  const units = Object.keys(UNIT_WORDS).sort((a, b) => b.length - a.length)
    .map((u) => u.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&')).join('|');
  t = t.replace(R(`(\\d{1,3}(?:\\.\\d{3})+|\\d+)(?:,(\\d+))?\\s?(${units})(?![${W}])${sfx}`), (m, n, frac, unit, s) => {
    const word = UNIT_WORDS[unit];
    let w;
    if (frac && word === 'lira') {
      const k = +frac.padEnd(2, '0').slice(0, 2);
      w = `${numWords(n)} lira` + (+frac ? ` ${intWords(k)} kuruş` : '');
    } else if (frac) w = `${decimal(n, frac)} ${word}`;
    else w = `${numWords(n)} ${word}`;
    return w + (s || '');
  });
  t = t.replace(R(`${B}(\\d+)\\.(?=\\s+[a-zçğıöşü])`), (m, n) => ordinalWords(+n));
  t = t.replace(R(`${B}(\\d+)'(?:inci|ıncı|uncu|üncü|nci|ncı|ncu|ncü)${E}`), (m, n) => ordinalWords(+n));
  t = t.replace(R(`${B}(\\d{1,3}(?:\\.\\d{3})+|\\d+),(\\d+)${sfx}`), (m, i, f, s) => decimal(i, f) + (s || ''));
  t = t.replace(R(`${B}(\\d{1,3}(?:\\.\\d{3})+|\\d+)${sfx}`), (m, n, s) => numWords(n) + (s || ''));
  t = t.replace(/&/g, ' ve ').replace(/\+/g, ' artı ').replace(/=/g, ' eşittir ').replace(/@/g, ' et ');
  t = t.replace(R(`${B}([A-ZÇĞİÖŞÜ]{2,5})(?:'([a-zçğıöşü]+))?(?![a-zçğıöşü])`), (m, a, s) =>
    a.length <= 3 || !/[AEIİOÖUÜ]/u.test(a) ? spell(a) + (s || '') : trLower(a) + (s || ''));
  t = t.replace(R(`([${W}])'([${W}])`), '$1$2');
  t = t.replace(/\//g, ' ');
  return keepFinalPunct(text, clean(t));
}

const KEEP = ';:,.!?…', EM = '—';
export function chunkTr(text) {
  const out = [], parts = text.split(/([;:,.!?…—"()[\]{}¿¡]+)/u);
  for (let i = 0; i < parts.length; i += 2) {
    const words = parts[i].trim();
    let kept = [...(parts[i + 1] || '')].filter((c) => KEEP.includes(c) || c === EM).join('');
    if (kept) for (const s of ['?', '!', '…', '.', ';', ':', EM, ',']) if (kept.includes(s)) { kept = s; break; }
    if (words) out.push([words, kept]);
    else if (kept && out.length && !out[out.length - 1][1]) out[out.length - 1][1] = kept;
  }
  return out;
}

const mapSymbols = (ps, table) => table.reduce((s, [a, b]) => s.split(a).join(b), ps);
const toVocab = (ps) => clean([...ps].filter((c) => VOCAB.has(c)).join(''));

async function phonemesTr(text) {
  const pairs = chunkTr(normalizeTr(text));
  if (!pairs.length) return '';
  const ph = await espeak(pairs.map(([w]) => trLower(w)), 'tr');
  const pieces = [];
  ph.forEach((p, i) => {
    p = p.trim();
    if (!p) return;
    const k = pairs[i][1];
    pieces.push(k === EM ? p + ' ' + EM : p + k);
  });
  return toVocab(mapSymbols(clean(pieces.join(' ')), TR_MAP));
}

// ── İngilizce: kokoro.js phonemize.js (hexgrad, Apache-2.0) ──
function splitNum(m) {
  if (m.includes('.')) return m;
  if (m.includes(':')) {
    const [h, mi] = m.split(':').map(Number);
    return mi === 0 ? `${h} o'clock` : mi < 10 ? `${h} oh ${mi}` : `${h} ${mi}`;
  }
  const year = parseInt(m.slice(0, 4), 10);
  if (year < 1100 || year % 1000 < 10) return m;
  const left = m.slice(0, 2), right = parseInt(m.slice(2, 4), 10), s = m.endsWith('s') ? 's' : '';
  if (year % 1000 >= 100 && year % 1000 <= 999) {
    if (right === 0) return `${left} hundred${s}`;
    if (right < 10) return `${left} oh ${right}${s}`;
  }
  return `${left} ${right}${s}`;
}
function flipMoney(m) {
  const bill = m[0] === '$' ? 'dollar' : 'pound';
  if (isNaN(Number(m.slice(1)))) return `${m.slice(1)} ${bill}s`;
  if (!m.includes('.')) return `${m.slice(1)} ${bill}${m.slice(1) === '1' ? '' : 's'}`;
  const [b, c] = m.slice(1).split('.'), d = parseInt(c.padEnd(2, '0'), 10);
  const coins = m[0] === '$' ? (d === 1 ? 'cent' : 'cents') : d === 1 ? 'penny' : 'pence';
  return `${b} ${bill}${b === '1' ? '' : 's'} and ${d} ${coins}`;
}
const pointNum = (m) => { const [a, b] = m.split('.'); return `${a} point ${b.split('').join(' ')}`; };
export function normalizeEn(t) {
  return t.replace(/[‘’]/g, "'").replace(/«/g, '“').replace(/»/g, '”').replace(/[“”]/g, '"')
    .replace(/\(/g, '«').replace(/\)/g, '»')
    .replace(/、/g, ', ').replace(/。/g, '. ').replace(/！/g, '! ').replace(/，/g, ', ').replace(/：/g, ': ')
    .replace(/；/g, '; ').replace(/？/g, '? ')
    .replace(/[^\S \n]/g, ' ').replace(/  +/, ' ').replace(/(?<=\n) +(?=\n)/g, '')
    .replace(/\bD[Rr]\.(?= [A-Z])/g, 'Doctor').replace(/\b(?:Mr\.|MR\.(?= [A-Z]))/g, 'Mister')
    .replace(/\b(?:Ms\.|MS\.(?= [A-Z]))/g, 'Miss').replace(/\b(?:Mrs\.|MRS\.(?= [A-Z]))/g, 'Mrs')
    .replace(/\betc\.(?! [A-Z])/gi, 'etc').replace(/\b(y)eah?\b/gi, "$1e'a")
    .replace(/\d*\.\d+|\b\d{4}s?\b|(?<!:)\b(?:[1-9]|1[0-2]):[0-5]\d\b(?!:)/g, splitNum)
    .replace(/(?<=\d),(?=\d)/g, '')
    .replace(/[$£]\d+(?:\.\d+)?(?: hundred| thousand| (?:[bm]|tr)illion)*\b|[$£]\d+\.\d\d?\b/gi, flipMoney)
    .replace(/\d*\.\d+/g, pointNum).replace(/(?<=\d)-(?=\d)/g, ' to ').replace(/(?<=\d)S/g, ' S')
    .replace(/(?<=[BCDFGHJ-NP-TV-Z])'?s\b/g, "'S").replace(/(?<=X')S\b/g, 's')
    .replace(/(?:[A-Za-z]\.){2,} [a-z]/g, (m) => m.replace(/\./g, '-')).replace(/(?<=[A-Z])\.(?=[A-Z])/gi, '-')
    .trim();
}
const EN_PUNCT = /(\s*[;:,.!?¡¿—…"«»“”(){}[\]]+\s*)+/g;
async function phonemesEn(text) {
  text = normalizeEn(text);
  const parts = [];
  let prev = 0;
  for (const m of text.matchAll(EN_PUNCT)) {
    if (prev < m.index) parts.push([false, text.slice(prev, m.index)]);
    parts.push([true, m[0]]);
    prev = m.index + m[0].length;
  }
  if (prev < text.length) parts.push([false, text.slice(prev)]);
  const words = parts.filter(([p, s]) => !p && s.trim()).map(([, s]) => s.replace(/\s+/g, ' ').trim());
  const ph = await espeak(words, 'en-us');
  let k = 0;
  const ps = parts.map(([p, s]) => (p ? s : s.trim() ? ph[k++] : s)).join('')
    .replace(/kəkˈoːɹoʊ/g, 'kˈoʊkəɹoʊ').replace(/kəkˈɔːɹəʊ/g, 'kˈəʊkəɹəʊ').replace(/ʲ/g, 'j').replace(/r/g, 'ɹ')
    .replace(/x/g, 'k').replace(/ɬ/g, 'l').replace(/(?<=[a-zɹː])(?=hˈʌndɹɪd)/g, ' ')
    .replace(/ z(?=[;:,.!?¡¿—…"«»“” ]|$)/g, 'z').replace(/(?<=nˈaɪn)ti(?!ː)/g, 'di');
  return toVocab(mapSymbols(ps, AFFRICATES));
}

// ≤ MAX ses birimlik parçalar: önce cümle sonu, sonra virgül, en son boşluk.
const MAX = 400;
export function segments(ps) {
  const out = [];
  while (ps.length > MAX) {
    const head = ps.slice(0, MAX);
    let cut = -1;
    for (const re of [/[.!?…] /g, /[,;:—] /g, / /g]) {
      for (const m of head.matchAll(re)) cut = m.index + m[0].length;
      if (cut > MAX / 4) break;
      cut = -1;
    }
    if (cut < 0) cut = MAX;
    out.push(ps.slice(0, cut).trim());
    ps = ps.slice(cut).trim();
  }
  if (ps) out.push(ps);
  return out;
}

export const g2p = { tr: phonemesTr, en: phonemesEn };

let session = null, style = null, lang = 'tr';

async function fetchAll(urls) {
  const bufs = [], loaded = urls.map(() => 0), total = urls.map(() => 0);
  for (const [i, u] of urls.entries()) {
    const res = await fetch(new URL(u, BASE));
    if (!res.ok) throw new Error(`${u}: HTTP ${res.status}`);
    total[i] = Number(res.headers.get('Content-Length')) || 0;
    const reader = res.body.getReader(), parts = [];
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      parts.push(value);
      loaded[i] += value.byteLength;
      postMessage({ type: 'progress', loaded: loaded.reduce((a, b) => a + b, 0), total: total.reduce((a, b) => a + b, 0) });
    }
    const all = new Uint8Array(loaded[i]);
    let o = 0;
    for (const p of parts) { all.set(p, o); o += p.byteLength; }
    bufs.push(all);
  }
  return bufs;
}

// ── Model yaması (bellekte; diskteki dosya özetiyle aynı kalır) ──
// Kök neden (2026-11-21, ORT Web 1.30/1.31 + int8): üretecin STFT evresi
// atan(sanal/gerçek) ile hesaplanıyor; nicemli evrişim sessiz karede tam 0
// veriyor → 0/0 = NaN → tüm ses NaN (sessiz). Paydaya 1e-12 eklenir:
// atan2(0,0)=0 olur, öteki değerler değişmez.
function rv(b, p) {
  let x = 0, s = 0, c;
  do { c = b[p++]; x += (c & 0x7f) * 2 ** s; s += 7; } while (c & 0x80);
  return [x, p];
}
function wv(x) {
  const o = [];
  while (x > 127) { o.push((x % 128) | 0x80); x = Math.floor(x / 128); }
  o.push(x);
  return o;
}
function* fields(b, p, end) {
  while (p < end) {
    const k = p;
    let key, vs, ve, len;
    [key, p] = rv(b, p);
    const f = Math.floor(key / 8), w = key % 8;
    vs = p;
    if (w === 0) [, ve] = rv(b, p);
    else if (w === 2) { [len, vs] = rv(b, p); ve = vs + len; }
    else if (w === 5) ve = p + 4;
    else if (w === 1) ve = p + 8;
    else throw new Error('onnx: bozuk');
    yield { f, k, vs, ve };
    p = ve;
  }
}
const enc = new TextEncoder(), dec = new TextDecoder();
const cat = (parts) => {
  const out = new Uint8Array(parts.reduce((a, p) => a + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
};
const field = (f, bytes) => cat([new Uint8Array(wv(f * 8 + 2)), new Uint8Array(wv(bytes.length)), bytes]);
const str = (f, s) => field(f, enc.encode(s));

export function patchAtan(b) {
  const g = [...fields(b, 0, b.length)].find((x) => x.f === 7);
  if (!g) return b;
  let atanIn = null;
  const divs = new Map();
  for (const n of fields(b, g.vs, g.ve)) {
    if (n.f !== 1) continue;
    const ins = [], outs = [];
    let op = '';
    for (const x of fields(b, n.vs, n.ve)) {
      if (x.f === 4) op = dec.decode(b.subarray(x.vs, x.ve));
      else if (x.f === 1) ins.push(x);
      else if (x.f === 2) outs.push(x);
    }
    const name = (x) => dec.decode(b.subarray(x.vs, x.ve));
    if (op === 'Atan') atanIn = name(ins[0]);
    else if (op === 'Div' && outs.length) divs.set(name(outs[0]), { n, ins: ins.map(name), out: name(outs[0]) });
  }
  const d = divs.get(atanIn);
  if (!d) return b;
  const eps = new Uint8Array(new Float32Array([1e-12]).buffer);
  const graph = cat([
    b.subarray(g.vs, d.n.k),
    field(1, cat([str(1, d.ins[1]), str(1, 'kokoro_eps'), str(2, 'kokoro_den'), str(4, 'Add')])),
    field(1, cat([str(1, d.ins[0]), str(1, 'kokoro_den'), str(2, d.out), str(4, 'Div')])),
    b.subarray(d.n.ve, g.ve),
    field(5, cat([new Uint8Array([0x10, 0x01]), str(8, 'kokoro_eps'), field(9, eps)])),
  ]);
  return cat([b.subarray(0, g.k), new Uint8Array(wv(7 * 8 + 2)), new Uint8Array(wv(graph.length)), graph,
    b.subarray(g.ve)]);
}

async function load({ lang: l, dir, voice }) {
  lang = l;
  ort.env.wasm.wasmPaths = new URL('antalia/vendor/ort/', BASE).href;
  const cores = self.crossOriginIsolated ? navigator.hardwareConcurrency || 1 : 1;
  ort.env.wasm.numThreads = Math.max(1, Math.min(4, Math.floor(cores / 2)));
  const [model, v] = await fetchAll([`${dir}/model_quantized.onnx`, `${dir}/${voice}.bin`]);
  style = new Float32Array(v.buffer, v.byteOffset, v.byteLength / 4);
  session = await ort.InferenceSession.create(patchAtan(model), { executionProviders: ['wasm'] });
  postMessage({ type: 'ready' });
}

export async function infer(ps, speed) {
  const ids = [0, ...[...ps].map((c) => VOCAB.get(c)).filter((x) => x !== undefined), 0];
  const row = Math.min(Math.max(ids.length - 3, 0), 509);
  const out = await session.run({
    input_ids: new ort.Tensor('int64', BigInt64Array.from(ids, BigInt), [1, ids.length]),
    style: new ort.Tensor('float32', style.slice(row * 256, row * 256 + 256), [1, 256]),
    speed: new ort.Tensor('float32', new Float32Array([speed]), [1]),
  });
  return out[session.outputNames[0]].data;
}

async function speak({ id, text, speed = 1 }) {
  const segs = segments(await g2p[lang](text));
  for (const [index, s] of segs.entries()) {
    const audio = await infer(s, speed);
    postMessage({ type: 'chunk', id, index, count: segs.length, audio }, [audio.buffer]);
  }
  postMessage({ type: 'done', id, rate: 24000 });
}

self.onmessage = async (ev) => {
  const m = ev.data;
  try {
    if (m.type === 'load') await load(m);
    else if (m.type === 'speak') await speak(m);
  } catch (e) {
    postMessage({ type: 'error', id: m.id, message: String((e && e.message) || e) });
  }
};
''';
