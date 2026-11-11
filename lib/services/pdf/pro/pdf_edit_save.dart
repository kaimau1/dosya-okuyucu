/// **Düzenleme oturumunun kaydı** (PDF Pro Faz 54 / 3, PK4).
///
/// * **Kaydet** = özgün dosyaya ARTIMLI yaz (özgün baytlar başta aynen durur);
///   yazmadan önce dosyanın o anki hâli sürüm geçmişine girer
///   ([PdfVersionHistory]).
/// * Özgün konum **salt okunursa** kopya kendiliğinden Belgeler'e düşer ve
///   sonuç bunu açıkça söyler ([PdfEditSaveResult.fellBack]).
/// * **Farklı kaydet** = aynı klasör ya da Belgeler.
///
/// Belge yeniden yüklenmez (PK2): PDFium belleğindeki belge açıldığı baytlara
/// dayanır; her kayıt "açılıştaki baytlar + bugüne kadarki değişiklikler"dir,
/// dosya kayıt başına ek biriktirmez.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../docs_home.dart';
import '../../fm/safe_write.dart';
import '../../pdf_save.dart';
import 'pdf_edit_bridge.dart';
import 'pdf_edit_session.dart';
import 'pdf_incremental_trim.dart';
import 'pdf_version_history.dart';

class PdfEditSaveResult {
  /// Yazılan dosya.
  final String path;

  /// Özgünün üstüne mi yazıldı (false = kopya).
  final bool overwritten;

  /// Özgüne yazılamadığı için kopyaya mı düşüldü.
  final bool fellBack;

  /// Yazılan bayt sayısı ve özgüne eklenen kısım.
  final int size, growth;

  const PdfEditSaveResult({
    required this.path,
    required this.overwritten,
    required this.fellBack,
    required this.size,
    required this.growth,
  });
}

class PdfEditSaver {
  PdfEditSaver({
    required this.session,
    required this.path,
    this.password,
    String? tempDir,
  }) : _tempDir = tempDir ?? Directory.systemTemp.path;

  final PdfEditSession session;

  /// Görüntüleyicinin açtığı dosya.
  final String path;

  /// Parolalı belgede yeniden oynatma için (kullanıcının girdiği parola).
  final PdfPasswordProvider? password;

  final String _tempDir;

  /// Belgenin AÇILDIĞI baytların kopyası — ilk üzerine yazmadan önce alınır
  /// (ondan sonra diskteki dosya artık açılış hâli değildir).
  String? _basePath;

  /// Belgenin açıldığı baytlar.
  Future<Uint8List> baseBytes() => File(_basePath ?? path).readAsBytes();

  Future<void> _ensureBase() async {
    if (_basePath != null) return;
    final target = p.join(_tempDir,
        'pdf_edit_base_${DateTime.now().microsecondsSinceEpoch}.pdf');
    await File(path).copy(target);
    _basePath = target;
  }

  /// Düzenlenmiş belgenin baytları: açılış baytları + artımlı ek.
  ///
  /// Oturumda bir sayfa anlık görüntüden geri konduysa ([PdfEditSession
  /// .needsReplay]) canlı belge kaydedilmez: geri konan sayfa yeni bir
  /// nesnedir, eski sayfaya bakan yer imleri boşa düşerdi. Onun yerine
  /// açılış baytları ayrı bir belge olarak açılır ve kalan komutlar sırayla
  /// yeniden oynatılır — çıktı, o komutları hiç geri almadan yapmış bir
  /// oturumun çıktısıyla aynıdır.
  Future<Uint8List> encode() async {
    final live = session.document;
    if (live == null) throw StateError('Oturum bir belgeye bağlı değil.');
    final base = await baseBytes();
    final ops = session.needsReplay ? session.ops : null;
    if (ops == null) return _trimmed(base, await _raw(live));
    final fresh = await PdfDocument.openData(base, passwordProvider: password);
    try {
      for (final op in ops) {
        await op.applyTo(fresh);
      }
      return _trimmed(base, await _raw(fresh));
    } finally {
      await fresh.dispose();
    }
  }

  static Future<Uint8List> _raw(PdfDocument doc) =>
      PdfEditBridge.saveIncremental(doc);

  /// PDFium ekinin kırpılması saf Dart'tır ve büyük belgede ana iş
  /// parçacığını tutardı (30 sn'lik geçici kayıt yazarken takılma) → ayrı
  /// izolatta.
  static Future<Uint8List> _trimmed(Uint8List base, Uint8List saved) =>
      Isolate.run(() => PdfIncrementalTrim.trim(base, saved));

  /// Özgüne artımlı yazar; yazılamıyorsa Belgeler'e kopya.
  Future<PdfEditSaveResult> save() async {
    final bytes = await _checked();
    final baseSize = await File(_basePath ?? path).length();
    try {
      await _ensureBase();
      await PdfVersionHistory.push(path);
      await _overwrite(bytes);
    } on FileSystemException {
      final target = await _documentsTarget();
      await File(target).writeAsBytes(bytes, flush: true);
      return PdfEditSaveResult(
        path: target,
        overwritten: false,
        fellBack: true,
        size: bytes.length,
        growth: bytes.length - baseSize,
      );
    }
    session.markSaved();
    return PdfEditSaveResult(
      path: path,
      overwritten: true,
      fellBack: false,
      size: bytes.length,
      growth: bytes.length - baseSize,
    );
  }

  /// Kopya kaydeder: [documents] false → özgünün klasörü (yazılamıyorsa
  /// Belgeler), true → Belgeler.
  Future<PdfEditSaveResult> saveAs({bool documents = false}) async {
    final bytes = await _checked();
    final baseSize = await File(_basePath ?? path).length();
    final target = documents
        ? await _documentsTarget()
        : await PdfSave.copyTargetFor(path);
    await File(target).writeAsBytes(bytes, flush: true);
    return PdfEditSaveResult(
      path: target,
      overwritten: false,
      fellBack: !documents && p.dirname(target) != p.dirname(path),
      size: bytes.length,
      growth: bytes.length - baseSize,
    );
  }

  Future<Uint8List> _checked() async {
    final bytes = await encode();
    if (!PdfBytesCheck.looksValid(bytes)) {
      throw const FileSystemException(
          'Üretilen PDF geçersiz göründü; dosyaya dokunulmadı');
    }
    return bytes;
  }

  /// Bölünmez yazım; klasöre geçici dosya açılamıyorsa [SafeWrite] doğrudan
  /// yazmayı dener, o da olmazsa [FileSystemException] → çağıran kopyaya düşer.
  Future<void> _overwrite(Uint8List bytes) => SafeWrite.bytes(path, bytes);

  Future<String> _documentsTarget() async {
    final docs = await DocsHome.resolve();
    return PdfSave.copyTargetFor(p.join(docs.path, p.basename(path)));
  }

  /// Açılış baytlarının geçici kopyasını siler.
  Future<void> dispose() async {
    final base = _basePath;
    _basePath = null;
    if (base == null) return;
    try {
      await File(base).delete();
    } catch (_) {
      // Bilinçli: geçici dosya; silinemezse sistem geçici klasörü temizler.
    }
  }
}
