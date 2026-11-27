/// Üst/alt bilgi + sayfa numarası **işareti** (B4/P20, Faz 63 m.3).
///
/// Syncfusion yazıyı sayfaya çizer; biz ardından yeni eklenen içerik akışını
/// `/Artifact <</Type /Pagination /DosyaOkuyucuHF 1>> BDC … EMC` ile
/// sararız. Kaldırma yalnız bu işaretli bloğu akıştan çıkarır — sayfanın
/// geri kalanına dokunulmaz.
///
/// Yanlış çıkan yol (2026-11-27): OCG katmanına çizip Syncfusion
/// `layers.remove(isRemoveGraphicalContent: true)` ile silmek 2 sayfalı
/// belgede 2. sayfanın TÜM içeriğini sildi (belge katmanının tek akışı
/// sayfalar arasında paylaşılıyor).
library;

import 'dart:convert' show latin1;

import 'pdf_objects.dart';
import 'pdf_syntax.dart';

const _marker = 'DosyaOkuyucuHF';
// Değer sayı (`true` değil): içerik tarayıcısı `true`yu operatör sanıp
// BDC'nin operandlarını keserdi.
const _open = '/Artifact <</Type /Pagination /$_marker 1>> BDC\n';

/// Sayfa başına çözülmüş içerik akışları (çözülemeyen akış `null`).
List<List<List<int>?>> _pageStreams(PdfFile f) => [
      for (final page in f.pages)
        [
          for (final s in f.contentsOf(page))
            () {
              try {
                return f.decodeStream(s);
              } catch (_) {
                return null;
              }
            }(),
        ],
    ];

/// [before] → [after] arasında sayfalara eklenen çizim akışlarını işaretler.
/// Şifreli belgede işaretleyemez ve [after]'ı aynen döndürür (kaldırılamaz).
/// Çizilen bir sayfada yeni akış bulunamazsa [StateError] — işaretsiz,
/// sonradan kaldırılamayan üst bilgi üretmektense işlem reddedilir.
List<int> markHeaderFooter(List<int> before, List<int> after,
    {required Set<int> drawnPages}) {
  final a = PdfFile.parse(after);
  if (a.isEncrypted) return after;
  final old = _pageStreams(PdfFile.parse(before));
  final updates = <PdfObject, List<int>>{};
  for (final p in drawnPages) {
    if (p >= a.pages.length || p >= old.length) continue;
    // Özgün akışlar (çözülmüş içerikle) çoklu küme olarak düşülür; kalan
    // yeni akışlardan yalnız q/Q olmayan çizim akışı sarılır.
    final pool = <String, int>{};
    for (final c in old[p]) {
      if (c == null) continue;
      final k = latin1.decode(c);
      pool[k] = (pool[k] ?? 0) + 1;
    }
    var found = false;
    for (final s in a.contentsOf(a.pages[p])) {
      List<int> c;
      try {
        c = a.decodeStream(s);
      } catch (_) {
        continue;
      }
      final k = latin1.decode(c);
      if ((pool[k] ?? 0) > 0) {
        pool[k] = pool[k]! - 1;
        continue;
      }
      final t = k.trim();
      if (t.isEmpty || t == 'q' || t == 'Q') continue;
      updates[s] = [...latin1.encode(_open), ...c, ...latin1.encode('\nEMC\n')];
      found = true;
    }
    if (!found) throw StateError('Üst/alt bilgi akışı bulunamadı (sayfa ${p + 1})');
  }
  return a.writeUpdatedStreams(updates);
}

/// [content] içindeki işaretli blokların `[başlangıç, bitiş)` aralıkları.
/// Dengesiz (EMC'siz) blokta [StateError]: emin olmadan silme yapılmaz.
List<(int, int)> _blocks(List<int> content) {
  final events = scanContent(content).events;
  final out = <(int, int)>[];
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    if (e.op != 'BDC') continue;
    final operands =
        latin1.decode(content.sublist(e.operandStart, e.operatorStart));
    if (!operands.contains('/$_marker')) continue;
    var depth = 0;
    int? end;
    for (var j = i; j < events.length; j++) {
      final op = events[j].op;
      if (op == 'BDC' || op == 'BMC') depth++;
      if (op == 'EMC' && --depth == 0) {
        end = events[j].end;
        i = j;
        break;
      }
    }
    if (end == null) throw StateError('Üst/alt bilgi bloğu kapanmamış');
    out.add((e.operandStart, end));
  }
  return out;
}

/// Belgede işaretli üst/alt bilgi var mı (şifreli belgede hep `false`).
bool hasMarkedHeaderFooter(List<int> bytes) {
  final f = PdfFile.parse(bytes);
  if (f.isEncrypted) return false;
  for (final page in f.pages) {
    for (final s in f.contentsOf(page)) {
      try {
        final c = f.decodeStream(s);
        if (latin1.decode(c).contains('/$_marker') && _blocks(c).isNotEmpty) {
          return true;
        }
      } catch (_) {
        // Bilinçli: çözülemeyen akış / kapanmamış blok "işaret yok" sayılır.
      }
    }
  }
  return false;
}

/// İşaretli blokları tüm sayfalardan çıkarır; yoksa [StateError].
/// Akış başka sayfalarca paylaşılıyorsa bir kez işlenir.
List<int> stripHeaderFooter(List<int> bytes) {
  final f = PdfFile.parse(bytes);
  if (f.isEncrypted) throw StateError('Şifreli belgede kaldırılamaz');
  final updates = <PdfObject, List<int>>{};
  final seen = <int>{};
  for (final page in f.pages) {
    for (final s in f.contentsOf(page)) {
      if (!seen.add(s.number)) continue;
      List<int> c;
      try {
        c = f.decodeStream(s);
      } catch (_) {
        continue;
      }
      if (!latin1.decode(c).contains('/$_marker')) continue;
      final blocks = _blocks(c);
      if (blocks.isEmpty) continue;
      final out = List<int>.of(c);
      for (final (start, end) in blocks.reversed) {
        out.replaceRange(start, end, const <int>[]);
      }
      updates[s] = out;
    }
  }
  if (updates.isEmpty) throw StateError('Üst/alt bilgi yok');
  return f.writeUpdatedStreams(updates);
}
